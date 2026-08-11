# Pass 1 — claude-md-compliance

## Database Safety Rules

| Rule | Plan Compliance |
|------|----------------|
| No DROP DATABASE | Plan uses `db:rollback` and `db:migrate` only — COMPLIANT |
| No `db:reset` / `db:setup` / `db:schema:load` | Not used — COMPLIANT |
| No direct `psql` | Not used — COMPLIANT |
| No setting `DATABASE_URL` | Not set — COMPLIANT |
| No editing `.env` | Not edited — COMPLIANT |
| `db:rollback` is in the allowed list | COMPLIANT |
| `db:migrate` is in the allowed list | COMPLIANT |

## core_critical_rules.md Compliance

| Rule | Plan Compliance |
|------|----------------|
| Rule 8: Guard clauses — bare `return` | Plan uses bare `return` everywhere (G.2.1, D.1.2, D.2.1, E.1.2) — COMPLIANT |
| Rule 10: No bang methods | Plan uses non-bang `update`, `save`, `create` — COMPLIANT. Plan explicitly notes bang methods allowed in specs (J preamble) |
| Rule 11: Check save/update return values | Plan checks `unless ai_summary.update(...)` (D.1.7), `return unless ai_job_criteria.save` (G.2.1) — COMPLIANT |
| Rule 3: Use `ap` not `pp` | Plan uses `ap` (G.1.1 job file) — COMPLIANT |

## Frozen Prompt Files

Plan states "FROZEN — do not modify" for 4 prompt files:
- `job_description_structured_data.rb`
- `job_description_criteria_extraction.rb`
- `job_application_scoring.rb`
- `scoring_display.rb`

Plan does NOT modify these prompt files in any task step. The only prompt file the plan creates is `integrated_analysis.rb` (D.5). COMPLIANT.

**However:** The REVIEW-ANGLES.md "Modified files" section lists these three files as modified:
- `app/services/ai_job_application_action/scoring/prompts/job_description_structured_data.rb` — MODEL constant update
- `app/services/ai_job_application_action/scoring/prompts/job_description_criteria_extraction.rb` — MODEL constant update
- `app/services/ai_job_application_action/scoring/prompts/job_application_scoring.rb` — MODEL constant update

The plan does NOT include any task steps to update MODEL constants in these files. The REVIEW-ANGLES.md was generated from the spec, and the spec says "MODEL constants already pinned to API-returned versions on the branch." So these files are already correct on the branch and require no modification. The REVIEW-ANGLES.md listing is from an earlier version of the spec before MODEL pinning was confirmed. No issue with the plan — it correctly does not modify these files.

## Known Failure Patterns

| Pattern | Compliance |
|---------|-----------|
| #6 Rename cascades: grep for ALL references | Plan Phase C includes exhaustive grep + explicit `grep` for stale `in_progress` and `extracted` — COMPLIANT |
| #8 Webhook handlers: trace guard ordering | Not applicable — no webhook handlers modified |
| #10 Fix agents must not add code beyond scope | Not applicable (implementation plan, not fix) |
| #14 Analog structural matching | Plan explicitly matches `Summary::Generate` for `ExtractCriteria`, `GetResumeTextFromTextractJob` for `ExtractJobCriteriaJob` — COMPLIANT |

## Findings

No findings. Plan is compliant with all safety rules and conventions.
