-- Harden IndustryHub account/profile and marketplace workflows.
-- Business-critical state transitions are performed in database functions so
-- they cannot be bypassed by calling Supabase directly from a modified client.

-- Preserve completed deal history while allowing listings to leave the public
-- marketplace without being physically deleted.
alter table public.listings
  add column if not exists status text not null default 'ACTIVE';
alter table public.listings
  drop constraint if exists listings_status_check;
alter table public.listings
  add constraint listings_status_check
  check (status in ('ACTIVE', 'MATCHED', 'WITHDRAWN'));
alter table public.deal_requests
  drop constraint if exists deal_requests_listing_id_fkey;
alter table public.deal_requests
  alter column listing_id drop not null;
alter table public.deal_requests
  add constraint deal_requests_listing_id_fkey
  foreign key (listing_id) references public.listings(id) on delete set null;
alter table public.deal_requests
  drop constraint if exists deal_requests_note_length_check;
alter table public.deal_requests
  add constraint deal_requests_note_length_check
  check (char_length(note) <= 240);
with ranked_pending as (
  select id,
         row_number() over (
           partition by listing_id, requester_id
           order by created_at desc, id desc
         ) as row_number
  from public.deal_requests
  where listing_id is not null and status = 'REQUEST SENT'
)
update public.deal_requests d
set status = 'CANCELLED',
    response_note = 'Duplicate pending request closed during marketplace migration.'
from ranked_pending r
where d.id = r.id and r.row_number > 1;
create unique index if not exists deal_requests_one_pending_per_listing_requester
  on public.deal_requests(listing_id, requester_id)
  where listing_id is not null and status = 'REQUEST SENT';
create index if not exists listings_status_created_at_idx
  on public.listings(status, created_at desc);
-- Create the profile as part of auth-user creation. This also works when email
-- confirmation means there is no authenticated session immediately at signup.
create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_name text;
  v_sector text;
  v_role text;
begin
  v_business_name := coalesce(nullif(btrim(new.raw_user_meta_data ->> 'business_name'), ''), '');
  v_sector := coalesce(nullif(btrim(new.raw_user_meta_data ->> 'sector'), ''), 'General manufacturing');
  v_role := coalesce(nullif(btrim(new.raw_user_meta_data ->> 'role'), ''), '');

  insert into public.profiles (user_id, business_name, sector, role)
  values (new.id, v_business_name, v_sector, v_role)
  on conflict (user_id) do update
  set business_name = case
        when btrim(public.profiles.business_name) = '' then excluded.business_name
        else public.profiles.business_name
      end,
      sector = case
        when btrim(public.profiles.sector) = '' then excluded.sector
        else public.profiles.sector
      end;

  return new;
end;
$$;
drop trigger if exists on_auth_user_created_industryhub_profile on auth.users;
create trigger on_auth_user_created_industryhub_profile
after insert on auth.users
for each row execute function public.handle_new_user_profile();
-- Backfill a missing business name from signup metadata where possible.
update public.profiles p
set business_name = coalesce(nullif(btrim(u.raw_user_meta_data ->> 'business_name'), ''), p.business_name)
from auth.users u
where p.user_id = u.id
  and btrim(p.business_name) = '';
-- A client may edit normal business fields, but must not self-assign trust
-- badges or directly change a listing's marketplace lifecycle state.
revoke insert, update on table public.profiles from authenticated;
grant insert (user_id, business_name, sector, role, msic_code, msic_description)
  on table public.profiles to authenticated;
grant update (business_name, sector, role, msic_code, msic_description)
  on table public.profiles to authenticated;
revoke insert, update on table public.listings from authenticated;
grant insert (
  type, material, quantity, unit, location, description,
  asking_price_per_kg, owner, owner_id
) on table public.listings to authenticated;
grant update (
  type, material, quantity, unit, location, description,
  asking_price_per_kg
) on table public.listings to authenticated;
revoke delete on table public.listings from authenticated;
drop policy if exists listings_select_authenticated on public.listings;
drop policy if exists listings_select_active_or_owner on public.listings;
create policy listings_select_active_or_owner
  on public.listings for select to authenticated
  using (status = 'ACTIVE' or auth.uid() = owner_id);
