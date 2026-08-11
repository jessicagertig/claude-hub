# criteria-enqueue transaction safety (W3) — Round 1

Traced: `job.rb` callbacks `:56-65` → `handle_before_update:481-489` → `handle_status_change:517-539` → `handle_status_changed_to_published:548-563` → NEW `handle_criteria_extraction_after_commit:734-740` + `description_saved_change_is_meaningful?:742-747` + `sanitize_for_compare:753` → `auto_extract_job_criteria:698-713` → `extract_job_criteria_job.rb:13-14`.

## Findings

W3 is structurally correct and matches the analog (`handle_after_update_commit`'s post-commit `previous_changes` pattern):
- Both old call sites removed: `auto_extract_job_criteria` deleted from `handle_status_changed_to_published` (was `:560`); `handle_description_change` call removed from `handle_before_update` (`:485` region). `auto_extract_job_criteria` now has exactly one caller path (the two `if/elsif` branches of the new after_commit callback — at most one fires per save). Grep-confirmed no other caller.
- Dedicated `after_commit :handle_criteria_extraction_after_commit, on: [:update]` registered at `:63` — NOT inside `handle_after_update_commit` (which early-returns on `:496 return if skip_update_callback`). So criteria extraction runs irrespective of `skip_update_callback`, preserving the pre-fix behavior (before_update fired regardless of the flag). HARD requirement W3.3 satisfied.
- Publish detection: `saved_change_to_status? && published?` — correct post-commit dirty API. Description detection: `description_saved_change_is_meaningful?` uses `saved_change_to_description` (`[old,new]`) and the shared `sanitize_for_compare` — it does NOT read `description_was` (which would be reset post-commit). The W3.2.2 dirty-tracking trap is correctly avoided.
- `description_meaningfully_changed?` retained (refactored to use `sanitize_for_compare`) because the existing `job_criteria_lifecycle_spec.rb:104-142` still calls it directly; behavior preserved.
- `auto_extract_job_criteria` body unchanged (flipper guard, pending poison-guard, `wait: 30.seconds` debounce) — only the WHEN changed. Its own `AiJobCriteria.save` commits before `ExtractJobCriteriaJob.perform_later`, and the after_commit placement guarantees the Job row is committed → the worker always finds the row.

No double-fire: the dedicated callback is registered once; `auto_extract_job_criteria`'s pending-guard would no-op a redundant second call anyway.

No correctness issues. The implementation chose option (b) (analog-matching) as the plan preferred. **However, W3 has ZERO test coverage of the changed code path** — see `test-coverage.md` (HIGH).
