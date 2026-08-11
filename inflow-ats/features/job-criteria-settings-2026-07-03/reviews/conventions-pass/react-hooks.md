# Conventions pass — cursor_rules/frontend/react_hooks.md

Diff reviewed: `git diff develop...HEAD -- app/javascript/shared/queryHooks/useAiJobCriteria.ts app/javascript/ats/src/views/jobApplications/jobSetup` at 68e5e6a4e in /Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings

No issues found.

Checks performed against react_hooks.md:
- No new `useState` declarations in the diff (the pre-existing `autoGenerateSetting` useState in JobSetupAiSettings.tsx is untouched), so the useState pitfalls (errors mixed with form data, combined unrelated state, prop-initialized state without guards) do not apply.
- "Don't use useState for server state (use React Query instead)": compliant — useAiJobCriteria.ts:22 uses `useQuery` and :33 uses `useMutation`; no server data is copied into component state in JobCriteriaSection.tsx, RegenerateJobCriteriaConfirmModal.tsx, JobCriteriaViewModal.tsx, or the JobSetupAiSettings.tsx additions.
- Hook call placement: all hooks are unconditional and top-level — JobCriteriaSection.tsx:34-35 (`useAiJobCriteria`, `useModalContext`) precede the `isLoading` early return; RegenerateJobCriteriaConfirmModal.tsx:19-21 (`useModalContext`, `useToastContext`, `useRegenerateAiJobCriteria`); JobCriteriaViewModal.tsx has no hooks.
- Boolean naming convention (`is/show/has` prefix): compliant — `isLoading`, `isFetching`, `isPayloadStatusInFlight`, `isInFlight` (JobCriteriaSection.tsx:31-33, 55-59), `isLoading` (RegenerateJobCriteriaConfirmModal.tsx:21).
- Dependency handling: no `useEffect`/`useMemo`/`useCallback` in the diff; the query key `["aiJobCriteria", jobId]` (useAiJobCriteria.ts:22) includes its dependency and the mutation invalidates `["aiJobCriteria", variables.jobId]` (useAiJobCriteria.ts:34); `enabled: jobId != undefined` guards the query (useAiJobCriteria.ts:23).
- State-synced-with-props pattern: not introduced anywhere in the diff, so the guard requirements do not apply.
