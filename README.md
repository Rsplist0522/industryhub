# IndustryHub

IndustryHub is a Flutter workspace for Malaysian industrial SMEs. It brings workforce planning, indicative price checks, business profiles, and a resource marketplace into one practical operations console.

## Product modules

| Module | Purpose |
| --- | --- |
| **SkillMatch** | Turn a plain-language career or workforce need into a structured brief, rank live Supabase course records, show DOSM workforce context, and open a generated live Coursera search when no matching record is synced. No seeded course catalogue is bundled. |
| **FairPrice** | Select a material, load live marketplace asking-price evidence and DOSM/FRED context, then use a user-driven AI negotiation chat. No comparable asking-price band is shown when evidence is unavailable. |
| **ReSource Profile** | Maintain a business identity using DOSM MSIC context, publish supply or demand listings, and ask the AI Profile Advisor for profile-readiness and resource recommendations. |
| **ReSource Marketplace** | Search, filter, sort, and review industrial listings; view data.gov.my state-manufacturing context; ask the AI Marketplace Advisor; send structured deal requests, cancel outgoing requests, and review request history. The empty state can load three clearly labelled presentation examples into the signed-in workspace. |

## Getting started

Install the Flutter SDK, copy `.env.example` to `.env`, and put your public Supabase URL and publishable key into `.env`:

```powershell
Copy-Item .env.example .env
notepad .env
flutter pub get
flutter run
```

The actual `.env` file is ignored by Git. It contains only the public Supabase URL and publishable key required by the Flutter client. Do not add private AI or service-role keys to it. The application loads `.env` automatically, so the normal command is simply `flutter run` from the project root. Android Studio Flutter configurations also work without extra run arguments. For a release Web or Android build, keep `.env` in the project root while building; it is public client configuration, not a place for private server secrets.

The private AI key does **not** belong in the Flutter `.env` file. When configured, the shared AI service is actively used by **SkillMatch** to structure career/workforce requests, **FairPrice** to generate user-driven negotiation dialogue, **ReSource Profile** to generate profile-advisor guidance, and **ReSource Marketplace** to compare visible listings. Supabase Flutter is configured with persistent sessions and automatic token refresh, so the app restores the signed-in user after a Web refresh or Android restart unless the user signs out, the session expires, or app storage is cleared. If the AI service is unavailable, the app labels that state explicitly rather than pretending a local response is AI. Supabase remains required for the application bootstrap and for persisted profile, listing, saved-match, FairPrice, market-signal, programme, workforce-signal, and deal-request records.

After linking your Supabase project, configure the AI provider as Edge Function secrets and deploy the proxy:

```bash
npx supabase secrets set AI_API_KEY=your-groq-key AI_BASE_URL=https://api.groq.com/openai/v1 AI_MODEL=openai/gpt-oss-20b
npx supabase functions deploy ai-chat --use-api
```

For another OpenAI-compatible provider, replace `AI_BASE_URL` and `AI_MODEL` with that provider’s values. Do not use retired Groq model IDs; check the provider’s current model catalogue before deployment. The Flutter client calls the authenticated `ai-chat` function; the provider key remains server-side.

## Data expectations

The active client-side repositories use `profiles`, `listings`, `deal_requests`, `saved_matches`, `fair_price_sessions`, `training_programmes`, `workforce_skill_signals`, `msic_codes`, `data_sources`, `commodity_price_observations`, `price_index_observations`, and `industry_context_observations`. Saved matches and FairPrice sessions are persisted under the signed-in user. You do **not** need to create these tables one by one: the repository includes a schema-only migration at `supabase/migrations/202608230001_industryhub_core.sql` with indexes, triggers, and Row Level Security policies. It intentionally contains no hardcoded dataset inserts.

If you have the Supabase CLI installed and have linked the project, run:

```bash
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push
```

If the app reports permission denied for `listings`, make sure the latest migration `202608250004_grant_authenticated_workspace_access.sql` has been applied, then sign out and sign back in so the app uses a fresh authenticated session.

Alternatively, open your Supabase SQL Editor, paste and run these migration files in order:

```text
supabase/migrations/202608230001_industryhub_core.sql
supabase/migrations/202608240002_remove_legacy_seeds.sql
supabase/migrations/202608250003_persist_workspace_actions.sql
supabase/migrations/202608250004_grant_authenticated_workspace_access.sql
```

The second migration removes only the known demo rows from the previous version; it does not remove user-created listings or profiles. After the schema and cleanup exist, use the Dart-only live importer:

```bash
# Verify public sources without writing anything
SUPABASE_URL=https://your-project.supabase.co dart run scripts/ingest_live_data.dart --dry-run --course-query "software engineering"

# Write live records to Supabase using a server-only service key
SUPABASE_URL=https://your-project.supabase.co SUPABASE_SERVICE_ROLE_KEY=your-service-role-key dart run scripts/ingest_live_data.dart --course-query "software engineering"
```

The importer crawls the public Coursera search page for real course URLs, reads DOSM `lfs_qtr_sru_age` workforce signals, MSIC and PPI data from data.gov.my, and reads public FRED metal-index CSVs. The runtime clients also directly use data.gov.my for M1 workforce fallback, M2 PPI fallback, M3 MSIC fallback, and M4 state-manufacturing context. Keep `SUPABASE_SERVICE_ROLE_KEY` out of the Flutter app and out of Git. If a public source is temporarily unavailable, the importer reports the failed source instead of inserting fake seed data. If your existing tables use different required column names or types, review those differences before running the migrations. Re-run the importer whenever you want to refresh live records; the app itself does not invent replacement courses or price observations when the tables are empty.

For a strong M4 presentation, sign in and open **ReSource Marketplace** with an empty workspace. Select **Load presentation examples**. IndustryHub creates three idempotent, clearly labelled `[PRESENTATION SAMPLE]` records—aluminium supply in Pulau Pinang, an HDPE demand request in Selangor, and copper supply in Johor—under the current authenticated user. They are visibly marked `DEMO SAMPLE` and are not official data.gov.my records. Replace or delete them before production use.

For production use, review the included Row Level Security policies and use Supabase email/password authentication. The visible profile readiness label is not formal government or third-party verification. The app now requires a signed-in user before loading or mutating workspace records.

## Design direction

The interface uses a compact operations-console visual language: navy for navigation and trust, amber for decisions, green for verified or positive states, and rust for demand or attention states. The dashboard now surfaces the current workspace name, live date, synchronization state, and a recommended next action based on profile readiness.

## Verification

From a machine with the Flutter SDK installed, run:

```bash
flutter analyze
flutter test
```

Run the Flutter analyzer and widget tests after installing the Flutter SDK. The Dart importer also supports a dry run so public-source retrieval can be verified without writing to Supabase; FRED is treated as an optional external context source and is skipped if its endpoint times out.
