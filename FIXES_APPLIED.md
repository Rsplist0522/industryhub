# IndustryHub Fixes Applied — 1 September 2026

This copy contains the fixes from the Marketplace/auth/profile/FairPrice/SkillMatch audit.

## Required before running the fixed Marketplace

The Flutter client now depends on the new database functions and `listings.status` column in:

`supabase/migrations/202609010001_harden_marketplace_and_profiles.sql`

If the project is already linked to Supabase, apply all pending migrations:

```bash
npm install
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF
npx supabase db push
```

Then run the normal Flutter checks on a machine with Flutter installed:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Security action that code changes cannot do for you

Old repository history contained server-side credential material. This repaired ZIP intentionally excludes `.git`, but deleting a secret from files does not revoke an already-issued key. Rotate/revoke any previously committed Supabase service-role key and AI/provider API key in their dashboards. Then remove those secrets from the history of the repository you actually push to GitHub.

Never put `SUPABASE_SERVICE_ROLE_KEY` or `AI_API_KEY` in Flutter assets or `.env`. The Flutter `.env` should contain only the Supabase URL and publishable client key; the AI key belongs in Supabase Edge Function secrets.

## Main fixes

- Deal creation, cancellation, acceptance, rejection, and listing withdrawal are database-controlled RPC operations.
- Accepted deals keep their history; listings become `MATCHED` instead of being deleted.
- Pending requests are protected against duplicate submissions and cancel/accept races.
- Users cannot directly self-assign `verified` or alter protected marketplace status fields.
- Listing business identity and verification are derived/synchronised from the profile at the database layer.
- Email-confirmation signup preserves the business profile through an auth-user trigger.
- Role selection is saved and incomplete roles route through onboarding.
- Listing ownership uses authenticated user IDs rather than business-name equality.
- Profile readiness and MSIC clearing logic are corrected.
- Fractional Marketplace quantities are preserved.
- FairPrice no longer applies seller delivery twice and clamps recommendations to non-negative values.
- SkillMatch no longer treats every generic engineer request as software engineering.
- Android main manifest explicitly includes Internet permission.
- Protected application routes redirect signed-out users to login.
- Own listings no longer invite the owner to send themselves a deal request.
- Login accepts any non-empty password and leaves credential verification to Supabase.
- Marketplace score wording is changed from a misleading “match” percentage to search relevance.
- A pre-existing Dart test error using Python-style string multiplication was corrected.
- `.env.example` now contains placeholders instead of project-specific values.

## Validation performed in this environment

Flutter/Dart/Supabase CLIs are not installed in the review environment, so an actual `flutter analyze`, `flutter test`, APK build, emulator run, or database migration execution could not be performed here. Static checks completed successfully for Dart delimiter balance, Android XML parsing, JSON parsing, SQL delimiter/parenthesis balance, duplicate high-risk client status mutations, direct listing deletion patterns, and the original redundant requester-name null check.
