# Angle 7 — WebSocket frontend handler, copy rules, DECIDED-OUT absence verification — Round 1

## Handler case

`WebsocketGlobalChannelHandler.tsx:250-262` — `JOB_CRITERIA_EXTRACTION_COMPLETE` placed after the `AI_SUMMARY_FAILED` block (:236) and before `AI_SUMMARY_BULK_FAILED` (:263), per plan F.1.3. Three-way toast exactly as specced (succeeded → success; `zeroCriteriaFailure` → warning zero-found copy; else → warning generic), all `delay: 10000`. Invalidation `queryCache.invalidateQueries(["aiJobCriteria", Number(payload.jobId)])` — key shape matches the hook's `["aiJobCriteria", jobId]` (number) exactly; `queryCache` is the handler's existing `useQueryClient()` identifier (:11); `Number()` cast per the attachExternalResumeComplete precedent. Structural mirror of the `AI_SUMMARY_COMPLETE` case.

## Payload type

`aiSummaryWebsocketPayloads.ts` — `JobCriteriaExtractionCompletePayload { status: "succeeded" | "failed"; jobId: number; jobTitle: string; zeroCriteriaFailure: boolean; errorMessage?: string; }` matches the backend broadcast fields exactly (broadcast keys are camelCase written directly in Ruby — no api.ts transform on the socket path; `zero_criteria_failure?` on a loaded record is always boolean, matching the non-nullable type). Header comment updated to "AI WebSocket broadcasts". Existing interfaces untouched. Type imported in the handler alongside the existing imports (:7).

## Copy rules sweep (every new user-facing string checked against SPEC §10)

Checked: 3 toasts, 3 empty states (titles + messages), card title/description, section intro, sidebar glossary (title, intro, 3 leads + descriptions), slide-over h2 + description, confirm modal title/lead/statement/buttons, controller error messages, guard message. Results:
- No em dashes, no emoji, sentence case throughout. ✓
- "extract" used, never "read" (all new strings; RunPlatoAddDescriptionModal's pre-existing "reads" copy is NOT part of this diff). ✓
- "count most/less toward the score" verbatim in sidebar leads; no "weight"/"heaviest". ✓
- Button labels static: "View criteria", "Generate criteria", "Regenerate criteria", "Cancel" — no interpolated counts. ✓
- Timestamp appears ONLY in the card description (`distanceInWords`). ✓
- No "candidates will be rescored" anywhere; point-in-time framing used ("Reviews that have already run keep the criteria they were scored against"). ✓
- DECISIONS-verbatim strings byte-match (empty-state titles/messages, tier leads, statement copy). ✓
- Toast strings match SPEC §8.6 verbatim. ✓

## DECIDED-OUT absence verification (whole committed diff)

- `internal_job_criteria`: 0 occurrences. ✓
- Guard modals: `GuardTitle`/`GuardBody`/`GuardFoot`: 0; bare `guard` grep scoped to `app/javascript` added lines (per plan-review F2): 0. No ≤5-criteria warning, no 0-criteria popup. ✓
- After-description-update confirm variant / "Keep current criteria" trigger: absent. ✓
- `TierHint`: 0 occurrences. ✓
- `tier1`/`tier2`/`tier3` payload keys: 0 (all tier values are `tier_1`-form); no bundle variable names leaked. ✓
- `??`: 0 in the diff; `|| []`/`|| 0`/`|| ""`: 0 (the error-toast string fallback is the sanctioned exception). ✓
- No frontend test harness half-added (no new test files/config under app/javascript). ✓

## Findings

No issues found. (LOW formatting nit — `aiSummaryWebsocketPayloads.ts` still ends without a trailing newline — recorded in code-quality.md.)
