# Verify T2 — Manual resume upload/replacement

**Verdict: CLEAN**

## Files checked
- OLD: backend-flow-map-2026-06-17.md (changelog lines 30-46; Part body 358-371; Trigger D 202-214; bridge/pipeline 187-200; matrix 369; Flipper 356)
- NEW: backend-flow-map-2026-06-22-neutral.md (T2 section 160-179; shared callback 120-122; bridge 325-336; AI pipeline auto-branch case 3 388-392; S-D rest 394-395; tables 457,482-484,540-542; matrix 594,608-609; Flipper 578; deltas 649-650)

## CHECK 1 — Fact preservation

All 16 load-bearing T2 facts in OLD are present in NEW with matching file:line citations:

1. Change-detection surface = controller `update` action (not model callback); no AR dirty-tracking for ActiveStorage; comments `:109,111` → NEW:163
2. Controller resume-present gate `temp_params.key?(:resume) && temp_params[:resume].present?` (`:110`), blank rejected before in-service `:10` guard → NEW:165,168
3. Controller-side Flipper gate `:113-114`; flag OFF → resume replaced, no Textract, prior summary succeeded+non-stale, status row current → NEW:169
4. DocxToPdfJob `:112` enqueued before Textract, both perform_later no ordering, prefers resume_docx_to_pdf `:15` → NEW:120,165
5. `regenerating` IS set `find_or_create...:14-15`, guarded on summary `status_succeeded?` `:12` → NEW:174,517
6. credit-flow guard `:67-68`; stale-succeeded no longer short-circuits → NEW:174,345
7. `create_status_record` removed from AiJobApplicationSummary → NEW:69,647
8. 4-value enum, no regenerating boolean column, value 3 via update_columns → NEW:78,82,517
9. update_summary_status_record sets current via .update (not succeeded/int-7/update_columns) → NEW:66,484,648
10. STUCK-regenerating-with-stale-data terminal, NOT current→regenerating→current round trip; orchestrate.rb:15-16 JobApplication-scoped no-stale-filter, succeeded branch returns `:46-48` → NEW:174,390,542
11. auto-gen GATE `:138`; ON→regenerating, OFF→stays current with stale data, prior summary stale:true → NEW:173,175,542,609
12. no requesting user → no AI_SUMMARY_COMPLETE toast `:142` → NEW:174
13. no-resume removal terminal `:10` before stale update_all `:18-19` and build `:22` → NEW:170
14. guarded-skip stale window `:18` unless guard → NEW:179
15. waiting-summary relink redirects bridge in guarded-skip window `:25-26`, IF branch `:125` → NEW:179
16. rescue-swallow resting state on T2 replacement submit failure (job rescue `:9-11`, service rescue `:31-40`) → NEW:171 (mechanism citations at NEW:133,356)

Also preserved: recovery to current via later manual (S-A) OR bulk (S-B) regen, both filter where(stale:false), bulk pre-filter drops only :current (NEW:177); regenerating broadcast ai_summary_status_change `:16-20` (NEW:390,517,532); two-site Flipper relationship controller-side T2 vs model-side T1/T3/T4/T5/T6 (NEW:122,578).

No DROPPED facts. No ALTERED facts (no changed line numbers, no flipped conditions).

## CHECK 2 — Neutrality

No banned vocab or defect-framing in the T2 region. OLD's framing was neutralized:
- OLD "STUCK regenerating" → NEW "remains/stays `regenerating`" (174,542)
- OLD "MAP-WRONG Gap 7/Gap 8 BROKEN" → NEW plain factual statements
- OLD "dead end" / "no further actor" → NEW "resting" / factual control-flow
- "never reached" (NEW:168) is a factual control-flow statement, not "never recovers" framing — acceptable
- "should_auto_generate_ai_summaries?" is a method name; "stale" is a column value — not framing

No residual framing items.
