# Spec Compliance (always-on) — Round 1

Also carries the always-on check **Source accuracy** (folded here per the round directive).

## Committed-code verification (pipeline rule 15)

`git status --short` clean in the worktree at review start. Reviewed `git diff 05c9513ef..HEAD`: 8 commits, 32 files, +1635/−15 — matches expectations exactly. All findings cite committed code.

## Section-by-section

- §3 data model: no migrations in the diff. ✓
- §4.1 gating change: DECISIONS-verbatim + approved kwarg; comments preserved; `auto_extract_job_criteria`/`extract_job_criteria` untouched; no pending guard. ✓ — EXCEPT the §4.1 documented mitigation "The frontend disables the button once the payload shows an in-flight status" is not implemented (F1 [HIGH], owned by frontend-display-states.md; SPEC §8.3 lists only `loading={isInFlight}` — internal spec tension recorded there; `disabled={isInFlight}` satisfies both clauses).
- §4.2 constants + `zero_criteria_failure?`: verbatim; three writers switched. ✓
- §4.3 predicate: verbatim, placed after `latest_succeeded_ai_job_criteria`. ✓
- §5.1 route, §5.2 controller, §5.3 serializer: SPEC-verbatim (see api-surface.md). ✓
- §6.2 guards at exactly the 4 specced sites; §6.3 claim-row fix minimal; §6.4 race left documented-and-accepted (no state transition added). ✓
- §7 job signature + 3 broadcast sites + helper: SPEC-verbatim including flag-4 positional form. ✓
- §8.1 hook: verbatim. §8.2 display states: exact precedence. §8.3 section: implemented per plan D-1–D-7 (extraction, action-row placement, icon sizing, token map, isInFlight derivation, route insertion, sidebar copy) — except F1 above. §8.4 view modal: verbatim incl. accepted frozen-prop staleness. §8.5 confirm modal: verbatim. §8.6 handler: verbatim. §8.7 payload type + header comment: verbatim. ✓
- §9 authorization: `show?` / `update_ai_settings?`, no new policy methods, org scoping, Flipper on POST only. ✓
- §10 constraints: decided-OUT absent (angle 7 greps clean); copy rules pass; regenerate works in ANY job state (no status conditions; draft+published tests); loading states present; pipeline rules 1/11/12/13/14/22/25/26 checked across angles — rule 11 is the one violation (F1). 
- §12 test plan: fully executed (see test-coverage.md). §13 file inventory: exactly the 9 new + 23 modified files, including the conditional `JobCriteriaSection.tsx` pinned YES by plan D-1. No EXTRA files, no MISSING files. ✓
- §14 flags 1-7: code honors every adjudicated ruling (kwarg; third message in the frozen constant list; failure broadcasts; positional args read positionally at all sites; failed-latest display precedence; claim-row fix minimal; optional `job` input). ✓

## Implementer interpretation call — ADJUDICATED

**View criteria during state 1 layered over state 4 (extraction in flight over an older success): CORRECT.** SPEC 8.2 row 4's own condition reads "`criteria` present (status `"succeeded"`, **or in-flight over an older success**)" — the layered state IS state 4 by the spec's own definition, so "View renders only in state 4" (§8.3) includes it; row 1 additionally directs rendering "row 4's card" whose rendering column includes the View action. §8.4's frozen-prop acceptance ("if a regeneration completes while the slide-over is open") presupposes View is reachable during an in-flight extraction. Not a finding; ruling recorded here.

## Source accuracy (always-on check)

Re-verified every load-bearing citation against the committed worktree: writer strings (extract_criteria.rb:59-62/:119-122, score_job_application.rb:40-43 post-substitution); analog job structure (generate_ai_job_application_summary_job.rb:13-22/:24/:34/:39-46/:50-80); `exists`/`render_one`/`render_general_errors` (application_controller.rb:40/:52-60/:89-91); `current_organization_user` (base_controller.rb:28-30); policies (job_policy.rb:12-14/:24-26; ai_job_application_summary_policy.rb:16-18 — reads `user` only); FullModal conditional header (:104-111); CenterModal required `headerTitleText`; EmptyState props (:7-13); FormSection `intro` (:11/:36/:47); SettingsContainer `sidebar` (:10/:25/:40/:72); PlatoChip `size`/`radius`; `distanceInWords` (time.ts:89-91); `queryCache` identifier (handler :11); `t.poly` composition (AppAuthRouter.tsx:411-415); JobSetupContainer route-prop spread (:487). All held.

## Findings

- (Cross-reference) F1 [HIGH] — section button not disabled during in-flight status; counted once in frontend-display-states.md.
