# Always-on checks — Round 1

## Source accuracy (every SPEC file:line verified against the worktree)
| SPEC ref | Claim | Result |
|---|---|---|
| create_ai_summary_generation.rb:36 | `if active_ai_summary` | CONFIRMED |
| create_bulk_ai_summary_generation.rb:45 | `if active_ai_summary && !job_application.ai_summary_rescore_requested` | CONFIRMED |
| bulk_ai_job_application_summaries_controller.rb:77-86 | `require(:bulk_ai_job_application_summary)` + `.require(:rescore_requested)` + `.permit` | CONFIRMED |
| PlatoTab.tsx:247 | `statusValue === "current" && fullSummary?.stale` | CONFIRMED |
| BulkGenerateAiSummariesConfirmModal.tsx:74 | `rescoreRequested: false` | CONFIRMED |
| organization_user.rb:48 | `scope :actives, -> { where(is_active: true) }` | CONFIRMED (receives_new_job_application_emails at :37) |
| job_application_mailer.rb:19,28-32 | recipient resolution + map + `any?` guard (:21) | CONFIRMED |
| job_application.rb:11 | `attribute :ai_summary_rescore_requested, :boolean, default: false` | CONFIRMED |
| config/routes.rb:315 | `resources :ai_job_application_summaries, only: [:show, :create]` | CONFIRMED |
| CustomQuestionModal/index.js:192-199 & :254-273 | info block + `Styled.Info` styles | CONFIRMED |
| RunPlatoReviewAllModal.tsx:135-143 / :145-151 / :186-206 | RescoreCheckbox / Statement usage / Statement styles | CONFIRMED |
| textract_result.rb:68 | `return if latest_ai_summary&.status_succeeded? && !latest_ai_summary.stale?` | CONFIRMED |
| job_application.rb:32 | `has_one :latest_ai_job_application_summary, -> { order(created_at: :desc) }` | CONFIRMED |

No stale file:line references found. Repo not drifted (branch `job-criteria-settings-qa`, HEAD f8815555a; relevant files clean per `git status`).

## Test coverage
- Two new backend specs required (`create_ai_summary_generation_spec.rb`, `ai_job_application_summaries` controller spec) — both CONFIRMED not to exist yet. One extended (`bulk_all_stages_ai_summary_result_mailer_spec.rb`).
- Falsifiability (core rule 26 / known-failure #26): the interactor spec's `true`→builds-pending+enqueues vs `false`→returns-existing+enqueues-nothing pair is falsifiable by reverting the gate. The controller spec's without/with `rescore_requested` pair is falsifiable. OK.
- (c) The extended mailer spec MUST reconcile the pre-existing arity/subject/tags/recipient mismatch — raised in item1-mailer-recipients F2, SPEC 1.7 amended.
- (d) Interactor-spec double must stub `textract_pending: false` so it does not mask/raise on the extra field the single-send interactor reads — raised in item2-single-send-gate F1, SPEC 2.8 amended.
- "Already covered, no change" claims verified: `queue_bulk_ai_summary_jobs_spec.rb` (rescore_requested true/false threading, :110-127+) and `bulk_ai_job_application_summaries_controller_spec.rb` (rescore_requested pass-through, :57-143) both genuinely cover the shared enqueue path. CONFIRMED.

## Backward compatibility
- `GenerateParams.rescoreRequested` now required: only consumers are `PlatoTab.tsx` (4 callsites updated) and `AiSummaryState.tsx` (deleted). No survivor lacks the field. CONFIRMED.
- `BulkGenerateAiSummariesConfirmModal` `Props` interface is unchanged by SPEC 1.1-1.4 (checkbox uses internal state; `rescoreRequested` is internal to the `bulkGenerate` call). Callers unaffected. CONFIRMED.
- `BulkAllStagesAiSummaryResultMailer.complete/.failed` method SIGNATURES unchanged (only internal `to:` resolution changes) — callers/jobs pass the same args. CONFIRMED (mailer arg lists untouched by SPEC 1.6).

## Full-stack analog completeness
- No new end-to-end pipeline; both analog relationships are partial by owner decision. Item 1 backend enqueue path pre-existing/unchanged. Item 2 adds param boundary + one gate + frontend threading over the existing single-send pipeline. The one completeness check (rescoreRequested has a piece at every hop) passes — see item2-rescore-threading-contract. No "missing job/serializer/policy" flagged for Item 2 (they exist and are untouched per SPEC 2.1). OK.

## Analog structural matching (scoped)
- Item 1: implementation is measured against the SPEC's pinned strings/styles/file:line (all verified faithful to the pinned sources). Sanctioned divergences (leading "The", dropped preference scope, added info block) are NOT mismatches.
- Item 2: the only required structural matches — gate-condition string (create_bulk_ai_summary_generation.rb:45 → create_ai_summary_generation.rb:36) and the strong-params `require(...).require(:rescore_requested)` shape (bulk controller → single-send controller) — are both faithful. Interactors/controllers NOT diffed wholesale (guardrail 1). OK.

## Findings
- No NEW findings beyond those in the angle files (item1-mailer-recipients F1/F2, item2-single-send-gate F1, item1-modal F1 LOW, item1-runplato F1 LOW).
