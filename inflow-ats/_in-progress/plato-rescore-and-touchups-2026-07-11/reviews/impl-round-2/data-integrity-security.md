# data-integrity-security (always-on impl) — Round 2

- Authorization unchanged: controller `create` still runs `authorize :ai_job_application_summary, :create?` before any work; the new attribute-set line sits after auth + validation, before the interactor. ✓
- Tenancy unchanged: `exists(current_organization.job_applications.where(id: params[:job_application_id]), ...)` scopes the job_application to the current org (untouched). ✓
- Strong params enforce presence at the boundary: `params.require(:ai_job_application_summary).require(:rescore_requested)` — a truly-absent key raises `ParameterMissing` (400-class), `false` passes (Rails special-case). Requiredness lives in strong params, not the interactor (owner rationale). ✓
- No mass-assignment surface added — the required value is a scalar boolean assigned to a virtual attribute; no `.permit` of arbitrary keys. ✓
- Mailer recipients scoped to `job.organization_users.actives` — active hiring-team members of that job only; no cross-org/inactive leakage (the spec asserts inactive exclusion). ✓
- No new SQL/string interpolation into queries; `.where`/scopes used throughout. ✓
- Re-score consumes one AI credit via the unchanged charge-on-success path (SPEC 2.1 gate list) — no billing bypass. ✓

## Findings
No issues found.
