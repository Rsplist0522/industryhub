-- Allow both sides of a deal request to see the request and update only the
-- status they are authorised to change.

alter table public.deal_requests
  add column if not exists requester_name text not null default 'A ReSource business';

alter table public.deal_requests
  add column if not exists response_note text not null default '';

create index if not exists deal_requests_listing_owner_id_idx
  on public.deal_requests(listing_owner_id, created_at desc);

drop policy if exists deal_requests_select_requester_or_owner on public.deal_requests;
create policy deal_requests_select_requester_or_owner
  on public.deal_requests for select to authenticated
  using (auth.uid() = requester_id or auth.uid() = listing_owner_id);

drop policy if exists deal_requests_update_requester_or_owner on public.deal_requests;
create policy deal_requests_update_requester_or_owner
  on public.deal_requests for update to authenticated
  using (auth.uid() = requester_id or auth.uid() = listing_owner_id)
  with check (auth.uid() = requester_id or auth.uid() = listing_owner_id);

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'deal_requests'
  ) then
    alter publication supabase_realtime add table public.deal_requests;
  end if;
end;
$$;