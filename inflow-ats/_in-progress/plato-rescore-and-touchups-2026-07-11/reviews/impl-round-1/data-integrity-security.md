# data-integrity-security (always-on impl) — Round 1

- Authorization intact: controller `create` retains `authorize :ai_job_application_summary, :create?` (Pundit) and tenancy scope `current_organization.job_applications.where(id: params[:job_application_id])`. The new attribute-set line sits inside that authorized block, after `ValidateAiSummaryGeneration`. ✓
- Strong params: `require(:ai_job_application_summary).require(:rescore_requested)` — absent key raises `ParameterMissing`; no mass-assignment surface added (single scalar extracted, no `.permit` of arbitrary keys). ✓
- Type safety: `rescore_requested` cast via `:boolean` virtual attribute — string `"true"`/`"false"` → boolean; no raw string reaches the gate. ✓
- Mailer recipients scoped to `@job.organization_users.actives` — no cross-org leakage, inactive members excluded. `list_unsubscribe` retained. No PII beyond name/email of active team members (intended). ✓
- Credit consumption unchanged: a re-score consumes one credit via the existing charge-on-success + balance-check path (SPEC 2.7); no bypass introduced. ✓
- No SQL injection surface (all ActiveRecord scopes/finders). No secrets touched.

## Findings
No issues found.
