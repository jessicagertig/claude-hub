# description-change-detection -- Round 5

## Scope
`Job#handle_description_change`, `description_meaningfully_changed?`, interaction with `handle_before_update` callbacks, transaction timing.

## Files reviewed
- `app/models/job.rb` lines 476-717

## `handle_before_update` integration

```ruby
def handle_before_update
  if changed?
    handle_status_change      # line 479
    handle_description_change  # line 480
    UpdateDistributionsJob.perform_later(id) unless skip_update_callback
    update_columns(display_location: location_pretty) if location_pretty_has_changed?
  end
end
```

`handle_description_change` placed after `handle_status_change`. Order matters: if a job transitions to `published` AND has a description change in the same save, `handle_status_change` fires `handle_status_changed_to_published` which calls `extract_job_criteria`. Then `handle_description_change` fires, but `extract_job_criteria` sees a `pending` record (just created by the publish path) and returns immediately via the debounce guard. No double-extraction. Correct.

## `description_meaningfully_changed?` logic

```ruby
def description_meaningfully_changed?
  old_text = ActionView::Base.full_sanitizer.sanitize(description_was).to_s.downcase.gsub(/[^a-z]/, '')
  new_text = ActionView::Base.full_sanitizer.sanitize(description).to_s.downcase.gsub(/[^a-z]/, '')
  old_text != new_text
end
```

- Uses `ActionView::Base.full_sanitizer.sanitize` -- same approach as existing `description_without_html` method (line 681-682)
- `.to_s` handles nil from `description_was` gracefully
- `.downcase` -- case-insensitive
- `.gsub(/[^a-z]/, '')` -- strips everything except lowercase letters. Digits removed intentionally per spec.

## Guards on `handle_description_change`

1. `description_changed?` -- Rails dirty tracking
2. `published?` -- only for published jobs
3. `description_meaningfully_changed?` -- content-based comparison

All three guards present. Draft jobs, non-description changes, and trivial changes (whitespace, HTML tags, numbers, case) do not trigger extraction.

## Findings

None.
