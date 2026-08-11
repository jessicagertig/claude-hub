# Verify — Coverage (X0 write-site census, feature gates summary, trigger matrix)

**OLD:** backend-flow-map-2026-06-17.md (Part 6 Feature Gates, Part 7 Trigger Matrix, Part 10 X0 census; plus changelog cross-refs)
**NEW:** backend-flow-map-2026-06-22-neutral.md (Feature gates, Trigger matrix, Write-site coverage (X0 census))

## CHECK 1 — Fact preservation

### Feature gates (OLD Part 6 :710-718 → NEW :576-584)
All 7 gate rows present and identical (`TEXTRACT_RESUME_PROCESSING`, `AI_APPLICANT_SUMMARY`, `ai_credits_available?`, `should_auto_generate_ai_summaries?`, `has_job_description?`, `can_use_ai_credits?`, controller create gate). All `file:line` citations preserved. CLEAN.

### Trigger matrix — Textract triggers (OLD :725-735 → NEW :591-601)
All 9 rows present with identical entry points, resume sources, Flipper gates, status-row values, and notes. Row 6 "permanent no-Textract terminal even after later attach" → NEW "no `TextractResult` even after later attach (T7)" (fact preserved). Row 9 detail preserved. CLEAN.

### Trigger matrix — AI summary triggers (OLD :738-744 → NEW :604-610)
All 5 rows (A-E) present. Create interactors, auto-gen checks, user-broadcast, credits all preserved. Row D "Textract callback else after new result" → NEW "Bridge else after new result" (same). CLEAN.

### X0 census (OLD Part 10 :843-861 → NEW :618-638)
- TextractResult, AiJobApplicationSummary, AiJobApplicationSummaryStatus, AiJobCriteria, BulkAiSummaryJobApplication, JobApplication/external_resume_status: all six table groups present with identical `file:line` enumerations and trigger/structural angle ownership lists.
- Record-destroy sites (3) preserved with owners (NEW :630).
- Rake-layer sites (ai_bulk_extract.rake 3 sites, housekeeping_tasks.rake :409/:445) preserved (NEW :635-636).
- Untraced-to-terminal items (NewJobApplicationJob, DocxToPdfJob, RoleFitFilterable, bulk mailer bodies) preserved (NEW :638).
- "ORPHANS: NONE" folded into the positive "every site owned by ≥1 path" statement (NEW :632) — fact preserved.

**De-duplication (not flagged):** OLD's circular `X0` self-references ("...,X0" on `integrate_analysis` :844 and `update_summary_status_record` :845; "(and X0 census)" :846; "(and X0)" :847; "(T-trigger censuses)" :848) are dropped in NEW. These are the X0 census naming itself as an owner — pure self-reference, not a load-bearing angle. Not a fact drop.

**ALTERED — runtime consequence of the two stale rake enum sites narrowed.**
OLD :855 states the two `ai_bulk_extract.rake` sites (`:34-38` `create(status: :in_progress)`, `:59-62` `update(status: :extracted)`) "would raise `ArgumentError`" and "would error at runtime against the current 10-value enum." NEW :635 reduces this to "(`:in_progress` is not a value in the current 10-value enum)" / "the first two reference enum values not present in the current enum" — stating only the precondition and dropping the runtime consequence. The ArgumentError-on-invalid-enum-assignment behavior is a factual Rails runtime consequence, not defect-framing.
- Neutral fix preserving the fact: "assigning `:in_progress` / `:extracted` raises `ArgumentError` because the value is not in the current 10-value enum."

## CHECK 2 — Neutrality
NEW topic text (Feature gates, Trigger matrix, X0 census, :574-638) contains no banned vocab. The only "orphan"/"cleanup" match is `cleanup_orphaned_summary` (allowed method name, :630). OLD's "STUCK `regenerating`" (ALL-CAPS judgmental, Part 7 row 2) is correctly neutralized to "status row `regenerating`" (NEW :594) with the state fact preserved. No prescriptive should, no editorializing, no defect framing. CLEAN on neutrality.

## Verdict: ISSUES (one ALTERED fact — runtime ArgumentError consequence dropped at NEW :635)
