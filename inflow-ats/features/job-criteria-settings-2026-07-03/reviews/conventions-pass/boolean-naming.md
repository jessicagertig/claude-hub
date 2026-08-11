# Conventions pass — boolean_variables_and_naming.md

Rules file: `cursor_rules/frontend/boolean_variables_and_naming.md` (worktree `/Users/jessica/wrk/wrk-corp/inflow-ats.job-criteria-settings`, HEAD 68e5e6a4e)
Diff: `git diff develop...HEAD -- app/javascript`

No issues found.

Booleans checked (all compliant):

- `isPayloadStatusInFlight` — app/javascript/ats/src/views/jobApplications/jobSetup/components/JobCriteriaSection.tsx:57. Variable creation permitted: complex logic with multiple `||` operators (three status equality checks, rule 1). Name generalizes the three statuses per rule 2 instead of enumerating them.
- `isInFlight` — JobCriteriaSection.tsx:61 (`isPayloadStatusInFlight || isFetching`). Compound `||` condition, used multiple times (lines 151, 152); fully inlined it is a 4-term `||` chain, so extraction is permitted under rule 1. Not the prohibited "simple condition used once / used multiple times but standalone" pattern.
- `isLoading`, `isFetching` — JobCriteriaSection.tsx:32-33 and RegenerateJobCriteriaConfirmModal.tsx:21. Destructured from react-query hooks, not created from conditions; names are library-fixed.
- `zeroCriteriaFailure` — app/javascript/shared/queryHooks/useAiJobCriteria.ts:14 and app/javascript/shared/types/aiSummaryWebsocketPayloads.ts:33. API payload interface fields, not local boolean variable creation; consumed inline without extraction (JobCriteriaSection.tsx:66, WebsocketGlobalChannelHandler.tsx:254). The rules file requires "specify exactly what they mean" and generalized names for complex conditions; it does not mandate an `is`/`has` prefix, and the name states its meaning.
- Inline conditions correctly left inline (rule 1 "don't create a variable for a simple boolean"): `tierCriteria.length === 0` (JobCriteriaViewModal.tsx), `payload.status === "succeeded"` (WebsocketGlobalChannelHandler.tsx:253), `enabled: jobId != undefined` (useAiJobCriteria.ts:23), `tier.key === "tier_3" && tierCount === 0` (JobCriteriaSection.tsx).
- `isDirty` (rule 1a) — not present in the diff; no form-dirtiness logic added. Not applicable.
- `displayState` values (`"neverExtracted"`, `"zeroCriteria"`, `"failure"`, `"card"`) — string union, not booleans; outside this rules file's scope.
