# IndustryHub data-source map

IndustryHub gives every module a named source and stores source provenance in Supabase. Public sources do not require an API key. The migration creates schema only; the Dart ingestion command populates live course, classification, and price-index records after the migration.

| Module | Dataset/source | How the app uses it | Key required | Freshness / limitation |
| --- | --- | --- | --- | --- |
| **SkillMatch** | [Coursera public course catalogue](https://www.coursera.org/courses) | Dart-crawls the public search page, stores live course/certificate records and actual provider URLs in `training_programmes`, then ranks them against the AI-extracted brief. | No | Provider HTML can change; rerun the importer to refresh records. |
| **SkillMatch** | [DOSM Quarterly Skills-Related Underemployment by Age](https://data.gov.my/data-catalogue/lfs_qtr_sru_age) | Imports the latest Malaysian skills signal into `workforce_skill_signals` and shows it in the M1 UI as context for the AI learning recommendation. | No | Workforce context, not a personal skills diagnosis or course list. |
| **FairPrice** | [FRED public CSV series](https://fred.stlouisfed.org/series/WPU102402) | Dart-imports live monthly secondary-aluminium, copper-scrap, and iron-and-steel-scrap indexes into `price_index_observations` for negotiation context. | No | U.S. BLS indexes; not a direct Malaysian RM/kg quote. |
| **FairPrice** | [Malaysia Producer Price Index](https://data.gov.my/data-catalogue/ppi) | Shows Malaysia’s producer-price index context with the source base year and observation month. | No | Monthly ex-factory index; recent observations may be revised and it is not a material-specific RM/kg quote. |
| **ReSource Profile** | [Malaysia Standard Industrial Classification 2008](https://data.gov.my/data-catalogue/msic) | Supplies official top-level industry-sector choices and saves the selected MSIC code with the profile. | No | Classification lookup, not business-registration verification. |
| **ReSource Marketplace** | [Malaysia state manufacturing context](https://api.data.gov.my/data-catalogue?id=gdp_state_real_supply) | Displays state-level manufacturing context alongside user-generated supply and demand listings. | No | Context only; it does not create, verify, price, or rank marketplace listings. |

## Database setup

Run `supabase/migrations/202608230001_industryhub_core.sql` with `supabase db push`, or paste that file once into the Supabase SQL Editor. It creates the module tables, indexes, triggers, and baseline Row Level Security policies without inserting dataset records. Then run the Dart-only importer to populate `training_programmes`, `workforce_skill_signals`, `msic_codes`, `price_index_observations`, and the other live reference tables:

```bash
SUPABASE_URL=https://your-project.supabase.co dart run scripts/ingest_live_data.dart --dry-run --course-query "software engineering"
SUPABASE_URL=https://your-project.supabase.co SUPABASE_SERVICE_ROLE_KEY=your-service-role-key dart run scripts/ingest_live_data.dart --course-query "software engineering"
```

The service-role key is used only by the local ingestion command to write live records and must never be placed in the mobile app or committed to Git.

## AI service for Modules 1, 2, and 3

A single OpenAI-compatible configuration is shared by the AI-enabled modules. **SkillMatch** sends each workforce brief to the assistant for structured requirement extraction and a conversational response before ranking the Supabase programme catalogue. **FairPrice** sends the selected material, transparent reference evidence, terms, and external market context to the assistant for user-driven negotiation dialogue, counter-position guidance, and risk flags. **ReSource Profile** sends the current profile, MSIC context, and the user’s question to the assistant for profile-readiness and resource recommendations. No local response is labelled as AI: if the proxy is absent or the provider is unavailable, each module shows an explicit setup/unavailable message; no fake course or price records are inserted by the migration.

The Flutter app’s local `.env` contains only the public Supabase URL and publishable key. Configure the private AI provider as Supabase Edge Function secrets and deploy the included proxy:

```bash
supabase secrets set AI_API_KEY=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 AI_BASE_URL=https://api.groq.com/openai/v1 AI_MODEL=llama-3.3-70b-versatile
supabase functions deploy ai-chat
```

The Flutter client calls the authenticated `ai-chat` function. The function then calls `POST {AI_BASE_URL}/chat/completions` with the bearer token and JSON response format. Keep the provider key server-side; never ship it in an Android or iOS build. If the function is unavailable, M1, M2, and M3 show a clear unavailable state instead of presenting local text as an AI response.


## Live-ingestion source verification

The Dart ingestion command uses public source pages and APIs rather than seed inserts. Coursera’s public software-engineering search page exposes course titles, providers, course/certificate type, and outbound links such as `https://www.coursera.org/learn/software-engineering-software-design-and-project-management`; the importer crawls the course links from the public HTML page. The public page was verified on 2026-08-24. M1 also imports the official DOSM `lfs_qtr_sru_age` dataset from data.gov.my into `workforce_skill_signals`; the UI attributes this Malaysian workforce signal and passes it to the AI as context only.

The Malaysian Steel Institute dataset page is available in the archived official open-data catalogue at https://archive.data.gov.my/data/dataset/international-price-of-iron-ore-and-scrap and offers XLSX resources, but its catalogue metadata says it was last updated in 2021. The importer therefore does not treat it as live/current without a fresh approved source. DailyMetalPrice advertises daily spot prices, but its public pages returned HTTP 403 to server-side Dart HTTP requests during verification. The FairPrice app must show current data availability and never present a blocked or stale source as live.


The FairPrice live importer now uses public FRED CSV endpoints instead of the blocked DailyMetalPrice page. It imports `WPU102402` Secondary Aluminum, `WPU102301` Copper Base Scrap, and `WPU1012` Iron and Steel Scrap from `https://fred.stlouisfed.org/graph/fredgraph.csv?id={SERIES_ID}`. FRED pages report monthly indexes with the latest verified observations in July 2026: Secondary Aluminum 444.705, Copper Base Scrap 958.694, and Iron and Steel Scrap 588.920. These are U.S. BLS producer-price indexes, not Malaysian RM/kg quotes, so the UI must label them as market context rather than local price guarantees.
