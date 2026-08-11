# Verify T5 — Customer API Import

**Verdict: ISSUES** (one dropped fact; neutrality CLEAN)

## Files checked
- OLD: backend-flow-map-2026-06-17.md (changelog 83-104, 23, 25, 71; Part 398-408; census 639/649/679/712/731/843-845)
- NEW: backend-flow-map-2026-06-22-neutral.md (T5 §221-234; shared §118-149)

## Fact preservation — 20 OLD T5 facts checked, 1 dropped

All preserved except:

### DROPPED
- **`content_type_mismatch` error-code terminal distinction.** OLD line 88 names TWO distinct `context.fail!` calls inside `resolve_file_metadata`: `content_type_mismatch` when decoded bytes match no supported format (`customer_api_file_validation.rb:116-119`) AND `invalid_file_type` when the resolved content type is not in `RESUME_CONTENT_TYPES` (`:123-127`). NEW line 234 names ONLY `invalid_file_type` and collapses the citation to the merged range `customer_api_file_validation.rb:116-127`. The `content_type_mismatch` error_code and its specific `:116-119` sub-citation are absent from NEW. (The merged range `116-127` does span both, so this is a loss of error-code specificity, not a line-number alteration.)

## Neutrality — CLEAN
NEW T5 §221-234 and the shared poll service/job sections (§135-149) that carry T5 facts contain no banned vocab and no defect-framing. The only "orphan" match is the allowed method name `cleanup_orphaned_summary`. Phrasings like "rejection terminal", "self-healing re-submit", "no effect", "auto-path no-pre-existing-summary outcome", "returns at `:16` (no waiting summary)" are neutral graph/behavior descriptions.
