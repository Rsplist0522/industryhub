
comment on column public.profiles.verified is
  'IndustryHub business verification status. Separate from Supabase Auth email confirmation and not client-writable.';

revoke insert, update on table public.profiles from authenticated;
revoke insert (verified), update (verified)
  on table public.profiles from authenticated, anon;
grant insert (user_id, business_name, sector, role, msic_code, msic_description)
  on table public.profiles to authenticated;
grant update (business_name, sector, role, msic_code, msic_description)
  on table public.profiles to authenticated;

create or replace function public.prevent_client_business_verification_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if current_user in ('anon', 'authenticated') then
    if (tg_op = 'INSERT' and new.verified is distinct from false)
       or (tg_op = 'UPDATE' and new.verified is distinct from old.verified) then
      raise exception using
        errcode = '42501',
        message = 'Business verification can only be changed by an authorised administrator.';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.prevent_client_business_verification_change()
  from public, anon, authenticated;

drop trigger if exists profiles_protect_business_verification
  on public.profiles;
create trigger profiles_protect_business_verification
before insert or update of verified on public.profiles
for each row execute function public.prevent_client_business_verification_change();

create or replace function public.handle_new_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_business_name text;
  v_sector text;
  v_role text;
begin
  v_business_name := coalesce(
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'business_name'), ''),
    ''
  );
  v_sector := coalesce(
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'sector'), ''),
    'General manufacturing'
  );
  v_role := coalesce(
    nullif(pg_catalog.btrim(new.raw_user_meta_data ->> 'role'), ''),
    ''
  );

  insert into public.profiles (user_id, business_name, sector, role)
  values (new.id, v_business_name, v_sector, v_role)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

revoke all on function public.handle_new_user_profile()
  from public, anon, authenticated;
