# item2-single-send-gate — Pass 1

Scope: Task B4 (`create_ai_summary_generation.rb`, SPEC 2.1) + Task T2 (`create_ai_summary_generation_spec.rb`, SPEC 2.8).

## Fact Check

| Claim (plan) | Verify | Result |
|---|---|---|
| `if active_ai_summary` at `create_ai_summary_generation.rb:36` (B4.1) | Read interactor | TRUE — line 36 |
| pinned gate `active_ai_summary && !job_application.ai_summary_rescore_requested` = `create_bulk_ai_summary_generation.rb:45` | Read bulk interactor | TRUE — line 45 exact |
| `active_ai_summary` query lines 30-34 | lines 30-34 | TRUE |
| `validation_result.textract_pending` branch lines 41-53 | lines 41-53 | TRUE |
| pending build + `GenerateAiJobApplicationSummaryJob.perform_later` lines 55-72 | lines 55-72 | TRUE — enqueue at 66-69 |
| bulk staleness-refresh block `create_bulk_ai_summary_generation.rb:40-43` NOT ported (guardrail 1) | bulk lines 40-43 | TRUE — plan B4.2 forbids porting |
| bulk interactor spec rescore pairs `:74-113` (mirror) | Read bulk spec | TRUE |
| bulk spec double omits `textract_pending` (line 34) — single-send must add it (T2.2) | bulk spec line 34 | TRUE — single-send reads `.textract_pending` at line 41 on fall-through |

## Trace (rescore-true path)

`active_ai_summary` present + `ai_summary_rescore_requested == true` → line 36 condition `active && !true` = false → falls through → line 41 reads `validation_result.textract_pending` (stubbed false) → builds `:pending` row (55-59) → `save` → enqueues `GenerateAiJobApplicationSummaryJob` (66). rescore-false → line 36 returns existing, no enqueue. Matches SPEC 2.1. `context.user.current_organization_user.id` at line 68 (no safe-nav) requires `user` with `current_organization_user` set — T2.1 setup provides it (`u.update(current_organization_user: org_user)`).

## Completeness (SPEC 2.1 / 2.8)

- One condition changed; all other lines (`ap` debug, query 30-34, textract_pending branch, pending build+enqueue, `requested_by_organization_user_id`) unchanged (B4.2). COVERED.
- Eight untouched gates confirmed out of file scope (SPEC 2.1) — none altered by B4. COVERED.
- T2.3 rescore-true: new pending row (`id != existing.id`, status `pending`), existing untouched (`succeeded`, `stale false`), `have_enqueued_job(GenerateAiJobApplicationSummaryJob)` — the single-send-specific assertion. COVERED.
- T2.4 rescore-false: returns existing, `not_to have_enqueued_job`. COVERED.
- T2.2 double stubs `textract_pending: false`. COVERED (SPEC A3).
- T2.5 falsifiable: reverting B4 makes T2.3 return existing + no enqueue → both id-inequality and `have_enqueued_job` fail. Non-tautological (core rule 26). COVERED.

## Findings
- No issues found.

## Amendments Applied
- None.
