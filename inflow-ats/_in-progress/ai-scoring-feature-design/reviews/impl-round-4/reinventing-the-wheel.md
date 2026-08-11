# reinventing-the-wheel -- Round 4

## Scope

Check for reimplemented patterns that already exist in the codebase.

## Findings

### AiApiRequest creation pattern

All four services (`ExtractCriteria`, `ScoreJobApplication`, `IntegrateAnalysis`, and the existing `Summary::Generate`) use the same private `create_ai_api_request` method pattern. The method signature and body are nearly identical across all four. This is a slight DRY concern but follows the existing analog pattern -- `Summary::Generate` already has this as a private method, and the new services copy it. Extracting to a shared module is a potential future improvement but not a current defect.

### AiClient usage

Uses `AiClient.new(provider: ...)` and `AiClient.calculate_cost(...)` -- existing infrastructure. No new HTTP clients or AI providers invented.

### Cost tracking

Reuses `AiApiRequest` with polymorphic `requestable`. No new cost tracking mechanism.

### Job patterns

`ExtractJobCriteriaJob` follows the `GetResumeTextFromTextractJob` pattern exactly: `retry_on` with exhaustion block, `find_by` guard, delegate to service. No reinvention.

### Status read model

`AiJobApplicationSummaryStatus` is a new concept (lightweight read model for list views) but doesn't reinvent anything -- it's a standard denormalization pattern to avoid loading heavy jsonb columns.

### HTML stripping

`description_meaningfully_changed?` uses `ActionView::Base.full_sanitizer.sanitize` -- the same approach as the existing `description_without_html` method on `Job`. No reinvention.

## Result: PASS -- 0 findings
