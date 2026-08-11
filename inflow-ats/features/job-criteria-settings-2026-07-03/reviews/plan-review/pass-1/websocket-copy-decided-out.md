# WebSocket frontend handler, copy rules, and DECIDED-OUT absence verification — Pass 1

## Fact Check

| Plan claim | Verified against | Result |
|---|---|---|
| F.1.3: type import at handler :7 | WebsocketGlobalChannelHandler.tsx:7 (`import { AiSummaryCompletePayload, ... } from "@shared/types/aiSummaryWebsocketPayloads"`) | ✓ exact — adding `JobCriteriaExtractionCompletePayload` there is well-formed |
| `AI_SUMMARY_FAILED` block closing brace at :248 | Read handler :214-252 | ✓ case :236-248, closing `}` at :248; next case (`AI_SUMMARY_BULK_FAILED`) at :250 — insertion point unambiguous |
| Structural mirror of `AI_SUMMARY_COMPLETE` (:216-234) | Read handler | ✓ analog case confirmed at :216-234 (payload cast, toast kind by status, `delay: 10000`, queryCache invalidations, break) |
| `queryCache` identifier | handler :11 (`const queryCache = useQueryClient();`) | ✓ plan snippet uses the file's actual identifier |
| `Number()` cast precedent at :153 | handler :152-154 (`attachExternalResumeComplete` → `Number(data.payload.jobApplicationId)`) | ✓ exact |
| Invalidation key `["aiJobCriteria", Number(payload.jobId)]` matches hook key `["aiJobCriteria", jobId]` (number) | F.1.1 hook (numeric `job.id`) | ✓ shapes match — full-stack analog chain closes (broadcast → handler case → payload type → invalidation → hook) |
| F.1.2 payload interface matches backend broadcast fields exactly | E.2.5 payload (`status`, `jobId`, `jobTitle`, `zeroCriteriaFailure`, conditional `errorMessage`) | ✓ field-for-field, `errorMessage?` optional; camelCase keys written directly in Ruby — socket path has no api.ts transform (analog `candidateFullName` precedent verified in generate_ai_job_application_summary_job.rb:70 and aiSummaryWebsocketPayloads.ts) |
| Header comment update | aiSummaryWebsocketPayloads.ts:1-2 ("AI summary WebSocket broadcasts…") | ✓ current text as claimed; change is comment-only, existing interfaces untouched (C NOT-touched list) |
| Three-way toast logic (succeeded → success; zeroCriteriaFailure → warning zero-found; else → warning generic) | SPEC 8.6 | ✓ byte-identical snippet |

## Copy rules sweep (SPEC 10, binding) — every new user-facing string in the plan

Checked: 3 toasts (F.1.3), 3 empty states (F.2.1.3), card description (F.2.1.5), section intro (F.2.1.4), sidebar glossary (F.2.2.2), slide-over body (F.3.1.3), confirm lead + statement (F.3.2.3/F.3.2.4), backend guard message (E.4), blank-description + Flipper messages (E.5.2), button labels.

- No em dashes ✓ (all strings scanned)
- Sentence case ✓; no emoji ✓
- "extract" never "read" ✓ ("re-extract", "extracted", "extracting" throughout)
- "count most/less toward the score" never "weight/heaviest" ✓ (sidebar leads DECISIONS-verbatim)
- Static button labels, no interpolated counts ✓ (`Generate criteria`, `Regenerate criteria`, `View criteria`, `Cancel`)
- Timestamps only in the card description ✓ (`distanceInWords` appears only in F.2.1.5)
- Never "candidates will be rescored" ✓ (statement box says "you can also regenerate all candidate reviews"; slide-over/lead say "keep the criteria they were scored against")
- DECISIONS-verbatim strings byte-checked: 2 empty-state titles+messages ✓, 3 sidebar leads ✓; state-3 failure copy is the SPEC draft (DECISIONS delegated) ✓; toast copy marked draft, "do not improvise different strings" ✓

## DECIDED-OUT absence verification (plan text + F.4 sweep)

- Guard modals: no plan step builds them; F.4.1 greps the diff for `guard`/`GuardTitle`/`GuardBody`/`GuardFoot` ✓ (see F2 below on the bare-`guard` term)
- After-description-update confirm variant: F.3.2.3 "manual variant ONLY"; F.4.1 grep ✓
- TierHint: F.3.1.4 "NO TierHint sentences (decided OUT)"; F.4.1 grep ✓
- `internal_job_criteria`: zero occurrences in any task; C NOT-touched list; F.4.1 whole-diff grep ✓
- Bundle leaks: F.4.1 greps `tier1`/`tier2`/`tier3` payload keys; F.2.1.2 TIERS uses stored `tier_1`-form ✓; bundle variable names discarded per §A authority chain ✓
- Frontend tests: none, documented (H) — no half-added harness anywhere ✓; Cypress: no changes (H) ✓

## Completeness (vs SPEC §8.6, §8.7, §10)

- SPEC 8.6 handler case → F.1.3 ✓ verbatim; SPEC 8.7 payload type + header comment + import → F.1.2/F.1.3 ✓; SPEC 10 constraints → G checklist ✓ (decided-OUT list, copy rules, any-job-state, loading states, flags settled, backward-compat invariants all carried)

## Findings

- F2 [MED] **F.4.1's bare `guard` grep over the whole diff can false-positive on legitimate backend text.** Where: plan.md F.4.1 ("ALL must return zero hits in the diff: … `guard`/`GuardTitle`/…"). The decided-OUT target is the design bundle's guard-MODAL artifacts (frontend). But the backend diff may legitimately contain the word "guard" in spec example descriptions (e.g., E.3.2.1's no-pending-guard documentation test) or comments, making the zero-hits requirement either unsatisfiable or a false alarm the implementer must talk themselves past. Evidence: E.3.2.1 instructs a test that "documents the deliberate absence of a pending guard". Fix (not required for MED): scope the bare-`guard` grep to frontend files (`app/javascript`), keeping the `GuardTitle`/`GuardBody`/`GuardFoot` terms diff-wide.

## Amendments Applied

None (MED does not require amendment; noted for the implementer).
