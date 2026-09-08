-- Store the listing owner's optional reason when declining a deal request.

alter table public.deal_requests
  add column if not exists response_note text not null default '';
