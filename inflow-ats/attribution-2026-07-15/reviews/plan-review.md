# Plan Review

**Source:** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/plan.md`
**Spec:** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/SPEC.md` (amended, authoritative) + `approved-decisions.md` (D1–D17, no D11)
**Verdict: APPROVED** (with 4 corrections applied directly to plan.md during Pass 1 and verified in Pass 2)
**Reviewed:** 2026-07-16 (repo `/Users/jessica/wrk/wrk-corp/inflow-ats`, branch `attribution-work` at 62dd55867; working tree dirty only at `app/javascript/shared/lib/posthog.ts` — the intentional feature diff)

## Pass 1 Summary

| Angle | Findings |
|---|---|
| frontend-capture-and-sanitization | 1 LOW (F2 — `AuthRegister.tsx:134` → live line 136) |
| params-threading-contract | 0 |
| sso-oauth-session-contract | 0 |
| org-inheritance-and-persistence | 0 |
| posthog-events-and-identity | 1 LOW (F3 — `AppAuthRouter.tsx:165-176` → 165-177, two citations) |
| test-coverage-and-ghost-tests | 1 HIGH (F1 — T4.1 missing `@request.env['devise.mapping'] = Devise.mappings[:api_v1_user]`; devise 4.8.1 `DeviseController` `prepend_before_action :assert_is_devise_resource!` raises `AbstractController::ActionNotFound` in every T4 example without it — `Devise::Test::ControllerHelpers` does not set the mapping, and the action's own line-5 assignment runs after the prepend_before_action) |
| conventions-compliance | 2 LOW (F4 — files-list header/total count drift vs the correct itemized list; F5 — independent steps not marked parallelizable, sequential order is safe, noted only) |
| claude-md-compliance | 0 violations |

Pass 1 verdict: FAIL (1 HIGH) → amendment applied per the phase prompt.

## Pass 2 Summary

| Angle | Findings |
|---|---|
| frontend-capture-and-sanitization | 0 |
| params-threading-contract | 0 |
| sso-oauth-session-contract | 0 |
| org-inheritance-and-persistence | 0 |
| posthog-events-and-identity | 0 |
| test-coverage-and-ghost-tests | 0 (F1 amendment verified; mapping key `:api_v1_user` confirmed correct — `Devise.mappings[:user]` does not exist in this app; consistency across all five RSpec skeletons confirmed) |
| conventions-compliance | 0 (F4 corrections verified; zero stale references remain) |
| claude-md-compliance | 0 violations |

Pass 2 verdict: PASS (0 BLOCKER / 0 HIGH / 0 MED / 0 LOW).

## Fact-check coverage (highlights)

Every file:line claim in the plan was verified against the live tree. Specifically re-verified live, as directed:
- **Check-before-create (C.1–C.6):** no `utm_*` columns on users/organizations (only `ahoy_visits`); `sanitizeTrackingParams` nonexistent; none of the five event-name strings exists (only `organization_created_via` substrings + the `email_verified:` comment at `smtp_email_validator.rb:113`); none of the six test files exists (`spec/controllers/hire/` and `spec/controllers/api/v1/users/` must be created); `posthog.ts` is the sole dirty file.
- **`from_omniauth` census:** exactly two files — `app/models/user.rb:379` (definition) and `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:22` (sole call site, positional).
- **query-string v6.1.0 (installed source read):** `parse` ends in `Object.keys(ret).sort().reduce(...)` (index.js:157) — keys alphabetized, no opt-out; repeated-param arrays are built in occurrence order and pass the final sort untouched via the `!Array.isArray(value)` guard; `extract` returns `''` when no `?`; `+`→space precedes the `=` split. All plan claims exact.
- **Test-adapter around-block precedent:** `bulk_ai_job_application_summaries_controller_spec.rb` — helpers include at line 7, around block at lines 9–14, exactly as cited; `queue_adapter = :inline` at `test.rb:64`; `NotifyUserJob` really pings Slack when the user has an organization.
- **Devise claims:** mapping name is `:api_v1_user` (devise_for under `namespace :api/:v1`); devise 4.8.1 `assert_is_devise_resource!` verified in the installed gem — this produced the one HIGH (T4.1).
- **Open-PR conflict claim:** `gh pr list` — newest is #3035 `messaging-improvements` (2026-06-05); `gh pr diff 3005` (`recruiter-links`) touches `organization_params` only (adds `:enable_recruiter_submission_links`), not `#create`. Claim accurate.
- **Verbatim code blocks:** migrations match D6 exactly (string/string/jsonb/string, no default/null/index, class names match file names); the sanitizer implements D4 exactly (255 truncation, first-of-array, 10-key cap in RAW-STRING occurrence order, source/campaign exclusions, absent→absent, null passthrough); event names/placements match D12–D17 exactly; B3.2's branches reproduce live lines 88–107 byte-for-byte plus the four keys in both branches; `ActionController::Parameters#as_json` delegation confirmed in installed actionpack 6.1.7.7.
- **Decision conformance:** no plan-vs-decision mismatch found across D1–D17; the five approved analog deviations are correctly carried and pinned against re-litigation.

## Verdict

**APPROVED** — the plan, as amended, is factually correct, complete against the spec, safe (zero CLAUDE.md/cursor_rules violations, DB-safety compliant), and properly scoped (every task traces to a decision; Do-NOT-touch list guards scope). The implementation agent can execute it as-is.

## Reviewed Plan

The corrected plan is **`plan.md` itself** — the four amendments below were applied directly to it during this review (the phase prompt's "apply amendments" step) and verified in Pass 2, so `plan.md` in this directory IS the reviewed, standalone document the implementation agent consumes. It is not duplicated here to avoid a second diverging copy.

Amendments applied to plan.md:
1. **T4.1 (HIGH F1):** added `before { @request.env['devise.mapping'] = Devise.mappings[:api_v1_user] }` to the omniauth-callbacks controller spec skeleton, with the devise 4.8.1 `assert_is_devise_resource!` rationale (same requirement as T2.1; without it every T4 example raises `AbstractController::ActionNotFound` at dispatch).
2. **F3.6 (LOW F2):** `AuthRegister.tsx:134` → `AuthRegister.tsx:136`.
3. **Pattern table + F7.2 (LOW F3):** `AppAuthRouter.tsx:165-176` → `AppAuthRouter.tsx:165-177` (both citations).
4. **Files list + Estimated scope (LOW F4):** header corrected to "(6 backend + 9 frontend incl. posthog.ts + schema)"; total corrected to "16 modified files (incl. `db/schema.rb` and `posthog.ts`)".

Note recorded, no action required: the T4.1 gap was inherited from spec §9.3 (which mandates only the `Devise::Test::ControllerHelpers` include); the fix is test mechanics, not a design change — §9.1 sets the in-spec precedent for the mapping line. LOW F5 (no parallelizable markers; strictly sequential order) left as-is: the given order is dependency-correct and safe.
