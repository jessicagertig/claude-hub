# Coverage Audit — Plato AI manual QA map notes

Audit of the 22 map notes in this directory against the full feature diff
(`git -C /Users/jessica/wrk/wrk-corp/inflow-ats diff --name-only production...develop`).

A changed file is counted **covered** if its full path, basename, basename stem,
derived CamelCase class name, migration timestamp (full/short), or migration table
name appears in any `_map/*.md` note — OR if a note declares an explicit wildcard
scope over its directory (e.g. `-- app/models/`, `.chief/specs/*`).

## Totals

- **Total changed files:** 289
- **Covered:** 269
- **Coverage gaps (not referenced in any map note):** 20

## Coverage gaps

### A. Frontend components — genuinely uncovered (regression risk)

These two billing confirm modals are explicitly punted in `fe-account-platoai-settings.md`
("the two confirm modals … belong to the billing slice — noted only for adjacency"),
but the billing slice note (`fe-account-billing.md`) never picks them up. Neither their
path, basename, nor class name appears in any note. No QA guidance exists for them.

- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/PurchaseAiCreditTopUpConfirmModal.tsx`
- `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/UpdateAiCreditSubscriptionConfirmModal.tsx`

(For contrast, the sibling `CancelAiCreditSubscriptionConfirmModal.tsx` IS covered.)

### B. Spec files — production code covered, spec file itself unreferenced

`be-spec-interactors.md` covers "all 15" interactor specs and `be-spec-models.md` covers
"all 13" model specs. No map note covers controller, job, service, policy, or support specs.
The production classes these exercise ARE covered by the BE notes (`be-jobs.md`,
`be-controllers-policies.md`, `be-ai-action-*.md`, `be-stripe-billing.md`), but the spec
files themselves are not referenced by basename.

- `spec/controllers/api/v1/bulk_ai_job_application_summaries_controller_spec.rb`
- `spec/controllers/api/v1/organization_ai_credit_purchases_purchase_top_up_spec.rb`
- `spec/controllers/api/v1/organization_ai_credit_purchases_subscription_change_spec.rb`
- `spec/jobs/bulk_generate_ai_summaries_job_spec.rb`
- `spec/jobs/docx_to_pdf_job_spec.rb`
- `spec/jobs/extract_job_criteria_job_spec.rb`
- `spec/jobs/generate_ai_job_application_summary_job_spec.rb`
- `spec/jobs/get_resume_text_from_textract_job_spec.rb`
- `spec/jobs/stripe_webhook_handler_ai_credits_spec.rb`
- `spec/policies/organization_ai_credit_balance_policy_spec.rb`
- `spec/services/ai_job_application_action/orchestrate_spec.rb`
- `spec/services/ai_job_application_action/scoring/calculate_spec.rb`
- `spec/services/ai_job_application_action/scoring/extract_criteria_spec.rb`
- `spec/services/ai_job_application_action/scoring/integrate_analysis_spec.rb`
- `spec/services/ai_job_application_action/scoring/score_job_application_spec.rb`
- `spec/support/ai_credits_test_helpers.rb`

### C. Bookkeeping / config — low risk

- `.gitignore` — not referenced anywhere. No QA surface.
- `db/data_schema.rb` — data-migration version bookkeeping file. `be-db.md` covers the
  data-migration surface generically but does not name this file. No QA surface.

## Notes on near-misses (counted as covered)

- `.chief/specs/ai-applicant-summaries-epic.json` and
  `.chief/specs/ai-cleanup-and-consolidation-epic.json` — covered via the explicit
  wildcard `.chief/specs/*` scope in `meta-config-tests.md` (flagged "no runtime effect").
- All `app/models/*` files are additionally covered by `be-models.md`'s directory scope
  (`Source: … diff production...develop -- app/models/`).
