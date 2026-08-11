# analog-structural-matching (SCOPED) — Round 1

Per guardrails 1 & 2: Item 1 compared to SPEC pinned text + pinned sources; Item 2 limited to the gate string and the strong-params shape.

## Item 1
- Copied strings/styles/emotion-labels/`FormCheckbox` contract are faithful to the SPEC pins (see item1-modal-copy-and-state-machine, item1-runplato-defect-fixes, item1-mailer-recipients).
- `Styled.Info` = verbatim `CustomQuestionModal` `Styled.Info`; `Styled.Statement`/`Styled.RescoreCheckbox` = verbatim `RunPlatoReviewAllModal` blocks (label renamed only).
- Mailer recipient resolution = faithful copy of `job_application_mailer.rb` shape minus `.receives_new_job_application_emails` (owner-ruled). Block var renamed to `organization_user` per rule 9.
- Sanctioned divergences (leading "The" on per-stage checked sentence; mailer preference-scope omission; per-stage overestimate info block absent from all-stages) are all owner-ruled — NOT structural mismatches.

## Item 2
- Gate-condition string `create_bulk_ai_summary_generation.rb:45` → `create_ai_summary_generation.rb:36`: byte-identical. ✓
- Strong-params `require(:x).require(:rescore_requested)` shape from `bulk_ai_job_application_summaries_controller.rb` → `ai_job_application_summaries_controller.rb`: matched. ✓
- Interactors and controllers NOT diffed wholesale; bulk staleness block / textract_pending handling / enqueue behavior correctly NOT imported (guardrail 1).

## Findings
No issues found.
