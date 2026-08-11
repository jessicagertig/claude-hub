# Verify — Pipeline topic

**Topic:** The AI pipeline — `generate_ai_summary_with_credit_flow` driving method, `GenerateAiJobApplicationSummaryJob` (`retry_on`, `broadcast_completion`), `Orchestrate#call` selection + case branches, Summary/Scoring/Integration stages, the `succeeded` `.update` terminal write and what it fires.

**Verdict: ISSUES**

## Files checked
- OLD: `backend-flow-map-2026-06-17.md` (changelog Triggers A/C/D/E lines 168-235, S-C/S-D reconciliation 290-295; Part 2 lines 463-608; Part 3 bridge 612-616; Part 4 620-627; Part 5 tables 5.2/5.3/5.4 lines 651-704; Part 8 WebSocket 748-759; Part 9 dedicated 763-835; Part 10 census 839-861)
- NEW: `backend-flow-map-2026-06-22-neutral.md` (Data models 44-114; bridge 325-336; The AI pipeline 340-435; State tables 459-499; dedicated section 503-547; Frontend/WebSocket 550-570; gates 574-584; matrix 588-610; X0 census 614-638; Changes-since 642-658)

## CHECK 1 — Fact preservation

Nearly all load-bearing pipeline facts are preserved (driving-method 5 steps + `:68` early return; `GenerateAiJobApplicationSummaryJob` `retry_on`/`:30` nil-guard/`broadcast_completion`/`failed`-only writer; `Orchestrate` `:6/:12/:15/:16` selection + full dispatch case table + `check_criteria_and_score`; all three Stages incl. `:124`/`:53` writes and all `retrying`/`failed` writer lines; `integrate_analysis.rb:53` `.update` terminal firing `update_summary_status_record` + `destroy_previous_textract_results`; auto-branch 3 cases incl. conditional-credit detail; X3 re-trigger newest-summary fork; bulk flow; credit system; status-row transition table). De-duplicated repetition is fine.

### DROPPED
1. **S-E advancing-selector divergence window (OLD changelog line 234, pass-7).** OLD states the bridge selector `textract_result.rb:121-123` (unordered `.first`) is read ONLY to get `requested_by_organization_user_id` and choose the branch; the job carries `textract_result_id` only, never a summary id; the TRUE advancing record is re-selected by a *separate ordered query* at `orchestrate.rb:15` AND `generate.rb:30`; if the latest-by-`created_at` summary is not the bridge-selected `textract_processing` one, the advanced record diverges from the record whose user drove the broadcast-branch decision. NEW cites `orchestrate.rb:15` re-selection (line 404, in the X3 context) but never cites `generate.rb:30` as an independent ordered re-selection site, and never states the S-E divergence window. `grep diverg` over NEW returns only T5/T6 import/CSV uses; no pipeline divergence-window statement exists.

## CHECK 2 — Neutrality

NEW pipeline topic text is clean. No banned vocab (`grep -niE "dead end|stuck|broken|orphan|no-op|silently|hazard|fails to|gap|map-wrong|never recovers|incorrect|problem|defect|wrong|matters|concerning|should "` → zero hits across the whole file). No judgmental ALL-CAPS (`NO-OP|STUCK|BROKEN|DEAD|NEVER|WRONG|SILENT` → zero). All "never" usages are factual state-graph descriptions ("never written by app code", "never processed", "never `:retrying`", "row was never created"). "Resting" is explicitly defined as a neutral graph property (line 441). The `STALE-REBUILD` token is a branch name carried over neutrally.

### ALTERED (framing, on the same point as the dropped fact)
1. **NEW line 331:** "This determines which record advances and is read to choose the branch." This inverts OLD's pass-7 correction (changelog 234), which says the bridge selector is used ONLY to read the user and choose the branch and is NOT the advancing selector (the advancing record is the separate ordered query). Old cite: line 234 "The bridge selects the waiting summary … ONLY to read `requested_by_organization_user_id` and choose the branch; the job receives `textract_result_id` only … `Orchestrate#call` independently re-selects …". Neutral fix: change to "is read to choose the branch and to read `requested_by_organization_user_id`; the record that actually advances is re-selected independently by `Orchestrate#call` (`orchestrate.rb:15`) and `Summary::Generate` (`generate.rb:30`) via an ordered query, so when the latest-by-`created_at` summary is not this `textract_processing` one, the advanced record differs from the one read here."

This is a content-fidelity inversion, not defect-framing; flagged as ALTERED.
