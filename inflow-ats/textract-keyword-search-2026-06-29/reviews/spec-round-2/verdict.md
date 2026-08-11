# Spec Review — Round 2 Verdict
**Date:** 2026-06-29 13:00

## Counts
- BLOCKER: 0
- HIGH: 0
- MED: 5
- LOW: 1

## MED Findings

1. **Internal inconsistency: old "Integration point" still says "OR"** (reference-fidelity F1): Lines 129-132 still presented both options, but the decision was made at lines 193-197 (after_commit + background job). Amendment: updated old section to match.

2. **Model section omits `has_many :ai_api_requests`** (reference-fidelity F2): Service section says to add it, but Model section didn't list it. Amendment: added to Model section.

3. **`call_type` value unspecified for AiApiRequest** (reference-fidelity F3): Spec said to create AiApiRequest but didn't say what call_type string. Amendment: specified `call_type: 'keyword_extraction'`.

4. **`organization` navigation for AiApiRequest not explicit** (reference-fidelity F4): The organization is required (NOT NULL) but the spec only referenced the existing pattern without calling out the navigation path or nil handling. Amendment: specified `textract_result.job_application.job&.organization` with nil guard.

5. **Custom error class was generic "CustomError"** (cross-fork identification): The retry_on spec referenced `CustomError` which is not a real class in the codebase. Amendment: specified `CustomErrorStructuredExtraction` with file path matching existing `CustomErrorTextract` / `CustomErrorAiSummary` pattern.

## LOW Findings (no amendments)

6. **Novel backfill-enqueue-from-migration pattern** (reference-fidelity F5): No existing data migrations enqueue Sidekiq jobs. Risk if Sidekiq isn't running at migration time. Acceptable trade-off but backfill job should be monitored separately from deploy.

## Amendments Applied

1. "Integration point" paragraph updated to match Call Site decision (removed "OR")
2. Model section expanded with `has_many :ai_api_requests, as: :requestable`
3. AiApiRequest creation expanded with all required fields, `call_type: 'keyword_extraction'`, organization access path, nil guard
4. Custom error class specified: `CustomErrorStructuredExtraction` in `app/errors/`

## Verdict: FAIL
