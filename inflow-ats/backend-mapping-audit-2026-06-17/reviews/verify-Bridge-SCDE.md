# Verify — Bridge-SCDE

**Topic:** The bridge `TextractResult#queue_ai_summary_job` (entry guards, waiting-summary selector, if/else branches) + the auto-branch three downstream cases (S-C no-pre-existing-summary; pre-existing non-succeeded; prior succeeded-but-stale S-D/T2) + S-E handoff + S-D auto-gen-ON validation-failure rest + the credit-scope distinction `orchestrate.rb:15` vs `textract_result.rb:77`.

**Verdict:** ISSUES

## Files checked
- OLD: `backend-flow-map-2026-06-17.md` — changelog lines 30-46 (T2/bridge), 187-235 (Trigger C/D/E), 290-295 (RECONCILIATION), Part 1 lines 299-371, Part 3 lines 612-617.
- NEW: `backend-flow-map-2026-06-22-neutral.md` — bridge 325-336, AI pipeline 340-405, S-D validation rest 394-395, T2 continuation 160-179, data-model callbacks 38-67, state-transition tables 460-499, Part 9 503-546, trigger matrix 606-610, changelog 642-658.

## CHECK 1 — Fact preservation

### Confirmed preserved (load-bearing facts + citations)
- Bridge registration / entry guards `textract_result.rb:114-144`, `:7`, `:115`/`:116`/`:119` — NEW 327, 329.
- Waiting-summary selector `:121-123` (JobApplication-scoped, stale:false, `.first`, no order) — NEW 331.
- `if` branch `:125-131` validate `:126`, requesting user `:127-131`, failure destroy `:134` + `AI_SUMMARY_FAILED` `:132-135` — NEW 333.
- `else` branch `:137-142`: `should_auto_generate_ai_summaries?` `:138`, validate `:140`, enqueue no-user `if result.success?` `:142`, validation-failure has no destroy/broadcast — NEW 334. Full validate fail list `:24-29` — NEW 334.
- Auto-branch three cases (S-C #1 no summary `orchestrate.rb:16` → `textract_result.rb:82`; #2 pre-existing non-succeeded advances + conditional credit on `textract_result_id` match, reuse keeps original id `generate.rb:31-33/:37`; #3 stale-succeeded `orchestrate.rb:46-48`, `:77` empty → `:82`, no credit) — NEW 386-392, 388-390.
- Credit-scope distinction `orchestrate.rb:15` (JobApplication-scoped) vs `textract_result.rb:77` (TextractResult-scoped, empty on new result) — NEW 40-42, 348, 390, 392.
- S-D / T2 auto-continuation: regenerating flip `find_or_create_…status.rb:14-15` driven by row pointer `:12`; status-only `:15`; no `current` reset; `ai_summary_status_change` broadcast `:16-20`; recovery via S-A/S-B `where(stale:false)` — NEW 173-177, 390, 483, 517-518, 542.
- S-D auto-gen-ON validation-failure rest (`:140`/`:142`; credits-exhausted `:28`/missing-job-description `:29`; set_initial_summary_pending suppressed by `:102` guard against `regenerating`) — NEW 395.
- S-E: user broadcast `textract_result.rb:128-131` → `AI_SUMMARY_COMPLETE` (corrects "None") — NEW 657, 333, 610. `textract_processing → extracting` via `.update` `generate.rb:31-33` — NEW 378, 657. `set_initial_summary_pending` `:98-108`/`:101`/`:102`/`:104-107` — NEW 510, 482. Terminal `.update` `integrate_analysis.rb:53` fires `update_summary_status_record` + `destroy_previous_textract_results` — NEW 65, 66, 380, 470. `ai_summary_succeeded` broadcast `:93-97` — NEW 66, 518. Status row → `current` shared writer `:69-80` — NEW 66, 484. awaiting_job_criteria rest desync (row stays `initial_summary_pending`) — NEW 539, 482, 467. Credit on S-E success `:82`/`:84`/`:87-88` — NEW 349, 610. `:68` early return does not fire for textract_processing — NEW (mechanism at 345/351). Retry/exhaustion `retrying` `generate.rb:175`, `retry_on attempts:3 :13`, exhaustion `:failed :19` — NEW 356, 471.
- BROADCAST_STATUSES omits `awaiting_job_criteria`/`retrying` `:23`; `before_update :broadcast_status_change` only for BROADCAST_STATUSES — NEW 56-57, 67. (Consequence "awaiting transition emits no `ai_summary_status_change`" is derivable from these + the desync note 539; treated as preserved via de-duplication.)
- X3 resume drops requesting user → no toast `ai_job_criteria.rb:25-27`, `generate_…job.rb:34` — NEW 405.

### DROPPED
1. **S-E direct-path divergence window (OLD line 234, pass-7).** OLD states that the bridge selection at `textract_result.rb:121-123` (unordered `.first`) is read ONLY to obtain `requested_by_organization_user_id` and choose the branch — the job receives `textract_result_id` only (`:129`), never a summary id — and that the TRUE advancing selector is a SEPARATE ordered query (`orchestrate.rb:15`, `Summary::Generate generate.rb:30`), creating a divergence window when the latest-by-`created_at` summary is not the bridge-selected `textract_processing` one. NEW line 331 retains only the earlier OLD-219 framing ("This determines which record advances and is read to choose the branch"), which OLD line 234 explicitly refined. NEW line 404 carries the analogous ordered-re-selection point only for the **X3 resume** path, not for the **S-E direct** bridge handoff. The S-E-direct divergence window and the "bridge selection does not actually pick the advancing record" correction are absent from NEW.

2. **Exhaustion broadcast citation `:20` (OLD line 230, minor).** OLD: on `GenerateAiJobApplicationSummaryJob` retry exhaustion, sets `:failed` (`:19`) AND broadcasts completion (`:20`). NEW line 356 retains the `:19` `:failed` write but omits the `:20` broadcast-completion-on-exhaustion citation.

### ALTERED
- None. (NEW line 331's "determines which record advances" is the OLD-219 wording faithfully carried; the issue is the missing OLD-234 refinement, logged as DROPPED above, not an alteration of meaning of a fact OLD still holds.)

## CHECK 2 — Neutrality
No banned vocabulary in the topic text. OLD's "STUCK `regenerating`", "NO-OP dead end", "silently", "broken", "gap", "MAP-WRONG" framings are all neutralized: NEW uses "remains `regenerating` with the old denormalized data", "no credit is charged", "the row is not flipped", "returns at `:138`". Occurrences of "never" (e.g. NEW 191 "never the waiting-summary branch", 452 "never written by app code", 211 "never saves the candidate") are factual descriptions of code behavior, not defect-framing. "load-bearing" (NEW 40) is a neutral technical descriptor. No prescriptive `should`/`must`, no `incorrect`/`problem`/`defect`/`wrong`, no judgmental ALL-CAPS. CLEAN on neutrality.

## Net
ISSUES — one substantive dropped fact (S-E direct-path divergence window, OLD 234) and one minor dropped citation (`:20` exhaustion broadcast, OLD 230). Neutrality clean.
