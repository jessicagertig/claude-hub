# operational-concerns — Impl Round 1

## Findings

### Logging
- Change 1: No logging added. `ap` statements from the existing code (lines 14, 29) remain. The new code is a simple query + update — logging would be noise. Acceptable.
- Change 2: No logging added in the exhaustion block. The existing `ap` logging in `GetResumeTextFromTextract` (lines 26-29, 33, 37) covers the failure path. Acceptable.
- Change 3: No logging needed for a guard clause. Correct.

### Error handling
- Change 1: `find_by` returns nil if not found. `&.update_columns` is nil-safe. No error to handle.
- Change 2: `find_by` returns nil. Guard clauses handle nil cases with `return unless`. `summary.destroy` could raise, but ActiveRecord `destroy` on a simple record should not fail. If it does, the exception propagates to the caller (ActiveJob exhaustion handler), which is appropriate.
- Change 3: `return unless textract_result` — guard prevents crash. Correct.

### Performance
- Change 1: One `find_by` query + one `update_columns` SQL. Negligible. Runs once per `submit_resume` call.
- Change 2: Three `find_by` queries + one `destroy` + one `order(created_at: :desc).first`. All indexed. Negligible. Runs only on retry exhaustion (rare event).
- Change 3: `textract_result` is an association accessor (single query, cached). Negligible.

### Deployment
- No migrations needed (migration already applied as prerequisite).
- No environment variables needed.
- No feature flags needed.
- Changes are backward-compatible — safe to deploy.

No issues found.
