-- Persistent SkillMatch saves and FairPrice sessions for existing deployments.
-- Safe to run after the core migration.

alter table public.profiles alter column business_name drop default;
alter table public.profiles alter column sector drop default;
alter table public.profiles alter column role drop default;

create table if not exists public.saved_matches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  programme_id text not null,
  programme_name text not null,
  provider text not null default '',
  source_url text not null default '',
  source_name text not null default '',
  created_at timestamptz not null default timezone('utc', now()),
  unique (user_id, programme_id)
);

create table if not exists public.fair_price_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product text not null,
  quantity numeric(14, 2) not null check (quantity > 0),
  proposed_price numeric(18, 4) not null check (proposed_price > 0),
  floor_price numeric(18, 4) not null check (floor_price >= 0),
  target_price numeric(18, 4) not null check (target_price >= 0),
  ceiling_price numeric(18, 4) not null check (ceiling_price >= 0),
  condition text not null,
  collection_terms text not null,
  strategy text not null,
  has_live_evidence boolean not null default false,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists saved_matches_user_id_idx on public.saved_matches(user_id, created_at desc);
create index if not exists fair_price_sessions_user_id_idx on public.fair_price_sessions(user_id, created_at desc);

alter table public.saved_matches enable row level security;
alter table public.fair_price_sessions enable row level security;

drop policy if exists saved_matches_select_own on public.saved_matches;
create policy saved_matches_select_own on public.saved_matches for select to authenticated using (auth.uid() = user_id);
drop policy if exists saved_matches_insert_own on public.saved_matches;
create policy saved_matches_insert_own on public.saved_matches for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists saved_matches_delete_own on public.saved_matches;
create policy saved_matches_delete_own on public.saved_matches for delete to authenticated using (auth.uid() = user_id);

drop policy if exists fair_price_sessions_select_own on public.fair_price_sessions;
create policy fair_price_sessions_select_own on public.fair_price_sessions for select to authenticated using (auth.uid() = user_id);
drop policy if exists fair_price_sessions_insert_own on public.fair_price_sessions;
create policy fair_price_sessions_insert_own on public.fair_price_sessions for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists fair_price_sessions_delete_own on public.fair_price_sessions;
create policy fair_price_sessions_delete_own on public.fair_price_sessions for delete to authenticated using (auth.uid() = user_id);

drop policy if exists deal_requests_update_own on public.deal_requests;
create policy deal_requests_update_own on public.deal_requests for update to authenticated using (auth.uid() = requester_id) with check (auth.uid() = requester_id);
