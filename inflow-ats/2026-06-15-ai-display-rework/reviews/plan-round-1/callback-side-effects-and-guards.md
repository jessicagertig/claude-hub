# callback-side-effects-and-guards -- Round 1

## Fact Check

**Plan claim A.1.3: guard 1 uses `status_changed?` because this is `before_update`**
- Verified: in a `before_update` callback, the record is dirty but not yet saved. `saved_change_to_status?` returns false (no saved changes yet). `status_changed?` checks the dirty tracking (ActiveModel::Dirty) and is correct.

**Plan claim A.3.4: `destroy_previous_textract_results` guarded by `saved_change_to_status? && status_succeeded?`**
- Verified: line 51 exactly matches. This is an `after_commit on: :update` callback, so `saved_change_to_status?` is correct here.

**Plan claim A.3.4: `update_summary_status_record` guarded by `saved_change_to_status? && status_succeeded?`**
- Verified: line 60 exactly matches. Same `after_commit on: :update` context.

**Plan claim A.3.4: `create_status_record` is `on: :create` only**
- Verified: line 27 is `after_commit :create_status_record, on: :create`.

**Plan claim: switching `update_columns` to `update` means `after_commit on: :update` callbacks now fire on every status transition**
- Correct: `update_columns` bypasses callbacks; `update` triggers them. The existing guards correctly filter: both `after_commit` callbacks only proceed when `status_succeeded?`. Intermediate statuses (`extracting`, `scoring`, etc.) will trigger the callbacks but they return early.

**Plan claim A.1.1: `BROADCAST_STATUSES` excludes `pending`, `awaiting_job_criteria`, `retrying`**
- Verified against spec: spec says `BROADCAST_STATUSES = %w[textract_processing extracting summarizing scoring integrating succeeded failed]`. This excludes `pending` (status 0), `awaiting_job_criteria` (status 4), and `retrying` (status 8). Correct.

## Completeness

Spec requirements this angle covers:
1. `before_update :broadcast_status_change` callback with correct guards -- plan A.1
2. Existing callback guards adequate for intermediate transitions -- plan A.3.4
3. `BROADCAST_STATUSES` constant with correct exclusions -- plan A.1.1

All covered.

## Findings

No issues found.

## Amendments Applied

None.
