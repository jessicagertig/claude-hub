# Round 6 Fixes — AI Credit One-Off Purchase Analog Audit

Audit reported 1 deviation.

## Deviation: Fulfillment data-broadcast channel and payload-key shape (`broadcast_event`)

**Analog:** `app/models/board_wwr_listing.rb:267-269`
`JobChannel.broadcast_to(job, event: event, payload: { jobId: job.id, boardWwrListingId: id, wwrSlug: wwr_slug, publishedAt: published_at })`

**OURS (before):** `app/models/organization_ai_credit_purchase.rb:244-246`
`GlobalChannel.broadcast_to(<user>, action: event, payload: { organizationId: organization_id })`

The deviation has two structural parts:

### Part A — channel + top-level key (`GlobalChannel`/`action:` vs `JobChannel`/`event:`) → CANNOT-MATCH (forced)

Traced: `app/models/board_wwr_listing.rb:267` (analog) → `app/channels/job_channel.rb` (`JobChannel#subscribed` does `Job.find(params[:jobId]); stream_for job` — can ONLY stream to a `Job`) → `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:61-65` (`handleGlobalMessage` guards `if (data.action != null)` and switches on `data.action`) vs `app/javascript/ats/src/websockets/WebsocketJobChannelHandler.tsx:53-54` (switches on `data.event`).

- An `OrganizationAiCreditPurchase` is org-scoped and has no `Job` (SANCTIONED #7), so it cannot use `JobChannel`.
- The AI-credit billing frontend subscribes to `GlobalChannel` only (`stream_for current_user`), never to any `JobChannel`; a `JobChannel` broadcast would reach no consumer on the billing page.
- `GlobalChannel`'s frontend handler dispatches exclusively on `data.action`, so the top-level key MUST be `action:`, not `event:`. The sibling `broadcast_show_growl` on the same record uses the identical `GlobalChannel … action:` form.

This is the same forced cause as SANCTIONED #7 (no job → org-level), already documented as **W4** in SUGGESTED-WHITELISTS.md across rounds 4 and 5. Position unchanged. No code change to channel/key — already the closest possible match.

### Part B — payload missing the record's own id → FIXED (matchable)

The analog's payload structure is `{ <parent-target id: jobId>, <record's own id: boardWwrListingId: id>, <record descriptive fields> }`. OURS carried only `organizationId` (the parent-target id, equivalent to `jobId`) and was MISSING the record's own id (equivalent to `boardWwrListingId: id`).

**Fix** — `app/models/organization_ai_credit_purchase.rb` `broadcast_event`:

- Before: `payload: { organizationId: organization_id }`
- After: `payload: { organizationId: organization_id, organizationAiCreditPurchaseId: id }`

Added `organizationAiCreditPurchaseId: id` so the payload mirrors the analog's `{ <parent-id>, <record-own-id>, … }` shape. The analog's remaining keys `wwrSlug`/`publishedAt` are `BoardWwrListing` columns with no `OrganizationAiCreditPurchase` equivalent (no slug, no publish timestamp on a credit purchase), so no further payload key is matchable.

**Frontend:** `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx:212-214` consumes the `AI_CREDIT_TOP_UP_COMPLETE` action by invalidating `["organizationAiCreditBalance"]` and does not read the payload. The added payload key is additive and breaks nothing; no frontend change required.

Also updated the `broadcast_event` doc comment in `organization_ai_credit_purchase.rb` to describe the now-matched payload shape and the forced channel/key contract.

## CANNOT-MATCH items

- **CANNOT-MATCH: broadcast_event channel + top-level key (`GlobalChannel`/`action:` vs analog `JobChannel`/`event:`):** forced by the absence of a `Job` on the org-scoped `OrganizationAiCreditPurchase` and by `GlobalChannel`'s `data.action` dispatch contract (the AI-credit billing frontend listens only on `GlobalChannel`). Same forced cause as SANCTIONED #7. Closest match retained.

## SUGGESTED-WHITELISTS additions

- Appended a round-6 update to existing entry **W4** in `SUGGESTED-WHITELISTS.md` documenting that the channel/key portion remains CANNOT-MATCH (forced) and that round 6 matched the one fixable gap (added `organizationAiCreditPurchaseId: id` to the payload to mirror the analog's record-own-id key). No new W-number created — this is the same deviation W4 already covers.
