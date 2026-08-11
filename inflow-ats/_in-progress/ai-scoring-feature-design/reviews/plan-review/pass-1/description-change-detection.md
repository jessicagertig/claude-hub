# Pass 1 — description-change-detection

## Fact Check

### `handle_before_update` runs inside a `before_update` callback

Plan says this is a `before_update` callback. Actual: `app/models/job.rb` line 59: `before_update :handle_before_update`. CORRECT.

### `handle_before_update` structure (lines 475-483)

Plan G.3.1 shows the proposed `handle_before_update` with `handle_description_change` added after `handle_status_change`. Verified current source matches the plan's baseline (without `handle_description_change`). CORRECT.

### `description_meaningfully_changed?` implementation

Plan G.4.1 uses `ActionView::Base.full_sanitizer.sanitize` — matches the existing `description_without_html` method at line 677-678. CORRECT.

Plan uses `.gsub(/[^a-z]/, '')` to remove non-alpha characters (including digits). Spec says "Remove all non-alphabetical characters (including digits — intentional)." CORRECT.

### `before_update` callback context — nested save

Plan G.2.1 note documents that `extract_job_criteria` saves an `AiJobCriteria` record inside the `before_update` callback. This is a nested save inside a transaction. The plan cites existing precedent: `UpdateDistributionsJob.perform_later(id)` at line 479 (same callback). CORRECT.

However, there's a difference: `UpdateDistributionsJob.perform_later(id)` only enqueues a job (no nested model save), while `extract_job_criteria` both saves a model AND enqueues a job. Let me check if any other callback in `handle_before_update` does a nested save...

Looking at the source:
- `handle_status_change` (line 478) → `handle_status_changed_to_published` → `touch(:published_at)`, `update_column(:originally_published_at, ...)` — these are direct writes, not full saves
- `update_columns(display_location: ...)` (line 481) — direct column write

So `extract_job_criteria` would be the first method in `handle_before_update` that does a full `model.save` (AiJobCriteria) inside the callback. The plan's precedent citation is technically about job enqueuing, not about nested saves. But `touch` and `update_column` also write to the database inside the callback, so nested writes are established practice here.

### `description_changed?` guard in `handle_description_change`

Plan G.3.2 uses `description_changed?` as the first guard. In a `before_update` callback, `changed?` and `description_changed?` are available (they reflect dirty tracking before the save commits). CORRECT.

### `description_meaningfully_changed?` uses `description_was`

Plan G.4.1 uses `description_was` to get the old value. In a `before_update` callback, `description_was` returns the value before the change. CORRECT.

## Completeness

- [x] `handle_description_change` placed in `handle_before_update` (G.3.1)
- [x] Three guard conditions: `description_changed?`, `published?`, `description_meaningfully_changed?` (G.3.2)
- [x] HTML stripping matches existing pattern (G.4.1)
- [x] Digit removal intentional per spec (G.4.1)
- [x] Transaction timing documented (G.2.1 note)
- [x] Interaction with `handle_status_change` — both can fire on the same update if status and description change simultaneously. `handle_status_change` fires first. If the job is being published, `handle_status_changed_to_published` calls `extract_job_criteria`. Then `handle_description_change` also calls `extract_job_criteria`. The debounce in `extract_job_criteria` (return if `pending`) handles this — the second call returns immediately. CORRECT.

## Findings

No findings. Description change detection is correctly specified.
