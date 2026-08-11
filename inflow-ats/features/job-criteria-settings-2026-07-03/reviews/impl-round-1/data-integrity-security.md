# Data Integrity & Security (always-on) — Round 1

## Authorization

- Both actions scope the lookup through `current_organization.jobs` — no cross-org job access via `job_id` tampering (`exists` renders 422 'no job found' otherwise).
- `authorize` AFTER find with explicit policy queries; GET requires `JobPolicy#show?` (hiring-team-or-admin), POST requires `update_ai_settings?` → `can_use_ai_credits?` — the identical gate `jobs_controller.rb:163` uses for AI-settings changes. Policy methods verified to never read `record` beyond `show?`'s job-scoped check, so passing a Job is safe. Authz split covered by passing controller tests (show 200 / create 403 for an org_user without AI-credits control). One observation, spec-adjudicated (SPEC §9, not a finding): `can_use_ai_credits?` has no hiring-team requirement, so an org_user with the org setting enabled can regenerate criteria for any org job — exactly the pre-existing gate's semantics.
- Flipper `AI_APPLICANT_SUMMARY` on POST prevents non-AI orgs from triggering paid OpenAI calls (`extract_job_criteria_immediately` itself has no Flipper gate — controller-level gate is the specced defense). GET ungated returns only null/status data — no sensitive leak (criteria content derives from the org's own job description).

## Input handling

- No body params accepted on either action (zero params methods — no mass-assignment surface). `params[:job_id]` used only inside an org-scoped `where`.
- No raw SQL; all queries through AR scopes. No user input reaches the broadcast payload except org-owned `job.title`/`error_message` delivered only to the requesting user's own channel (`GlobalChannel.broadcast_to(user, …)`).

## Data consistency

- `zero_criteria_failure?` is a pure read; the guard adds no writes. The claim-row fix writes `:failed` via `update_columns` NOT inside a transaction (pipeline rule 25 — verified `each_iteration` has no transaction block).
- Two-pending-rows double-enqueue (no pending guard) is DECISIONS-documented; latest-row-wins semantics hold at every read site (`latest_ai_job_criteria` ordered by created_at). The frontend-disable mitigation gap is F1 [HIGH] (frontend-display-states.md) — it widens the double-enqueue window but cannot corrupt data.
- Broadcast helper reloads before the terminal check, so it can never broadcast a stale in-flight status as terminal; nil-row paths guarded at all three sites.
- No enum changes, no new callbacks, no validation changes on any shared model (rule 20 boundary verified on `ai_job_criteria.rb`, `job.rb`, `textract_result.rb`, `bulk_generate_ai_summaries_job.rb` diffs).
- No migrations; no destructive operations; no `.env`/config changes in the diff.

## Findings

No issues found. (F1 counted in frontend-display-states.md.)