drop policy if exists listings_update_own on public.listings;
drop policy if exists listings_delete_own on public.listings;
create policy listings_update_active_own
  on public.listings for update to authenticated
  using (auth.uid() = owner_id and status = 'ACTIVE')
  with check (auth.uid() = owner_id and status = 'ACTIVE');
create or replace function public.set_listing_business_identity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_name text;
  v_verified boolean;
begin
  select business_name, verified into v_business_name, v_verified
  from public.profiles
  where user_id = new.owner_id;

  if not found or btrim(v_business_name) = '' then
    raise exception 'Complete your business profile before publishing a listing.';
  end if;

  new.owner := v_business_name;
  new.verified := coalesce(v_verified, false);
  return new;
end;
$$;
drop trigger if exists listings_set_business_identity on public.listings;
create trigger listings_set_business_identity
before insert on public.listings
for each row execute function public.set_listing_business_identity();
update public.listings l
set owner = p.business_name,
    verified = p.verified
from public.profiles p
where l.owner_id = p.user_id
  and btrim(p.business_name) <> ''
  and (l.owner is distinct from p.business_name
       or l.verified is distinct from p.verified);
create or replace function public.sync_business_identity_to_listings()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.business_name is distinct from old.business_name
     or new.verified is distinct from old.verified then
    update public.listings
    set owner = new.business_name,
        verified = new.verified
    where owner_id = new.user_id;
  end if;
  return new;
end;
$$;
drop trigger if exists profiles_sync_business_name_to_listings on public.profiles;
drop trigger if exists profiles_sync_business_identity_to_listings on public.profiles;
create trigger profiles_sync_business_identity_to_listings
after update of business_name, verified on public.profiles
for each row execute function public.sync_business_identity_to_listings();
-- Deal requests are read through RLS but created/transitioned only through the
-- validated functions below.
revoke insert, update, delete on table public.deal_requests from authenticated;
grant select on table public.deal_requests to authenticated;
drop policy if exists deal_requests_select_own on public.deal_requests;
drop policy if exists deal_requests_select_requester_or_owner on public.deal_requests;
drop policy if exists deal_requests_insert_own on public.deal_requests;
drop policy if exists deal_requests_update_own on public.deal_requests;
drop policy if exists deal_requests_update_requester_or_owner on public.deal_requests;
create policy deal_requests_select_requester_or_owner
  on public.deal_requests for select to authenticated
  using (auth.uid() = requester_id or auth.uid() = listing_owner_id);
