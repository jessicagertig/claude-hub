# Angle 8 — cursor_rules compliance — Round 1

Checked the committed diff against the rules-file → diff-file map in REVIEW-ANGLES §Angle 8. Files read: `core_critical_rules.md` (root), `backend/_base.md`, `backend/core_critical_rules.md`, `frontend/core_critical_rules.md`, `frontend/_base.md`, plus the specific-area rules cited below where the diff touches their territory.

## Backend

- Rule 1 (no begin blocks): none in the diff; job uses method-level dual rescue; controller has no rescue at all. ✓
- Rule 3 (`ap` not `pp`): `ap` used in job logging. ✓
- Rule 5 (one params method): new controller has ZERO params methods (no body params) — compliant. ✓
- Rule 8 (bare guard returns): `job.rb` guards, `textract_result.rb:70` funnel guard, job `return unless ai_job_criteria` — all bare. ✓
- Rule 11 (no bang methods in app/): none added (all `create!`/`update!` are in spec/ — sanctioned exception). ✓
- Rule 12 (check save returns): `return unless new_ai_job_criteria.save` preserved. `update_columns` calls are boolean-irrelevant row writes matching sibling patterns (bulk job :54/:69/:88; extract job failure writes) — consistent with existing convention in the same methods. ✓
- backend/_base §7 (single quotes): all new Ruby strings single-quoted except interpolations (`"ExtractJobCriteriaJob failed for #{...}"`). ✓
- backend/_base §9 / record variable naming: `ai_job_criteria`, `new_ai_job_criteria`, `requesting_organization_user`, `job_application_bulk_job_status`, `succeeded_ai_job_criteria` — all full-model names. (Spec-file locals like `ou`/`ready` match each spec file's pre-existing local convention; spec/ is exempt from backend/_base.) ✓
- backend/_base §8 (no `reload` in app/): **one occurrence** — `ai_job_criteria.reload` in `ExtractJobCriteriaJob#broadcast_completion` (extract_job_criteria_job.rb:45). SPEC §7-verbatim, plan R-1-documented, and gate-bound to the dedicated Phase 6.5 conventions pass per the round directive. NOTED, NOT COUNTED this round (see code-quality.md). The rule-compliant one-liner (re-`find_by` + nil guard) is already recorded in plan R-1 for the gate.
- controllers/* (patterns, error handling, pundit): `exists`+block, authorize-after-find with explicit queries, `render_one`/`render_general_errors`, no new policy methods. ✓
- serializers.md §1/§7: raw jsonb pass-through; computation delegated to Job model methods. ✓
- background_jobs.md: retry/discard semantics untouched; broadcast added inside existing lifecycle shapes; exhaustion block reads `job.arguments` per its signature form. ✓
- interactors/*: `context.fail!` chains extended in existing style; optional context input via safe navigation. ✓
- services.md: `extract_criteria.rb` / `score_job_application.rb` — constant substitutions ONLY (verified nothing beyond one-line swaps). ✓
- architecture.md placement: predicate on models, guard in validators + shared model funnel, broadcast in the job, serializer off Job — consistent with the analog architecture. ✓

## Frontend

- Rule 2 (theme colors exist): every color resolves — poly tokens verified in lightTheme.ts/darkTheme.ts (both modes), `gray[100]`/`gray[700]` in theme.ts:5-17; `t.poly` accessor real (AppAuthRouter.tsx:414). Raw px values are DECISIONS-pinned visual specs, not theme colors. ✓
- Rule 7 (casing + enum exception): camelCase keys, snake_case enum values (`"in_progress"`, `"tier_1"`); WS payload camelCase from Ruby matches the socket-path convention. ✓
- Rule 9 (never set undefined): none. ✓ Rule 10 (no fabricated fallbacks): none (sanctioned toast-string fallback only). ✓
- frontend/_base §1 (no `??`): zero in diff. ✓ §4 (pragmatic TS): `job: any; history: any` props, `const t: any = props.theme`. ✓ §6 (no useMemo for minor computation): none used. ✓
- react_query rules: array query keys, `enabled` guard, hook-level onSuccess invalidation, call-site callbacks in the modal. ✓
- modal rules: mutation owned by modal, loading+disabled on primary, error toast + stays open, CenterModal/FullModal contracts honored. ✓
- component_size_and_extraction.md: section extracted to `jobSetup/components/JobCriteriaSection.tsx` (280 lines); `JobSetupAiSettings.tsx` at 195 lines. ✓
- ui_styling / pipeline rule 1: Emotion text utilities standalone. ✓ Pipeline rule 12: separate styled components per variant; no boolean variant props forwarded to DOM. ✓
- boolean_variables_and_naming.md: `isLoading`/`isFetching`/`isInFlight`/`isPayloadStatusInFlight` — `is` prefixes; `isInFlight` extracted because used twice and composed. ✓
- contexts rules: ModalContext/ToastContext consumed, never edited. ✓
- File naming: PascalCase components, camelCase hook file. ✓

## Findings

No issues found at MED+ severity. LOW items (recorded in code-quality.md): the R-1 `reload` (gate-owned); missing trailing newline in `aiSummaryWebsocketPayloads.ts` (Prettier formatting); `<a onClick>` without `href` in the section intro link.
