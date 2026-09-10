-- Add persistent per-user read state for marketplace deal notifications.
-- Each deal request can be viewed by the requester and the listing owner, so
-- read state is tracked separately for both sides.

alter table public.deal_requests
  add column if not exists requester_read_at timestamptz,
  add column if not exists owner_read_at timestamptz;

-- Existing requests were already visible before this notification centre was
-- introduced. Mark the requester's initial "request sent" state as read so it
-- does not appear as a new notification for an action they performed themself.
update public.deal_requests
set requester_read_at = coalesce(requester_read_at, created_at)
where status = 'REQUEST SENT';

-- New requests should notify the listing owner, but not the requester who just
-- sent the request.
create or replace function public.set_deal_request_notification_state()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    new.requester_read_at := coalesce(new.requester_read_at, now());
    new.owner_read_at := null;
    return new;
  end if;

  if new.status is distinct from old.status then
    if new.status in ('ACCEPTED', 'REJECTED') then
      -- A final owner response is new information for the requester.
      new.requester_read_at := null;
    elsif new.status = 'CANCELLED' then
      -- Cancellation is new information for the listing owner.
      new.owner_read_at := null;
      -- The requester initiated the cancellation, so it is already read by
      -- that requester.
      new.requester_read_at := coalesce(new.requester_read_at, now());
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists deal_requests_notification_state on public.deal_requests;
create trigger deal_requests_notification_state
before insert or update of status on public.deal_requests
for each row execute function public.set_deal_request_notification_state();

-- Mark one notification as read for the listing owner.
create or replace function public.mark_deal_request_owner_read(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in before viewing notifications.';
  end if;

  update public.deal_requests
  set owner_read_at = now()
  where id = p_request_id
    and listing_owner_id = auth.uid();

  if not found then
    raise exception 'Notification could not be found.';
  end if;
end;
$$;

-- Mark one notification as read for the requester.
create or replace function public.mark_deal_request_requester_read(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Sign in before viewing notifications.';
  end if;

  update public.deal_requests
  set requester_read_at = now()
  where id = p_request_id
    and requester_id = auth.uid();

  if not found then
    raise exception 'Notification could not be found.';
  end if;
end;
$$;

revoke all on function public.mark_deal_request_owner_read(uuid) from public;
revoke all on function public.mark_deal_request_requester_read(uuid) from public;
grant execute on function public.mark_deal_request_owner_read(uuid) to authenticated;
grant execute on function public.mark_deal_request_requester_read(uuid) to authenticated;
