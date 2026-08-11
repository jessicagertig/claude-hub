# Angle 7 — WebSocket handler, copy rules, decided-OUT absence — Round 2

Handler/type files byte-identical to round-1 state; merge did not touch them. Re-verified at HEAD:

- **Handler case** `JOB_CRITERIA_EXTRACTION_COMPLETE` (WebsocketGlobalChannelHandler.tsx:250-262), placed after the `AI_SUMMARY_FAILED` block: three-way toast (succeeded → success; `zeroCriteriaFailure` → warning zero-found; else → warning generic), all `delay: 10000`; `queryCache.invalidateQueries(["aiJobCriteria", Number(payload.jobId)])` — exact key-shape match with the hook (number).
- **Payload type** `JobCriteriaExtractionCompletePayload` matches the backend broadcast field-for-field (`status`, `jobId`, `jobTitle`, `zeroCriteriaFailure`, optional `errorMessage`); header comment reads "AI WebSocket broadcasts"; imported in the handler.
- **Copy rules sweep** (re-run on the full `develop...HEAD` diff): zero em dashes in added lines across app code; sentence case; no emoji; "extract" vocabulary; static button labels; timestamps only in the card description; no "rescored" phrasing. DECISIONS-verbatim strings intact.
- **Decided-OUT absence greps** (re-run on the full diff): `internal_job_criteria` 0; `Guard(Title|Body|Foot)` 0; `TierHint` 0; `tier1|tier2|tier3` payload-key forms 0 (only `tier_1`-form values). No after-description-update variant, no guard modals, no tier hints.
- No frontend test harness half-added (no new test files in the diff).

## Findings

No issues found.
