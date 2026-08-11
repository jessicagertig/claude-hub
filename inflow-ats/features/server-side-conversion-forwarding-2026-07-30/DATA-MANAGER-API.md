# Google Data Manager API — server-to-server conversion forwarding

Discovery research, 2026-07-30. Sources labelled OFFICIAL (google.com / googleapis.com) or PRACTITIONER.
Field names and enum values below were verified against the live discovery document
`https://datamanager.googleapis.com/$discovery/rest?version=v1`, revision `20260729`.

---

## 1. Can we use it

Yes, and the access gate is open. **The Data Manager API is generally available, is not allowlist-gated for
our use case, and does not require a Google Ads developer token** — so the 15 June 2026 developer-token
closure does not block this path. Google's own migration guide states verbatim: *"The Data Manager API doesn't
require a developer token, and you specify login and linked customer information using fields of a
`Destination` instead of request headers."* I confirmed this structurally rather than editorially: grepping the
full 195 KB discovery document for `developerToken`, `developer-token`, `loginCustomerId` and
`login-customer-id` returns **zero hits** — there is no field, header, or global parameter anywhere in the API
that could carry a developer token. Google now actively pushes migrations toward it, banner on the old Google
Ads API page: *"Starting June 15, 2026, UploadClickConversion requests will fail if the developer token hasn't
previously sent requests to upload offline conversions or enhanced conversions for leads. **Use the Data
Manager API instead.**"*

A conversion 14–30 days after the click is squarely inside the supported envelope. Offline upload is the
entire point of the `UPLOAD_CLICKS` path; there is no browser requirement and no short recency limit on the
Google Ads destination. The pipeline is one authenticated `POST` from the Stripe webhook plus one optional
status poll — no CSV, no Sheets, no human step.

