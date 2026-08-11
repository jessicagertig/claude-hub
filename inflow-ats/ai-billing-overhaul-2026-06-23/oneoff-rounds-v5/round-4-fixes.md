# Round 4 Fixes — AI Credit One-Off Purchase Analog Audit

Audit reported 3 deviations. 1 fully fixed (backend), 1 partially fixed (the
matchable gap fixed in the frontend; the channel/key portion is a forced
CANNOT-MATCH), 1 CANNOT-MATCH (forced by component shape).

---

## Dev 2 (round-4 audit) — Checkout invoice_data.metadata extra `organization_id` key — FIXED

- **File:** `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:171-174`
- **Analog:** `board_wwr_listings_controller.rb:103-109` — `invoice_creation.invoice_data.metadata` is `{ board_wwr_listing_id:, job_id: }`; it does NOT carry `organization_id`. `organization_id` appears only in `payment_intent_data.metadata` and the top-level session `metadata`.
- **Before:** OURS' `invoice_data.metadata` = `{ organization_ai_credit_purchase_id:, organization_id: }`.
- **After:** OURS' `invoice_data.metadata` = `{ organization_ai_credit_purchase_id: }` — removed the EXTRA `organization_id` key, matching the analog's invoice_data block (which has no organization_id). `organization_id` remains in `payment_intent_data.metadata` (line 162-165) and top-level `metadata` (line 179-182), matching the analog.
- **Safety verified:** the `invoice.paid` webhook (`stripe_webhook_handler_job.rb:243-253`) routes the AI-credit one-off branch by `object.metadata['organization_ai_credit_purchase_id']` presence (mirroring the analog's `board_wwr_listing_id` read) and reads ONLY `organization_ai_credit_purchase_id` from the invoice metadata; `organization_id` was never read from invoice metadata, so removal is safe. The org is reachable via `OrganizationAiCreditPurchase.find(...).organization`.

> Note: this superficially conflicts with the prior round-3 W3 whitelist note,
> which claimed `organization_id` was "re-added to invoice_data.metadata" in round 4.
> The CURRENT analog (`board_wwr_listings_controller.rb:103-109`) has NO
> `organization_id` in invoice_data.metadata, and the round-4 audit (Dev 2) flagged
> OURS' `organization_id` there as an UNSANCTIONED EXTRA key. Matching the analog
> means removing it, which round 4 did. W3's round-4 note is now stale on this point.

---

## Dev 1 (round-4 audit) — Fulfillment broadcast channel/key/payload — PARTIAL FIX + CANNOT-MATCH

- **Analog:** `board_wwr_listing.rb:267-269` — `broadcast_event` = `JobChannel.broadcast_to(job, event: event, payload: { jobId:, boardWwrListingId:, wwrSlug:, publishedAt: })`, consumed by the frontend `WebsocketJobChannelHandler.tsx:55` case `wwr_listing_published` → `invalidateQueries(["jobs", jobId])`.
- **OURS:** `organization_ai_credit_purchase.rb:245-247` — `broadcast_event` = `GlobalChannel.broadcast_to(user, action: event, payload: { organizationId: })`.

### CANNOT-MATCH (forced): channel + key + target + payload shape
`JobChannel#subscribed` requires `params[:jobId]` and `stream_for job` — it can ONLY broadcast to a `Job` record. An AI credit top-up has NO `Job` (org-scoped purchase; sanctioned #7 omits all job constructs). The AI-credit frontend (account billing settings) never subscribes to any `JobChannel`; it listens on `GlobalChannel` (streamed for `current_user`). On `GlobalChannel`, the dispatch key is `action:` not `event:` — the GlobalChannel frontend handler (`WebsocketGlobalChannelHandler.tsx:62,65`) switches exclusively on `data.action`, and all ~25 existing cases use `action:`; no GlobalChannel broadcast anywhere in the codebase uses `event:`. The payload keys `wwrSlug`/`publishedAt` are WWR-listing columns OURS does not have. So channel→key→target→payload-shape is a forced cascade from sanctioned #7 (no job), NOT a free choice. This portion is already captured by whitelist **W4** (updated this round); not changed.

### FIXED (the matchable gap): broadcast was not consumed by the frontend
The analog's `broadcast_event` is genuinely CONSUMED by its frontend (handler case → query invalidation). OURS broadcast `AI_CREDIT_TOP_UP_COMPLETE` but the GlobalChannel handler had NO matching case — the message hit the `data.action` switch, matched nothing, and fell through to `default: break`, so the broadcast→consume→invalidate structure of the analog was broken (the websocket refresh did nothing).

- **File:** `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx`
- **After (added after the `MAINTENANCE_COMPLETE` case):**
  ```tsx
  case "AI_CREDIT_TOP_UP_COMPLETE":
    queryCache.invalidateQueries(["organizationAiCreditBalance"]);
    break;
  ```
- This restores the analog's broadcast-consumed-and-invalidates structure: the OURS `["organizationAiCreditBalance"]` query is the org-scoped equivalent of the analog's `["jobs", jobId]` query. The payload OURS sends (`{ organizationId }`) is not needed for the invalidation (the balance query is a per-org singleton), matching how the analog's handler invalidates by the jobId it already has.

---

## Dev 3 (round-4 audit) — Direct-charge frontend onSuccess handler — CANNOT-MATCH

- **File:** `app/javascript/ats/src/views/accountAdmin/accountPlatoAi/AiCreditSubscription.tsx:181` — `purchaseTopUp`'s mutation `onSuccess: () => {}`.
- **Analog:** `JobDistributionWeWorkRemotely.tsx:268-272` — `handleCreateBoardWwrListing`'s `onSuccess` runs `setErrors(null)` and `setIsDirty(false)`.
- **Why CANNOT-MATCH (forced by component shape, not effort):** the two states the analog resets do not exist in OURS' component. The analog's `errors` (`useState(null)`, line 157) holds inline form-validation errors rendered in the WWR listing-configuration form; `isDirty` (`useState(false)`, line 158) tracks unsaved edits to that editable form (set true on field change at line 384; guards save/navigation). `AiCreditSubscription`'s top-up is a buy-a-pack button, NOT an editable form: it has no `errors`/`setErrors` state (errors surface only as toasts via `handlePurchaseError`, with no inline error-render path) and no `isDirty`/`setIsDirty` state (no editable fields to dirty). There is nothing to reset; the empty `onSuccess` is correct. The mutation's own `onSuccess` (in `usePurchaseAiCreditTopUp`) already invalidates the balance query, and the success growl is emitted server-side from `grant_credits`. Fabricating `errors`/`isDirty` state (and, for `errors`, a consuming render path) solely to mirror the reset would be unscoped code the component's design does not use.
- **Closest fix made:** none possible without unscoped state fabrication; left empty `onSuccess`. (Parallels W10, which covers the same component's `onError` handler.)
- **Escalated:** added as **W11** to SUGGESTED-WHITELISTS.md.

---

## CANNOT-MATCH summary

- **Dev 1 (broadcast channel/key/target/payload portion):** forced by no `Job` + GlobalChannel's `action:` dispatch contract. Captured by W4 (updated). The frontend-consumer gap WITHIN this deviation WAS fixed.
- **Dev 3 (onSuccess setErrors/setIsDirty):** forced by component shape (purchase button vs editable form). Escalated as W11.

## SUGGESTED-WHITELISTS additions/updates

- **W4** — updated with a round-4 note: channel/key/target/payload still CANNOT-MATCH; the frontend-consumer gap was fixed (added `AI_CREDIT_TOP_UP_COMPLETE` handler case).
- **W11** — new: frontend top-up `onSuccess` empty vs analog's `setErrors(null)`/`setIsDirty(false)`.

## Files changed (code)

1. `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb` — removed `organization_id` from `invoice_data.metadata` (Dev 2).
2. `app/javascript/ats/src/websockets/WebsocketGlobalChannelHandler.tsx` — added `AI_CREDIT_TOP_UP_COMPLETE` handler case invalidating `["organizationAiCreditBalance"]` (Dev 1 matchable gap).
