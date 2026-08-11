# Conventions pass — cursor_rules/frontend/_base.md

Scope: `git diff develop...HEAD -- app/javascript` at 68e5e6a4e in /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings
Rules file: cursor_rules/frontend/_base.md ONLY.

## Findings

- F1 [LOW] app/javascript/ats/src/views/jobApplications/jobSetup/JobCriteriaViewModal.tsx:16 / Rule 4 "Use `interface` for component Props" / Component props declared with `type` alias instead of `interface` / Evidence: `type Props = {` (line 16), consumed by `function JobCriteriaViewModal({ criteria, onCancel }: Props)` / Fix: change to `interface Props { criteria: AiJobCriterion[]; onCancel: () => void; }`

- F2 [LOW] app/javascript/ats/src/views/jobApplications/jobSetup/RegenerateJobCriteriaConfirmModal.tsx:13 / Rule 4 "Use `interface` for component Props" / Component props declared with `type` alias instead of `interface` / Evidence: `type Props = {` (line 13), consumed by `function RegenerateJobCriteriaConfirmModal({ jobId, onCancel }: Props)` / Fix: change to `interface Props { jobId: number; onCancel: () => void; }`

## Rules checked clean

- Rule 1 (no `??` nullish coalescing): zero occurrences in the diff (grep-verified). Error fallback at RegenerateJobCriteriaConfirmModal.tsx:37 correctly uses `||`.
- Rule 2 (never deliberately set `undefined`): no explicit `undefined` assignments. Sole occurrence is a comparison, not a set: `enabled: jobId != undefined` (shared/queryHooks/useAiJobCriteria.ts:22).
- Rule 3 (no snake_case fallbacks): no dual camelCase/snake_case property checks. `tier_1`/`tier_2`/`tier_3` and `pending`/`in_progress`/`retrying`/`succeeded`/`failed` are Ruby enum values, which the rule's exception says remain snake_case.
- Rule 4 (pragmatic TypeScript, remainder): `const t: any = props.theme;` used in all styled components; union types used for status/tier (no enums); JobCriteriaSection.tsx:24 correctly uses `interface Props`.
- Rule 5 (boolean variable declarations, quick rule): `isPayloadStatusInFlight` (JobCriteriaSection.tsx:57) combines three conditions and is used twice; `isInFlight` (JobCriteriaSection.tsx:61) combines conditions and is used by both `loading` and `disabled` props. Both extractions qualify.
- Rule 6 (no `useMemo` for minor computation): zero `useMemo` occurrences in the diff.
- File structure: `.tsx` PascalCase for components (JobCriteriaViewModal.tsx, RegenerateJobCriteriaConfirmModal.tsx, JobCriteriaSection.tsx), `.ts` camelCase for the hook (useAiJobCriteria.ts). Compliant.
