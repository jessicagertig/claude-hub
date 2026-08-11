# cursor_rules compliance — Pass 1

Scope: does the PLAN route the implementer to the right rules files, and do the plan's prescribed code/steps comply? (The Phase 6.5 fan-out re-checks the actual diff.)

## Fact Check — rules-file routing vs REVIEW-ANGLES Angle 8 map

| REVIEW-ANGLES rules file | Plan coverage | Result |
|---|---|---|
| `core_critical_rules.md` (root) | §E/§F preambles: mandatory read before ANY step | ✓ |
| `backend/_base.md`, `backend/core_critical_rules.md` | §E preamble mandatory reads | ✓ (both files exist — verified) |
| `backend/controllers/controller_patterns_and_crud.md`, `controller_error_handling.md` | E.5 tags; controller_patterns also tagged on E.4 (bulk controller edit) | ✓ (E.4's bulk-controller change is an argument pass-through — error-handling file not tagged there; no error-handling change occurs. Acceptable) |
| `backend/controllers/pundit_policies.md` | E.5 tag | ✓ ("authorize AFTER finding" rule verified in file :11/:32; plan complies) |
| `backend/serializers.md` | E.5 tag | ✓ (§1 jsonb pass-through, §2 no `?` in attribute names, §7 model-level computation — prescribed serializer complies with all; methods are for ASSOCIATED-row derivations, not Job columns, so §1's "no methods for regular columns" is not violated) |
| `backend/background_jobs.md` | E.2, E.4 tags | ✓ (pass IDs not objects ✓; find_by + guard ✓) |
| `backend/interactors/*` (both) | E.4 tags | ✓ |
| `backend/services.md` | E.1 tag with "constant substitutions ONLY — flag anything beyond one-line swaps" | ✓ |
| `backend/code_style_and_structure.md`, `backend/architecture.md` | E.1/E.3 tags | ✓ |
| `frontend/core_critical_rules.md`, `frontend/_base.md` | §F preamble mandatory reads | ✓ (§1 no-`??` and §4 pragmatic-`any` verified real in _base.md — F.2.1 props typing and F preamble comply) |
| `frontend/react_query/react_query_queries.md`, `react_query_mutations_and_cache.md` | F.1 tags | ✓ (array keys `["jobs", jobId]` rule at queries.md:66; hook-level callbacks primary pattern at mutations.md:30 — F.1.1 complies; F.3.2.6 call-site callbacks comply) |
| `frontend/modals/*` (both) | F.3 tags | ✓ ("DON'T: Pass onSuccess/onError to Form Modals" honored — modal owns mutation) |
| `frontend/components/component_size_and_extraction.md`, `component_architecture.md` | F.2 tags | ✓ (>400 → extract rule verified at :12/:23; D-1 applies it) |
| `frontend/ui_styling.md`, `react_hooks.md`, `boolean_variables_and_naming.md`, `contexts/*` | F.2/F.3/F.1 tags | ✓ all tagged where the map requires |
| Explicitly NOT relevant (migrations, cypress, job_board, public_api, console, forms/*, lists/*, reference_patterns) | No plan step touches those areas; no form-state handling added (existing FormSelect flow untouched) | ✓ consistent with the map's exclusions |

## Compliance spot-checks of prescribed code

- Core 1 (no begin blocks): E.5.2 controller has none ✓
- Core 5 (one params method max): zero params methods, no body params ✓
- Core 7 (+ enum exception): serializer/hook/WS types keep `status`/`tier` values snake_case, keys camelCase ✓; WS payload camelCase written in Ruby matches the socket path's no-transform reality ✓
- Core 8 (bare guards): E.3.1/E.4.5 guards all bare `return`/`return if` ✓
- Core 10 / pipeline 13 (no fabricated fallbacks): serializer safe-nav without `|| false` ✓; no `criteria || []` (F.2.1.2 explicit) ✓; sanctioned toast-fallback exception documented ✓
- Core 11/12 (no bangs outside spec/; check save returns): E.3.1 `return unless new_ai_job_criteria.save` ✓; no bang calls in prescribed app code ✓ (spec files may use bangs — exception)
- Record variable naming: `ai_job_criteria`, `new_ai_job_criteria`, `requesting_organization_user`, `job_application_bulk_job_status` ✓ (§E preamble bans `row`/`record`/`latest`)
- Pipeline 25: both `update_columns` sites (E.2.3/E.2.4 rescue paths, E.4.6 iteration) outside transactions ✓
- Pipeline 1 (Emotion utilities standalone), 12 (separate styled variants): D-4 note + F.2.1.7 ✓
- Pipeline 14 (structural analog matching): P5/P6 signature-level comparison done; sole deviation (positional args) is flag 4, pre-adjudicated ✓
- Pipeline 26 (falsifiable tests): E.2.6 broadcast tests assert `GlobalChannel.broadcast_to` outcomes; `CustomErrorAiSummary` test asserts `have_enqueued_job` — behavioral, not reflective ✓
- backend/_base.md §8 (no `reload` in app/): **conflict — E.2.5's SPEC-verbatim helper contains `ai_job_criteria.reload`.** The plan does not hide this: R-1 documents the rule, the reason the spec chose reload, the analog's rule-compliant alternative (re-query), and defers to the human gate ("do NOT preemptively deviate"). SPEC is authoritative and 5-round-reviewed; REVIEW-ANGLES Angle 3 itself requires verifying the reload happens. Recorded as a documented, gate-bound tension — not a silent violation. See claude-md-compliance.md. [MED-2, no amendment: amending would contradict SPEC + Angle 3]

## Findings

- MED-2 [MED] E.2.5 `reload` vs backend/_base.md §8 — documented conflict, deliberately deferred (R-1). Needs the human-gate ruling R-1 anticipates; plan handles it correctly by SPEC-fidelity + explicit flag, so no plan amendment is warranted.

## Amendments Applied

None.
