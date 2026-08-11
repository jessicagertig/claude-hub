# Verify T1 — Trigger 1 (new job application created)

**Verdict: CLEAN**

## Files checked
- OLD: backend-flow-map-2026-06-17.md (changelog lines 20-28; Part 1 shared service lines 300-356)
- NEW: backend-flow-map-2026-06-22-neutral.md (lines 118-158; state table line 480; X1 lines 509, 646)

## CHECK 1 — fact preservation

Every load-bearing T1 fact in OLD is present in NEW:

| OLD fact | OLD cite | NEW location |
|---|---|---|
| Callback registration line + body | job_application.rb:45 / :164-171 | NEW:120, 152 |
| `find_or_create_ai_job_application_summary_status` unconditional, `'none'` on fresh app, not Flipper-gated | job_application.rb:170; find_or_create:34 assign + :37 save | NEW:120, 156, 480 (`status.rb:34,37 ... save`), 646 |
| `created_via` 8 values enumerated | job_application.rb:83-91 | NEW:154 |
| source-agnostic `on:[:create]`, all 8 reach; no insert_all bypass; public assign | public/jobs_controller.rb:38 | NEW:154 |
| resume-less fork → 'No resume attached' before build :22, no TextractResult | submit_resume_to_textract.rb:10, :22 | NEW:127, 157 |
| self-healing re-submit on nil textract_job_id | get_resume_text_from_textract.rb:14-17 | NEW:139, 158 |
| flag-OFF: submit not enqueued, in-service :10 not reached, different mechanism | job_application.rb:167-168 | NEW:122 |
| Flipper checked at exactly two app sites | :167 / controller :113 | NEW:122 |
| job.organization deref to scope Flipper; belongs_to :job | job_application.rb:167 | NEW:154 |
| in_progress only when resume present | — | NEW:157 |

No DROPPED facts. No ALTERED facts (all file:line citations match; no flipped conditions).

## CHECK 2 — neutrality

Scanned NEW T1-specific lines (151-158), shared-service lines (120-149), and whole-doc for banned vocab and subtler framing. Only hit is `cleanup_orphaned_summary` (NEW:149) — the explicitly-allowed method name. The OLD framing terms in the changelog (MAP-WRONG, "hazard", "dead end") were dropped while the underlying facts were retained (e.g., OLD line 28 "not a real T1 terminal hazard" → NEW:154 states the deref fact neutrally). No residual framing.
