# Test Coverage (always-on) — Round 1

Also carries the always-on check **Test coverage** from REVIEW-ANGLES §4 (folded here).

## Suite executed against COMMITTED code

Ran the full plan-F.4.3 list in the clean worktree at HEAD:
`spec/models/ai_job_criteria_spec.rb spec/models/job_criteria_lifecycle_spec.rb spec/models/textract_result_ai_trigger_spec.rb spec/jobs/extract_job_criteria_job_spec.rb spec/jobs/bulk_generate_ai_summaries_job_spec.rb spec/interactors/validate_ai_summary_generation_spec.rb spec/interactors/validate_auto_ai_summary_generation_spec.rb spec/interactors/queue_bulk_ai_summary_jobs_spec.rb spec/controllers/api/v1/ai_job_criteria_controller_spec.rb spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb spec/serializers/api/v1/job_ai_job_criteria_serializer_spec.rb`

**Result: 135 examples, 9 failures — all 9 are the known pre-existing `on_complete` NoMethodErrors in `bulk_generate_ai_summaries_job_spec.rb`** (verified pre-existing: the failing examples and the `on_complete do` DSL are byte-identical at base `05c9513ef`; the diff touched neither — see operational-concerns.md). Every feature test passes, including the new zero-criteria batch test that exercises the real job-iteration lifecycle.

## SPEC §12 test plan — executed item by item

- New `ai_job_criteria_controller_spec.rb`: all six `#show` payload states; `#create` row+enqueue with `[row.id, current_organization_user.id]`; blank-description 422 exact message + no row; Flipper 422 + no row; in-flight no-op 200 for BOTH `in_progress` and `retrying`; draft AND published jobs; authz split. ✓
- New `validate_ai_summary_generation_spec.rb` (first dedicated spec for this interactor): happy path; all three `ZERO_CRITERIA_ERROR_MESSAGES`; negative cases (`'Job description is blank'`, `pending` latest, in-flight over zero). ✓
- New `job_ai_job_criteria_serializer_spec.rb`: never-ran all-nil + mixed state (criteria from older succeeded, status failed, zero_criteria_failure true). ✓
- `job_criteria_lifecycle_spec.rb`: blank desc; in_progress; retrying; **pending → row IS created (the no-pending-guard documentation test — present and passing)**; kwarg passthrough `[id, requesting_id]`; `[id, nil]` default; `_if_needed` succeeded no-op / failed delegates / no-rows delegates. ✓
- `ai_job_criteria_spec.rb`: full truth table (3 messages × failed = true; × 4 non-failed statuses = false; failed × blank-desc message, × parse message, × nil = false). ✓
- `extract_job_criteria_job_spec.rb`: behavioral broadcast coverage — asserts `GlobalChannel.broadcast_to` outcomes with action/status/`zeroCriteriaFailure`/`errorMessage`; `CustomErrorAiSummary` → `have_enqueued_job` + no broadcast; no-requesting-user → no broadcast on success or failure; existing positional examples untouched (they ARE the backward-compat assertion) and passing. Service stub uses production kwargs (rule 7 — no type-mismatch masking). ✓
- `validate_auto_ai_summary_generation_spec.rb`: zero-criteria fail + in-flight-over-zero pass. ✓
- `queue_bulk_ai_summary_jobs_spec.rb`: zero-criteria fail context (message, nothing enqueued, no claim rows) + explicit job-less-call-still-succeeds example. ✓
- `bulk_ai_job_application_summaries_controller_spec.rb`: `hash_including(job: kind_of(Job))` for both actions + 422 per action. ✓
- `textract_result_ai_trigger_spec.rb`: funnel guard returns before `extract_job_criteria_if_needed` AND before `Orchestrate.new`. ✓
- `bulk_generate_ai_summaries_job_spec.rb`: **claim-row test asserts `:failed` (flag-6 behavior)** — the previous stays-`:processing` example was inverted to the new behavior; zero-criteria batch → all rows `:failed` + completion notification still fires. ✓
- Frontend tests: none — documented decision (SPEC §12); verified no half-added harness in the diff. ✓

## Ghost-test hunt (rule 26 — BLOCKER severity if found)

Audited every new/changed example for falsifiability: no reflection-only assertions, no assigned-but-unasserted variables, no always-true type checks. Spot-falsification reasoning: remove the pending-guard absence → the "creates a row anyway" test fails; remove the claim-row fix → `eq('failed')` fails; remove any broadcast site gate → the `not_to receive(:broadcast_to)` examples fail; remove a constant from the guard → the message-looped validator examples and the explicit-constant controller/serializer/textract examples fail. **No ghost tests found.**

## Findings

- F1 [LOW] spec/jobs/extract_job_criteria_job_spec.rb / the `retry_on` exhaustion-block broadcast site (extract_job_criteria_job.rb:5-13) has no direct test — coverage exercises the perform-end and StandardError-rescue sites only / this matches the SPEC §12 / plan E.2.6 test plan exactly (the specced `CustomErrorAiSummary` case asserts re-enqueue + no broadcast, not exhaustion), so it is a residual gap in the adjudicated plan, not an implementation omission / optional hardening: a `perform_now` with `executions` forced past attempts, or invoking the rescue handler, asserting the failure write + failed broadcast.

No MED+ findings.
