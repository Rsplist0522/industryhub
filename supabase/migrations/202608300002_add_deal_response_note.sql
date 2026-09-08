-- Store the listing owner's optional reason when declining a deal request.

alter table public.deal_requests
  add column if not exists response_note text not null default '';

drop policy if exists deal_requests_update_own on public.deal_requests;
drop policy if exists deal_requests_update_requester_or_owner on public.deal_requests;
create policy deal_requests_update_requester_or_owner
  on public.deal_requests for update to authenticated
  using (auth.uid() = requester_id or auth.uid() = listing_owner_id)
  with check (auth.uid() = requester_id or auth.uid() = listing_owner_id);