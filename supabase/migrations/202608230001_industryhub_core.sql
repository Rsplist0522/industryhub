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

-- Keep an existing compatible schema usable when this migration is added later.
alter table public.profiles add column if not exists msic_code text;
alter table public.profiles add column if not exists msic_description text;
alter table public.profiles add column if not exists verified boolean not null default false;
alter table public.profiles add column if not exists created_at timestamptz not null default timezone('utc', now());
alter table public.profiles add column if not exists updated_at timestamptz not null default timezone('utc', now());

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

insert into public.data_sources (id, module_key, name, access_type, source_url, requires_api_key, license, notes, last_verified_at)
values
  ('skillmatch-upskill-malaysia', 'skill_match', 'Upskill Malaysia / HRD Corp course catalogue', 'Public catalogue import', 'https://upskillmalaysia.gov.my/', false, null, 'Use as the operator-maintained source for programme catalogue seeding; do not scrape on every mobile launch without a stable export.', '2026-08-23'),
  ('fairprice-world-bank-pink-sheet', 'fair_price', 'World Bank Commodity Price Data (Pink Sheet)', 'Public XLSX download', 'https://thedocs.worldbank.org/en/doc/5d903e848db1d1b83e0ec8f744e55570-0350012021/related/CMO-Historical-Data-Monthly.xlsx', false, 'World Bank open data terms', 'Global aluminium, copper, and iron ore reference series in USD; use for trend context, not direct RM/kg quotes.', '2026-08-23'),
  ('fairprice-malaysia-ppi', 'fair_price', 'Malaysia Producer Price Index', 'Public CSV / Open API', 'https://data.gov.my/data-catalogue/ppi', false, 'CC BY 4.0', 'Monthly ex-factory producer-price index from DOSM; recent months may be revised.', '2026-08-23'),
  ('resource-profile-msic', 'resource_profile', 'Malaysia Standard Industrial Classification 2008', 'Public CSV / Open API', 'https://data.gov.my/data-catalogue/msic', false, 'CC BY 4.0', 'DOSM classification lookup for structured business-sector selection.', '2026-08-23'),
  ('marketplace-state-industry-context', 'marketplace', 'Malaysia state manufacturing context', 'Public Open API', 'https://api.data.gov.my/data-catalogue?id=gdp_state_real_supply', false, 'CC BY 4.0', 'Contextual state manufacturing activity shown alongside user-generated marketplace listings.', '2026-08-23')
on conflict (id) do update set
  name = excluded.name,
  access_type = excluded.access_type,
  source_url = excluded.source_url,
  requires_api_key = excluded.requires_api_key,
  license = excluded.license,
  notes = excluded.notes,
  last_verified_at = excluded.last_verified_at;

insert into public.training_programmes (id, name, provider, skills, level, duration_days, source_name, source_url, credential, summary)
values
  ('cnc-setup', 'CNC Programming & Setup', 'Penang Skills Development Centre', '{"CNC machining","Production planning"}', 'Intermediate', 3, 'Upskill Malaysia / HRD Corp', 'https://upskillmalaysia.gov.my/', 'Practical setup competency', 'Builds confidence in machine setup, tool offsets, safe operation, and basic programme adjustment.'),
  ('lean-essentials', 'Lean Manufacturing Essentials', 'Malaysia Productivity Corporation', '{"Lean manufacturing","Production planning"}', 'Foundation', 2, 'Upskill Malaysia / HRD Corp', 'https://upskillmalaysia.gov.my/', 'Continuous-improvement toolkit', 'Introduces visual management, waste reduction, and practical improvement routines for production teams.'),
  ('quality-systems', 'Industrial Quality Systems', 'SIRIM Academy', '{"Quality systems","Production planning"}', 'Intermediate', 4, 'Upskill Malaysia / HRD Corp', 'https://upskillmalaysia.gov.my/', 'Quality systems evidence', 'Covers process controls, internal quality checks, traceability, and non-conformance handling.'),
  ('welding-safety', 'Welding Process & Workplace Safety', 'Skills Training Centre Catalogue', '{"Welding","Occupational safety"}', 'Foundation', 3, 'Upskill Malaysia / HRD Corp', 'https://upskillmalaysia.gov.my/', 'Safety and process evidence', 'Supports safe preparation, process discipline, and basic quality checks for welding work.'),
  ('supervision', 'Production Team Supervision', 'Manufacturing Leadership Catalogue', '{"Team supervision","Production planning","Lean manufacturing"}', 'Intermediate', 2, 'Upskill Malaysia / HRD Corp', 'https://upskillmalaysia.gov.my/', 'Supervisor action plan', 'Helps emerging supervisors coordinate shifts, coach workers, and manage daily production priorities.')
