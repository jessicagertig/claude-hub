# AI Spec Test Remediation — Final Results

Two workflows + targeted cleanup. Source: `/Users/jessica/wrk/wrk-corp/inflow-ats` branch `UI-polishes`.
**All changes uncommitted in the working tree.**

## Final state

**All 16 reworked specs pass — zero failures.** Every fix is spec-only; production code untouched except one approved debug-line fix.

- **15 specs green + adversarially CLEAN.**
- **1 spec green + 1 example honestly DEFERRED** (`find_or_create`, concurrent-race — marked `pending` with documented reason; can't be tested deterministically without editing production).
- **4 ghosts DEFERRED** from round 1 — all `retry_on` exhaustion blocks that can't fire under the `:test` adapter (listed below).
- **1 production change** (approved): `grant_ai_credits.rb:67`.

## Production change (approved)

`app/interactors/grant_ai_credits.rb:67` — `ap txn.errors` → `ap txn.errors.full_messages`. awesome_print 1.9.2 can't render an `ActiveModel::Errors` object (calls `marshal_dump`, which it doesn't respond to in this Rails version), so the line crashed whenever the save-failure path ran. `full_messages` is a plain `Array<String>` it renders fine. Keeps `ap` in production; test now passes.

## CLEAN — green + passed adversarial review (15)

No further action.

Models / interactors (round 1, clean first pass):
- `ai_job_application_summary_spec.rb` — incl `broadcast_status_change` payload drift fix
- `ai_job_application_summary_status_spec.rb`
- `ai_job_criteria_spec.rb` — incl `retrying` enum drift fix (5 values)
- `textract_result_ai_trigger_spec.rb`
- `create_ai_credit_balance_transaction_spec.rb`
- `queue_bulk_ai_summary_jobs_spec.rb`
- `scoring/extract_criteria_spec.rb`
- `get_resume_text_from_textract_job_spec.rb`
- `extract_job_criteria_job_spec.rb`

Reworked in round 2 to be meaningful (each now fails if its production logic is removed):
- `submit_resume_to_textract_spec.rb` — not-found stub fixed; test reaches the guard, asserts message + Textract not called
- `score_job_application_spec.rb` — median now uses distinct scores (20/40/60/80/100) so median selection is provably bound
- `orchestrate_spec.rb` — failed-guard now uses a complete-but-failed fixture; pre-summarization contexts assert scoring/criteria NOT called
- `bulk_generate_ai_summaries_job_spec.rb` — confirmed binding assertions
- `grant_ai_credits_spec.rb` — replaced `save → false` stub with a genuinely invalid record
- `generate_ai_job_application_summary_job_spec.rb` — guard bound via "rescue log not emitted"; retry_on uses `perform_now` + `have_enqueued_job`; real consumption-decline test via `and_wrap_original`; two redundant zero-state ghost assertions removed

## DEFERRED — documented, untouched

### `find_or_create` rescue — intentionally not tested (not pending)
`find_or_create_ai_job_application_summary_status_spec.rb` — the `rescue ActiveRecord::RecordNotUnique` only fires on a true cross-process INSERT race, which is unreachable in a spec: the model has both a `uniqueness` validation AND a DB unique index, so a duplicate makes `save` return false before the DB raises; transactional fixtures roll back any concurrent row. Faking it requires stubbing the boundary under test (a ghost). The pending example was removed and replaced with an explicit "left untested by design" comment.

Separately, the create-branch `!latest.stale?` guard was previously uncovered (the `none` test used no summary at all). Added a "succeeded but stale → none" case that binds it — fails if `&& !latest.stale?` were dropped.

### 4 ghosts — retry_on exhaustion blocks (round 1)
Can't trigger under the `:test` adapter; inline block logic has no extractable helper to call without editing `app/`. Coverage stays open:
1. `submit_resume_to_textract_spec.rb` — `InvalidS3ObjectException`/`StandardError` rescue marking textract_result `failed`
2. `generate_ai_job_application_summary_job_spec.rb` — `retry_on CustomErrorAiSummary` exhaustion (marks summary failed + broadcast)
3. `get_resume_text_from_textract_job_spec.rb` — `retry_on CustomErrorTextract` exhaustion wiring to `cleanup_orphaned_summary` (target tested directly; only the wiring is open)
4. `extract_job_criteria_job_spec.rb` — `retry_on CustomErrorAiSummary` exhaustion marking `AiJobCriteria` failed

## To commit

Spec changes across the 16 files + the one production line in `grant_ai_credits.rb`, on a dedicated branch off `UI-polishes`, when you're ready.