create or replace function public.create_deal_request(
  p_listing_id uuid,
  p_note text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_listing public.listings%rowtype;
  v_profile public.profiles%rowtype;
  v_request public.deal_requests%rowtype;
  v_note text := btrim(coalesce(p_note, ''));
begin
  if v_user_id is null then
    raise exception 'Sign in before sending a deal request.';
  end if;

  if char_length(v_note) > 240 then
    raise exception 'Deal request message must be 240 characters or fewer.';
  end if;

  select * into v_listing
  from public.listings
  where id = p_listing_id
    and status = 'ACTIVE'
  for update;

  if not found then
    raise exception 'This listing is no longer available.';
  end if;

  if v_listing.owner_id = v_user_id then
    raise exception 'You cannot send a request to your own listing.';
  end if;

  select * into v_profile
  from public.profiles
  where user_id = v_user_id;

  if not found
     or btrim(v_profile.business_name) = ''
     or btrim(v_profile.sector) = '' then
    raise exception 'Complete your business name and industry sector before sending a deal request.';
  end if;

  insert into public.deal_requests (
    listing_id,
    requester_id,
    listing_owner_id,
    material,
    owner,
    requester_name,
    location,
    quantity,
    note,
    status,
    response_note
  ) values (
    v_listing.id,
    v_user_id,
    v_listing.owner_id,
    v_listing.material,
    v_listing.owner,
    v_profile.business_name,
    v_listing.location,
    v_listing.quantity::text || ' ' || v_listing.unit,
    v_note,
    'REQUEST SENT',
    ''
  )
  returning * into v_request;

  return to_jsonb(v_request);
exception
  when unique_violation then
    raise exception 'You already have a pending request for this listing.';
end;
$$;
create or replace function public.cancel_deal_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_updated_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sign in before cancelling a deal request.';
  end if;

  update public.deal_requests
  set status = 'CANCELLED', response_note = ''
  where id = p_request_id
    and requester_id = v_user_id
    and status = 'REQUEST SENT'
  returning id into v_updated_id;

  if v_updated_id is null then
    raise exception 'This request is no longer pending and cannot be cancelled.';
  end if;
end;
$$;
create or replace function public.respond_to_deal_request(
  p_request_id uuid,
  p_accept boolean,
  p_reason text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_request public.deal_requests%rowtype;
  v_listing public.listings%rowtype;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if v_user_id is null then
    raise exception 'Sign in before responding to a deal request.';
  end if;

  if char_length(v_reason) > 240 then
    raise exception 'Response note must be 240 characters or fewer.';
  end if;

  -- Read the request first without locking it. Accept operations then lock the
  -- listing before any request row, giving all concurrent acceptances the same
  -- lock order and preventing two winners/deadlocks.
  select * into v_request
  from public.deal_requests
  where id = p_request_id
    and listing_owner_id = v_user_id;

  if not found or v_request.status <> 'REQUEST SENT' then
    raise exception 'This request is no longer pending.';
  end if;

  if p_accept then
    if v_request.listing_id is null then
      raise exception 'The listing for this request no longer exists.';
    end if;

    select * into v_listing
    from public.listings
    where id = v_request.listing_id
      and owner_id = v_user_id
      and status = 'ACTIVE'
    for update;

    if not found then
      raise exception 'This listing is no longer available to accept.';
    end if;

    -- Re-check the request after obtaining the listing lock. It may have been
    -- cancelled while this response was waiting.
    select * into v_request
    from public.deal_requests
    where id = p_request_id
      and listing_owner_id = v_user_id
      and status = 'REQUEST SENT'
    for update;

    if not found then
      raise exception 'This request is no longer pending.';
    end if;

    update public.deal_requests
    set status = 'ACCEPTED', response_note = ''
    where id = p_request_id;

    update public.deal_requests
    set status = 'REJECTED',
        response_note = 'This listing was accepted by another business and is no longer available.'
    where listing_id = v_request.listing_id
      and id <> p_request_id
      and status = 'REQUEST SENT';

    update public.listings
    set status = 'MATCHED'
    where id = v_request.listing_id;
  else
    select * into v_request
    from public.deal_requests
    where id = p_request_id
      and listing_owner_id = v_user_id
      and status = 'REQUEST SENT'
    for update;

    if not found then
      raise exception 'This request is no longer pending.';
    end if;

    update public.deal_requests
    set status = 'REJECTED', response_note = v_reason
    where id = p_request_id;
  end if;
end;
$$;
create or replace function public.withdraw_listing(p_listing_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_listing_id uuid;
begin
  if v_user_id is null then
    raise exception 'Sign in before removing a listing.';
  end if;

  update public.listings
  set status = 'WITHDRAWN'
  where id = p_listing_id
    and owner_id = v_user_id
    and status = 'ACTIVE'
  returning id into v_listing_id;

  if v_listing_id is null then
    raise exception 'This listing is no longer active or does not belong to you.';
  end if;

  update public.deal_requests
  set status = 'REJECTED',
      response_note = 'The listing owner withdrew this listing before a deal was completed.'
  where listing_id = p_listing_id
    and status = 'REQUEST SENT';
end;
$$;
revoke all on function public.create_deal_request(uuid, text) from public;
revoke all on function public.cancel_deal_request(uuid) from public;
revoke all on function public.respond_to_deal_request(uuid, boolean, text) from public;
revoke all on function public.withdraw_listing(uuid) from public;
grant execute on function public.create_deal_request(uuid, text) to authenticated;
grant execute on function public.cancel_deal_request(uuid) to authenticated;
grant execute on function public.respond_to_deal_request(uuid, boolean, text) to authenticated;
grant execute on function public.withdraw_listing(uuid) to authenticated;
