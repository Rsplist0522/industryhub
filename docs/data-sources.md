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

## AI service for Modules 1 and 2

A single OpenAI-compatible configuration is shared by both AI-enabled modules. **SkillMatch** sends each workforce brief to the assistant for structured requirement extraction and a conversational response before ranking the Supabase programme catalogue. **FairPrice** sends the transparent reference band, material terms, and external market context to the assistant for negotiation dialogue, counter-position guidance, and risk flags. The deterministic local logic remains as a fallback when the AI variables are absent or the provider is unavailable.

The Flutter app’s local `.env` contains only the public Supabase URL and publishable key. Configure the private AI provider as Supabase Edge Function secrets and deploy the included proxy:

```bash
supabase secrets set AI_API_KEY=your-api-key AI_BASE_URL=https://api.openai.com/v1 AI_MODEL=gpt-4o-mini
supabase functions deploy ai-chat
```

The Flutter client calls the authenticated `ai-chat` function. The function then calls `POST {AI_BASE_URL}/chat/completions` with the bearer token and JSON response format. Keep the provider key server-side; never ship it in an Android or iOS build. The fallback mode is functional, but it is not the AI chatbot experience.
