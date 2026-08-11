# Conventions pass — frontend core_critical_rules.md

Scope: `git diff develop...HEAD -- app/javascript` at HEAD 68e5e6a4e in `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings`
Rules source: `cursor_rules/frontend/core_critical_rules.md` ONLY. Known exception applied: enum-value strings stay snake_case (`"in_progress"`, `"tier_1"`, `"pending"`, etc.) — not flagged.

## Findings

- F1 [LOW] app/javascript/shared/types/aiSummaryWebsocketPayloads.ts:35 / General Principles > Code Quality: "Format code consistently (respect Prettier & linter)" / File has no trailing newline at EOF; repo uses Prettier 2.x (`.prettierrc.json`, `prettier ^2.2.0` in package.json), which enforces a final newline / Evidence: `git diff develop...HEAD` shows `\ No newline at end of file` after the final `}` (line 35); confirmed via byte inspection — last byte is `}` with no `\n`. The condition pre-existed on this file, but the diff modifies the file (adds `JobCriteriaExtractionCompletePayload`, lines 29-35) and leaves it unformatted / Fix: add a trailing newline after the closing `}` on line 35.

## Rules verified clean (evidence)

- Rule 2 (theme colors — only use colors that exist): every color reference in the diff resolves to a defined theme value.
  - `t.poly.color.canvas`, `border`, `loudText`, `primaryText`, `secondaryText`, `subtleHover`, `cardCanvas`, `cardBorder` (used in JobCriteriaViewModal.tsx, JobCriteriaSection.tsx) — all defined in `app/javascript/shared/styles/lightTheme.ts:6-28` and `app/javascript/shared/styles/darkTheme.ts:6-28`; `theme.poly` is injected in `app/javascript/shared/layouts/AppDefaultWrapper.tsx:74`.
  - `t.color.gray[100]`, `[200]`, `[300]`, `[400]`, `[500]`, `[600]`, `[700]`, `[900]`, `t.color.black` (used in JobSetupAiSettings.tsx, RegenerateJobCriteriaConfirmModal.tsx, JobCriteriaViewModal.tsx:183) — all defined in `app/javascript/ats/styles/theme.ts:5-18`. No fabricated shades, no raw hex colors in the diff.
  - `t.color.data` not used outside `window.logger` (it is not used at all).
- Rule 2a (window.logger): no `window.logger` calls in the diff; nothing to flag.
- Rule 7 (frontend camelCase): all property access and interface fields are camelCase — `jobTitle`, `jobId`, `zeroCriteriaFailure`, `extractedAt`, `sourceHeading`, `errorMessage` (useAiJobCriteria.ts:4-15, aiSummaryWebsocketPayloads.ts:29-35, WebsocketGlobalChannelHandler.tsx:250-261). Snake_case appearances are enum values (`"tier_1"`/`"tier_2"`/`"tier_3"`, `"in_progress"`) — documented exception, not flagged — and Rails route path strings (`/jobs/${jobId}/ai_job_criteria`), which are backend URLs, not frontend attributes.
- Rule 9 (never deliberately set undefined): no `x ? y : undefined`, no `|| undefined`, no explicit `undefined` assignments in the diff. `enabled: jobId != undefined` (useAiJobCriteria.ts:23) is a comparison, not an assignment.
- Files You Should Never Edit: `ModalContext.tsx`, `ToastContext.tsx`, `api.ts` are imported/used but not modified by the diff.
- File naming: components `PascalCase.tsx` (JobCriteriaViewModal.tsx, RegenerateJobCriteriaConfirmModal.tsx, JobCriteriaSection.tsx), hook `useAiJobCriteria.ts` (camelCase, `use` prefix), types `aiSummaryWebsocketPayloads.ts` (camelCase) — all conform.
- Coding styles: double quotes throughout; functional components with hooks; no placeholders or TODOs.

Backend-only rules (1, 3, 4, 5, 6, 8, 10, 11) not applicable to this frontend-only diff.
