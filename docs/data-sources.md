# IndustryHub data-source map

IndustryHub now gives every module a named source and stores source provenance in Supabase. Public sources do not require an API key. The migration seeds a snapshot so the app works after one database migration; a secure server-side refresh job can update those snapshots later.

| Module | Dataset/source | How the app uses it | Key required | Freshness / limitation |
| --- | --- | --- | --- | --- |
| **SkillMatch** | [Upskill Malaysia / HRD Corp](https://upskillmalaysia.gov.my/) | Seeds and attributes the `training_programmes` catalogue used for matching workforce briefs. | No | The public course page was verified, but a stable public export/API was not. Current records are curated/imported seed data. |
| **FairPrice** | [World Bank Commodity Price Data](https://thedocs.worldbank.org/en/doc/5d903e848db1d1b83e0ec8f744e55570-0350012021/related/CMO-Historical-Data-Monthly.xlsx) | Shows aluminium, copper, or iron-ore global reference observations alongside the in-app indicative negotiation band. | No | Global USD reference series; not a direct Malaysian scrap quote. The migration seed is a historical snapshot. |
| **FairPrice** | [Malaysia Producer Price Index](https://data.gov.my/data-catalogue/ppi) | Shows Malaysia’s producer-price index context with the source base year and observation month. | No | Monthly ex-factory index; recent observations may be revised and it is not a material-specific RM/kg quote. |
| **ReSource Profile** | [Malaysia Standard Industrial Classification 2008](https://data.gov.my/data-catalogue/msic) | Supplies official top-level industry-sector choices and saves the selected MSIC code with the profile. | No | Classification lookup, not business-registration verification. |
| **ReSource Marketplace** | [Malaysia state manufacturing context](https://api.data.gov.my/data-catalogue?id=gdp_state_real_supply) | Displays state-level manufacturing context alongside user-generated supply and demand listings. | No | Context only; it does not create, verify, price, or rank marketplace listings. |

## Database setup

Run `supabase/migrations/202608230001_industryhub_core.sql` with `supabase db push`, or paste that file once into the Supabase SQL Editor. It creates the module tables, source metadata, seeded observations, indexes, triggers, and baseline Row Level Security policies.

## Optional AI service

The current SkillMatch experience does not require an AI key. It uses deterministic requirement extraction, Supabase programme records, and a curated fallback catalogue. The repository contains an optional `AiService` contract for a future chat-completion integration. If that integration is wired into the UI later, provide `AI_BASE_URL`, `AI_API_KEY`, and `AI_MODEL` in the local `.env` file and keep the API key on a trusted server rather than shipping it in a mobile build.
