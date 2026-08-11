# update-columns-to-update-migration -- Round 1

## Fact Check

**Plan claim A.3.1: `orchestrate.rb` line 72 has `update_columns(status: :awaiting_job_criteria)`**
- Verified: line 72 exactly matches.
- Count: 1 `update_columns` call in file. Plan says 1. Correct.

**Plan claim A.3.2: `score_job_application.rb` has 5 `update_columns` calls at lines 23, 32, 115, 120, 124**
- Verified: all 5 lines match exactly.
  - Line 23: `update_columns(status: :awaiting_job_criteria)` -- happy path
  - Line 32: `update_columns(status: :scoring)` -- happy path
  - Line 115: `&.update_columns(status: :retrying, error_message: ...)` -- rescue `CustomErrorAiSummary`
  - Line 120: `&.update_columns(status: :failed, ...)` -- rescue `JSON::ParserError`
  - Line 124: `&.update_columns(status: :failed, ...)` -- rescue `StandardError`

**Plan claim A.3.3: `integrate_analysis.rb` has 3 `update_columns` calls at lines 59, 64, 68**
- Verified: all 3 lines match exactly.
  - Line 59: `&.update_columns(status: :retrying, ...)` -- rescue `CustomErrorAiSummary`
  - Line 64: `&.update_columns(status: :failed, ...)` -- rescue `JSON::ParserError`
  - Line 68: `&.update_columns(status: :failed, ...)` -- rescue `StandardError`

**Plan claim: total 9 `update_columns` call sites**
- Verified: 1 + 5 + 3 = 9. Correct.

**Plan claim A.3.4: existing callbacks guarded by `saved_change_to_status? && status_succeeded?`**
- Verified: `destroy_previous_textract_results` (line 51) and `update_summary_status_record` (line 60) both use this exact guard. These callbacks are `after_commit on: :update`, so `saved_change_to_status?` is the correct method to use.

**Plan claim: `create_status_record` is `on: :create` only**
- Verified: line 27 is `after_commit :create_status_record, on: :create`. Not affected by `update`.

**Plan claim: model only has `validates :status, presence: true`**
- Verified: line 23 is `validates :status, presence: true`. The only validation. Safe for rescue-path `update` calls.

**Plan claim P7: `summary/generate.rb` already uses `update` on happy path**
- Not directly verified (not required to read that file for this angle), but the plan notes lines 68, 102, 129, 169 use `update` and lines 175, 180, 184 use `update_columns`. The pattern is consistent with what the plan proposes.

**Plan claim: `score_job_application.rb` already uses `update` at line 109 for the main happy-path data save**
- Verified: line 109 is `unless @ai_job_application_summary.update(update_params)`.

**Plan claim: `integrate_analysis.rb` already uses `update` at line 53 for the main happy-path data save**
- Verified: line 53 is `unless @ai_job_application_summary.update(update_params)`.

## Completeness

Spec requirements this angle covers:
1. Switch `update_columns` to `update` in `orchestrate.rb` -- plan A.3.1
2. Switch `update_columns` to `update` in `score_job_application.rb` -- plan A.3.2
3. Switch `update_columns` to `update` in `integrate_analysis.rb` -- plan A.3.3
4. Existing callback guards are adequate -- plan A.3.4

All covered.

## Findings

- F1 [MED] The plan's Risks section #4 says "Wrap the broadcast in its own rescue inside `broadcast_status_change` so a broadcast failure doesn't mask the pipeline error." But this rescue wrapping is not reflected in any task step. A.1.3 does not mention adding a rescue inside `broadcast_status_change`. This is a noted risk mitigation that lacks a corresponding implementation instruction. However, since `before_update` fires before the DB write, a broadcast failure in the callback would prevent the status from being saved at all (the exception would propagate up through the `update` call). The `before_update` callback runs within the transaction. If `JobChannel.broadcast_to` raises, the transaction rolls back and the status change is lost.
  - This is more significant than MED on reflection. Promoting to HIGH.

- F1 [HIGH] `broadcast_status_change` as a `before_update` callback runs inside the ActiveRecord transaction. If `JobChannel.broadcast_to` raises an exception, the exception propagates through `update`, causing the status change to fail. In rescue blocks (e.g., `score_job_application.rb` line 115), the code is trying to persist a `failed`/`retrying` status. If the broadcast raises, the status never persists. The plan's Risk #4 identifies this but does not add a task step for the rescue wrapper.
  - **Evidence:** `before_update` callbacks run within the transaction context. Exceptions in the callback abort the update.
  - **Fix:** Add to A.1.3: wrap `JobChannel.broadcast_to` in a `rescue StandardError => e` block inside `broadcast_status_change` with `ap` + `Rails.logger.error` logging. This ensures broadcast failures never prevent status persistence.

## Amendments Applied

- plan.md A.1.3: added rescue wrapper around `JobChannel.broadcast_to` call.
