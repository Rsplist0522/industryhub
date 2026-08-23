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

The active client-side repositories expect these Supabase tables:

- `profiles`, keyed by `user_id`, with `business_name`, `sector`, `role`, and optional `verified` fields.
- `listings`, with `type`, `material`, `quantity`, `unit`, `location`, `description`, `owner`, `owner_id`, and optional `verified` fields.
- `training_programmes`, with `is_active`, `name`, `provider`, `skills`, `level`, `duration_days`, `source_name`, `source_url`, `credential`, and `summary` fields.
- The deal-request repository contains the request schema used by Marketplace history and submission flows.

For production use, configure Supabase Row Level Security so profiles, listings, and requests are scoped to the authenticated workspace. The current bootstrap uses anonymous Supabase authentication for the demo workspace; the readiness label is not formal government or third-party verification.

## Design direction

The interface uses a compact operations-console visual language: navy for navigation and trust, amber for decisions, green for verified or positive states, and rust for demand or attention states. The dashboard now surfaces the current workspace name, live date, synchronization state, and a recommended next action based on profile readiness.

## Verification

From a machine with the Flutter SDK installed, run:

```bash
flutter analyze
flutter test
```

The supplied sandbox did not include the Flutter SDK, so those commands could not be executed during this enhancement pass. Source-level checks were completed with `git diff --check` and repository-wide reference scans.