**On allowlisting, precisely:** the discovery document contains exactly **one** occurrence of the word
"allowlist", and it is attached to `adEvents.ingest` (*"Uploads a list of AdEvent resources to Google
Analytics. This feature is only available to accounts on an allowlist."*) — a method we do not use.
`events.ingest`, the conversion method, carries no such note. Allowlists elsewhere in the docs apply only to
Google Ads **store sales** conversions and Google Analytics **multi-source** events. The "approval process"
and "interest form" language on Google's setup and support pages appears only under the **Data Partner** tabs;
an advertiser sending its own conversions to its own Google Ads account is entirely self-serve.

**The one thing that will silently break this** is not access — it is the conversion action's click-through
conversion window, which defaults to 30 days and is **not retroactive**. See §4.

---

## 2. One-time setup

Every step below is performed by hand, once. Nothing here recurs.

### 2a. Google Cloud

1. Create or select a Google Cloud project.
2. Confirm your Google Account holds `serviceusage.services.enable` on it. Either `roles/owner` or
   `roles/serviceusage.serviceUsageAdmin` includes that permission.
3. Enable the **Data Manager API** (`datamanager.googleapis.com`). Self-serve button at
   `https://developers.google.com/data-manager/api/devguides/quickstart/set-up-access`, or the Cloud console
   library page `https://console.cloud.google.com/apis/library/datamanager.googleapis.com`. There is no
   request form and no approval step.
4. Create a **service account** and note its email address. Do **not** set up domain-wide delegation and do
   **not** create an OAuth consent screen — neither is needed on the service-account path, and Google states
   verbatim: *"Google OAuth verification isn't required for service accounts."* (The user-credential path
   drags in OAuth verification because `datamanager` is a sensitive scope; the service-account path skips it.)
5. Grant the service account `roles/serviceusage.serviceUsageConsumer` on the project. This carries
   `serviceusage.services.use`, which is what permits it to send API requests billed to the project.

### 2b. Google Ads — grant access

6. Sign in to Google Ads as an administrator. Go to **Admin** → **Access and security** → **Users** tab.
7. Click the **+** button, type the service account's email into the **Email** input box, select access level
   **Standard**, and click **Add account**.
   - Standard is the minimum. The `Destination` reference states verbatim: *"To add or remove data from the
     `operating_account`, this `login_account` must have **write access** to the `operating_account`."*
     Read-only cannot edit and will fail.
   - Note: *"By default, you cannot grant administrator access to a service account."* Admin is not needed;
     Standard is directly grantable.
8. Verify it took: **Admin** → **Access and security** → **Users**. On a manager account, turn **off** the
   **Show users in full hierarchy** toggle first, then confirm the service account email is listed.

### 2c. Google Ads — create the conversion action

9. Click the **Goals** menu, then **Summary**.
10. Select **+ Create conversion action**.
11. Check **Conversions offline**.
12. Select **Add data source**, then **Continue**.
13. Choose **CRMs, files, or other data sources**, then **Track conversions from clicks**.
    - This is what produces a conversion action of type `UPLOAD_CLICKS`. Verbatim from the Data Manager guide:
      *"For Google Ads offline conversions or enhanced conversions for leads, the `productDestinationId` must
      be the ID of a Google Ads conversion action with type set to `UPLOAD_CLICKS`. In the Google Ads UI, the
      Conversion source for an `UPLOAD_CLICKS` conversion action is **Website (Import from clicks)**."*
    - Older label chain still present in some accounts: **Goals** → **Conversions** → **Summary** → **New
      conversion action** → **Import** → **CRM/files/other data sources** → **Track conversions from clicks**.
14. When offered a connection source, choose **Skip this step and set up a data source later**. The API
    pushes events; no scheduled data-source connection is involved.
15. Select **Continue**. Choose a **Conversion goal** — the category matching a paid subscription start is
    `SUBSCRIBE_PAID` (*"The start of a paid subscription for a product or service."*). Name the conversion.

### 2d. Google Ads — the four settings on that conversion action

Set at creation, or afterwards via **Goals** → **Conversions** → **Summary** → *[conversion action]* → **Edit
settings** → **Settings** tab.

16. **Click-through conversion window** → set to **90 days**. The default is 30 and it is not retroactive.
    This is the single setting that decides whether a day-35 conversion counts. Do it before the clicks you
    intend to count.
17. **Count** → select **One**. The default for import conversion actions is **Every** (*"Every conversion is
    the default for website, in-app actions, Analytics transactions, clicks on your number on your mobile
    website, and import conversion actions."*), which is wrong for one subscription start per click. This
    must be changed explicitly.
18. **Value** → choose **Use different values for each conversion**, and supply a default value and default
    currency as the fallback. We send a real per-purchase amount, so the "always use default" behaviour must
    stay off.
19. **Attribution model** → **Data-driven** (the default for most conversion actions) or **Last click**.

20. Confirm **auto-tagging is enabled** on the account. Stated prerequisite, verbatim: *"You've enabled
    auto-tagging. This lets you import offline conversions."* Without it there is no gclid to capture at
    signup in the first place.

21. **Wait 4–6 hours** after creating the conversion action before sending anything. Verbatim: *"After
    creating a new conversion action, wait 4-6 hours before uploading conversions for that conversion action.
    If you upload conversions during the first 4-6 hours, it might take 2 days for those conversions to appear
    on your reports."*

### 2e. Google Ads — Enhanced Conversions and the customer data terms

Required **only because we send the hashed email** alongside the gclid. A gclid-only payload does not engage
these settings at all — that is the simpler path if these prove awkward.

22. Go to the **Goals** menu → **Settings**.
23. Expand the **Enhanced conversions for web** panel and the **enhanced conversions for leads** drop-down.
    If **Turn on enhanced conversions** is already checked, it is on — this answers the owner's uncertainty
    directly.
24. To enable: check **Turn on enhanced conversions**, *"Review the compliance statement, and select
    **Agree**"*, and choose an implementation method from **Google Tag Manager**, **The Google tag**, or
    **Google Ads API**.
25. Accept the customer data terms, verbatim: *"Select **View Terms** next to 'Customer data terms' and read
    the 'Policies and Additional Terms for Customer Data'. Click the checkbox beside 'I have read and accepted
    the terms on behalf of my company'. Click **Agree**."*

Note the April 2026 merge, verbatim: *"Enhanced conversions for web and leads will soon be combined into a
single on/off setting. Starting in April 2026, Google Ads will simultaneously accept user-provided data from
website tags, Data Manager, and API connections and you will no longer need to choose between different
implementation methods."* That date has passed, so the account may show one combined toggle rather than two
panels — and the GTM container `GTM-N6H844WJ` tag and Data Manager uploads can coexist without choosing.

Per-conversion-action check, if wanted: **Goals** → **Summary** → *[conversion action]* → **Settings** →
expand **Enhanced conversions**.

### 2f. Get the conversion action ID

26. Go to **Conversions** in the Google Ads UI and click the conversion action name. The ID is the **`ctId`**
    query parameter in the browser URL:
    `https://ads.google.com/aw/conversions/detail?ocid=...&ctId=CONVERSION_ACTION_ID&...`

    That bare numeric value is `productDestinationId`. It is **not** the
    `customers/{cid}/conversionActions/{id}` resource-name form — that convention belongs to the Google Ads
    API, and this is a documented trap. Verbatim: *"Set to the numeric ID of the conversion action. Don't use
    the resource name of the `ConversionAction`."*

    The GAQL alternative (`SELECT conversion_action.id ... FROM conversion_action`) runs against the Google
    Ads API and therefore needs a developer token. Use the `ctId` method.

---

## 3. What we send

### Endpoint and auth

```
POST https://datamanager.googleapis.com/v1/events:ingest
Authorization: Bearer ACCESS_TOKEN
x-goog-user-project: PROJECT_ID
Content-Type: application/json
```

Single OAuth scope, and the only scope `events.ingest` declares:

```
https://www.googleapis.com/auth/datamanager
```

No `developer-token` header. No `login-customer-id` header. Verbatim: *"Don't set request headers in an
IngestionService request. The Data Manager API ignores headers in an ingestion request."* The manager-account
relationship that `login-customer-id` used to express lives in the JSON body as `Destination.loginAccount`.

### Our stored values, mapped

| What we store | Data Manager field | Transform |
|---|---|---|
| `google_click_id` | `events[].adIdentifiers.gclid` | none — sent raw, never hashed |
| user email | `events[].userData.userIdentifiers[].emailAddress` | normalize → SHA-256 → hex (rules below) |
| purchase amount in cents | `events[].conversionValue` | **cents ÷ 100** — *"Set to the currency value, not the value in micros. For example, for a conversion value of $5.23, use the value `5.23`."* |
| currency | `events[].currency` | ISO 4217 |
| conversion time (Stripe webhook) | `events[].eventTimestamp` | RFC 3339 |
| Stripe invoice / subscription id | `events[].transactionId` | optional here, recommended for dedupe |
| `ga_client_id` | `events[].clientId` | only meaningful for a `GOOGLE_ANALYTICS_PROPERTY` destination, not for Google Ads |
| `ga_session_id`, `utm_source`, `utm_campaign` | no direct field | see note below |

`utm_source` / `utm_campaign` have no home on this API. The nearest surfaces are
`adIdentifiers.sessionAttributes` (a base64 blob built browser-side from `gad_*` params at landing time — not
what we store) or `customVariables` (requires pre-created Google Ads custom variables referenced by numeric
ID). Neither is a clean fit. This needs a decision, not a lookup, and is not required for the conversion to
land.

### The request body

```json
{
  "destinations": [
    {
      "operatingAccount": {
        "accountType": "GOOGLE_ADS",
        "accountId": "GOOGLE_ADS_CUSTOMER_ID"
      },
      "loginAccount": {
        "accountType": "GOOGLE_ADS",
        "accountId": "GOOGLE_ADS_CUSTOMER_ID"
      },
      "productDestinationId": "CONVERSION_ACTION_ID"
    }
  ],
  "encoding": "HEX",
  "validateOnly": true,
  "events": [
    {
      "adIdentifiers": {
        "gclid": "STORED_GOOGLE_CLICK_ID"
      },
      "eventTimestamp": "2026-07-30T14:22:01Z",
      "eventSource": "WEB",
      "conversionValue": 49.00,
      "currency": "USD",
      "transactionId": "STRIPE_INVOICE_ID",
      "userData": {
        "userIdentifiers": [
          { "emailAddress": "SHA256_HEX_OF_NORMALIZED_EMAIL" }
        ]
      }
    }
  ]
}
```

Notes on that body:

- `accountType` is **`GOOGLE_ADS`**, verified from the discovery document's enum:
  `["ACCOUNT_TYPE_UNSPECIFIED", "GOOGLE_ADS", "DISPLAY_VIDEO_PARTNER", "DISPLAY_VIDEO_ADVERTISER",
  "DATA_PARTNER", "GOOGLE_ANALYTICS_PROPERTY", "GOOGLE_AD_MANAGER_AUDIENCE_LINK", "FLOODLIGHT_CONFIG"]`.
  Some secondary write-ups say `GOOGLE_ADS_ACCOUNT`; that value does not exist.
- Customer IDs are digits only — strip hyphens.
- `loginAccount` may be omitted for direct access (it defaults to `operatingAccount`); if credentials sit on
  an MCC, put the manager customer ID there instead.
- `eventTimestamp` is the **only** unconditionally required field on `Event`. `eventSource` is additionally
  required for the Google Ads offline use case.
- `validateOnly: true` validates without executing and returns errors only. Flip to `false` for live sends.
- **Sending gclid and hashed email together is correct and encouraged.** The requirement is *"Set **at least
  one** of the following"*, not exactly one, and best practices state verbatim: *"include as many
  `user_identifiers` as possible, including sending multiple identifiers of the same type."* Google's own
  sample data (`googleads/data-manager-python`, `samples/sampledata/events_1.json`) ships events carrying a
  gclid alongside three emails and three phone numbers. The gclid gives deterministic click attribution; the
  hashed email is the fallback when the gclid has aged out or the click was cross-device. Cap: 10
  `userIdentifiers` per event.

### Email normalization and hashing — verbatim rules

From `https://developers.google.com/data-manager/api/devguides/concepts/formatting`:

> - "Convert to lowercase."
> - "If the email address has the `gmail.com` or `googlemail.com` domain: Remove all dots (`.`) before the
>   `@` symbol. Remove the plus sign (`+`) from the local-part and remove all characters that follow it.
>   Example: `cloudy.sanfrancisco+shopping@gmail.com` → `cloudysanfrancisco@gmail.com`"
> - "If the email address has a domain other than `gmail.com` or `googlemail.com`, don't remove dots or plus
>   signs. Example: `user.name+NYC@Example.com` → `user.name+nyc@example.com`"
> - "Trim leading, trailing and intermediate whitespace."
> - "Hash using the SHA-256 algorithm. Encode the hash bytes using hex or Base64 encoding."

On encoding case:

> - "The case of the encoding output doesn't matter when using hexadecimal encoding (hex)."
> - "The case of the encoding output _matters_ when using Base64 encoding."

Whichever is used, the request-level `encoding` field must declare `HEX` or `BASE64` to match.

One detail the prose understates, visible in Google's canonical implementation
(`googleads/data-manager-python`, `google/ads/datamanager_util/format.py`): its `hash_string` strips **all**
whitespace before hashing, for every field, not just email.

Not applicable to us but worth recording: `regionCode`, `postalCode`, `city` and `administrativeArea` are
**not** hashed; `givenName` and `familyName` are.

### Reading the result

The synchronous response is `{ "requestId": ..., "fieldWarnings": [...] }` only. A 200 is a receipt, not a
success — record validation happens asynchronously.

- Persist `requestId`. It is the only handle on the outcome, and it is **not** issued for `validateOnly`
  requests.
- Inspect `fieldWarnings[]` inline (each has `field`, `reason`, `description`).
- Then `GET https://datamanager.googleapis.com/v1/requestStatus:retrieve?requestId=<id>` — returns
  `requestStatusPerDestination[]` with `requestStatus` ∈ `{REQUEST_STATUS_UNKNOWN, SUCCESS, PROCESSING,
  FAILED, PARTIAL_SUCCESS}`, plus `errorInfo.errorCounts[]`, `warningInfo`, and
  `eventsIngestionStatus.recordCount`.

Two operational facts that shape how we batch:

- **Fast-fail, not partial-failure.** Verbatim: *"The Data Manager API uses a fast-fail model, where all
  records in a request fail if any record has an error. The fast-fail model of the Data Manager API differs
  from the partial failure model used by the Google Ads API."* One bad record kills the whole batch.
- **No per-event failure detail.** `ErrorCount` carries only `{recordCount, reason}` — a count, never an
  identifier. Nothing in the v1 response surface names *which* gclid failed. So batches must stay small
  enough that "3 records failed with `EVENT_TOO_OLD`" is actionable, or one event per request with `requestId`
  correlated to the record on our side.

Window-relevant error reasons to watch: `EVENT_TOO_OLD` (*"The conversion is older than max supported age"*),
`CLICK_NOT_FOUND`, `INVALID_GCLID`, `DUPLICATE_GCLID`, `CONVERSION_PRECEDES_CLICK`, `TOO_RECENT_CLICK`,
`DESTINATION_ACCOUNT_NOT_ENABLED_ENHANCED_CONVERSIONS_FOR_LEADS`,
`DESTINATION_ACCOUNT_ENHANCED_CONVERSIONS_TERMS_NOT_SIGNED`.

### Limits

100,000 requests/day and 300 requests/minute per Cloud project on `IngestionService`; max 2,000 `Event` per
request; max 10 `Destination` per request; max 10 user identifiers per `UserData`. Over-limit →
`RESOURCE_EXHAUSTED` / HTTP 429. Recommended concurrency: up to 10 concurrent requests.

---

## 4. Time windows

| Window | Default | Max | Retroactive when changed? |
|---|---|---|---|
| **Click-through conversion window** (conversion action setting) | **30 days** | **90 days** (1–30/60/90 by source) | **No.** *"any changes apply to all conversions going forward"* |
| **View-through conversion window** | 1 day | 30 days (or 1–4 weeks) | No — same rule |
| **Engaged-view conversion window** | 3 days | 30 days | No — same rule |
| **gclid retention / max upload age** | 90 days (fixed) | not settable | n/a — Google's retention: *"We retain the GCLID for only 90 days"* |
| **Hashed-PII (enhanced conversions) max upload age** | 63 days (fixed) | not settable | n/a |
| **Minimum click age before upload** | 6 hours | n/a | n/a — `TOO_RECENT_CLICK` before that |
| **New conversion action cool-down** | 4–6 hours | n/a | n/a — one-time, at setup |
| **`eventTimestamp` recency — Google Analytics destinations only** | 72 hours | n/a | n/a — **does not apply to Google Ads** |
| **`requestStatus:retrieve` first poll** | wait ≥ 30 min | processing up to 24 h | n/a |

Retroactivity, quoted in full because it is the decision-relevant one:

> "You also can change the conversion window as often as you'd like. Just remember that **any changes apply to
> all conversions going forward**. So, if you're using a 30-day conversion window and you change it to 10
> days, the 10-day window will only apply to conversions recorded from that day forward."

> "March 16: You change the conversion window again to 20 days. **A March 13 conversion from this interaction,
> which wasn't counted within the last window, won't be retroactively counted.** But future conversions before
> March 20 will be counted for the March 1 interaction."

Implications for a 14-day trial that converts on day 14–30:

- A 14-day trial converting on day 14–20 fits under the 30-day default — but only barely, and only if signup
  happened on the click day. A late trial start, a retried payment, or a 30-day trial falls outside. **Set 90.**
- 14–30 days consumes 16–33% of the 90-day gclid retention budget. Not a constraint.
- The 63-day PII limit also clears comfortably — relevant only when the gclid is missing and the hashed email
  is doing the matching.
- Two things that read as bugs but are not: imported conversions **report on the original click's date**, so
  historical campaign rows change after the fact — use the **"All conv. (by conv. time)"** column to see them
  by conversion date instead. And note the Google Ads attribution setting: when it is **Paid and organic
  channels** rather than **Google paid channels**, conversion-window and count changes must be made in Google
  Analytics, not Google Ads. Worth checking before assuming the Ads UI controls are live, given GA4 property
  313449782 is linked.

---

## 5. Ruby

**Recommendation: plain REST with a bearer token.** The Ruby-version constraint below is the reason, and the
one real Rails implementation in the wild made the same call.

### Official Ruby client libraries exist — two families, both blocked on Ruby 3.1

| Gem | Latest | Ruby floor | Last version supporting Ruby 3.1 |
|---|---|---|---|
| `google-ads-data_manager` (GAPIC wrapper) | 0.4.0 (2026-06-11) | >= 3.2 | 0.2.0 (2026-03-04) |
| `google-ads-data_manager-v1` (GAPIC versioned) | 0.7.0 (2026-06-17) | >= 3.2 | 0.2.0 (2025-11-11) |
| `google-apis-datamanager_v1` (generated REST) | 0.11.0 (2026-07-12) | >= 3.2 | 0.9.0 (2026-05-24) |
| `google-apis-core` (dependency of the above) | 1.2.5 | >= 3.2 | 1.1.0 (2026-06-03) |

This app is Ruby 3.1. Every current version of both families fails `bundle install`. Pinning to the
3.1-compatible releases is possible (`google-apis-datamanager_v1` 0.9.0 **with** `google-apis-core` pinned
≤ 1.1.0) but means adopting a frozen dependency for a two-call API.

By contrast `googleauth` — which is all the plain-REST route needs — supports Ruby >= 3.0 through **1.17.1**
(2026-06-16); only 1.17.2+ moved to >= 3.2. It also typically arrives transitively via any existing Google gem
already in the bundle, so the REST route may add no new dependency at all. **Worth a one-line check of the
lockfile before assuming that.**

### Auth mechanics

Mint a bearer token from a service account with `scope: ['https://www.googleapis.com/auth/datamanager']` via
`googleauth`'s `Google::Auth::ServiceAccountCredentials`, then send it as `Authorization: Bearer <token>` on
an ordinary JSON POST. Google's documented setup flow prefers impersonation over key files (*"service account
keys can become a security risk if not managed carefully"*), but that is an interactive workstation flow —
for a long-running Rails process on a platform with no attached service account, a key JSON held in an env var
or config record is the realistic path, and ADC supports it like any other `google-cloud-*` gem.

Watch for HTTP 403 `INSUFFICIENT_AUTHENTICATION_SCOPES` against a `datamanager.googleapis.com` URL — that is
the signature of a cached token minted before the scope grant.

### Prior art

**`chatwoot/chatwoot`** (PRACTITIONER, open-source Rails, ~26k stars) is the only Ruby implementation of this
on public GitHub, and the use case is close to ours: a SaaS that stores a click ID at signup and uploads the
conversion server-to-server on later paid plan activation, with no browser involved. It uses **neither** gem —
plain `HTTParty.post` plus `require 'googleauth'`, async via ActiveJob, click ID only with no `userData` (so
no hashing and no customer-data-terms prerequisite). Files:

- `enterprise/app/services/internal/accounts/marketing_conversion_tracking_service.rb`
- `enterprise/app/jobs/internal/accounts/marketing_conversion_tracking_job.rb`
- `spec/enterprise/services/internal/accounts/marketing_conversion_tracking_service_spec.rb`

Its spec is a clean HTTParty-stub pattern asserting the URL, the `make_creds` scope argument, the
Authorization header, and the full request body — a usable model for how to test ours without hitting Google.

**Official samples exist in five languages — Java, Python, TypeScript, C#, PHP — under the `googleads` GitHub
org, but there is no Ruby samples repo.** The best populated-payload reference is
`googleads/data-manager-python`, `samples/events/ingest_events.py`. Google's only Ruby snippet is an
auto-generated skeleton in `googleapis/google-cloud-ruby` that builds an empty request. Practically this means
the SHA-256 normalization helpers that ship as `datamanager_util.format` in the other five languages have no
Ruby counterpart — those ~20 lines are ours to write from the verbatim rules in §3.

Also available as cross-checks: Stape's server-side GTM tag (`stape-io/google-conversion-events-tag`, Apache
2.0) is the most complete public implementation of the full hashing and validation logic, and walkerOS
(`@walkeros/server-destination-datamanager`, MIT) is a minimal plain-REST reference.

---

## 6. Unknowns

Each with the smallest test that settles it. None of these blocks starting.

1. **The numeric threshold behind `EVENT_TOO_OLD`.** The API never states it — grepping the discovery document
   for age/window/expire strings returns only *"The conversion is older than max supported age"* and *"The
   click occurred too recently."* The 90-day and 63-day figures come from Google Ads Help for offline imports
   generally, not from any Data Manager page. **Test:** send one event with a gclid of known age via
   `validateOnly: false`, then read `errorInfo.errorCounts[]` from `requestStatus:retrieve`. Cheap, and worth
   doing once with a deliberately old gclid to find the real edge.

2. **Whether *widening* the click-through window (30 → 90) rescues clicks already past 30 days.** Google
   documents only the narrowing direction. Safe reading is forward-only both ways. **Test:** none available
   cheaply — treat as forward-only and set 90 before the clicks we intend to count. This is why §2d step 16
   comes first.

3. **Whether a gclid-only upload (no `userData`) needs the customer data terms at all.** Stape ties the
   requirement specifically to sending user email/phone, and Chatwoot's production gclid-only implementation
   does not mention it — but no official sentence states the exemption. **Test:** one `validateOnly: true`
   call with gclid only, before touching the Enhanced Conversions settings. If it validates, §2e is optional.

4. **Whether Enhanced Conversions is currently enabled on the account** (the owner's stated uncertainty).
   **Test:** read it in the UI — **Goals** → **Settings** → **Enhanced conversions for web** / **enhanced
   conversions for leads**; the checkbox state is the answer. Programmatic equivalent
   (`customer.conversion_tracking_setting.accepted_customer_data_terms` and
   `.enhanced_conversions_for_leads_enabled`) needs a developer token, so the UI is the route.

5. **Whether an `UPLOAD_CLICKS` conversion action already exists.** **Test:** open **Conversions** and read
   the **Conversion source** column — `UPLOAD_CLICKS` shows as **Website (Import from clicks)**.

6. **Whether the Cloud project needs billing enabled.** Never mentioned in the prerequisites, never
   contradicted. **Test:** create the project without billing and enable the API; the enable step fails
   immediately if billing is required.

7. **Whether a service-account key JSON is officially supported** (as opposed to impersonation). Docs show
   only the impersonation flow and steer away from keys without prohibiting them. These are standard ADC
   clients, so a key should work. **Test:** one live `events:ingest` call authenticated by key.

8. **`requestId` retention for `requestStatus:retrieve`.** Explicitly undocumented. **Test:** poll one
   `requestId` at increasing delays until it 404s. Low value — persist our own record regardless.

9. **Whether the "14-day trial period" for a new conversion action** (non-biddable, value updates disabled)
   applies to a fresh `UPLOAD_CLICKS` action used only via the API, or only to the multi-source path. Both
   sentences appear only in the multi-source section. **Test:** watch whether the first two weeks of uploads
   appear in reporting but not in bidding. Plan for two weeks of non-biddable data either way.

10. **Exact behaviour when the gclid is present but stale/unmatched and a hashed email is also present** —
    whether Google falls back to email matching for that same event, or drops it. Docs say attribution uses
    *"the identifiers you provided (like `adIdentifiers.gclid` or `userData`)"* without specifying precedence.
    **Test:** send one event with a deliberately invalid gclid plus a valid hashed email and check whether the
    conversion lands.

11. **`ga_session_id` / `utm_source` / `utm_campaign` placement.** No field fits cleanly (see §3). This needs
    a product decision about whether we care, not a lookup.

12. **The official quotas page 404s** at the obvious URL. The 2,000-events-per-request cap is official (stated
    in the `events.ingest` reference); the daily/minute figures come from a practitioner doc that flags them as
    unverified, though Stape independently enforces the 10-destination and 10-identifier caps. **Test:** not
    worth one — we are nowhere near any of these volumes.

13. **Practitioner coverage of the Data Manager API specifically is thin**, because the API is recent (first
    Ruby gem October 2025) and the June 2026 lockout only just forced adoption. Most match-rate and
    gotcha literature describes the legacy `UploadClickConversions` path. This is undocumented territory, not
    absent capability — the official surface is complete and four independent working implementations exist.

One inconsistency worth recording rather than resolving: the OFFICIAL Google Ads API developer-token page
(`.../google-ads/api/docs/get-started/dev-token`, updated 2026-07-22) still reads *"Both companies and
individual developers can apply for a developer token"* and carries no closure notice. This does not change
anything — Data Manager has no developer-token concept at all — but the closure itself could not be
corroborated from Google's own docs.

---

## 7. Sources

### OFFICIAL — Data Manager API reference

- https://developers.google.com/data-manager/api/reference/rest — REST index; service name, v1, all methods
- https://datamanager.googleapis.com/$discovery/rest?version=v1 — machine-readable discovery doc, revision `20260729`; authoritative for every field, enum, and scope quoted here; source of the zero-developer-token and single-allowlist findings
- https://developers.google.com/data-manager/api/reference/rest/v1/events/ingest — `events:ingest` schema, scope, 2,000-event cap
- https://developers.google.com/data-manager/api/reference/rest/v1/requestStatus/retrieve — status polling, `RequestStatus` enum
- https://developers.google.com/data-manager/api/reference/rest/v1/Destination — the "write access" requirement
- https://developers.google.com/data-manager/api/reference/rest/v1/UserData — identifier union, hashing requirements
- https://developers.google.com/data-manager/api/reference/rest/v1/accountTypes.accounts.partnerLinks — `ProductAccount` / `AccountType` enum
- https://developers.google.com/data-manager/api/reference/rpc — gRPC service and method names
- https://developers.google.com/data-manager/api/reference/rpc/google.ads.datamanager.v1 — full `ProcessingErrorReason` enum with verbatim descriptions
- https://developers.google.com/data-manager/api/reference — release notes, v1.0 (2025-04-02) through v1.8 (2026-07-30); GA declared at v1.3

### OFFICIAL — Data Manager API guides

- https://developers.google.com/data-manager/api — API home, purpose, GA status
- https://developers.google.com/data-manager/api/devguides/quickstart/set-up-access — prerequisites, scopes, service-account flow, "OAuth verification isn't required for service accounts"
- https://developers.google.com/data-manager/api/devguides/quickstart/install-library — client libraries, curl skeleton, `x-goog-user-project`
- https://developers.google.com/data-manager/api/devguides/events — events overview, destinations, allowlist scoping
- https://developers.google.com/data-manager/api/devguides/events/send-events — the verbatim example body, per-use-case required fields, `UPLOAD_CLICKS` requirement, GA-only 72-hour limit
- https://developers.google.com/data-manager/api/devguides/events/google-ads/offline — offline conversions entry point
- https://developers.google.com/data-manager/api/devguides/events/google-ads/offline/upgrade — "does not require a developer token"; fast-fail model
- https://developers.google.com/data-manager/api/devguides/events/google-ads/offline/upgrade/steps — migration steps; new credentials with the new scope
- https://developers.google.com/data-manager/api/devguides/events/google-ads/offline/upgrade/field-mappings — full `ClickConversion` → `Event` mapping; "A developer token is not required for the Data Manager API"
- https://developers.google.com/data-manager/api/devguides/events/google-ads/online — multi-source conversions; 14-day bidding trial
- https://developers.google.com/data-manager/api/devguides/concepts/destinations — `productDestinationId` per product; the `ctId` method; header rules
- https://developers.google.com/data-manager/api/devguides/concepts/formatting — verbatim normalization and hashing rules
- https://developers.google.com/data-manager/api/devguides/concepts/understand-errors — fast-fail, `fieldWarnings` on HTTP 200
- https://developers.google.com/data-manager/api/devguides/concepts/best-practices — batching, concurrency, "include as many user_identifiers as possible"
- https://developers.google.com/data-manager/api/devguides/diagnostics — 30-minute minimum, 24-hour ceiling, aggregate-only detail
- https://developers.google.com/data-manager/api/devguides/limits — per-project and per-request limits
- https://developers.google.com/data-manager/api/support — support form; data-partner interest form

### OFFICIAL — Google Ads API and protos

- https://developers.google.com/google-ads/api/docs/conversions/upload-clicks — the 15 June 2026 banner: "Use the Data Manager API instead"; email normalization; click-date reporting
- https://developers.google.com/google-ads/api/docs/conversions/upload-identifiers — enhanced conversions for leads; the two customer flags; short UI label chain
- https://developers.google.com/google-ads/api/docs/deprecations — the developer-token restriction and `CUSTOMER_NOT_ALLOWLISTED_FOR_THIS_FEATURE`
- https://developers.google.com/google-ads/api/docs/get-started/dev-token — still invites applications as of 2026-07-22 (noted inconsistency)
- https://developers.google.com/google-ads/api/docs/oauth/service-accounts — adding a service account email as a Google Ads user; 20-accounts-per-email limit
- https://developers.google.com/google-ads/api/reference/rpc/v25/ConversionAction — `click_through_lookback_window_days`, `view_through_lookback_window_days`
- https://developers.google.com/google-ads/api/reference/rpc/v25/ConversionAction.ValueSettings — `default_value`, `default_currency_code`, `always_use_default_value`
- https://developers.google.com/google-ads/api/reference/rpc/v25/ConversionActionTypeEnum.ConversionActionType — `UPLOAD_CLICKS`
- https://developers.google.com/google-ads/api/reference/rpc/v25/ConversionActionCountingTypeEnum.ConversionActionCountingType — `MANY_PER_CLICK` / `ONE_PER_CLICK`
- https://developers.google.com/google-ads/api/reference/rpc/v25/ConversionActionCategoryEnum.ConversionActionCategory — `SUBSCRIBE_PAID`
- https://developers.google.com/google-ads/api/reference/rpc/v25/AttributionModelEnum.AttributionModel — attribution model values
- https://raw.githubusercontent.com/googleapis/googleapis/master/google/ads/googleads/v21/errors/conversion_upload_error.proto — `EXPIRED_EVENT`, `TOO_RECENT_EVENT`, `TOO_RECENT_CONVERSION_ACTION` verbatim
- https://raw.githubusercontent.com/googleapis/googleapis/master/google/ads/datamanager/v1/ingestion_service.proto — 2,000-event cap
- https://github.com/googleapis/googleapis/tree/master/google/ads/datamanager/v1 — source protos for all clients

### OFFICIAL — Google Ads Help

- https://support.google.com/google-ads/answer/10029210 — **the age numbers**: 90-day gclid, 63-day PII, "too old" error text, "All conv. (by conv. time)"
- https://support.google.com/google-ads/answer/3123169 — **retroactivity**; window defaults and ranges; the Paid-and-organic caveat
- https://support.google.com/google-ads/answer/3438531 — Every vs One; "Every conversion is the default for … import conversion actions"
- https://support.google.com/google-ads/answer/6259715 — attribution models; Data-driven default
- https://support.google.com/google-ads/answer/7012522 — auto-tagging prerequisite; the 4–6 hour wait
- https://support.google.com/google-ads/answer/11021502 — current conversion-action creation flow; customer data terms click sequence
- https://support.google.com/google-ads/answer/11347292 — customer data terms verbatim steps
- https://support.google.com/google-ads/answer/13258081 — how to check whether Enhanced Conversions is on, account and per-action
- https://support.google.com/google-ads/answer/13262500 — enabling enhanced conversions for web
- https://support.google.com/google-ads/answer/15712870 — the April 2026 merge of web and leads settings
- https://support.google.com/google-ads/answer/9978556 — access levels matrix (Standard is the minimum write level)
- https://support.google.com/google-ads/answer/6372672 — granting account access UI path
- https://support.google.com/google-ads/answer/6386790 — transaction ID: 64 chars, optional for OCI
- https://support.google.com/google-ads/answer/16542291 — multi-source conversions; the `ctId` parameter
- https://support.google.com/google-ads-data-manager/answer/13761872 — the separate point-and-click Data Manager UI product (different thing, shared brand)

### OFFICIAL — client libraries and samples

- https://github.com/orgs/googleads/repositories?q=topic:googleads-data-manager-api — the five official sample repos
- https://github.com/googleads/data-manager-python — best populated-payload sample, `samples/events/ingest_events.py`
- https://github.com/googleads/data-manager-python/blob/main/google/ads/datamanager_util/format.py — canonical normalization/hashing implementation
- https://github.com/googleads/data-manager-python/blob/main/samples/sampledata/events_1.json — Google's own sample sending gclid + hashed emails on one event
- https://github.com/googleads/data-manager-dotnet/blob/main/samples/IngestEvents.cs — .NET sample referenced from the send-events guide
- https://github.com/googleads/data-manager-java — earliest official sample repo
- https://github.com/googleapis/google-cloud-ruby/tree/main/google-ads-data_manager — official Ruby GAPIC wrapper gem
- https://github.com/googleapis/google-cloud-ruby/tree/main/google-ads-data_manager-v1 — official Ruby versioned client
- https://github.com/googleapis/google-cloud-ruby/blob/main/google-ads-data_manager-v1/snippets/ingestion_service/ingest_events.rb — the only official Ruby snippet (skeleton)
- https://github.com/googleapis/google-api-ruby-client/tree/main/generated/google-apis-datamanager_v1 — official generated Ruby REST gem
- https://rubygems.org/api/v1/versions/google-apis-datamanager_v1.json — per-version Ruby floors (0.9.0 = last 3.1-compatible)
- https://rubygems.org/api/v1/versions/google-ads-data_manager-v1.json — per-version Ruby floors (0.2.0 = last 3.1-compatible)
- https://rubygems.org/api/v1/versions/googleauth.json — 1.17.1 = last release supporting Ruby >= 3.0

### PRACTITIONER

- https://github.com/chatwoot/chatwoot/blob/develop/enterprise/app/services/internal/accounts/marketing_conversion_tracking_service.rb — the only Ruby/Rails implementation on public GitHub; near-identical use case
- https://github.com/stape-io/google-conversion-events-tag — Stape's server-side GTM tag (VENDOR, Apache 2.0); most complete public hashing/validation logic; best practical write-up of the Ads prerequisites
- https://github.com/elbwalker/walkerOS/tree/main/packages/server/destinations/datamanager — walkerOS (VENDOR, MIT); minimal plain-REST reference
- https://github.com/talas9/gads-cli/blob/main/kb/data-manager-api.md — implementation-grade reference doc; the explicit no-developer-token statement; two claims now stale (see §3 on `fieldWarnings` and `requestStatus:retrieve`)
- https://github.com/rudderlabs/rudder-transformer/blob/develop/src/v0/destinations/google_adwords_remarketing_lists/dataManager/config.ts — RudderStack (VENDOR); audiences only, no conversion-events path
- https://github.com/theeufj/spectra-media-agent — `app/Services/GoogleAds/DataManagerService.php` (Laravel)
- https://github.com/rejourneyco/rejourney — `backend/src/services/googleAdsConversions.ts`
- https://guias.nexopath.com/blog/true-conversions-offline-conversion-match-rate/ — match-rate expectations (30–45% typical for PII matching; describes the legacy path)
- https://webmarketinginternational.com/gclid-tracking-guide/ — corroborates the 90-day gclid window
- https://twospouts.com/blog/data-manager-api-conversion-migration — B2B SaaS framing: "the event that actually matters happens days or weeks after the click"
- https://stape.io/blog/google-ads-conversions-tracking-with-data-manager-api — vendor setup walkthrough
