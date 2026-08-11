# Data Integrity & Security (always-on) — Round 2

Re-verified at merged HEAD:

- **Authorization unchanged and intact:** GET → `authorize job, :show?`; POST → `authorize job, :update_ai_settings?`; org scoping via `current_organization.jobs` in both actions. Bulk controller still authorizes `:bulk_create?` and scopes `current_organization.jobs.find(...)` — the merge's `job:`/`params:` threading did not alter authorization or scoping.
- **Flipper gate on POST** intact; a non-AI org cannot trigger paid extraction. GET deliberately ungated (adjudicated).
- **No mass assignment risk:** the new controller accepts no body params; the bulk controller's permit list unchanged apart from develop's own `rescore_requested` (permitted AND required by develop's PR).
- **Data consistency:** claim-row `:failed` fix prevents permanently-unqueueable candidates; `update_columns` sites are outside transactions (rule 25); no new validations removed/added; no schema changes.
- **Injection surface:** none new — no raw SQL, no string interpolation into queries; broadcast payload built from model attributes.
- **The documented funnel-guard race** (SPEC 6.4) remains accepted-as-specced; the merge did not widen it (develop's rescore path still passes through ValidateAiSummaryGeneration before any credit flow).

## Findings

No issues found.
