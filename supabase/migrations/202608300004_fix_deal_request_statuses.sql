-- Keep the database status values aligned with the marketplace workflow.

alter table public.deal_requests
  drop constraint if exists deal_requests_status_check;

alter table public.deal_requests
  drop constraint if exists dedal_requests_status_check;

alter table public.deal_requests
  add constraint deal_requests_status_check
  check (status in ('REQUEST SENT', 'ACCEPTED', 'REJECTED', 'CANCELLED'));