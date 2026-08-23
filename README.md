# IndustryHub

IndustryHub is a Flutter workspace for Malaysian industrial SMEs. It brings workforce planning, indicative price checks, business profiles, and a resource marketplace into one practical operations console.

## Product modules

| Module | Purpose |
| --- | --- |
| **SkillMatch** | Turn a plain-language workforce need into a ranked shortlist of training programmes. The app uses the Supabase catalogue when available and falls back to a curated in-app catalogue when it is not. |
| **FairPrice** | Compare a proposed material price with an indicative in-app reference, then review explainable adjustments for volume, condition, and collection terms. |
| **ReSource Profile** | Maintain a business identity and publish supply or demand listings to the marketplace. |
| **ReSource Marketplace** | Search, filter, sort, and review industrial listings; send structured deal requests and review outgoing request history. |

## Getting started

Install the Flutter SDK, then run:

```bash
flutter pub get
flutter run
```

The app expects a `.env` file in the project root with the following values:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-publishable-or-anon-key
```

The private AI key does **not** belong in the Flutter `.env` file. When configured, the shared AI service is actively used by **SkillMatch** to structure workforce requests and by **FairPrice** to generate negotiation dialogue, counter-position guidance, and risk flags. Without the AI service, both modules still run using deterministic local fallback logic. Supabase remains required for the current application bootstrap and for persisted profile, listing, market-signal, programme, and deal-request records.

After linking your Supabase project, configure the AI provider as Edge Function secrets and deploy the proxy:

```bash
supabase secrets set AI_API_KEY=your-api-key AI_BASE_URL=https://api.openai.com/v1 AI_MODEL=gpt-4o-mini
supabase functions deploy ai-chat
```

For another OpenAI-compatible provider, replace `AI_BASE_URL` and `AI_MODEL` with that provider’s values. The Flutter client calls the authenticated `ai-chat` function; the provider key remains server-side.

## Data expectations

The active client-side repositories use `profiles`, `listings`, `deal_requests`, `training_programmes`, `msic_codes`, `data_sources`, `commodity_price_observations`, `price_index_observations`, and `industry_context_observations`. You do **not** need to create these tables one by one: the repository includes a schema-only migration at `supabase/migrations/202608230001_industryhub_core.sql` with indexes, triggers, and Row Level Security policies. It intentionally contains no hardcoded dataset inserts.

If you have the Supabase CLI installed and have linked the project, run:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Alternatively, open your Supabase SQL Editor, paste and run these migration files in order:

```text
supabase/migrations/202608230001_industryhub_core.sql
supabase/migrations/202608240002_remove_legacy_seeds.sql
```

The second migration removes only the known demo rows from the previous version; it does not remove user-created listings or profiles. After the schema and cleanup exist, use the Dart-only live importer:

```bash
# Verify public sources without writing anything
SUPABASE_URL=https://your-project.supabase.co dart run scripts/ingest_live_data.dart --dry-run --course-query "software engineering"

# Write live records to Supabase using a server-only service key
SUPABASE_URL=https://your-project.supabase.co SUPABASE_SERVICE_ROLE_KEY=your-service-role-key dart run scripts/ingest_live_data.dart --course-query "software engineering"
```

The importer crawls the public Coursera search page for real course URLs, reads DOSM MSIC and PPI data, and reads public FRED metal-index CSVs. Keep `SUPABASE_SERVICE_ROLE_KEY` out of the Flutter app and out of Git. If a public source is temporarily unavailable, the importer reports the failed source instead of inserting fake seed data. If your existing tables use different required column names or types, review those differences before running the migrations. Re-run the importer whenever you want to refresh live records; the app itself does not invent replacement courses or price observations when the tables are empty.

For production use, review the included Row Level Security policies and enable anonymous authentication only for a controlled demo. The current bootstrap uses anonymous Supabase authentication for the demo workspace; the readiness label is not formal government or third-party verification.

## Design direction

The interface uses a compact operations-console visual language: navy for navigation and trust, amber for decisions, green for verified or positive states, and rust for demand or attention states. The dashboard now surfaces the current workspace name, live date, synchronization state, and a recommended next action based on profile readiness.

## Verification

From a machine with the Flutter SDK installed, run:

```bash
flutter analyze
flutter test
```

The Flutter analyzer and widget tests pass in the development environment. The Dart importer also supports a dry run so public-source retrieval can be verified without writing to Supabase.
