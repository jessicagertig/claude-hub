## Summary

Makes the bulk "Generate AI Summaries" flow report what will actually run, scopes the post-summary refetch to one stage, adds a per-job AI-summaries counter cache plus groundwork columns, and cleans up the AI credit interactors.

## Bulk count accuracy
- **`bulkAiSummaryCount.ts`** (new): `bulkSummaryProcessableCount` counts the selection minus candidates whose `AiJobApplicationSummaryStatus` is `current` (already summarized → excluded at enqueue). Returns `isExact` — `false` for a not-fully-loaded Select-All, where the number is an upper bound.
- **`JobStageMenu` / `BulkGenerateAiSummariesConfirmModal`**: show the processable count and credit estimate, three instruction states (nothing-to-generate / exact / "up to N" caveat), and disable Generate when nothing is processable.
- **`queue_bulk_ai_summary_jobs`**: drops `current`-status candidates from both `ready_ids` and `input_ids`, so already-summarized candidates never get a row and aren't counted as skipped.

## Scoped Harvey-ball refetch
- `ai_summary_succeeded` broadcast now carries `hiringStageId`.
- `WebsocketJobChannelHandler` invalidates only `["jobApplicationsForStage", hiringStageId]` instead of every stage.

## Per-job AI summaries counter cache
- Migration adds three `jobs` columns: `ai_job_application_summaries_count` (counter cache), `ai_job_criteria_generations_count`, and `internal_job_criteria` (text). The latter two are columns only — logic not yet wired.
- `counter_culture [:job_application, :job]` on `AiJobApplicationSummaryStatus`, conditional on `current`/`regenerating` (mirrors the `published_jobs_count` pattern). Increments live via the `none → current` transition, which required switching that write from `update_columns` to `update` in `update_summary_status_record` (`ap` on success, error in `else`; the existing broadcast is untouched).
- Data migration backfills existing jobs via `counter_culture_fix_counts`; the `reset_counters` rake task reconciles the new counter alongside the others (outside-the-app-drift safety net).
- `FindOrCreateAiJobApplicationSummaryStatus`: renamed `latest` → `latest_ai_job_application_summary` to disambiguate it from the status record the interactor also handles.

## Bulk-pending groundwork
- `JobApplication has_many :bulk_ai_summary_job_applications` (+ `belongs_to` back).
- Shallow serializer exposes `bulk_ai_summary_processing` (`status_processing.exists?`). No front-end consumer yet — groundwork for a future "pending in a bulk run" indicator.

## AI credit interactor cleanup
- Rename `txn` → `ai_credit_balance_transaction`, `existing` → `existing_purchase`, `ledger` → `ai_credit_balance_transaction`.
- Inline `record.update` guards; remove "ledger" jargon from error messages and comments.

## Not included
- Spec updates (held back per request).
- Logic for `ai_job_criteria_generations_count` / `internal_job_criteria` (columns only for now).

🤖 Generated with [Claude Code](https://claude.com/claude-code)
