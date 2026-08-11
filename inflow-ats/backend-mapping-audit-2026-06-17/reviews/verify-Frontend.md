# Verify — Frontend consumers (F1)

**Verdict: CLEAN**

## Files checked
- OLD: backend-flow-map-2026-06-17.md — F1 section (lines 276-288), Part summary (813-825, 832-833), WebSocket table (748-759), scattered F1 refs (160, 196, 210, 227, 257, 591-592, 691)
- NEW: backend-flow-map-2026-06-22-neutral.md — Every reader (521-535), Windows (537-546), Frontend consumers summary (550-557), WebSocket actions (559-570), supporting (66-67, 265, 269, 390, 488)

## CHECK 1 — Fact preservation

Every load-bearing F1 fact in OLD is present in NEW:

| OLD fact + cite | NEW location |
|---|---|
| Serializer attrs `:4-6`, `published_at_timestamp` method `:8-10` (= `updated_at.to_i`), Shallow `has_one :23-24`, JobApplicationSerializer `:40-41`, controller preloads `:27,38,:56` (277, 813) | 522, 554 |
| JobApplicationListContainer.tsx `:220,:226,:235,:236`; NavItem scalar props `:17-18` (278) | 527, 556 |
| Harvey ball `:26-29` renders only when status current/regenerating AND scorePercentage != null (279) | 527, 556 |
| JobChannel `ai_summary_status_change` `:73-76` (not list); `ai_summary_succeeded` `:77-81` invalidates `['jobApplicationsForStage', hiringStageId]` (280) | 532, 557, 566-567 |
| GlobalChannel `:227/:241/:253/:281` invalidate jobApplicationsForStage; list key useJobApplication.ts:185 (281) | 533, 557, 563-565 |
| bulkAiSummaryCount.ts `:37-41` subtracted `:46` (282) | 530, 556 |
| TS interface 4-value union jobApplication.ts:4; publishedAtTimestamp sent by serializer `:6`, read by Activity, not declared on TS interface `:1-9`, untyped runtime access (283) | 529, 535 |
| No optimistic-UI; queryHooks; useJobApplication.ts:229 setQueryData in onSuccess (284) | 534, 555 |
| PlatoTab display fallbacks `:127,:129` (''/0); fetch key `:46` no fallback; useAiJobApplicationSummary.ts:45 enabled gate (285) | 528, 555 |
| PlatoTab full reader `:42,:50,:52,:151,:154,:187,:210,:218`, `:46`, `:130`; `:187` no-resume gate (286) | 528, 556 |
| JobApplicationActivity.tsx `:79-91`, gate `:80-83`, renders `:87,:88,:89,:90,:91` (287) | 529, 556 |
| PlatoOverviewCallout unwired: `:13` prop union, deriveCalloutStatus `:40-47`, zero callers, two same-named files (288) | 531, 556 |
| attachExternalResumeComplete handler `WebsocketGlobalChannelHandler.tsx:152-154` invalidates jobApplication query (126, 757) | 265, 557, 568 |

No DROPPED facts. No ALTERED facts (every file:line number matches; no flipped conditions).

Notes (not drops — methodology/repetition removed):
- OLD 286 `grep -n statusValue returns exactly these lines` annotation dropped; the line list itself is preserved verbatim in NEW 528/556.
- OLD 288 full path `app/javascript/ats/src/views/jobApplications/Plato/PlatoOverviewCallout.tsx` condensed to `Plato/PlatoOverviewCallout.tsx` in NEW 531 — same short form OLD itself uses at 821; file still uniquely identified.

## CHECK 2 — Neutrality

No banned vocab or framing in the NEW F1 text. OLD's defect-framing was de-framed:
- OLD "UNWIRED, zero callers ... present-but-dead status reader" → NEW 531 "present, no callers ... zero callers ... produces no live display" (factual).
- OLD "fabricating ''/0" → NEW 528 "substituting ''/0 for absent denormalized data" (factual).
- "untyped runtime access" carried from OLD 283 — factual, neutral.

No residual prescriptive should / never / incorrect / problem / wrong / matters / concerning / judgmental ALL-CAPS in the F1 lines.