on conflict (id) do update set
  name = excluded.name,
  provider = excluded.provider,
  skills = excluded.skills,
  level = excluded.level,
  duration_days = excluded.duration_days,
  source_name = excluded.source_name,
  source_url = excluded.source_url,
  credential = excluded.credential,
  summary = excluded.summary,
  is_active = true;

insert into public.msic_codes (item_code, digits, section, description_en, description_bm)
values
  ('A', 1, 'A', 'Agriculture, forestry and fishing', 'Pertanian, Perhutanan dan Perikanan'),
  ('B', 1, 'B', 'Mining and quarrying', 'Perlombongan dan Pengkuarian'),
  ('C', 1, 'C', 'Manufacturing', 'Pembuatan'),
  ('D', 1, 'D', 'Electricity, gas, steam and air conditioning supply', 'Bekalan elektrik, gas, wap dan pendingin udara'),
  ('E', 1, 'E', 'Water supply; sewerage, waste management and remediation activities', 'Bekalan air; pembentungan, pengurusan sisa dan aktiviti pemulihan'),
  ('F', 1, 'F', 'Construction', 'Pembinaan'),
  ('G', 1, 'G', 'Wholesale and retail trade; repair of motor vehicles and motorcycles', 'Perdagangan borong dan runcit; pembaikan kenderaan bermotor dan motosikal'),
  ('H', 1, 'H', 'Transportation and storage', 'Pengangkutan dan penyimpanan'),
  ('J', 1, 'J', 'Information and communication', 'Maklumat dan komunikasi'),
  ('M', 1, 'M', 'Professional, scientific and technical activities', 'Aktiviti profesional, saintifik dan teknikal'),
  ('N', 1, 'N', 'Administrative and support service activities', 'Aktiviti pentadbiran dan khidmat sokongan')
on conflict (item_code) do update set
  description_en = excluded.description_en,
  description_bm = excluded.description_bm;

insert into public.commodity_price_observations (source_name, source_url, series_name, observed_on, value, unit, currency, source_updated_at)
values
  ('World Bank Commodity Price Data (Pink Sheet)', 'https://thedocs.worldbank.org/en/doc/5d903e848db1d1b83e0ec8f744e55570-0350012021/related/CMO-Historical-Data-Monthly.xlsx', 'Aluminum', '2024-12-01', 2541.02, 'USD/mt', 'USD', '2025-01-03'),
  ('World Bank Commodity Price Data (Pink Sheet)', 'https://thedocs.worldbank.org/en/doc/5d903e848db1d1b83e0ec8f744e55570-0350012021/related/CMO-Historical-Data-Monthly.xlsx', 'Copper', '2024-12-01', 8916.32, 'USD/mt', 'USD', '2025-01-03'),
  ('World Bank Commodity Price Data (Pink Sheet)', 'https://thedocs.worldbank.org/en/doc/5d903e848db1d1b83e0ec8f744e55570-0350012021/related/CMO-Historical-Data-Monthly.xlsx', 'Iron ore, cfr spot', '2024-12-01', 102.21, 'USD/dmtu', 'USD', '2025-01-03')
on conflict (source_name, series_name, observed_on) do update set
  value = excluded.value,
  unit = excluded.unit,
  source_updated_at = excluded.source_updated_at;

insert into public.price_index_observations (source_name, source_url, dataset_id, series, observed_on, index_value, base_year)
values
  ('Department of Statistics Malaysia', 'https://data.gov.my/data-catalogue/ppi', 'ppi', 'abs', '2026-06-01', 125.6, 2010)
on conflict (dataset_id, series, observed_on) do update set
  index_value = excluded.index_value;

insert into public.industry_context_observations (source_name, source_url, state, sector, series, observed_on, value)
values
  ('Department of Statistics Malaysia', 'https://api.data.gov.my/data-catalogue?id=gdp_state_real_supply', 'Pulau Pinang', 'p3', 'abs', '2025-01-01', 61658.978)
on conflict (state, sector, series, observed_on) do update set
  value = excluded.value;

alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.deal_requests enable row level security;
alter table public.training_programmes enable row level security;
alter table public.msic_codes enable row level security;
alter table public.data_sources enable row level security;
alter table public.commodity_price_observations enable row level security;
alter table public.price_index_observations enable row level security;
alter table public.industry_context_observations enable row level security;

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
