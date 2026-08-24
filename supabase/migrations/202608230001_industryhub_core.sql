-- IndustryHub core schema and starter datasets.
-- Run with: supabase db push
-- The migration is safe to run more than once.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  business_name text not null default 'Kencana Precision Works',
  sector text not null default 'Precision manufacturing',
  role text not null default 'Factory owner',
  msic_code text,
  msic_description text,
  verified boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('supply', 'demand')),
  material text not null,
  quantity numeric(14, 2) not null check (quantity > 0),
  unit text not null default 'kg',
  location text not null,
  description text not null default '',
  asking_price_per_kg numeric(18, 4) check (asking_price_per_kg is null or asking_price_per_kg >= 0),
  owner text not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  verified boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.deal_requests (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,
  listing_owner_id uuid not null references auth.users(id) on delete cascade,
  material text not null,
  owner text not null,
  location text not null,
  quantity text not null,
  note text not null default '',
  status text not null default 'REQUEST SENT',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.training_programmes (
  id text primary key,
  name text not null,
  provider text not null,
  skills text[] not null default '{}',
  level text not null default 'Unspecified level',
  duration_days integer not null default 0 check (duration_days >= 0),
  source_name text not null default 'Upskill Malaysia / HRD Corp',
  source_url text not null default 'https://upskillmalaysia.gov.my/',
  credential text not null default '',
  summary text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.msic_codes (
  item_code text primary key,
  digits integer not null,
  section text not null,
  division text not null default '-',
  group_code text not null default '-',
  class_code text not null default '-',
  description_en text not null,
  description_bm text not null default '',
  source_name text not null default 'Department of Statistics Malaysia',
  source_url text not null default 'https://data.gov.my/data-catalogue/msic',
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.data_sources (
  id text primary key,
  module_key text not null check (module_key in ('skill_match', 'fair_price', 'resource_profile', 'marketplace')),
  name text not null,
  access_type text not null,
  source_url text not null,
  requires_api_key boolean not null default false,
  license text,
  notes text not null default '',
  last_verified_at date,
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.commodity_price_observations (
  id uuid primary key default gen_random_uuid(),
  source_name text not null,
  source_url text not null,
  series_name text not null,
  observed_on date not null,
  value numeric(18, 6) not null,
  unit text not null,
  currency text not null default 'USD',
  source_updated_at date,
  created_at timestamptz not null default timezone('utc', now()),
  unique (source_name, series_name, observed_on)
);

create table if not exists public.price_index_observations (
  id uuid primary key default gen_random_uuid(),
  source_name text not null,
  source_url text not null,
  dataset_id text not null,
  series text not null,
  observed_on date not null,
  index_value numeric(18, 6) not null,
  base_year integer not null default 2010,
  created_at timestamptz not null default timezone('utc', now()),
  unique (dataset_id, series, observed_on)
);

create table if not exists public.industry_context_observations (
  id uuid primary key default gen_random_uuid(),
  source_name text not null,
  source_url text not null,
  state text not null,
  sector text not null,
  series text not null,
  observed_on date not null,
  value numeric(18, 6) not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (state, sector, series, observed_on)
);

create table if not exists public.workforce_skill_signals (
  id uuid primary key default gen_random_uuid(),
  source_name text not null,
  source_url text not null,
  dataset_id text not null,
  variable text not null,
  age_group text not null,
  observed_on date not null,
  signal_value numeric(18, 6) not null,
  unit text not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (dataset_id, variable, age_group, observed_on)
);

-- Keep an existing compatible schema usable when this migration is added later.
alter table public.profiles add column if not exists msic_code text;
alter table public.profiles add column if not exists msic_description text;
alter table public.profiles add column if not exists verified boolean not null default false;
alter table public.profiles add column if not exists created_at timestamptz not null default timezone('utc', now());
alter table public.profiles add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table public.listings add column if not exists asking_price_per_kg numeric(18, 4);
alter table public.listings add column if not exists verified boolean not null default false;
alter table public.listings add column if not exists created_at timestamptz not null default timezone('utc', now());
alter table public.listings add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table public.deal_requests add column if not exists status text not null default 'REQUEST SENT';
alter table public.deal_requests add column if not exists created_at timestamptz not null default timezone('utc', now());
alter table public.deal_requests add column if not exists updated_at timestamptz not null default timezone('utc', now());

alter table public.training_programmes add column if not exists name text not null default 'Unnamed programme';
alter table public.training_programmes add column if not exists provider text not null default 'Unspecified provider';
alter table public.training_programmes add column if not exists skills text[] not null default '{}';
alter table public.training_programmes add column if not exists level text not null default 'Unspecified level';
alter table public.training_programmes add column if not exists duration_days integer not null default 0;
alter table public.training_programmes add column if not exists source_name text not null default 'Upskill Malaysia / HRD Corp';
alter table public.training_programmes add column if not exists source_url text not null default 'https://upskillmalaysia.gov.my/';
alter table public.training_programmes add column if not exists credential text not null default '';
alter table public.training_programmes add column if not exists summary text not null default '';
alter table public.training_programmes add column if not exists is_active boolean not null default true;
alter table public.training_programmes add column if not exists created_at timestamptz not null default timezone('utc', now());
alter table public.training_programmes add column if not exists updated_at timestamptz not null default timezone('utc', now());

create index if not exists listings_owner_id_idx on public.listings(owner_id);
create index if not exists listings_type_location_idx on public.listings(type, location);
create index if not exists deal_requests_requester_id_idx on public.deal_requests(requester_id, created_at desc);
create index if not exists training_programmes_active_idx on public.training_programmes(is_active);
create index if not exists msic_codes_description_idx on public.msic_codes using gin (to_tsvector('simple', description_en));
create index if not exists commodity_price_series_idx on public.commodity_price_observations(series_name, observed_on desc);
create index if not exists industry_context_state_idx on public.industry_context_observations(state, observed_on desc);
create index if not exists workforce_skill_signals_latest_idx on public.workforce_skill_signals(observed_on desc, variable);

 drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

 drop trigger if exists listings_set_updated_at on public.listings;
create trigger listings_set_updated_at before update on public.listings
for each row execute function public.set_updated_at();

 drop trigger if exists deal_requests_set_updated_at on public.deal_requests;
create trigger deal_requests_set_updated_at before update on public.deal_requests
for each row execute function public.set_updated_at();

 drop trigger if exists training_programmes_set_updated_at on public.training_programmes;
create trigger training_programmes_set_updated_at before update on public.training_programmes
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.deal_requests enable row level security;
alter table public.training_programmes enable row level security;
alter table public.msic_codes enable row level security;
alter table public.data_sources enable row level security;
alter table public.commodity_price_observations enable row level security;
alter table public.price_index_observations enable row level security;
alter table public.industry_context_observations enable row level security;
alter table public.workforce_skill_signals enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated using (auth.uid() = user_id);
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists listings_select_authenticated on public.listings;
create policy listings_select_authenticated on public.listings for select to authenticated using (true);
drop policy if exists listings_insert_own on public.listings;
create policy listings_insert_own on public.listings for insert to authenticated with check (auth.uid() = owner_id);
drop policy if exists listings_update_own on public.listings;
create policy listings_update_own on public.listings for update to authenticated using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
drop policy if exists listings_delete_own on public.listings;
create policy listings_delete_own on public.listings for delete to authenticated using (auth.uid() = owner_id);

drop policy if exists deal_requests_select_own on public.deal_requests;
create policy deal_requests_select_own on public.deal_requests for select to authenticated using (auth.uid() = requester_id);
drop policy if exists deal_requests_insert_own on public.deal_requests;
create policy deal_requests_insert_own on public.deal_requests for insert to authenticated with check (auth.uid() = requester_id);

drop policy if exists training_programmes_select_active on public.training_programmes;
create policy training_programmes_select_active on public.training_programmes for select to authenticated using (is_active = true);
drop policy if exists msic_codes_select_authenticated on public.msic_codes;
create policy msic_codes_select_authenticated on public.msic_codes for select to authenticated using (true);
drop policy if exists data_sources_select_authenticated on public.data_sources;
create policy data_sources_select_authenticated on public.data_sources for select to authenticated using (true);
drop policy if exists commodity_price_observations_select_authenticated on public.commodity_price_observations;
create policy commodity_price_observations_select_authenticated on public.commodity_price_observations for select to authenticated using (true);
drop policy if exists price_index_observations_select_authenticated on public.price_index_observations;
create policy price_index_observations_select_authenticated on public.price_index_observations for select to authenticated using (true);
drop policy if exists industry_context_observations_select_authenticated on public.industry_context_observations;
create policy industry_context_observations_select_authenticated on public.industry_context_observations for select to authenticated using (true);
drop policy if exists workforce_skill_signals_select_authenticated on public.workforce_skill_signals;
create policy workforce_skill_signals_select_authenticated on public.workforce_skill_signals for select to authenticated using (true);
