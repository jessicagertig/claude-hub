# Round 1 — Angle 7: WebSocket frontend handler, copy rules, DECIDED-OUT absence verification

## Verified against source

**Handler case (SPEC 8.6):**
- Placement: `AI_SUMMARY_FAILED` block ends at WebsocketGlobalChannelHandler.tsx:248 — new case after it ✓.
- Structural mirror of `AI_SUMMARY_COMPLETE` (:216-234): payload cast, kind/title branch, `delay: 10000`, invalidations ✓. Three-way branch (succeeded / zeroCriteriaFailure / other) is a justified extension of the analog's two-way branch — driven by the DECISIONS-required zero-found state.
- Invalidation key `["aiJobCriteria", Number(payload.jobId)]` EXACTLY matches the hook's query key shape `["aiJobCriteria", jobId]` (number) ✓; `Number()` cast precedent at :153 (`attachExternalResumeComplete`) ✓.
- Existing type imports at line 7 of the handler (`AiSummaryCompletePayload, ...` from `@shared/types/aiSummaryWebsocketPayloads`) — spec's "import alongside line 7" citation ✓.

**Payload type (SPEC 8.7):** interface fields match the backend broadcast exactly (`status: "succeeded" | "failed"`, `jobId`, `jobTitle`, `zeroCriteriaFailure`, optional `errorMessage` — conditional in the Ruby helper) ✓. Header comment currently reads "AI summary WebSocket broadcasts" (aiSummaryWebsocketPayloads.ts:1-2) — spec's update to "AI WebSocket broadcasts" is accurate in scope ✓. Existing interfaces untouched (section 13) ✓.

**Phase-1 trace note 5 ADJUDICATED — dual casing mechanisms:** the WS path writes camelCase keys directly in Ruby (`jobId`, `jobTitle`, `zeroCriteriaFailure`) exactly like the analog (`candidateFullName`, `jobApplicationLink` — generate_ai_job_application_summary_job.rb:68-73; textract_result.rb:156-160); ActionCable has no api.ts case transform. The serializer path emits snake_case (`extracted_at`) transformed by api.ts to camelCase. The spec's two type definitions each match their source's actual wire format (`JobCriteriaExtractionCompletePayload` camelCase-from-Ruby; `AiJobCriteriaPayload` camelCase-post-transform with snake_case enum VALUES per core rule 7's Ruby-enum exception). Coherent; no change needed.

**Copy-rules sweep (SPEC 10 binding rules) over EVERY drafted user-facing string in the spec:**
- Toasts (8.6): "Job criteria generated for X" / "No criteria found in the job description for X" / "Could not generate job criteria for X" — sentence case, no em dashes, no emoji, static structure ✓.
- Empty states (8.2): titles/messages match DECISIONS verbatim (never-extracted; zero-found); drafted other-failure copy compliant ✓.
- Card description (8.3): "Plato extracted these from your job description {time} ago." — "extract" vocabulary ✓; timestamp lives ONLY in the card description ✓.
- Section intro (8.3): explains the automatic lifecycle (publish + description-change re-extract) per DECISIONS ✓; no "candidates will be rescored" anywhere ✓; "Each review scores a candidate against the criteria as they stand when it runs" — point-in-time framing ✓.
- Sidebar glossary: leads verbatim from DECISIONS ("count most toward", "count toward the score, less than core") — no "weight/heaviest" ✓.
- Modal copy (8.5): lead + statement box use "re-extract", "affect scoring", "keeps scores comparable" ✓; "Reviews that have already run keep the criteria they were scored against" — point-in-time ✓.
- Slide-over body (8.4) ✓. Backend error strings (5.2, 6.2): sentence case, no em dashes ✓.
- Button labels all static: View criteria / Generate criteria / Regenerate criteria / Cancel — no interpolated counts ✓.

**DECIDED-OUT absence from the SPEC (grep of SPEC.md):**
- Guard modals: mentioned only in section 10 as "Decided OUT — do not build" (GuardTitle/GuardBody/GuardFoot named as discarded) ✓ — no build instructions anywhere.
- After-description-update confirm variant: only as OUT (8.5 "manual variant ONLY", 10) ✓.
- Tier hints: only as OUT (8.4 "NO tier hint sentences", 10) ✓.
- `internal_job_criteria`: only as OUT (section 3, 10) ✓.
- Design-bundle variable names: `tier1/tier2/tier3` payload keys explicitly rejected (8.3 — TIERS uses stored `tier_1`-form values, writer verified extract_criteria.rb:110-113) ✓.

**Frontend tests none:** documented decision (SPEC 12) — verified `app/javascript` has only `Button.test.tsx` as component-test precedent; no hook/view test infra to extend ✓.

## Taken on trust from the spec
Nothing load-bearing; handler, types file, and both broadcast analogs read this round.

## Findings

No issues found.

## Amendments Applied

None (this angle).
