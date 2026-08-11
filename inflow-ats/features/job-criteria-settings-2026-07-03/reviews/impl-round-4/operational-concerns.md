# Operational Concerns — Round 4

- **Logging improved by the commit:** the bulk validation-failure branch (previously a silent `:failed` write) now emits a `Rails.logger.error` with job_application id and the interactor's error message — closes the observability gap the conventions pass flagged. Sibling-consistent grep target (`BulkGenerateAiSummariesJob validation failed`).
- **Broadcast reliability:** the fresh read cannot raise where `reload` could (`RecordNotFound` from the exhaustion handler); failure paths now degrade to a skipped broadcast instead of a raised exception inside `retry_on`'s block. Marginal operational improvement, zero regression.
- **Performance:** `find_by(id:)` is the same single-row PK query `reload` issues — no query-count change. The shared tiers constant is module-level — no per-render allocation change of consequence.
- **Deploy:** no migrations, no signature changes, no queue-payload shape changes in the commit; safe with in-flight jobs.
- **Test-environment note:** see test-coverage.md F1 (LOW) — transient first-runs-after-idle suite instability from stale test-DB residue, washed out and stable by run 3; not attributable to this commit; worth knowing when interpreting a first red pre-commit run.

## Findings

No issues found. (test-coverage.md F1 is recorded there.)
