# Server-side paid-subscription conversions → Google Ads

Research report. Date: 2026-07-30.

Every load-bearing claim below is labelled **OFFICIAL** (a Google statement, with URL) or **PRACTITIONER** (agency, vendor, forum, or public repo). Absence of documentation is reported as "nobody documents this", never as "does not work".

---

## 0. How to build it

The route: **capture the gclid at the ad click (already done) → store it on the user/organization record (already done) → when the Stripe webhook confirms the paid subscription, upload an offline conversion DIRECTLY to Google Ads keyed on that stored gclid, with the SHA-256-hashed email attached as a secondary identifier.** GA4 does not sit in the path for the Google Ads half.

This is the architecture every production implementation found in the corpus uses. The closest analogs:

- **PRACTITIONER** — CodeWords template "Stripe checkout to Google Ads conversion tracking" (https://www.codewords.ai/templates/stripe-checkout-google-ads-conversion): Stripe `checkout.session.completed` webhook → look up the stored gclid by customer email → upload gclid + SHA-256 email + value + currency + timestamp to Google Ads. Same trigger, same identifiers, same shape as Polymer's case.
- **PRACTITIONER** — Conner Crowe, HubSpot closed-won → Google Ads offline conversions (https://connercrowe.com/blog/closed-won-webhook-hubspot-google-ads-offline-conversions/): the only source in the corpus reporting a measured match rate — "87% after 60 days of reconciliation cleanup, mostly capped by stale gclids beyond the 90-day lookback", with deal-to-Google-Ads latency of 45–90 seconds and deal-to-Smart-Bidding-signal of 24–48 hours.
- **PRACTITIONER** — Two Spouts B2B SaaS offline conversion stack (https://twospouts.com/blog/google-ads-offline-conversion-crm-b2b-saas): "GCLID capture at form submission, GCLID storage in your CRM, a trigger that fires when a lead reaches the target event … and an upload mechanism."

### Step 1 — Google Ads account prerequisites

**OFFICIAL** (https://support.google.com/google-ads/answer/7012522):

- Auto-tagging must be ON in the Google Ads account. "You've enabled auto-tagging. This lets you import offline conversions." Auto-tagging is what appends `&gclid=` to the landing URL in the first place (**OFFICIAL**, https://support.google.com/google-ads/answer/3095550). Verify this before anything else — with auto-tagging off, there is no gclid to have captured.
- Conversion tracking must have been enabled in the account **at the time of the click**. A gclid captured before conversion tracking existed is unusable later; the API returns `CONVERSION_TRACKING_NOT_ENABLED_AT_IMPRESSION_TIME` (**OFFICIAL**, `conversion_upload_error.proto`).

### Step 2 — Create the conversion action

Google Ads UI: **Goals icon → Conversions → Summary → New conversion action → Import → CRM, files, or other data sources → Track conversions from clicks**.

Requirements:

- Type must be `UPLOAD_CLICKS`, status `ENABLED` (**OFFICIAL**, https://developers.google.com/google-ads/api/docs/conversions/upload-clicks). The GAQL to confirm: `WHERE conversion_action.type = 'UPLOAD_CLICKS' AND conversion_action.status = 'ENABLED'`.
- **Set the click-through conversion window to 90 days now, before the clicks you care about occur.** Default is 30 days. **OFFICIAL** (https://support.google.com/google-ads/answer/3123169): "You can set it anywhere from 1 to 30, 60, or 90 days for Search and Display campaigns depending on the conversion source", and "any changes apply to all conversions going forward" — a conversion that fell outside the old window "won't be retroactively counted." A trial converting on day 45 against a default-window action is rejected with `EXPIRED_EVENT` even though the gclid is perfectly valid. This is the single most likely silent failure in the whole build.
- Accept the customer data terms and opt in to enhanced conversions for leads. **OFFICIAL** (https://developers.google.com/google-ads/api/docs/conversions/upload-offline): `customer.conversion_tracking_setting.accepted_customer_data_terms` and `customer.conversion_tracking_setting.enhanced_conversions_for_leads_enabled` must both be `true` before hashed email is accepted.
- Import it as a **secondary** conversion action first. **PRACTITIONER** consensus (https://adslabsolutions.com/reduce-cac-b2b-saas-google-ads-offline-conversion/, https://noticemesenpai.com/news/google-ads-trial-signup-smart-bidding-stripe-revenue-saas/): promote to primary once volume supports it (one agency cites 30–50 imports/month), then demote the trial-signup event to secondary. Expect cost-per-lead up and cost-per-customer down, and 60–90 days of Smart Bidding recalibration during which metrics look worse.

**OFFICIAL** (https://support.google.com/google-ads/answer/7012522): "After creating a new conversion action, wait 4-6 hours before uploading conversions for that conversion action." The API equivalent is `TOO_RECENT_CONVERSION_ACTION` — "Try importing again in 6 hours."

### Step 3 — Pick the upload transport

Three transports reach the same destination. Listed cheapest-first.

**3a. No credentials at all — scheduled file upload.** **OFFICIAL** (https://support.google.com/google-ads/answer/7014069). Google Ads UI: **Goals icon → Conversions → Uploads → Schedules → +**. Sources: a linked Google Sheet, an HTTPS URL with username/password, or an SFTP URL with username/password, plus a frequency and time-of-day dropdown. No developer token, no Cloud project, no OAuth.

Exact column headers (**OFFICIAL**, verbatim):

| Column | Required |
|---|---|
| `Google Click ID` | yes — "Don't remove the column that begins with 'Google Click ID', or your import will fail." |
| `Conversion Name` | yes — must match the conversion action name exactly |
| `Conversion Time` | yes |
| `Order ID` | optional (dedupe key) |
| `Conversion Value` | optional |
| `Conversion Currency` | optional |
| `Ad User Data` | optional (consent) |
| `Ad Personalization` | optional (consent) |

The file also carries a parameters row: `Parameters:TimeZone=America/Chicago` or `Parameters:TimeZone=-0500`. Accepted `Conversion Time` formats include `MM/dd/yyyy hh:mm:ss aa`, `yyyy-MM-dd HH:mm:ss`, `yyyy-MM-ddTHH:mm:ss`, with offset (`2012-08-14 13:00:00-0500`) or named zone (`2012-08-14 13:00:00 America/Los_Angeles`).

Two **PRACTITIONER** walkthroughs build the entire architecture on this and nothing else: Blackbird PPC ("there are other set-up options that require a little dev work for manual upload; this is the quickest option to help you get started", https://www.blackbirdppc.com/blog/offline-conversion-tracking-in-google-a-set-up-guide) and Stape ("No HubSpot, no Salesforce, no Zapier, and no custom development", https://stape.io/blog/google-ads-offline-conversion-tracking-without-crm).

**3b. Programmatic — the Data Manager API.** **OFFICIAL** (https://developers.google.com/data-manager/api/reference/rest/v1/events/ingest):

```
POST https://datamanager.googleapis.com/v1/events:ingest
OAuth scope: https://www.googleapis.com/auth/datamanager
Max 2000 Event resources per request
```

Request body fields (**OFFICIAL**): `destinations[]` (required), `events[]` (required), `consent`, `validateOnly`, `encoding` (`HEX` or `BASE64`, required when sending `userData`), `encryptionInfo`. Response returns `requestId` and optional `fieldWarnings[]`.

`Destination` fields (**OFFICIAL**, https://developers.google.com/data-manager/api/reference/rest/v1/Destination): `reference`, `loginAccount`, `linkedAccount`, `operatingAccount` (required — "The account to send the data to"), `productDestinationId` (required — the conversion action). `accountType` enum values: `GOOGLE_ADS_ACCOUNT`, `GOOGLE_ANALYTICS_PROPERTY`, `FLOODLIGHT_CONFIGURATION`.

`Event` fields relevant here (**OFFICIAL**): `adIdentifiers.gclid` (also `.gbraid`, `.wbraid`, `.sessionAttributes`, `.dclid`, `.matchId`, `.impressionId`), `eventTimestamp` (required, RFC 3339 / ISO 8601 with timezone, e.g. `2025-06-10T15:07:01-05:00`), `transactionId`, `conversionValue`, `conversionCount`, `currency` (ISO 4217), `userData.userIdentifiers[].emailAddress`, `eventSource` (`WEB` | `APP` | `IN_STORE` | `PHONE` | `MESSAGE` | `OTHER`), `consent`, `cartData`, `lastUpdatedTimestamp`. `eventName` and `clientId` are required only for the Google Analytics destination.

Matching-signal rule (**OFFICIAL**, https://developers.google.com/data-manager/api/devguides/events/send-events): each event needs "at least one of the following: `adIdentifiers` with at least one of `gclid`, `gbraid` or `wbraid`, or `landingPageDeviceInfo.ipAddress` set; Session attributes; `userData`; or `eventDeviceInfo.ipAddress`". A stored gclid alone satisfies it; `userData` alone also satisfies it.

Access setup (**OFFICIAL**, https://developers.google.com/data-manager/api/devguides/quickstart/set-up-access): a Google Cloud project, a Google Account with `serviceusage.services.enable` on it, the gcloud CLI, enable the API, create an OAuth2 client or service account, generate ADC, and grant the calling email access to the Destination. **The words "developer token" do not appear on that page.** A **PRACTITIONER** source states the elimination explicitly with a comparison table: "The Data Manager API does not require a developer token. It authenticates using standard OAuth 2.0 with Google Cloud credentials" (https://almcorp.com/blog/google-ads-api-customer-match-disabled-april-2026/). No Google sentence affirmatively says "no developer token required" — the evidence is an enumerated prerequisite list that omits it.

**3c. The Google Ads API `ConversionUploadService.UploadClickConversions` — closed to us.** **OFFICIAL** (https://developers.google.com/google-ads/api/docs/conversions/upload-offline and .../upload-clicks): "Starting June 15, 2026, UploadClickConversion requests will fail if the developer token hasn't previously sent requests to upload offline conversions or enhanced conversions for leads." That date is past. The Google Ads Developer Blog announcement (2026-05-15) names the qualifying period and the error: developers who have not imported offline conversions "between December 2025 and May 2026 … will receive the error `CUSTOMER_NOT_ALLOWLISTED_FOR_THIS_FEATURE`" (quoted from a third-party verbatim mirror, https://www.googblogs.com/changes-to-offline-click-conversion-import-support-in-the-google-ads-api/ — **PRACTITIONER** transport, corroborated by the official page above). A brand-new developer token has no such history. Do not plan on this path.

There is also a fourth transport Google itself endorses: **Zapier's "Send Offline Conversion" action** (**OFFICIAL**, https://support.google.com/google-ads/answer/9838158), whose identifier dropdown offers "Google Click ID (GCLID), Email address, or Phone number", and whose only prerequisites are Google Ads account access, a conversion action with source "Import from Click", and a Zapier account. Google names the supported enhanced-conversions-for-leads paths as "Data Manager, Google Ads API, and Zapier" (**OFFICIAL**, https://support.google.com/google-ads/answer/15713840).

### Step 4 — What to put on each upload

Send **both** identifiers on every conversion. They are complementary, not alternatives — **OFFICIAL** (https://developers.google.com/google-ads/api/docs/conversions/upload-identifiers): "We recommend including GCLIDs in your import requests where possible, even if you have Google tag set up to track enhanced conversions for leads." And for the records with no gclid: "you can, and should, send _all_ relevant data for a given conversion, even if you don't have a GCLID for it."

- **gclid** — the exact stored string. Case sensitive (**OFFICIAL**: "GCLID is case sensitive, so make sure you're uploading it correctly"). A truncated value returns `UNPARSEABLE_GCLID`; **PRACTITIONER** reports the dominant cause is a too-short storage column — "GCLIDs can be lengthy strings (commonly 50-100+ characters)" (https://trueconversion.net/fix-offline-conversion-upload-errors-google-ads/). Check the column width on the stored value.
- **hashed email** — hex-encoded SHA-256 after normalization. **OFFICIAL** (https://developers.google.com/google-ads/api/docs/conversions/upload-identifiers): trim leading/trailing whitespace, lowercase, then **for `gmail.com` and `googlemail.com` only** remove periods from the local part and strip the `+` suffix. Documented example: `Jane.Doe+Shopping@googlemail.com` → `janedoe@googlemail.com` → hash. Other domains get trim + lowercase only. Only `hashed_email` and `hashed_phone_number` are accepted on a conversion upload; `address_info` is rejected. Max 5 identifiers per conversion.
- **conversion timestamp** — must carry an explicit timezone and must be after the click. Google Ads API format: `yyyy-mm-dd HH:mm:ss+|-HH:mm`. Data Manager format: ISO 8601 / RFC 3339. A timestamp preceding the click returns `CONVERSION_PRECEDES_EVENT`.
- **value + currency** — the real amount, ISO 4217 currency code. This is the point of the exercise: feeding Smart Bidding revenue rather than trial signups.
- **order_id / transactionId** — the dedupe key. **OFFICIAL**: "An order id can only be used for one conversion per conversion action." Reuse returns `ORDER_ID_ALREADY_IN_USE`; two rows in one request sharing it return `DUPLICATE_ORDER_ID`; PII in it returns `ORDER_ID_CONTAINS_PII`. Separately, the same gclid + same conversion timestamp twice returns `CLICK_CONVERSION_ALREADY_EXISTS`, and Google states uploads are de-duplicated on identifier + conversion name + date + time — so a retry is safe rather than double-counting.
- **consent** — `adUserData` / `adPersonalization`. Strongly encouraged on every upload; EEA/UK/CH handling was not researched (see Gaps).

### Step 5 — Timing rules the upload code must respect

- **Do not upload sooner than 6 hours after the click.** `TOO_RECENT_EVENT`: "The click associated with the given identifier occurred less than 6 hours ago. Retry after 6 hours have passed." (**OFFICIAL**, `conversion_upload_error.proto`). Irrelevant for a trial-to-paid conversion, relevant if the same path ever fires on a same-day upgrade.
- **Do not upload later than 90 days after the click** (63 days if the conversion is relying on the hashed-email match). See the Time windows table below.
- **PRACTITIONER**: Zapier's own doc advises "If the conversion event you're tracking can happen within 24 hours from when someone clicks the ad, add a Delay For action step."

### Step 6 — Verify

- **OFFICIAL**: "It takes about 3 hours for your imported conversion statistics to show up in your Google Ads account", and processing "typically takes less than 12 hours, but can take up to 72 hours if you use GBRAID and WBRAID-keyed conversions."
- Read the report by **conversion time**, not by click date. A conversion attributed to a click three weeks earlier will look absent on a click-date view.
- Set `partial_failure` / inspect `fieldWarnings[]` and log the per-row errors. `CLICK_NOT_FOUND` on an email-only row is explicitly a warning, not a failure — **OFFICIAL** (https://developers.google.com/google-ads/api/docs/conversions/troubleshooting): "Treat this error as a warning unless it occurs with the majority of your conversions", and those conversions "are still counted in successful event metrics."
- **PRACTITIONER** monitoring rule (https://twospouts.com/blog/offline-conversion-stack-b2b-saas-google-ads): compare weekly offline conversion volume in Google Ads against the count of records reaching that stage in the source system; investigate divergence over 20%. Named failure modes: zero/low imported conversions, conversion lag clustering at identical delays (a sign of batched rather than event-triggered upload), rejected rows from gclid expiry.

### Step 7 — The GA4 half, if wanted

GA4 reporting is a separate, optional job. Two ways to do it that do not compromise the Ads half:

1. **Same Data Manager API call, second destination.** **OFFICIAL** (https://developers.google.com/data-manager/api/devguides/events/send-events): `accountType: GOOGLE_ANALYTICS_PROPERTY` with `productDestinationId` set to the measurement ID (`G-FKDT1J0YB6`). Note the GA destination carries its own timing rule — "GA events within 72 hours; processed within 48 hours for attribution" — which the Google Ads destination does not.
2. **GA4 Measurement Protocol** — `POST https://www.google-analytics.com/mp/collect?measurement_id=G-FKDT1J0YB6&api_secret=API_SECRET`. Useful for GA4 reporting. **It will not carry the ad attribution for a conversion days after the click** (see route 1 below for exactly why). Sending it is fine; relying on it for campaign credit is not.

Everything the stored `ga_client_id` and `ga_session_id` are good for is here, not in the Ads path.

---

## 1. The answer

Build the **direct-to-Google-Ads offline conversion import keyed on the stored gclid, with the SHA-256-hashed email attached as a secondary identifier**, fired from the Stripe webhook. It requires auto-tagging on, an `UPLOAD_CLICKS` conversion action with its click-through conversion window set to 90 days **before** the clicks arrive, the customer data terms accepted, and one upload transport — either a scheduled Google Sheets/SFTP file (zero credentials) or the Data Manager API `events:ingest` (a Cloud project and an OAuth service account, no developer token). Do **not** route the Google Ads conversion through GA4: the Measurement Protocol has no gclid field and its only attribution mechanism is joining the original browser session, which Google's own 48-hour join guidance and 72-hour backdating cap close long before an hours-to-days-later webhook fires. Send the conversion to GA4 as well if GA4 reporting is wanted — as a separate destination, for reporting, not for Ads credit. The Google Ads API `UploadClickConversions` path that most older writing describes is closed to us as of 15 June 2026; use Data Manager.

---

## 2. The routes

### Route A — Google Ads offline conversion import via stored gclid

**Verdict: WORKS. This is the recommendation.**

| | |
|---|---|
| Needs from us | The stored gclid, the conversion timestamp, the amount, a dedupe key. Auto-tagging on at click time. A 90-day conversion window set in advance. |
| Identifiers | `gclid` (primary). `gbraid` / `wbraid` for iOS clicks. Hashed email as a secondary identifier on the same upload. |
| Time window | ≥6 hours and ≤90 days after the click, AND inside the conversion action's click-through window. |
| Access cost | Zero for the scheduled-file transport. A Cloud project + OAuth service account for the Data Manager API. No developer token on either. |
| Evidence | **OFFICIAL** permission statement: "You can upload any conversion with GCLID so long as it's no longer than 90 days" (https://support.google.com/google-ads/answer/10029210). **PRACTITIONER** measured production match rate of 87%, with the failures at the 90-day boundary, not at "weeks" (connercrowe.com). Multiple shipping implementations. |

Caveat worth carrying: for iOS 14+ non-consented clicks Google does **not** append a gclid at all — "The `&gclid={GCLID}` will not be appended to ad clicks" (**OFFICIAL**, https://support.google.com/google-ads/answer/10417364), `wbraid` appears instead (ad clicked inside an iOS app → your webpage). A capture implementation that reads only `gclid` stores nothing for those clicks. `gbraid` and `wbraid` cannot both be set on one conversion, and braid-keyed conversions cannot use one-per-click counting. **PRACTITIONER** claims wbraid/gbraid upload is API-only (not accepted in the UI or CSV); Google's docs are silent either way, which is consistent but not confirmation.

### Route B — Enhanced Conversions for Leads (hashed email, no gclid required)

**Verdict: WORKS as a supplement. Do not make it the only identifier.**

| | |
|---|---|
| Needs from us | SHA-256-hashed, normalized email. Account opt-in + customer data terms. |
| Identifiers | `hashed_email` / `hashed_phone_number` only. Max 5 per conversion. |
| Time window | **63 days** from click to upload — shorter than the gclid path's 90. |
| Access cost | Same transports as Route A. |
| Evidence | **OFFICIAL**: "you can, and should, send _all_ relevant data for a given conversion, even if you don't have a GCLID for it." **OFFICIAL** (Google's own ECL deck, https://services.google.com/fh/files/misc/enhanced-conversions-for-leads-intro-slides.pdf): "Import offline conversion events directly into Google Ads without having to store GCLID in your CRM." Four vendors ship email-only integrations (Adobe Advertising, DinMo, Zapier, Elevar). |

Two things qualify this. First, the Help Center's gclid rule is a conditional whose condition is **a tag, not a click ID**: "Google Click ID (GCLID): Required if you are not implementing a tag to collect user-provided data" (**OFFICIAL**, https://support.google.com/google-ads/answer/11347292). Google's intended design has the browser-side Google tag firing on the lead form with user-provided data collection enabled — that tag is what associates the hashed email with the click on Google's side. Without it, Google's own troubleshooting says "you will likely see low, or no, attribution", and a vendor (Elevar) reports the feature going "Needs Attention" for exactly this reason. Second, **one official page contradicts all the others**: the ECL implementation checklist (https://support.google.com/google-ads/answer/16782203) lists under "Match key inclusion" — "gClid: Required — PII: Required" with no conditional. It is the newest ECL artifact in the corpus and it is why this is "works as a supplement" rather than "settled".

Match quality is lossy. **PRACTITIONER**: "Typical B2B SaaS match rate: 45-65%" and coverage rising from 25–40% (gclid only) to 85–95% (gclid + ECL) (growthspreeofficial.com); a HubSpot-community rule of thumb not to expect match rates "to go over 70%".

### Route C — GA4 Measurement Protocol → GA4 key event → import into Google Ads

**Verdict: NOT VIABLE for our conversion timing. Viable only inside 48–72 hours of the click.**

This is the route the question asks about, so the evidence is worth spelling out. The negative is positive evidence about timing, not an inference from Google's silence about the mechanism.

| | |
|---|---|
| Needs from us | The stored `ga_client_id` (the middle two dot-separated segments of the `_ga` cookie, not the whole value), the ORIGINAL `ga_session_id` sent as an integer inside the event's `params` object, `engagement_time_msec`, and arrival inside Google's windows. Accounts linked, auto-tagging on, event marked as a key event. |
| Identifiers | `client_id` + `session_id`. **There is no gclid field.** |
| Time window | 48 hours from the original client-side event for a join; 72 hours max backdating via `timestamp_micros`; the GA4 session itself ends after 30 minutes of inactivity. |
| Access cost | An API secret. Trivial. |
| Evidence | Mixed, and it splits cleanly on delay. |

**Does the mechanism exist at all? Yes.** Google publishes no statement permitting or forbidding an MP-originated key event from importing into Google Ads. The only explicit MP/Google-Ads exclusion Google publishes is narrow and off-target — "App Measurement Protocol events sent to Google Analytics don't populate Search audiences in Google Ads for app users" (**OFFICIAL**), which is app streams and Search audiences. And there is first-hand affirmative testimony: on Stack Overflow 73433201 ("Conversions from Google Ads send via Measurement Protocol … are not shown on Google Ads as conversions") the original asker confirms "I also confirm that passing session_id to MP solved the issue". A second thread (77270569) resolves the same way, the bug being `session_id` sent as a string instead of an int. Both are **PRACTITIONER**.

**Does it work for OUR timing? Positive evidence says no.**

- **OFFICIAL** (https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events): "Events sent using the Measurement Protocol that are intended to be joined or processed in conjunction with events collected by … gtag.js should be received by Google Analytics within 48 hours of the original client-side event timestamp. Events received later than this may not be processed as expected, **particularly for purposes like conversion attribution**." Google names conversion attribution as the thing that breaks.
- **OFFICIAL**: `timestamp_micros` backdates at most 72 hours.
- **OFFICIAL**: a GA4 session ends after 30 minutes of inactivity, and "creating a new `session_id` creates a new session without the need to send `session_start`" — so an out-of-window hit silently spawns a new, source-less session. Google separately documents missing `session_start` as a cause of `(not set)` session source/medium.
- **PRACTITIONER**, and this is the closest thing to a controlled comparison in the entire corpus — Stack Overflow 78593388: a developer stores `client_id` and `session_id` and fires two MP events. The trial-start event attributes correctly once `session_id` is added. The subscription-payment event, sent ~7 days later **with identical code**, comes through "unassigned". Same property, same identifiers, only the delay differs.
- **OFFICIAL**: the MP payload has no `gclid` field at any level. Complete documented top-level body: `client_id` (required), `user_id`, `timestamp_micros`, `user_properties`, `user_data`, `consent`, `non_personalized_ads` (deprecated), `user_location`, `ip_override`, `device`, `user_agent`, `validation_behavior`, `events[]`; query params `api_secret` (required), `measurement_id`. The hit cannot assert the click — it can only inherit it by joining a session.
- **OFFICIAL**, and it removes the fallback: "Conversions measured by importing Google Analytics goals aren't supported for enhanced conversions" (https://support.google.com/google-ads/answer/13258081). Routing through GA4 forfeits the hashed-email rescue entirely.

Two further corrections to claims circulating in tutorials teaching this route. Putting `gclid` in the MP event params (as one widely-shared LinkedIn walkthrough instructs) does nothing — it becomes an unregistered custom event parameter. Putting the gclid **into** the `session_id` field is a misuse; `session_id` must be GA4's own numeric `ga_session_id`.

Practitioners who ship this route grade it below the direct one. A production repo running it writes that campaign attribution through the GA4 import is "best-effort" and "el camino 100 % fiable sería la subida offline de `gclid` por la API de Google Ads" (the 100% reliable path would be offline gclid upload via the Google Ads API). Stape's own staff, answering this exact webhook architecture: "Yes, this is the right approach and in the case of webhooks this is the approach most often used. But given that you have gclid — it also makes sense to send this as a conversion to Google ADS directly using the Google ADS offline tag." A SaaS-PPC agency: "For Smart Bidding optimisation, you should also import offline conversions directly into Google Ads. The two systems complement each other rather than compete."

**What nobody documents:** whether GA4's key-event attribution model — which Google states operates "across sessions" over a 90-day default lookback, and which "exclude[s] direct visits from receiving attribution credit, unless the path to key event consists entirely of direct visits" — rescues an MP key event that lands in a source-less new session by crediting the earlier Google Ads click. That is the one theoretical path by which route C could work at our delay. No source in the corpus, official or practitioner, tested it. See Gaps.

### Route D — Server-side Google Tag Manager

**Verdict: NOT AN ANSWER to this problem.**

**PRACTITIONER** (Simo Ahava, https://www.simoahava.com/analytics/google-ads-server-side-tagging-google-tag-manager/): the sGTM Google Ads conversion setup still round-trips through the browser — "the Server container sends a message that instructs the GA4 library in the browser to compose the DoubleClick request instead." With no browser at conversion time there is nothing to instruct. sGTM is relevant here only as a *host* for an offline-conversion tag that itself calls the Google Ads / Data Manager API — i.e. Route A wearing a different jacket. Stape now labels its own Google Ads API-based sGTM offline tag "an old approach" relative to Data Manager.

---

## 3. What decides it

**Fact 1 — the Measurement Protocol has no gclid field, so its only route to campaign credit is joining the original browser session, and that join is closed by 48/72-hour windows. (Google-stated.)** The complete MP payload field list is documented and contains no `gclid`, `campaign`, `source`, or `medium`. Google's own guidance says MP events intended to join gtag.js data should arrive within 48 hours, "particularly for purposes like conversion attribution", and caps `timestamp_micros` backdating at 72 hours. Our conversions fire hours-to-days after the click. This single fact eliminates GA4 as the Ads-attribution transport for us and is the answer to the question as asked.

**Fact 2 — the conversion action's click-through conversion window defaults to 30 days, maxes at 90, and changes are not retroactive. (Google-stated.)** This binds harder than the gclid's own 90-day validity and is the most likely silent failure in the whole build: a day-45 trial conversion against a default-window action is rejected with `EXPIRED_EVENT` while the gclid is perfectly good, and widening the window afterward does not recover it. Set it to 90 days before the clicks arrive.

**Fact 3 — the Google Ads API `UploadClickConversions` route is closed to new developer tokens as of 15 June 2026; Data Manager API `events:ingest` is the replacement and its documented prerequisites contain no developer token. (Google-stated for the closure; the "no developer token" reading is Google-stated by enumeration and practitioner-stated affirmatively.)** This inverts the usual objection to the direct route. Getting an approved developer token is not the gate — it would not even open this door. What it means practically: most writing about this architecture, including implementations and tutorials from before mid-2026, targets an API surface a new integration cannot use.

**Undocumented, and named so it is not mistaken for a fact:** whether GA4's cross-session key-event attribution model credits an MP-originated key event to an earlier Google Ads click when the MP hit lands outside the session-join window. Nobody tested it. It is the only remaining way route C could work at our timing.

---

## 4. Time windows

Our conversions happen days-to-weeks after the click, so this table decides the design.

| Window | Value | Measured from → to | Route | Source |
|---|---|---|---|---|
| gclid retention / upload deadline | **90 days** | click → upload | A | **OFFICIAL** "We only keep the GCLID for 90 days" (answer/13321563); "You can upload any conversion with GCLID so long as it's no longer than 90 days" (answer/10029210) |
| Enhanced-conversions-for-leads upload deadline | **63 days** | click → upload | B | **OFFICIAL** "Offline conversions for enhanced conversion leads that were uploaded more than 63 days after the associated last click won't be imported" (answer/15081888) |
| Click-through conversion window (the conversion action's own setting) | **default 30, settable 1–90** | click → conversion | A, B | **OFFICIAL** answer/3123169. Not retroactive. Exceeding it → `EXPIRED_EVENT` |
| Minimum delay after click | **6 hours** | click → upload | A, B | **OFFICIAL** `TOO_RECENT_EVENT` in `conversion_upload_error.proto`; restated in answer/13321563 |
| Minimum delay after creating a conversion action | **4–6 hours** | action created → first upload | A, B | **OFFICIAL** answer/7012522; `TOO_RECENT_CONVERSION_ACTION` |
| MP join with gtag.js data | **48 hours** | original client-side event → MP hit received | C | **OFFICIAL** sending-events guide. Names "conversion attribution" as what breaks past it |
| MP backdating via `timestamp_micros` | **72 hours** | event time → now | C | **OFFICIAL** MP reference |
| MP session_id geo/device join | **24 hours** | session **start** → MP hit received | C | **OFFICIAL** MP overview. Scoped in writing to geo/device only |
| GA4 session inactivity timeout | **30 minutes** | last activity → session end | C | **OFFICIAL** answer/9191807 |
| Data Manager API — GA destination | **72h event age, 48h to process for attribution** | event → ingest | C-adjacent | **OFFICIAL** send-events guide. Explicitly the GA destination; the Google Ads destination has no such rule |
| GA4 key event lookback | **90 days** default (30/60 selectable); 30 for acquisition events | touchpoint → key event | C | **OFFICIAL** answer/16291704 |
| Data Manager scheduled-connector lookback | **90 days** (GCS, S3, HTTP, SFTP, Sheets) / **14 days** (BigQuery, Redshift, Snowflake, MySQL, PostgreSQL, Salesforce, HubSpot) | per run | A, B | **OFFICIAL** answer/7012522 |
| Imported conversions visible in reports | **~3 hours**, full processing 12h (72h for braid-keyed) | upload → reporting | A, B | **OFFICIAL** answer/15081888, answer/13321563 |

Reading this for our case: a trial that converts on day 20 is comfortable everywhere on the Route A rows and impossible on every Route C row. A trial converting past day 90 has no attribution path at all — **PRACTITIONER** sources are unanimous that nothing recovers it, and Google's own advice is to upload a **different, earlier** conversion event that lands inside 90 days instead.

---

## 5. Event naming

Relevant only if a GA4 event is sent alongside the Ads upload.

### The rules, verbatim

**OFFICIAL** (https://support.google.com/analytics/answer/13316687):

> "Event names must start with a letter. Use only letters, numbers, and underscores. Don't use spaces."
> "Event names are case sensitive. For example, `my_event` and `My_Event` are distinct events."
> "Event names can include English and non-English words and letters."
> "Do not use reserved prefixes and event names."

**OFFICIAL** (https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference/events): "When creating custom event names, you must: (1) Follow the Event naming rules. (2) Avoid Reserved names and prefixes. (3) Stay within the Event collection limits, such as the 40-character limit for event and parameter names."

Limits (**OFFICIAL**): event names ≤40 chars, parameter names ≤40, parameter values ≤100 (500 on 360), user property names ≤24, values ≤36, 25 events per request, 25 parameters per event, 25 user properties per event, body <130kB. An over-40-char name specifically breaks key-event reporting: "If you mark an event as a key event and the event exceeds 40 characters, then the event will not be reported as a key event" (answer/9267744). There is no limit on distinct event names for **web** data streams (the 500 cap is app streams).

### Reserved event names, verbatim

**Web** (**OFFICIAL**, answer/13316687): `ad_impression`, `app_remove`, `app_store_refund`, `app_store_subscription_cancel`, `app_store_subscription_renew`, `click`, `error`, `file_download`, `first_open`, `first_visit`, `form_start`, `form_submit`, `in_app_purchase`, `page_view`, `scroll`, `session_start`, `user_engagement`, `view_complete`, `video_progress`, `video_start`, `view_search_results`.

**Mobile/app**: `ad_activeview`, `ad_click`, `ad_exposure`, `ad_query`, `ad_reward`, `adunit_exposure`, `app_clear_data`, `app_exception`, `app_install`, `app_remove`, `app_store_refund`, `app_update`, `app_upgrade`, `dynamic_link_app_open`, `dynamic_link_app_update`, `dynamic_link_first_open`, `error`, `firebase_campaign`, `firebase_in_app_message_action`, `firebase_in_app_message_dismiss`, `firebase_in_app_message_impression`, `first_open`, `first_visit`, `notification_dismiss`, `notification_foreground`, `notification_open`, `notification_receive`, `notification_send`, `os_update`, `session_start`, `user_engagement`.

**OFFICIAL** MP reference: "`ad_impression`, `in_app_purchase` and `screen_view` events are only allowed for App streams."

### Reserved prefixes, verbatim

**Event-name prefix (web)** — the naming-rules page lists exactly one, with no explanation: "The following prefix is reserved and cannot be used: `query_id`".

**Event-parameter name prefixes** (**OFFICIAL**, MP reference): "Parameter names cannot begin with: `_` (underscore), `firebase_`, `ga_`, `google_`, `gtag.`"

**User-property name prefixes** (**OFFICIAL**, note `gtag.` is absent here): "User property names cannot begin with: `_` (underscore), `firebase_`, `ga_`, `google_`"

Reserved parameter name: `firebase_conversion`. Reserved user property names: `first_open_time`, `first_visit_time`, `last_deep_link_referrer`, `user_id`, `first_open_after_install`.

Consequence worth noting for our stored fields: a parameter named `ga_client_id` or `google_click_id` would be **rejected** by the prefix rules. `gclid` and `client_id`-style names are not.

### Is camelCase legal?

**Yes.** The rule is "start with a letter, only letters, numbers, and underscores" — uppercase letters are letters. **OFFICIAL** corroboration from an unexpected place: the validation server's documented `NAME_INVALID` example uses a camelCase name and blames only the leading underscore —

> `"Event at index: [0] has invalid name [_badEventName]. Names must start with an alphabetic character."`

Google chose a camelCase string to illustrate a different failure. The complete `ValidationCode` enum is `VALUE_INVALID`, `VALUE_REQUIRED`, `NAME_INVALID`, `NAME_RESERVED`, `VALUE_OUT_OF_BOUNDS`, `EXCEEDED_MAX_ENTITIES`, `NAME_DUPLICATED` — no code and no code description references case.

Legal is not advisable. Names are case sensitive with no normalization, so `subscriptionPaid` and `subscription_paid` are two permanently separate events that can never be merged, and whichever exact string is sent is the one that must be marked as a key event. Every **PRACTITIONER** source says snake_case, and every Google recommended and auto-collected event is snake_case. One practitioner GA4 audit query is precise about the distinction, bucketing `NOT REGEXP_CONTAINS(event_name, r'^[a-zA-Z][a-zA-Z0-9_]*$')` as `invalid_characters` and `event_name != LOWER(event_name)` separately as `mixed_case_warning`.

Validation endpoint: `https://www.google-analytics.com/debug/mp/collect` (EU: `https://region1.google-analytics.com/debug/mp/collect`). The production endpoint returns 2xx regardless of whether the event was accepted — **OFFICIAL**: "The Google Analytics Measurement Protocol does not return `HTTP` error codes, even if an event is malformed or missing required parameters."

### Marking an event server-originated

**No convention exists.** Not a prefix, not a suffix, not a parameter, not a field, not a report dimension — from Google or from practitioners. Seven practitioner sources consulted specifically on this question returned no recommendation; one states it outright: "there's no separate naming convention specified for server-side versus Measurement Protocol events."

The invisibility is by design. **OFFICIAL**: "The intent of the Measurement Protocol is to augment automatic collection through gtag, Tag Manager, and Google Analytics for Firebase, not to replace it." An MP event sent to a web stream carries that stream's `stream_id` and `platform = WEB` in the BigQuery export — identical to a gtag event. The BigQuery schema's origin-adjacent fields are `stream_id`, `platform`, and `event_server_timestamp_offset`; none identifies MP origination.

The options, then, are all house conventions:

1. **A distinct event name.** Costs nothing on web streams (no distinct-name quota) and is trivially filterable. The obvious form is a name for what happened that no client-side tag emits — the practitioner-standard shape is `<object>_<action>`, e.g. `subscription_paid`. Note that if the goal were a GA4 key event importable into Google Ads, a distinct name is also what makes it markable independently of client-side `purchase`.
2. **A custom event parameter** (e.g. `source: "server"`), registered as an event-scoped custom dimension to become reportable. Limits: 50 event-scoped custom dimensions on a standard property, 125 on 360, and a 24–48 hour processing delay before it appears in reports. Nobody documents whether GA4 backfills a newly-registered dimension onto events collected before registration.
3. **`debug_mode: 1`** as a parameter routes MP events into DebugView — **PRACTITIONER** (Simo Ahava, corroborated on Stack Overflow); Google's own DebugView page documents `debug_mode` for gtag and GTM only and never mentions the MP. Good for isolating server events during testing. **Do not adopt as a permanent marker**: nobody documents whether debug-flagged events are excluded from standard reports, and if they are it would silently drop the conversions out of key-event counts.
4. **A separate data stream** — not a real separation. A stream is identified by its `measurement_id`, but the join of MP data to existing user/session/attribution data runs on `client_id` within the property. Google's server-side-tagging fundamentals recommends a separate *property* only for parallel testing, not for production separation.

If the same conversion could ever fire both client-side and server-side, the practitioner answer is **deduplication by a shared `transaction_id`, with identical event and parameter names** — not by giving the server event a different name.

---

## 6. Gaps

Questions neither Google nor practitioners answer. Each names what would settle it.

1. **Does GA4's cross-session key-event attribution model rescue an MP key event that lands outside the session-join window?** Google states event-scoped Source/Medium for key events "reflect the selected attribution model across sessions" over a 90-day lookback and that models "exclude direct visits from receiving attribution credit, unless the path to key event consists entirely of direct visits." Mechanically that should credit the earlier Google Ads click. Nobody tested it for an MP-originated key event. **Settled by:** sending one MP key event with a stored `client_id` 5+ days after a known ad click and checking whether the Google Ads conversions column credits the campaign, versus the same event inside 48 hours.
2. **Nobody has ever published a controlled measurement of route C.** Across the whole corpus there is no screenshot, no campaign-level number, no before/after showing an MP-originated key event in the Google Ads conversions column. The affirmative case is two people's testimony in one Stack Overflow thread. A user asking exactly this on Google's own Analytics support forum (thread 340217633) received no reply from anyone.
3. **The 48-hour join window and the 90-day key-event lookback are never reconciled** by any source, official or practitioner. Which governs a conversion that fires on day 5 is undocumented.
4. **Does the Data Manager API enforce the 90-day / 63-day / 6-hour Google Ads gates?** The only timing rule its docs state is the Google Analytics destination's 72h/48h. The 90/63/6 figures come from Google Ads Help and the Google Ads API error enum. Same backend, almost certainly the same rules — but not documented. **Settled by:** one `validateOnly: true` ingest of a deliberately 100-day-old click.
5. **Does the Data Manager API have its own adoption/allowlisting gate** analogous to the Google Ads API's `CUSTOMER_NOT_ALLOWLISTED_FOR_THIS_FEATURE` cutoff? It is presented as the open replacement; no doc states eligibility requirements. **Settled by:** creating the Cloud project and making one `validateOnly` call.
6. **Conflict on the required conversion action type for the Data Manager path.** The Data Manager send-events guide describes `productDestinationId` as "The ID of a Google Ads conversion with type set to `WEBPAGE`", while the Google Ads API ECL doc requires type `UPLOAD_CLICKS`. Unresolved. **Settled by:** one `validateOnly` ingest against an `UPLOAD_CLICKS` action.
7. **Does widening a conversion action's click-through window from 30 to 90 days help a click that already occurred?** Google says "any changes apply to all conversions going forward", which does not say whether an old click plus a future conversion is evaluated against the new window or the one in force at click time. One practitioner source claims it is retroactive; Google's own page contradicts that. **Assume not retroactive and set 90 days now.**
8. **Does a hashed-email upload match when the browser-side user-provided-data tag never fired and there is no gclid?** Google's Help Center conditional implies not; the signed-in-Google-Accounts matching statement implies it might. This is exactly the case for records where the gclid was never captured. **Settled by:** uploading a batch of email-only conversions for known ad-click customers and reading the `CLICK_NOT_FOUND` rate.
9. **The `query_id` reserved event-name prefix** is stated verbatim on Google's naming-rules page and explained nowhere. No practitioner source mentions it.
10. **Are `firebase_`, `google_`, `ga_` reserved as EVENT-name prefixes**, or only as parameter and user-property prefixes? Google lists them only under the latter two. The classic Firebase SDK sentence reserving them for event names could not be retrieved. Treat them as unsafe event-name prefixes.
11. **Are `debug_mode` events excluded from standard GA4 reports?** Decides whether `debug_mode` is usable as a permanent server-origin marker or would silently drop conversions from key-event counts.
12. **Does GA4 backfill a newly-registered event-scoped custom dimension onto historical events?** Undocumented.
13. **EEA/UK/CH consent handling on uploaded conversions** was not researched. Both APIs accept a `consent` object with `adUserData` / `adPersonalization`; what happens to an upload without granted consent is unexamined. `user_ip_address` is allowlist-only and explicitly unusable for EEA/UK/CH users.
14. **Conversion adjustments** (restate the value on an upgrade, retract on churn) were researched only through a vendor blog, which cites a ~55-day restatement limit. The official `ConversionAdjustmentUploadService` docs were not read, and whether adjustments have migrated to the Data Manager API alongside conversion uploads is unconfirmed.
15. **What share of our clicks arrive with `wbraid` instead of `gclid`?** No official figure exists; practitioner estimates use Safari's browser share as a proxy, which is not the same measurement. **Settled by:** counting stored records with a populated gclid against total signups from paid clicks.
16. **Reattribution when a stored gclid is older than a more recent click by the same user.** Google's 90-day rule is worded "after the associated **last** click", implying last-click governs, but no source states what happens when you upload an older stored gclid for a user who has since clicked another ad.

Two research-method gaps that limit confidence in the practitioner half of this report: the session's WebSearch budget was exhausted before most of the research ran, so discovery went through search-result-page fetches, several of which CAPTCHA'd; and reddit.com was unreachable throughout, so no r/PPC failure reports were read in full — the two Reddit citations in the corpus rest on search-result snippets only.

---

## 7. Sources

### Official — Google Ads

| URL | Fetched | What it gives |
|---|---|---|
| https://support.google.com/google-ads/answer/10029210 | OK | "You can upload any conversion with GCLID so long as it's no longer than 90 days"; 63-day ECL figure |
| https://support.google.com/google-ads/answer/15081888 | OK | 90-day and 63-day upload deadlines; dedupe rule; ~3h reporting lag |
| https://support.google.com/google-ads/answer/13321563 | OK | "We only keep the GCLID for 90 days"; 6-hour rule; 72h braid processing delay |
| https://support.google.com/google-ads/answer/7012522 | OK | Auto-tagging prerequisite; 4–6h wait; per-source 90/14-day lookbacks; GCLID case sensitivity |
| https://support.google.com/google-ads/answer/7014069 | OK | Scheduled/manual file import; exact column headers; `Parameters:TimeZone`; accepted time formats |
| https://support.google.com/google-ads/answer/3123169 | OK | Conversion windows: default 30, range 1–90, not retroactive |
| https://support.google.com/google-ads/answer/2998031 | OK | Offline conversion import overview; steer toward ECL; June 15 2026 migration statement |
| https://support.google.com/google-ads/answer/11347292 | OK | ECL via GTM; "GCLID: Required if you are not implementing a tag"; signed-in-account matching |
| https://support.google.com/google-ads/answer/11021502 | OK | ECL with the Google tag; hex SHA-256; E.164 phone rule |
| https://support.google.com/google-ads/answer/15713840 | OK | "supported in Data Manager, Google Ads API, and Zapier" |
| https://support.google.com/google-ads/answer/16782203 | OK | ECL implementation checklist — the page that says "gClid: Required" with no conditional |
| https://support.google.com/google-ads/answer/15249267 | OK | ECL diagnostics; "import all your events that have user-provided data, even if they don't have a GCLID" |
| https://support.google.com/google-ads/answer/9838158 | OK | Zapier Send Offline Conversion; gclid-or-lead-data either/or |
| https://support.google.com/google-ads/answer/2375435 | OK | Create conversions from GA events; prerequisites; silent on the Measurement Protocol |
| https://support.google.com/google-ads/answer/13258081 | OK (resolved to the web article) | "Conversions measured by importing Google Analytics goals aren't supported for enhanced conversions" |
| https://support.google.com/google-ads/answer/3095550 | OK | Auto-tagging appends the GCLID; required for offline conversion tracking |
| https://support.google.com/google-ads/answer/10417364 | OK | iOS 14: gclid not appended; wbraid/gbraid |
| https://support.google.com/google-ads/answer/9888656 | OK | Enhanced conversions overview |
| https://support.google.com/google-ads/answer/6386790 | OK | Transaction ID / duplicate prevention |
| https://support.google.com/google-ads/troubleshooter/16664541 | OK | ECL diagnostics troubleshooter alerts |
| https://services.google.com/fh/files/misc/enhanced-conversions-for-leads-intro-slides.pdf | OK (text extracted) | "without having to store GCLID in your CRM"; ECL prerequisites; verification GAQL |
| https://support.google.com/google-ads/answer/9744275 | OK | GCLID glossary — thin |
| https://support.google.com/google-ads/answer/10974651 | 404 | — |
| https://support.google.com/google-ads/answer/12103138 | 404 | — |
| https://support.google.com/google-ads/answer/14200782 | 404 | — |

### Official — Google Ads API / Data Manager API

| URL | Fetched | What it gives |
|---|---|---|
| https://developers.google.com/google-ads/api/docs/conversions/upload-clicks | OK | `UploadClickConversions`; ClickConversion fields; June 15 2026 restriction; `UPLOAD_CLICKS` requirement |
| https://developers.google.com/google-ads/api/docs/conversions/upload-offline | OK | ECL account flags; June 15 2026 restriction |
| https://developers.google.com/google-ads/api/docs/conversions/enhanced-conversions/leads | OK | "even if you don't have a GCLID for it"; matching-to-website-data statement |
| https://developers.google.com/google-ads/api/docs/conversions/upload-identifiers | OK | UserIdentifier oneof; SHA-256 normalization incl. the gmail/googlemail example |
| https://developers.google.com/google-ads/api/docs/conversions/troubleshooting | OK | `CLICK_NOT_FOUND` is a warning; tag-not-firing cause |
| https://raw.githubusercontent.com/googleapis/googleapis/.../conversion_upload_service.proto | OK (raw) | Verbatim ClickConversion field names |
| https://raw.githubusercontent.com/googleapis/googleapis/.../conversion_upload_error.proto | OK (raw) | Verbatim `EXPIRED_EVENT`, `TOO_RECENT_EVENT`, `CONVERSION_PRECEDES_EVENT`, `EVENT_NOT_FOUND`, order-ID and braid errors |
| https://developers.google.com/data-manager/api | OK | Data Manager overview |
| https://developers.google.com/data-manager/api/reference/rest/v1/events/ingest | OK | Endpoint, scope, 2000-event cap, Event fields |
| https://developers.google.com/data-manager/api/devguides/events/send-events | OK | Destination shape, matching-signal rule, hashing/encoding, GA 72h/48h note |
| https://developers.google.com/data-manager/api/reference/rest/v1/Destination | OK | `operatingAccount`, `loginAccount`, `productDestinationId`, accountType enum |
| https://developers.google.com/data-manager/api/reference/rest/v1/UserData | OK | Per-field SHA-256 / normalization spec |
| https://developers.google.com/data-manager/api/devguides/quickstart/set-up-access | OK | Full prerequisite list — no developer token in it |
| https://developers.google.com/google-ads/api/docs/get-started/dev-token | OK | 22-char token, manager account, immediate Explorer-vs-Pending outcome |
| https://developers.google.com/google-ads/api/docs/access-levels | OK | Explorer 2,880 ops/day; Basic 5 business days; Standard 10 |
| https://developers.google.com/google-ads/api/docs/api-policy/rmf | OK | RMF applies only to Standard; self-use exempt |
| https://developers.google.com/google-ads/api/docs/oauth/service-accounts | OK | Service account support; 20-account limit |
| https://developers.google.com/google-ads/api/docs/concepts/call-structure | OK | `developer-token`, `login-customer-id` headers |
| https://developers.google.com/tag-platform/tag-manager/server-side/ads-setup | OK | sGTM Google Ads conversion tag; `user_data` parameter name |
| https://ads-developers.googleblog.com/2026/05/changes-to-offline-click-conversion.html | Partial (index shell) | The May 2026 announcement |
| https://developers.google.com/data-manager/api/get-started | 404 | — |
| https://developers.google.com/google-ads/api/reference/rpc/v21/ClickConversion | Nav shell only | Substituted the raw .proto |

### Official — Google Analytics

| URL | Fetched | What it gives |
|---|---|---|
| https://developers.google.com/analytics/devguides/collection/protocol/ga4 | OK | "augment … not to replace"; client_id join is geo/device + GBRAID/WBRAID; 24h session_id rule |
| https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events | OK | Endpoint; **48-hour join window**; 72h backdating; limits; app Search-audience exclusion |
| https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference | OK | Complete top-level payload field list — no gclid |
| https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference/events | OK | Custom event name requirements; `campaign_details` (BigQuery-only) |
| https://developers.google.com/analytics/devguides/collection/protocol/ga4/validating-events | OK | `debug/mp/collect`; `_badEventName` example; ValidationCode enum; no HTTP error codes |
| https://developers.google.com/analytics/devguides/collection/ga4/uid-data | OK | MP `user_data` subfields and hashing |
| https://support.google.com/analytics/answer/9900444 | OK | "(not set) / (not set) … send the `session_id` parameter" |
| https://support.google.com/analytics/answer/13316687 | OK | Event naming rules; reserved names; `query_id` prefix |
| https://support.google.com/analytics/answer/9267744 | OK | 40-char limit breaks key-event reporting; no distinct-name cap on web streams |
| https://support.google.com/analytics/answer/9191807 | OK | 30-minute session timeout; `session_start` carries gclid/UTM/referrer |
| https://support.google.com/analytics/answer/11080067 | OK | Traffic-source scopes; non-key events are "(not set)" |
| https://support.google.com/analytics/answer/10596866 | OK | Key events are the source for Ads-shared conversions; direct excluded from credit |
| https://support.google.com/analytics/answer/10597962 | OK | Attribution settings; cross-session event scope |
| https://support.google.com/analytics/answer/16291704 | OK | Key-event lookback: 90-day default |
| https://support.google.com/analytics/answer/13504892 | OK | Missing `session_start` as a cause of "(not set)" source/medium |
| https://support.google.com/analytics/answer/10632359 | OK | Prerequisites for GA4→Ads conversion creation |
| https://support.google.com/analytics/answer/7029846 | OK | BigQuery schema; no MP-origin field; `collected_traffic_source.gclid` |
| https://support.google.com/analytics/answer/10075209 | OK | Event-scoped custom dimensions; 50/125 limits; 24–48h delay |
| https://support.google.com/analytics/answer/7201382 | OK | DebugView — `debug_mode` for gtag/GTM only, MP unmentioned |
| https://support.google.com/analytics/answer/11367152 | OK | iOS14+ consent and gclid |
| https://developers.google.com/tag-platform/gtagjs/reference | OK | `gtag('get', …)` retrievable fields: client_id, session_id, session_number, gclid |
| https://developers.google.com/analytics/devguides/collection/protocol/ga4/troubleshooting | OK | Contains no attribution guidance at all |
| https://developers.google.com/analytics/devguides/collection/protocol/ga4/limitations | 404 | No such page; constraints are split across the overview and sending-events |
| https://support.google.com/analytics/thread/340217633 | OK | User reports MP key events not reaching Ads — **no reply from Google, thread locked** |
| https://support.google.com/analytics/thread/296359732 | OK | MP with all four params, still "(not set)" |
| https://support.google.com/analytics/thread/381061256 | OK | Server-side source/medium degrading to "not set"; locked, unresolved |

### Practitioner — most load-bearing

| URL | Fetched | What it gives |
|---|---|---|
| https://connercrowe.com/blog/closed-won-webhook-hubspot-google-ads-offline-conversions/ | OK | **The only measured match rate in the corpus: 87%**, failures at the 90-day boundary |
| https://stackoverflow.com/questions/73433201/... | OK (via reader proxy) | Asker confirms `session_id` made an MP-originated key event appear in Google Ads |
| https://stackoverflow.com/questions/77270569/... | OK (via reader proxy) | `session_id` must be an int, not a string |
| https://stackoverflow.com/questions/78593388/... | OK (via reader proxy) | **The delayed case failing**: same code, day-7 event lands "unassigned" |
| https://community.stape.io/t/webhook-to-ga4-and-import-conversion-for-google-ads/3201 | OK | Vendor staff on this exact architecture: also send straight to Google Ads |
| https://www.simoahava.com/analytics/session-attribution-with-ga4-measurement-protocol/ | OK | The canonical MP session-join demonstration; "Events do not inherit properties from 'the session'" |
| https://www.codewords.ai/templates/stripe-checkout-google-ads-conversion | OK | Stripe webhook → stored gclid → Google Ads; closest analog |
| https://twospouts.com/blog/google-ads-offline-conversion-crm-b2b-saas | OK | The four-component chain; gclid stored at submission, not computed later |
| https://twospouts.com/blog/offline-conversion-stack-b2b-saas-google-ads | OK | Four transports with tradeoffs; monitoring rule |
| https://www.growthspreeofficial.com/blogs/gclid-expiration-b2b-saas-90-day-attribution-fix | OK | Stage-by-stage day-range table; day 7–45 "Within window" |
| https://www.growthspreeofficial.com/blogs/enhanced-conversions-for-leads-value-based-bidding-b2b-saas | OK | B2B SaaS ECL match rates 45–65%; coverage 25–40% → 85–95% |
| https://www.blackbirdppc.com/blog/offline-conversion-tracking-in-google-a-set-up-guide | OK | No-code Sheets architecture with client outcomes |
| https://stape.io/blog/google-ads-offline-conversion-tracking-without-crm | OK | Sheets-only architecture, dated 2026-07-28 |
| https://stape.io/blog/google-ads-offline-conversion-using-server-gtm | OK | Calls its own Google Ads API sGTM tag "an old approach" |
| https://almcorp.com/blog/google-ads-api-customer-match-disabled-april-2026/ | OK | "The Data Manager API does not require a developer token" |
| https://www.googblogs.com/changes-to-offline-click-conversion-import-support-in-the-google-ads-api/ | OK | Verbatim mirror of the May 2026 announcement; `CUSTOMER_NOT_ALLOWLISTED_FOR_THIS_FEATURE` |
| https://www.bounteous.com/insights/2025/12/05/ga4-attribution-issues-explained-not-set-unassigned-and-more/ | OK | New `session_id` → new session, usually source-less |
| https://www.uprawmedia.com/blog/ga4-offline-conversion-setup | OK | SaaS PPC: "you should also import offline conversions directly into Google Ads" |
| https://www.simoahava.com/analytics/google-ads-server-side-tagging-google-tag-manager/ | OK | sGTM Google Ads conversions still round-trip through the browser |
| https://trueconversion.net/fix-offline-conversion-upload-errors-google-ads/ | OK | gclid truncation as the dominant `UNPARSEABLE_GCLID` cause |
| https://trueconversion.net/wbraid-gbraid-google-click-ids-explained/ | OK | wbraid upload is API-only (Google is silent on this) |
| https://github.com/stellamansedouard-create/voxstel | OK (raw) | Chose GA4 MP over the Ads API because of developer-token friction; fires on the Stripe webhook |
| https://github.com/alvarotrigo/webbodas | OK (raw) | Runs both; grades the GA4-import path "best-effort" vs gclid upload as "el camino 100 % fiable" |
| https://github.com/andredezzy/maccing | OK (raw) | UserAttribution record → MP `sign_up` / `purchase` → GA4 → Ads; "gclid is NOT a GA4 MP field" |
| https://github.com/zwhitchcox/hitchcoxaesthetics.com | OK (raw) | Enforces the 72-hour MP window as a hard guard |
| https://experienceleague.adobe.com/.../google-enhanced-conversions-leads | OK | Shipped ECL integration built for "click IDs are unavailable" |
| https://www.dinmo.com/third-party-cookies/solutions/conversions-api/google-ads/ | OK | "GCLid does not need to be transmitted for leads" |
| https://docs.getelevar.com/docs/how-to-setup-enhanced-conversions-for-leads-for-google-ads | OK | "Google now requires a web tag to transmit submitted user data" |
| https://zapier.com/blog/track-offline-conversions-google-ads-zapier/ | OK | "Instead of GCLID, Google matches … using the customer's hashed email address" |
| https://measureschool.com/enhanced-conversions-for-leads/ | OK | Full ECL tutorial incl. Sheets hashing + scheduled upload |
| https://aelmgren.com/guides/server-side/measurement-protocol-offline-conversions | OK | `_ga` cookie: strip the `GA1.1` prefix |
| https://trackingchef.com/google-analytics/how-to-add-session-id-to-ga4-measurement-protocol-events/ | OK | `session_id` belongs in event `params`, not the body top level |
| https://aelmgren.com/guides/ga4/ga4-event-naming-cheat-sheet | OK | snake_case convention; "no separate naming convention … for server-side" |
| https://www.analyticsmania.com/post/google-analytics-and-google-tag-manager-naming-conventions/ | OK | snake_case convention |
| https://github.com/cognyai/claude-code-marketing-skills | OK (raw) | Audit query separating `invalid_characters` from `mixed_case_warning` |
| https://sweetcode.com/blog/ga4-mp-session-id-purchase-event-bug | OK | April 2024: GA4 silently dropped MP purchase events containing `session_id` |
| https://www.reddit.com/r/PPC/ (all threads) | **BLOCKED** | Unreachable from this environment; two citations rest on search snippets only |
| https://community.hubspot.com/t/expired-gclid-.../134794 | 403 | Would have corroborated short-window expiry errors |
| https://ppcpanos.com/native-google-ads-conversions-vs-importing-ga4-key-events/ | 403 | Title indicates a direct native-vs-GA4-import comparison |
