# Conventions review — react_query_mutations_and_cache.md

Diff: `git diff develop...HEAD` @ 68e5e6a4e — useAiJobCriteria.ts, RegenerateJobCriteriaConfirmModal.tsx, WebsocketGlobalChannelHandler.tsx
Rules file: cursor_rules/frontend/react_query/react_query_mutations_and_cache.md (only)

## Findings

- F1 [LOW] app/javascript/ats/src/views/jobApplications/jobSetup/RegenerateJobCriteriaConfirmModal.tsx:36 / rule "Error Handling — Log errors for debugging" (rules file line 24; call-site `onError` exemplars at rules file lines 176-178 and 216-218 both include `console.error`) / MISSING: the call-site `onError` shows a warning toast but does not log the error / evidence: `onError: (error: any) => { addToast({ title: error?.data?.errors?.general?.[0] || "Could not regenerate job criteria", kind: "warning", delay: 10000 }); }` — no `console.error` / fix: add `console.error("Failed to regenerate job criteria:", error);` inside the `onError` callback alongside the toast.

## Verified compliant (evidence)

- API functions defined outside hooks (rules file line 12): `getAiJobCriteria` at app/javascript/shared/queryHooks/useAiJobCriteria.ts:17 and `regenerateAiJobCriteria` at useAiJobCriteria.ts:27 are module-level.
- Hook-level callbacks for cache invalidation (rules file lines 13, 30-52): `useRegenerateAiJobCriteria` performs `queryClient.invalidateQueries(["aiJobCriteria", variables.jobId])` in a hook-level `onSuccess` (useAiJobCriteria.ts:33-37). Call-site callbacks in RegenerateJobCriteriaConfirmModal.tsx:33-42 do UI-only work (modal dismiss, error toast) with no cache interaction, matching the "Component-Level Success/Error Handling (Most Common)" pattern (rules file lines 162-199).
- Specific query keys / invalidation key shape (rules file lines 16-17): hook query key `["aiJobCriteria", jobId]` with `jobId: number` (useAiJobCriteria.ts:21-22; consumer passes `job.id` at app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:34). Mutation invalidation key `["aiJobCriteria", variables.jobId]` is the same numeric shape (useAiJobCriteria.ts:35). WS handler invalidation `queryCache.invalidateQueries(["aiJobCriteria", Number(payload.jobId)])` (app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:259) coerces to number, matching the hook's key shape and the file's existing analog `queryCache.invalidateQueries(["jobApplication", Number(data.payload.jobApplicationId)])` at line 153. `JobCriteriaExtractionCompletePayload.jobId` is typed `number` (app/javascript/shared/types/aiSummaryWebsocketPayloads.ts:31).
