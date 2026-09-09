# Module 1 - SkillMatch

## Purpose

SkillMatch helps Malaysian industrial and digital workers identify competency gaps, find relevant learning options, follow a roadmap, and measure improvement through reassessment. It supports SDG 9 through workforce capability development.

## User flow

1. Enter a career goal or select one of 10 supported roles.
2. Complete every competency question using behaviour-anchored levels.
3. Review readiness, per-skill gaps, and priority weaknesses.
4. Inspect ranked programmes and the evidence behind each score.
5. Follow and update a prerequisite-aware learning roadmap.
6. Reassess and compare the new result with the baseline.
7. Ask the AI coach to explain the verified result or suggest next actions.

Unsupported roles do not receive a generic competency profile. This avoids presenting an unverified assessment as valid.

## Data architecture

- Role profiles: bundled JSON loaded and validated once at runtime. They are not database records and are not embedded in the UI.
- Programme catalogue: one Supabase catalogue query, ranked locally.
- DOSM evidence: one cached time-series load from `lfs_qtr_sru_age`, with a direct data.gov.my API fallback.
- Personal assessment history and roadmap progress: stored in Supabase with user ownership and Row Level Security.
- AI conversation: session-only and not written to the database.

The role scope is aligned with MASCO occupation families. Competency targets are declared prototype assumptions, not government-certified occupational standards.

## Deterministic calculations

Each level has a fixed score: Beginner 20, Basic 40, Intermediate 65, Advanced 85.

For competency `i`:

```text
gap_i = max(target_i - current_i, 0)
competency_readiness_i = min(current_i / target_i, 1)
priority_i = gap_i * weight_i
```

Overall readiness:

```text
readiness = sum(weight_i * competency_readiness_i) / sum(valid weights) * 100
```

Programme match:

```text
40% skill coverage
20% level suitability
15% certification relevance
10% duration suitability
10% role and industry relevance
 5% prerequisite compatibility
```

Missing catalogue fields are excluded and the available weights are normalised. The UI separately displays evidence coverage so a high score based on incomplete metadata is not presented as equally certain.

Roadmap ordering places unresolved prerequisites before dependent competencies, then prioritises larger weighted gaps. Completing a roadmap stage never changes readiness; only reassessment creates a new score.

## Government open data

SkillMatch uses the Department of Statistics Malaysia dataset `Quarterly Skills-Related Underemployment by Age`. The user can select an age group and see the latest official rate, affected-person count when available, and quarter-to-quarter rate change.

This statistic measures tertiary-educated people working in semi-skilled or low-skilled jobs. It is used as Malaysian labour-market context and supplied to the AI coach, but it does not alter personal readiness or claim demand for a specific role.

Source: https://data.gov.my/data-catalogue/lfs_qtr_sru_age

## AI boundary

AI performs two explainable assistance tasks:

- Maps natural-language goals to the supported role library.
- Answers questions using the already-calculated assessment, roadmap, programme evidence, and DOSM context.

AI is explicitly instructed not to create or modify scores, programmes, credentials, progress, or government statistics. If AI is unavailable, role selection, diagnostics, ranking, roadmaps, persistence, and reassessment still work.

Runtime prompts are located in:

- `lib/features/skill_match/presentation/skill_match_screen.dart`
- `lib/features/skill_match/data/skill_coach_service.dart`

## Development AI disclosure

OpenAI Codex was used to inspect, refactor, and test Module 1. The requested constraints were to keep scoring deterministic, use Malaysian government open data meaningfully, avoid generic custom-role output, reduce database round trips, and add evidence-grounded AI interaction. Outputs were verified using static analysis, unit tests, schema review, explicit source labels, and AI-failure fallbacks.

## Demo script

1. Select an age group and explain the DOSM evidence card.
2. Enter `I want to work as a PLC technician` and show AI mapping it to Industrial Automation Technician.
3. Disable or disconnect AI if desired and show that manual role selection and the diagnostic still work.
4. Complete the diagnostic and open `How this score is calculated`.
5. Compare programme match and evidence coverage.
6. Update roadmap progress and restart the app to show persistence.
7. Reassess to show before, after, and per-skill improvement.
8. Ask the AI coach `What should I do this week?` and explain that it receives immutable calculated facts.

## Required setup

```powershell
npx supabase db push
supabase functions deploy ai-chat
dart run scripts/ingest_live_data.dart
flutter run
```

The importer requires `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in the terminal environment. Never place the service-role key in the Flutter application or commit it to Git.
