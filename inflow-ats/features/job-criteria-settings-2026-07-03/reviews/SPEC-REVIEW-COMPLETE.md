# SPEC REVIEW COMPLETE — job-criteria-settings

**Final verdict: READY FOR PLANNING.** Two consecutive full passes achieved (Rounds 4 and 5: zero findings, zero amendments). 5 rounds total. Worktree `05c9513ef` (branch `job-criteria-settings`), clean throughout — no repo drift.

**Process note:** Round 3 initially closed clean; the orchestrator then delivered two candidate findings from a cross-validating reviewer (dispatched by mistake; wrote nothing to reviews/; stood down after an independent trace that also corroborated the Rounds 1-2 amendments and the flag-4 ruling). Both candidates were independently verified against source by this reviewer, confirmed, and folded into Round 3 as findings, voiding the initial streak. Rounds 4-5 then passed clean.

## Plain English Summary

When Plato reviews candidates it scores them against criteria extracted from the job description, but users cannot currently see, time-stamp, or redo that extraction. This feature adds a "Job criteria" section to the per-job Plato AI settings tab: a card (relative extraction time + Core/Preferred/Bonus counts), a read-only slide-over listing every criterion by tier, and a confirmed Regenerate button driving an async re-extraction whose loading state comes from backend status (survives reload) and whose completion arrives as a WebSocket toast. Distinct empty states cover never-extracted / found-nothing / failed. One new backend rule: when the latest completed extraction found zero criteria, new AI summary reviews are refused at every entry point (they would burn credits scoring against nothing).

## Blast Radius (full version: reviews/plain-english-summary-and-blast-radius.md)

New: 2 endpoints, 1 controller, 1 serializer, 1 hook file, 2 modals, 1 WS event, 3 spec files. Shared infrastructure modified: `Job` extraction gating, zero-criteria guard at 4 sites spanning all 7 traced review entry points, `ExtractJobCriteriaJob` optional second arg + 3 broadcast sites, `BulkGenerateAiSummariesJob` claim-row fix, bulk controller pass-through, 2 constant substitutions, `JobSetupAiSettings.tsx` + WS handler + payload types. Untouched: scoring pipeline internals, `resume_waiting_summaries`, existing save flow, `internal_job_criteria`.

## Round-by-round

| Round | Findings | Amendments | Verdict |
|---|---|---|---|
| 1 | 5 MED, 3 LOW (flag-4 justification rationalized; broadcast sites missing analog row-presence guards; impossible "null/false" payload cell; unreachable "rows 3-5" in display table; action-row placement unstated; + 3 LOW precision/citation/documentation) | 10 | FAIL |
| 2 | 2 LOW (wrong job-nested-hook citation; `sourceHeading` nullable-value type) | 2 | FAIL |
| 3 | 1 MED, 1 LOW (funnel-guard race strands an enqueued summary in a non-terminal status, undocumented — cross-validation input, independently verified, documented-and-accepted per rule 20; §2 "1 job change" vs §13's two job classes) | 2 | FAIL |
| 4 | 0 | 0 | PASS |
| 5 | 0 | 0 | PASS — stop |

## FLAG 4 decision (deferred to this review; decided Round 1; independently corroborated)

**`ExtractJobCriteriaJob#perform` stays optional POSITIONAL (`perform(ai_job_criteria_id, requesting_organization_user_id = nil)`), not the analog's kwargs.** Grounds: kwargs conversion breaks in-flight positional `[id]` Sidekiq payloads at deploy — `ArgumentError` raises at invocation, before the method body, so neither the method rescues nor `retry_on CustomErrorAiSummary` fire, no failure write happens, and the row is stranded in-flight forever (button spins indefinitely). Payloads live across deploys via `set(wait: 30.seconds)` enqueues (job.rb:707) and 2-minute retry waves (extract_job_criteria_job.rb:5). The exhaustion block reads `job.arguments.first`/`.second` — the positional counterpart of the analog's `job.arguments.first[:key]` form. Full evidence: reviews/spec-round-1/gating-job-signature-broadcast.md.

## Open questions for Jessica

1. **Flag 4 ruling (above)** — made by the spec review as your proxy; the mistakenly-dispatched second reviewer independently reached the same conclusion. If you would rather take a two-deploy kwargs migration (or accept a window of stranded rows) to match the analog's signature exactly, say so before Phase 5; otherwise positional ships.
2. **Flag 6 (pre-existing orchestrator flag, still ⚠️ for your morning review)** — the `BulkGenerateAiSummariesJob#each_iteration` claim-row fix (validation failure → row `:failed` instead of stuck `:processing`) is shared bulk infrastructure, approved overnight because the new guard turns the latent gap into a common path.
3. **Funnel-guard race consequence (Round 3, documented-and-accepted — your call on the alternative).** A summary enqueued while validators passed can hit the new funnel guard after a zero-criteria failure lands, leaving it stuck `pending`/`textract_processing` with no toast; manual re-clicks return it without enqueueing; a bulk re-run or new resume upload revives it; pre-feature the same race yielded a revivable `awaiting_job_criteria`. The spec documents and accepts this (narrow window, no credit consumed) per rule 20. The alternative — the funnel guard setting the latest summary to `awaiting_job_criteria` instead of returning bare — is a new state transition on shared infrastructure and needs your approval if wanted. Full chain: SPEC §6.2.4 + reviews/spec-round-3/zero-criteria-review-guard.md.
4. **Zero-criteria display precedence (flag 5, ruled)** — a failed regeneration hides an older succeeded card (old criteria not viewable until a successful re-run). Ruled consistent with scoring semantics; flagging since it is user-visible data disappearing.
5. **Non-AI orgs can reach the tab by direct URL** — the FeatureFlipper gates only the nav item, not the `/ai` route; they would see the never-extracted empty state and get a 422 toast on POST (GET is deliberately ungated, POST Flipper-gated). Coherent today; noted in case you want route-level gating someday.
