# item2-rescore-threading-contract — Round 2

Re-reviewed SPEC 2.2-2.4 (unchanged). Fresh pass on the controller-side param handling.

## Findings
- F1 [LOW] Param-require PLACEMENT (non-blocking, decision-adjacent — NOT amended). SPEC 2.2 says set `job_application.ai_summary_rescore_requested = <required value>` "before `CreateAiSummaryGeneration.call`". In the current `create` flow that point is AFTER `ValidateAiSummaryGeneration.call`. So a request MISSING `rescore_requested` would run validation first — and `ValidateAiSummaryGeneration` can side-effect (`SubmitResumeToTextractJob.perform_later` when no textract result exists, :39/:55) — before the `ParameterMissing` raise rejects it. By contrast the bulk controller requires its params at the TOP of `create` (`bulk_ai_job_application_summaries_controller.rb:9`), before any work.
  - Impact is negligible: the frontend ALWAYS sends `rescoreRequested` (SPEC 2.3, literal false/true), so a missing param only occurs via direct API abuse, and the wasted-textract-enqueue only happens for a candidate with no textract result (not the real already-scored re-score flow). The owner approved the "just before the interactor" placement (approved-decisions "Item 2 — param threading"), so requiring it earlier would be a placement change, not a required fix. Surfaced for Jessica; not amended.
  - If Jessica wants the defensive early-reject, the params method can be called at the top of `create` (forcing the require) with the attribute still assigned just before the interactor.

## Amendments Applied
- None (F1 is LOW and decision-adjacent — owner approved the placement).
