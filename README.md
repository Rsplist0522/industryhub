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
SUPABASE_PUBLISHABLE_KEY=your-publishable-key
AI_BASE_URL=https://your-compatible-chat-endpoint/v1
AI_API_KEY=your-api-key
AI_MODEL=your-model-name
```

`AI_BASE_URL`, `AI_API_KEY`, and `AI_MODEL` are optional. SkillMatch has a deterministic curated fallback when an AI endpoint is not configured. Supabase remains required for the current application bootstrap and for persisted profile, listing, programme, and deal-request records.

## Data expectations

The active client-side repositories use `profiles`, `listings`, `deal_requests`, `training_programmes`, `msic_codes`, `data_sources`, `commodity_price_observations`, `price_index_observations`, and `industry_context_observations`. You do **not** need to create these tables one by one: the repository includes a complete migration at `supabase/migrations/202608230001_industryhub_core.sql` with starter datasets, indexes, triggers, and Row Level Security policies.

If you have the Supabase CLI installed and have linked the project, run:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Alternatively, open your Supabase SQL Editor, paste the contents of the migration file, and run it once. The migration uses `create table if not exists` and upserts for seed rows, so it is designed to be safe for a compatible existing schema. If your existing tables use different required column names or types, review those differences before running it.

For production use, review the included Row Level Security policies and enable anonymous authentication only for a controlled demo. The current bootstrap uses anonymous Supabase authentication for the demo workspace; the readiness label is not formal government or third-party verification.

## Design direction

The interface uses a compact operations-console visual language: navy for navigation and trust, amber for decisions, green for verified or positive states, and rust for demand or attention states. The dashboard now surfaces the current workspace name, live date, synchronization state, and a recommended next action based on profile readiness.

## Verification

From a machine with the Flutter SDK installed, run:

```bash
flutter analyze
flutter test
```

The supplied sandbox did not include the Flutter SDK, so those commands could not be executed during this enhancement pass. Source-level checks were completed with `git diff --check` and repository-wide reference scans.
