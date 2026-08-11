# Verify T3 — Clone Job Application

**Verdict: CLEAN**

## Files checked
- OLD: `backend-flow-map-2026-06-17.md` (changelog lines 48-62; Part lines 373-381; censuses/matrices 639,649,679,712,729,843-848; recap 651)
- NEW: `backend-flow-map-2026-06-22-neutral.md` (T3 section lines 181-200; censuses/matrices 447,457,480,578,595,618-628; recap 651)

## CHECK 1 — Fact preservation

Every load-bearing T3 fact in OLD is present in NEW:

| OLD fact / cite | NEW location |
|---|---|
| `clone_to_job` `job_applications_controller.rb:132-145`; route `config/routes.rb:282`; `→ clone_to_job_at_hiring_stage (job_application.rb:387)` | NEW:182 |
| Controller authorizes SOURCE job (`clone_to_job?` policy, `job_policy.rb:50` `on_hiring_team?`) at `:134` | NEW:184 |
| `dup` (`:391`, def `:387-412`) copies attributes only; does not copy `has_many :textract_results` (`:28`) / `ai_job_application_summaries`; zero TextractResults+summaries at creation; original `textract_job_result_text` not carried over | NEW:186, 188 |
| `resume.blob` re-attach CONDITIONAL `if has_resume` (`:401`); `additional_files` re-attached when present (`:403-407`); `created_via = 'created_via_clone'` (`:400`); `clone_of_job_application_id` (`:399`) | NEW:187 |
| Clone builds NEW `in_progress` TextractResult via `submit_resume_to_textract.rb:22` (no `find_or_create`), blob → AWS (`:16`); status row `'none'` (`:167-170`) | NEW:188 |
| stale `update_all` (`:18-19`) + waiting-summary relink (`:25-26`) no-effect on clone | NEW:189 |
| Else (auto-gen) branch (`textract_result.rb:137`), never IF (`:125`); requires BOTH `should_auto_generate_ai_summaries?` (`:138`) AND `ValidateAiSummaryGeneration result.success?` (`:140-142`); no requesting user (`:142`) | NEW:191 |
| Resume-bearing clone (flag ON): poll `GetResumeTextFromTextractJob.set(wait: 2.minutes)` (`:27`); auto-gen OFF → returns `:138`, succeeded TextractResult, no summary, status `'none'`; auto-gen ON → S-C no-op (`orchestrate.rb:16`, `textract_result.rb:82`), no summary/credit/broadcast | NEW:193 |
| No-resume clone terminal (`:401` re-attaches nothing; `'No resume attached'` `submit_resume_to_textract.rb:10`); status `'none'` | NEW:196 |
| Flipper-OFF clone terminal (`job_application.rb:167-168`) | NEW:197 |
| Candidate-already-in-target: `:taken` error (`:393`), guard `:139` short-circuit, no save/after_commit/status row/Textract/record | NEW:198 |
| `complete_cloning` after_create `:414-437`, copies only `question_responses` `:430-435`, channel/message commented out `:420-428`, no Textract/AI | NEW:200 |
| `CloneJobApplication` zero callers, not on any route, undefined `clone_to_job` + undefined local `new_job_id` (`:22`) | NEW:200 |
| Census/matrix T3 entries (in_progress, no-TextractResult, none, Flipper, trigger row 3, write-site censuses) | NEW:447,457,480,578,595,618-628 |

No DROPPED facts. No ALTERED facts (all `file:line` citations match; no flipped conditions).

De-duplications (not drops):
- `find_or_create_…status.rb:34,37` else-branch `'none'` creation: stated once in NEW's `none` state-table row (NEW:480, mapped T1,T3,T4,T5,T6) rather than repeated in T3.
- "fresh clone's `latest_ai_job_application_summary` (`job_application.rb:31`) is nil" (OLD:50): entailed by NEW:186 "zero summaries at creation"; the association is defined at NEW:112. Derivable consequence, not an independent load-bearing fact.

## CHECK 2 — Neutrality

No defect-framing in the NEW T3 text. The reframe correctly neutralized OLD's loaded vocab:
- OLD "DEAD CODE" / "dead/broken" (CloneJobApplication) → NEW "has zero callers and is not on any route; calls an undefined ... and an undefined local" (NEW:200). Neutral.
- OLD "candidate-already-in-target dead end" → NEW "Candidate already in target job → ... short-circuits: no save, ... no record persisted" (NEW:198). Neutral.
- NEW:189 "have no effect" replaces OLD "no-op" — neutral factual state description, not banned vocab.

No prescriptive "should" (only the method name `should_auto_generate_ai_summaries?`), no "never recovers", no judgmental ALL-CAPS, no "matters/concerning/problem/incorrect/wrong".

**Verdict: CLEAN**
