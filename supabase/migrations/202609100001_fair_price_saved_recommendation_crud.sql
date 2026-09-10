alter table public.fair_price_sessions
  add column if not exists material_category text not null default '',
  add column if not exists confidence numeric(5, 2),
  add column if not exists peer_observation_count integer not null default 0,
  add column if not exists notes text not null default '',
  add column if not exists updated_at timestamptz not null default timezone('utc', now());

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists fair_price_sessions_set_updated_at on public.fair_price_sessions;
create trigger fair_price_sessions_set_updated_at
before update on public.fair_price_sessions
for each row
execute function public.set_updated_at();

alter table public.fair_price_sessions enable row level security;

drop policy if exists fair_price_sessions_select_own on public.fair_price_sessions;
create policy fair_price_sessions_select_own on public.fair_price_sessions
for select to authenticated
using (auth.uid() = user_id);

drop policy if exists fair_price_sessions_insert_own on public.fair_price_sessions;
create policy fair_price_sessions_insert_own on public.fair_price_sessions
for insert to authenticated
with check (auth.uid() = user_id);

drop policy if exists fair_price_sessions_update_own on public.fair_price_sessions;
create policy fair_price_sessions_update_own on public.fair_price_sessions
for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists fair_price_sessions_delete_own on public.fair_price_sessions;
create policy fair_price_sessions_delete_own on public.fair_price_sessions
for delete to authenticated
using (auth.uid() = user_id);

grant select, insert, update, delete on public.fair_price_sessions to authenticated;
