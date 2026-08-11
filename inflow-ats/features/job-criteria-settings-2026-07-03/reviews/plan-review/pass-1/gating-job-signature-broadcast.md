# Job gating change, ExtractJobCriteriaJob signature, and the WebSocket broadcast lifecycle — Pass 1

## Fact Check

| Plan claim | Verified against | Result |
|---|---|---|
| E.3.1: job.rb:726-743 still has the OLD form (guards in `_if_needed`) | Read job.rb :685-745 | ✓ `extract_job_criteria_immediately` :726-733 (no in_progress/retrying guards, no kwarg); `extract_job_criteria_if_needed` :737-743 with the three guards. Old form confirmed |
| Four enqueue sites :707, :709, :723, :732 | Read job.rb | ✓ all four exact (`set(wait: 30.seconds)` variant at :707) |
| `_immediately` called only by `_if_needed` (:742); `_if_needed` only by textract_result.rb:70 | `grep -rn` app/ lib/ spec/ | ✓ exactly two call sites; zero spec references (E.3.1's "grepped spec/ — zero hits" claim verified true) |
| DO NOT touch `auto_extract_job_criteria` (":695-710") / `extract_job_criteria` (":712-724") | grep -n | Methods actually at :696-711 / :713-724 (±1 drift, by-name unambiguous). Their `status_pending?` guard + Flipper gate confirmed present and untouched by any plan step. LOW |
| E.3.1 replacement code matches DECISIONS verbatim + flag-1 kwarg | Diffed E.3.1 snippet against DECISIONS.md "Backend decisions" block | ✓ identical except `requesting_organization_user_id: nil` kwarg and threading it to `perform_later` — exactly the flag-1 APPROVED deviation. No pending guard added (documented consequence carried) |
| E.2.1: flag 4 ruling = optional POSITIONAL | ORCHESTRATION-LOG flag 4 + SPEC-REVIEW-COMPLETE "FLAG 4 decision" | ✓ plan matches the ruling (`def perform(ai_job_criteria_id, requesting_organization_user_id = nil)`); "do not re-litigate" carried in E.2 preamble and G |
| Existing exhaustion block at extract_job_criteria_job.rb:5-10 with `ai_job_criteria&.update_columns` at :9 | Read the job | ✓ exact; `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3` matches the plan's E.2.3 snippet head |
| Dual rescue :19-28 (`CustomErrorAiSummary` re-raise :19-22; StandardError re-lookup + failure write :23-28) | Read the job | ✓ exact; E.2.4's "keep the existing re-lookup and its failure write" is accurate |
| Analog: kwargs signature :24, perform-end broadcast :34, exhaustion `if textract_result` guard :17-21 reading `job.arguments.first[:key]` (:16, :20), StandardError broadcast gated on both :45, helper :50-80 with terminal-status guard :62, conditional errorMessage :73 | Read generate_ai_job_application_summary_job.rb in full | ✓ every citation exact. E.2's three-site + guard structure mirrors the analog structurally (rule 14), with `job.arguments.first`/`.second` as the positional counterpart |
| E.2.2 "unreachable mid-retry" claim | extract_criteria.rb rescue `CustomErrorAiSummary` sets `:retrying` then `raise` (:143-147 region, verified); job re-raises :19-22 | ✓ broadcast line after `.extract` is skipped while retrying — matches analog |
| JSON::ParserError path → failure write WITHOUT re-raise → perform continues → failed broadcast | extract_criteria.rb :148-151 verified | ✓ the flag-3 approval's dependency holds under the planned code |
| E.2.5 helper is SPEC-verbatim | Diffed against SPEC §7 code block | ✓ byte-identical (OrganizationUser lookup → user → reload → terminal guard → camelCase payload → conditional errorMessage → `GlobalChannel.broadcast_to`) |
| `GlobalChannel` exists, `broadcast_to(user, ...)` | app/channels/global_channel.rb:3-7 (`stream_for current_user`) | ✓ |
| E.2 lands BEFORE E.3 (job accepts two args before any caller passes them) | §L dependency list | ✓ ordering stated and correct; old positional `[id]` payloads bind `requesting_organization_user_id = nil` |
| Existing spec calls `perform_now(id)` positionally and stays untouched (backward-compat assertion) | grep spec/jobs/extract_job_criteria_job_spec.rb | ✓ :15, :30, :49, :63 all single positional arg |
| R-1: backend/_base.md §8 prohibits `reload` in app/ | Read cursor_rules/backend/_base.md :135-149 | ✓ rule real, including the "ask the user" escape; R-1 correctly documents the SPEC-vs-rule conflict and defers to the human gate instead of silently deviating (see claude-md-compliance.md) |

## Completeness (vs SPEC §4.1, §7, §12)

- SPEC 4.1 gating replacement + kwarg → E.3.1 ✓ (comments above the methods preserved; harmonization prohibited in both directions)
- SPEC 7 signature → E.2.1 ✓; perform-end broadcast gated on requesting id → E.2.2 ✓; exhaustion-block broadcast with row-exists guard reading `job.arguments.first`/`.second` → E.2.3 ✓; StandardError broadcast gated on row AND requesting id → E.2.4 ✓; helper → E.2.5 ✓; auto path never broadcasts → E.2.5 note ✓; failure broadcasts (flag 3) carried, not narrowed → E.2.5 note ✓
- SPEC 12 job spec: success broadcast, zero-criteria payload (`zeroCriteriaFailure: true` + `errorMessage`), StandardError failed broadcast, `CustomErrorAiSummary` re-enqueued + NO broadcast, no-requesting-user never broadcasts → E.2.6.1-E.2.6.5 ✓ all behavioral (rule 26)
- SPEC 12 lifecycle spec: blank description / in_progress / retrying / pending-creates-row / kwarg passthrough / nil default / `_if_needed` succeeded no-op + failed/none delegate / existing `extract_job_criteria` examples untouched → E.3.2 ✓ complete

## Findings

- F3 [LOW] Citation drift ±1: E.3.1 cites `auto_extract_job_criteria` ":695-710" (actual :696-711) and `extract_job_criteria` ":712-724" (actual :713-724). By-name instructions; no ambiguity.

## Amendments Applied

None required for this angle.
