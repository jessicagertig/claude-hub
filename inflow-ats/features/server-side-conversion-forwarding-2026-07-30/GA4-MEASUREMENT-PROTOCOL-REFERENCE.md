# GA4 Measurement Protocol — implementation reference

Every claim on this page traces to a fetched official Google URL, cited inline. Statements Google does not
make are recorded in [§11 Gaps](#11-gaps--not-answered-by-the-official-docs), never filled with a guess.

**Tab warning that governs this whole document.** The Measurement Protocol doc pages are tabbed by client
type. The bare URLs (`.../ga4/reference`, `.../ga4/sending-events`, `.../ga4/validating-events`,
`.../ga4/verify-implementation`) render the **Firebase / app-stream** variant, which documents
`firebase_app_id` + `app_instance_id` and contains **no `client_id` row at all**. The web variant requires
`?client_type=gtag`. A Rails web-stream integration must read the `?client_type=gtag` variant of every one of
those pages.

Page dates, where the page shows one: MP overview, reference, validating-events, troubleshooting, policy,
user-properties — 2026-06-08 UTC. sending-events — 2026-06-11 UTC. use-cases — 2026-06-09 UTC.
verify-implementation — 2026-06-15 UTC. gtag config reference — 2026-05-14 UTC. gtag API reference —
2026-04-17 UTC. Admin API `measurementProtocolSecrets` — 2026-04-14 UTC. Consent pages — 2026-07-30 UTC.
`support.google.com` pages display **no** last-updated date; their currency cannot be established.

---

## 1. Endpoint

### 1.1 URLs

| Purpose | URL | Source |
|---|---|---|
| Production, global | `https://www.google-analytics.com/mp/collect` | `.../protocol/ga4/reference` |
| Production, EU data collection | `https://region1.google-analytics.com/mp/collect` | `.../protocol/ga4/reference` |
| Validation / debug, global | `https://www.google-analytics.com/debug/mp/collect` | `.../protocol/ga4/validating-events?client_type=gtag` |
| Validation / debug, EU | `https://region1.google-analytics.com/debug/mp/collect` | `.../protocol/ga4/validating-events` |

> "For EU data collection, use: `https://region1.google-analytics.com/mp/collect`"
> — `.../protocol/ga4/reference`

> "The validation server's URL includes '/debug' unlike the standard Measurement Protocol URL."
> — `.../protocol/ga4/validating-events`

The doc presents the two servers as a path contrast:

| Server | Path |
|---|---|
| Measurement Protocol | `/mp/collect` |
| Measurement Protocol validation server | `/debug/mp/collect` |

— `.../protocol/ga4/validating-events`

**Path caveat.** The Firebase tab of the validating-events page rendered the path as `/_debug_/mp/collect`;
that is a markdown-emphasis artifact from the doc bolding the word *debug* in its comparison table. The
gtag tab renders it inside a code sample as `/debug/mp/collect` — single segment, no underscores.

### 1.2 Method, credentials, content type

> "All data must be sent securely using HTTPS `POST` requests."
> — `.../protocol/ga4/reference?client_type=gtag`

| Item | Value | Location | Required | Source |
|---|---|---|---|---|
| HTTP method | `POST` | — | yes | `.../ga4/reference?client_type=gtag` |
| `Content-Type` | `application/json` | header | shown in every sample | `.../ga4/sending-events?client_type=gtag` |
| `api_secret` | the Secret value from the GA4 admin UI | **query string** | **Required** | `.../ga4/reference?client_type=gtag` |
| `measurement_id` | the web data stream's `G-…` ID | **query string** | see note | `.../ga4/reference?client_type=gtag` |
| `client_id` | web-client instance identifier | **JSON body** | **Required** | `.../ga4/reference?client_type=gtag` |

Note on `measurement_id` requiredness: the reference page's `measurement_id` row is not marked Required the
way `api_secret` and `firebase_app_id` are. Every sending-events skeleton includes it. Recorded as a gap.

Verbatim request line:

```http
POST /mp/collect?measurement_id=MEASUREMENT_ID&api_secret=API_SECRET HTTP/1.1
HOST: www.google-analytics.com
Content-Type: application/json

PAYLOAD_DATA
```
— `.../protocol/ga4/sending-events?client_type=gtag`

Verbatim canonical web/gtag sample (JavaScript `fetch`; the docs contain **no Ruby sample**):

```js
const measurementId = "MEASUREMENT_ID";
const apiSecret = "API_SECRET";

fetch(`https://www.google-analytics.com/mp/collect?measurement_id=${measurementId}&api_secret=${apiSecret}`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    client_id: "CLIENT_ID",
    events: [
      {
        name: "tutorial_begin",
        params: {
          "session_id": "SESSION_ID",
          "engagement_time_msec": 100
        }
      }
    ]
  })
});
```
— `.../protocol/ga4/sending-events?client_type=gtag`

> "The `api_secret` is private. Don't expose it in the client-side code of your website or app."
> — `.../protocol/ga4/sending-events?client_type=gtag`

App streams substitute `firebase_app_id` for `measurement_id` (query string) and `app_instance_id` for
`client_id` (body). `app_instance_id` is documented as **"Not the same as a web `client_id`"**
(`.../protocol/ga4/reference`). Not applicable to a web-stream sender; recorded so the wrong tab is not copied.

### 1.3 Response contract — the production endpoint returns 2xx even for an invalid payload

**Yes. The production endpoint returns a 2xx for any received HTTP request, including one whose payload is
malformed or whose data is never processed.** HTTP status is therefore not a validation signal, and a
2xx is not evidence that an event was recorded.

> "The Measurement Protocol returns a `2xx` status code if the `HTTP` request is received. The Measurement
> Protocol doesn't return an error code if the payload is malformed, or if the data is incorrect or not
> processed by Google Analytics."
> — `.../protocol/ga4/reference?client_type=gtag`

> "The Google Analytics Measurement Protocol does not return `HTTP` error codes, even if an event is malformed
> or missing required parameters."
> — `.../protocol/ga4/validating-events`

| Endpoint | Status on receipt | Body | Errors surfaced? |
|---|---|---|---|
| `/mp/collect` | 2xx | not documented | **No** — no error code for malformed payload or unprocessed data |
| `/debug/mp/collect` | **not documented** | `{"validationMessages": [...]}` | Yes, as validation messages (see §9) |

The docs do not state the debug endpoint's HTTP status code, nor whether a clean payload returns an empty
`validationMessages` array, an empty body, or no `validationMessages` key. Recorded as a gap.

### 1.3.1 Preconditions — roles and property selection

Assembled here because the roles are otherwise scattered across the individual procedures. The fetched pages
never state the GA4 role hierarchy (whether Marketer ranks above or below Editor is **not stated** — recorded
as a gap), so the "maximum role needed" cannot be reduced to one entry.

| Step in this document | Role stated by the doc | Scope | Source |
|---|---|---|---|
| Create a property (§1.6) | **Editor** | **account** | answer/9304153 |
| Add / edit a data stream (§1.6) | Editor or above | property | answer/9304153, answer/9304776 |
| Read the measurement ID (§1.4) | Editor or above | property | answer/12270356 |
| Create an `api_secret` (§1.5) | Editor or above (**not** Administrator) | property | answer/9814495 |
| Mark an existing event as a key event (§10.2) | Editor or above | property | answer/13128484 |
| Create an event and mark it at creation (§10.2) | Marketer or above | property | answer/13128484 |
| Import key events as Google Ads conversions (§10.3) | "administrator or editor of the Google Analytics property" **and** "at least Marketer access" | property | answer/10632359 |

**Unreconciled source conflict.** answer/10632359 states both "Be an administrator or editor of the Google
Analytics property" and "at least Marketer access to import key events as conversions into Google Ads" in the
same prerequisite block, without reconciling them. `support.google.com/google-ads/answer/2375435` phrases the
same requirement as "at least a Marketer role in Google Analytics and admin access". No fetched page resolves
which single role satisfies the flow. No fetched page states what a reader sees, or what to do, when they lack
the required role. Both recorded as gaps.

**Property selection — do this before any Admin click path below.** The property is *not* part of any click
path; **Admin** opens whichever property was last used.

> "The previous link opens to the last Analytics property you accessed … change the property using the
> property selector"
> — `support.google.com/analytics/answer/12270356`

> "the top-left corner of your Google Analytics account … drop-down selector … to switch between your Google
> Analytics properties"
> — `support.google.com/analytics/answer/10252712`

This is load-bearing because §1.3 establishes that production returns 2xx regardless: a `measurement_id` and
`api_secret` copied from the wrong property produce **no error anywhere** — the events land in that other
property and nothing signals it.

### 1.4 Obtaining `measurement_id` (a GA4 property + web data stream already exists)

| Step | Action | Source |
|---|---|---|
| 0 | Open the **property selector** in the top-left corner, select the target account and property, and confirm the property name. **Admin** opens the last-accessed property. | `support.google.com/analytics/answer/10252712`, answer/12270356 |
| 1 | Click **Admin** (lower left) | `support.google.com/analytics/answer/12270356` |
| 2 | Under **Data collection and modification**, click **Data streams** | same |
| 3 | Select the **Web** tab | same |
| 4 | Click the web data stream | same |
| 5 | The measurement ID is in the **first row of the stream details** | same |

> "In **Admin**, under _Data collection and modification_, click **Data streams**." … "Select the **Web**
> tab." … "Click the web data stream." … "Find the measurement ID in the first row of the stream details."
> — `support.google.com/analytics/answer/12270356`

| Fact | Statement | Source |
|---|---|---|
| Format | `"G-" followed by a combination of numbers and letters` | answer/12270356 |
| Example | `G-PSW1MY7HB4` | answer/12270356 |
| Scope | unique identifier for **a web data stream** | answer/12270356 |
| Same as | in GA4, the measurement ID is the same ID as the destination ID | answer/12270356 |
| Permission | **Editor or above at the property level** | answer/12270356 |

`support.google.com/analytics/answer/9539598` ("Find your Google tag ID") gives the same value under the
**older** admin label — "In **Admin**, under _Property Settings_, click **Data streams**" — and notes the ID
"starts with `G-` or `AW-`". That page is stale relative to the others; use answer/12270356 wording.

### 1.5 Obtaining `api_secret`

| Step | Action | Source |
|---|---|---|
| 0 | Open the **property selector** in the top-left corner, select the target account and property, and confirm the property name. **Admin** opens the last-accessed property. | `support.google.com/analytics/answer/10252712`, answer/12270356 |
| 1 | Sign in to Google Analytics | `support.google.com/analytics/answer/9814495` |
| 2 | In **Admin**, under **Data collection and modification**, click **Data streams** | same |
| 3 | Click **Web**, then click a web data stream | same |
| 4 | In the stream details, click **Measurement Protocol API Secrets** | same |
| 5 | If necessary, review and accept the **User Data Collection Acknowledgement** | same |
| 6 | Click **Create** | same |
| 7 | Enter a **nickname** for the secret, then click **Create** | same |
| 8 | Click the copy icon to copy the secret so you can paste it into your POST request | same |

> **Copy and store the value before leaving this screen.** No support page states whether the UI redisplays a
> secret value after creation — one-time vs. persistent display is unstated (see §11, "Credentials"). The only
> slack if the value is lost is the 10-secrets-per-stream cap below.

The developer doc gives the same eight steps and names the UI field **"Secret value"**
(`.../protocol/ga4/sending-events?client_type=gtag`). The MP reference page states an older, shorter path:
"Admin > Data Streams > Choose your stream > Measurement Protocol > Create".

| Fact | Statement | Source |
|---|---|---|
| Per-stream cap | "You can generate up to 10 API secrets per data stream" | answer/9814495 |
| Permission | **Editor or above at the property level** (not Administrator) | answer/9814495 |
| Privacy | "Private to your organization. Should be regularly updated to avoid excessive SPAM." | `.../ga4/reference` |
| Deletion | "Click Delete to delete the secret" | answer/9814495 |
| Admin API | `secretValue` is **"Output only"**; "Pass this value to the `api_secret` field of the Measurement Protocol API when sending hits to this secret's parent property." | Admin API `properties.dataStreams.measurementProtocolSecrets` |
| Admin API resource | `properties/{property}/dataStreams/{dataStream}/measurementProtocolSecrets/{measurementProtocolSecret}`; `displayName` Required | same |
| Admin API methods | `create, delete, get, list, patch` | same |

Capitalization differs between official pages: answer/9814495 writes "Measurement Protocol API **S**ecrets",
the developer doc writes "Measurement Protocol API **s**ecrets". Neither confirmed against the live UI.

### 1.6 If no GA4 property or web data stream exists yet

Property creation — requires the **Editor role at the account level**
(`support.google.com/analytics/answer/9304153`), i.e. **this section assumes an Analytics account already
exists**. Creating the account itself is out of scope for this document; answer/9304153's step 1 branches to
its own "Create an Analytics account" section, which was not extracted (recorded as a gap):

> "1. Are you continuing from "Create an Analytics account", above? If so, skip to step 2. Otherwise, in
> Admin, click Create, then select Property. 2. Enter a name for the property (e.g. "My Business,
> Inc website") and select the reporting time zone and currency. 3. Click Next. Select your industry category
> and business size. 4. Click Next. Select how you intend to use Google Analytics. 5. Click Create and (if you
> are setting up a new account) accept the Analytics Terms of Service and the Data Processing Amendment."

Web data stream creation — **Admin > Data collection and modification > Data streams > Add stream > Web**,
requires **Editor or above at the property level**:

> "1. Enter the URL of your primary website, e.g., "example.com", and a Stream name, e.g. "Example, Inc. (web
> stream)". 2. You have the option to enable or disable enhanced measurement. Enhanced measurement
> automatically collects page views and other events. 3. Click Create stream."
> — answer/9304153

| Fact | Statement | Source |
|---|---|---|
| Collection start | "Data collection may take up to 30 minutes to begin." | answer/9304153 |
| Backfill | "Data is collected from the time you add the code" — no historical data | answer/9304153 |
| Properties per account | up to 2,000 | answer/9744165 |
| Streams per property | **recommended** max 3 (1 web + 1 iOS + 1 Android); no hard limit stated | answer/9679158 |
| One web stream | "In most cases, you should use a single web data stream to measure the web user journey." | answer/9679158 |
| Cross-domain | "The tag on each page must use the same tag ID (i.e., the same "G-" ID) from the same web data stream." | answer/10071811 |
| Subdomain cookie | gtag `cookie_domain` defaults to `'auto'` = eTLD+1, so `example.com` and `subdomain.example.com` both write the cookie on `example.com` | `.../collection/ga4/reference/config` |

Google tag snippet, verbatim (the only fetched page that reproduces it in full is
`developers.google.com/tag-platform/gtagjs/install`; it uses `TAG_ID`, not `G-XXXXXXXXXX`):

```html
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=TAG_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'TAG_ID');
</script>
```

> "Place the Google tag snippet immediately after the opening `<head>` HTML tag on every page you want to
> measure." … "Don't add more than one Google tag to each page."
> — `developers.google.com/tag-platform/gtagjs/install`, `support.google.com/analytics/answer/9744165`

The Measurement Protocol is documented as an augmentation of, not a substitute for, this tag:

> "The intent of the Measurement Protocol is to augment automatic collection through gtag, Tag Manager, and
> Google Analytics for Firebase, not to replace it. … You must use tagging (gTag, Tag Manager, or Google
> Analytics for Firebase) to use this protocol."
> "While it's possible to send events to Google Analytics solely with the Measurement Protocol, only partial
> reporting may be available."
> — `.../protocol/ga4`

And GA4's server-side event rules do not apply to Measurement Protocol traffic at all:

> "Rules for generating or renaming events aren't triggered by events sent with the Measurement Protocol."
> — `.../protocol/ga4`

That sentence rules out two things a reader might otherwise plan: deriving a second event from an MP-sent
event via an event-creation rule, and renaming an MP-sent event via an event-modification rule. See the
caveat on §10.2.

---

## 2. Request body — full field reference

All rows from `.../protocol/ga4/reference?client_type=gtag` (the web/gtag variant) unless noted.

### 2.1 Top-level fields

| Field | Type | Req. | Constraints | Notes (doc-stated) |
|---|---|---|---|---|
| `client_id` | string | **Required** | two accepted formats — see §3 | "Identifier for a user instance of a web client." |
| `user_id` | string | Optional | "Can include only utf-8 characters"; 256 chars max (answer/9267744, answer/9213390) | must not contain data a third party could use to identify the user |
| `timestamp_micros` | number | Optional | Unix **microseconds**; backdating ≤ 72 h | see §4 |
| `user_properties` | object | Optional | ≤ 25 per request; names ≤ 24 chars; values ≤ 36 chars | nested `{ "name": { "value": … } }` — see §6 |
| `user_data` | object | Optional | not detailed on fetched pages | "User-provided data." |
| `consent` | object | Optional | keys `ad_user_data`, `ad_personalization`; values `GRANTED` / `DENIED` | see §6 |
| `non_personalized_ads` | boolean | Optional | **Deprecated** | "Use the `ad_personalization` field of `consent` instead." |
| `user_location` | object | Optional | `city`, `region_id`, `country_id`, `subcontinent_id`, `continent_id` | "Sets the geographic information for the request in a structured format." |
| `ip_override` | string | Optional | — | "IP address Google Analytics uses to derive geographic information for the request." |
| `device` | object | Optional | `category`, `language`, `screen_resolution`, `operating_system`, `operating_system_version`, `model`, `brand`, `browser`, `browser_version` | "Sets the device information for the request in a structured format." |
| `user_agent` | string | Optional | — | "Provides a user agent for Google Analytics to use to derive device information." |
| `validation_behavior` | string | Optional | `RELAXED` (default) or `ENFORCE_RECOMMENDATIONS` | see §2.4 |
| `events[]` | array | **Required** | ≤ 25 events per request | "An array of `event` items." |

App-stream equivalents (do not use for a web stream): `app_instance_id` replaces `client_id`;
`firebase_app_id` replaces the `measurement_id` query param.

### 2.2 `events[]` and `events[].params`

| Field | Type | Req. | Constraints | Notes |
|---|---|---|---|---|
| `events[].name` | string | **Required** | ≤ 40 chars; alphanumeric + underscores only; must start with an alphabetic character; case sensitive | reserved names in §7.4 |
| `events[].params` | object | Optional | ≤ 25 params per event; names ≤ 40 chars; values ≤ 100 chars (500 on GA 360) | reserved prefixes in §7.4 |

> "must be 40 characters or fewer, can only contain alphanumeric characters and underscores, and must start
> with an alphabetic character"
> — `.../protocol/ga4/sending-events`

> "Event names are case sensitive. For example, `my_event` and `My_Event` are distinct events. … Event names
> must start with a letter. Use only letters, numbers, and underscores. Don't use spaces."
> — `support.google.com/analytics/answer/13316687`

Documented common params inside `events[].params`:

| Param | Type | Constraint | Doc statement |
|---|---|---|---|
| `session_id` | string/number | **must match `^\d+$`** | include it to align the MP event with a specific session |
| `engagement_time_msec` | number | — | "duration of user engagement in milliseconds" |
| `timestamp_micros` | number | microseconds | "The Unix epoch time, in microseconds, for the event." (per-event; overrides top-level) |
| `debug_mode` | boolean / `1` | presence-based | routes the event to DebugView — see §9 |

> "To ensure accurate session and user engagement metrics in your reports…include the `session_id` and
> `engagement_time_msec` parameters"
> — `.../protocol/ga4/reference?client_type=gtag`

> "While `session_start` is a reserved event name, creating a new `session_id` creates a new session without
> the need to send `session_start`."
> — `.../protocol/ga4/sending-events?client_type=gtag`

> "When session-based Measurement Protocol events are reported as '(not set) / (not set),' send the
> `session_id` parameter with a valid value from the client-side event."
> — `support.google.com/analytics/answer/9900444`

### 2.3 Verbatim full web/gtag body

```json
{
  "client_id": "CLIENT_ID",
  "events": [
    {
      "name": "tutorial_begin",
      "params": {
        "session_id": "SESSION_ID",
        "engagement_time_msec": 100
      }
    },
    {
      "name": "join_group",
      "params": {
        "group_id": "G_12345",
        "session_id": "SESSION_ID",
        "engagement_time_msec": 150
      }
    }
  ],
  "user_location": {
    "city": "Mountain View",
    "region_id": "US-CA",
    "country_id": "US",
    "subcontinent_id": "021",
    "continent_id": "019"
  },
  "device": {
    "category": "mobile",
    "language": "en",
    "screen_resolution": "1280x2856",
    "operating_system": "Android",
    "operating_system_version": "14",
    "model": "Pixel 9 Pro",
    "brand": "Google",
    "browser": "Chrome",
    "browser_version": "136.0.7103.60"
  }
}
```
— `.../protocol/ga4/sending-events`

Minimal form from the same page:

```json
{
  "client_id": "CLIENT_ID",
  "events": [
    {
      "name": "login",
      "params": {
        "method": "Google",
        "session_id": "SESSION_ID",
        "engagement_time_msec": 100
      }
    }
  ]
}
```

### 2.4 `validation_behavior`

| Value | Doc statement | Source |
|---|---|---|
| `RELAXED` (default) | "Only rejects requests that are malformed…ignores parameters that exceed limits." | `.../ga4/reference` |
| `ENFORCE_RECOMMENDATIONS` | "Rejects event parameters not correct type or exceeding limits…rejects timestamps not within 72 hours." | `.../ga4/reference` |

The reference page also states the field "defaults to `RELAXED`". The RELAXED/ENFORCE wording above was
captured as a paraphrase on one fetch and as a defaults statement on another; the exact sentences were not
recovered verbatim in a single read. Treat the ignore-vs-reject distinction as doc-stated but unverified word
for word. The docs also do not state whether `ENFORCE_RECOMMENDATIONS` is honored or silently ignored on the
**production** endpoint.

---

## 3. `client_id`

### 3.1 What it is

> "**Required**. Identifier for a user instance of a web client. The Measurement Protocol accepts either of
> the following formats for the `client_id` field:
>
> *   **Recommended:** Two positive numbers, joined by a period (`.`).
>     *   If you're using gtag.js, use [gtag.js('get')](/gtagjs/reference/api#get) to get this value. See
>         [Send event to the Measurement Protocol](/gtagjs/reference/api#get_mp_example).
>     *   If you're using Google Tag Manager:
>         *   In most cases, use the [Analytics Client ID](https://support.google.com/tagmanager/answer/7182738#utilities) built-in variable.
>         *   If you need to retrieve the `client_id` within a [custom template](/tag-platform/tag-manager/templates), use the [readAnalyticsStorage](/tag-platform/tag-manager/templates/api#readanalyticsstorage) API.
> *   A [client ID cookie](//support.google.com/analytics/answer/11397207).
>
>     Send the full value of the cookie."
> — `.../protocol/ga4/reference?client_type=gtag`

| Accepted format | Shape | Note |
|---|---|---|
| Recommended | two positive numbers joined by `.` | e.g. what `gtag('get', …, 'client_id')` returns |
| Alternative | **the full value of the client ID cookie** | "Send the full value of the cookie" — no stripping documented |

> "you use the `measurement_id` in the request URL and the `client_id` in the JSON body to identify the user
> instance. The `client_id` should match the ID generated by the Google Analytics tag on your website."
> — `.../protocol/ga4/sending-events`

### 3.2 Relationship to the `_ga` cookie — and the segment question

The MP reference's "client ID cookie" link points at `support.google.com/analytics/answer/11397207`, which
names the cookie:

| Cookie | Expiration | Purpose | Source |
|---|---|---|---|
| `_ga` | 2 years | "Used to distinguish users." | answer/11397207 |
| `_ga_<container-id>` | 2 years | "Used to persist session state." | answer/11397207 |

> "Google Analytics stores a client ID in a first-party cookie named `_ga` to distinguish unique users and
> their sessions on your website. … Analytics doesn't store the client ID when analytics storage is
> deactivated through Consent Mode."
> — `support.google.com/analytics/answer/11593727`

> "On a website, device ID gets its value from the client ID property of the `_ga` cookie. … Currently, there
> is no character limit for the client ID and the resulting device ID."
> — `support.google.com/analytics/answer/9356035`

**Which dot-separated segments are the client_id: NOT DOCUMENTED.** No page reachable on
`developers.google.com` or `support.google.com` states the `GA1.1.XXXXXXXXX.YYYYYYYYY` structure of the `_ga`
cookie value, or that the last two dot-separated segments are the client ID. answer/11397207, answer/9356035,
answer/11593727, the gtag config reference, and `business.safety.google/adscookies/` all name the cookie
without describing its value layout. The page that historically carried that layout,
`developers.google.com/analytics/devguides/collection/analyticsjs/cookies-user-id`, now 404s with an explicit
notice that Universal Analytics sunset July 1, 2024. **Do not cite Google for the `GA1.1` segment split.**

What *is* doc-stated, and is what the protocol requires: the MP reference accepts the **full cookie value** as
a legal `client_id`, so segment parsing is not required by the docs at all.

### 3.3 How the docs say to obtain it

The only documented sources are browser-side; the doc's own example is titled "Send event to the Measurement
Protocol" and ships the value to a server function:

```js
gtag('get', 'G-XXXXXXXXXX', 'client_id', (clientID) => {
      sendOfflineEvent(clientID, "tutorial_begin")
    });

    function sendOfflineEvent(clientID, eventName, eventData) {
      // Send necessary data to your server...
    }
```
— `developers.google.com/gtagjs/reference/api`

Fields retrievable via `gtag('get')`:

| Field | Supported targets |
|---|---|
| `client_id` | Google Analytics 4 |
| `session_id` | Google Analytics 4 |
| `session_number` | Google Analytics 4 |
| `gclid` | Google Ads, Floodlight |

— `developers.google.com/gtagjs/reference/api`

**No server-side generation method is documented.** The docs never state whether a backend may synthesize a
`client_id`, nor what attribution consequence that has.

### 3.4 Scoping

| Question | Doc position |
|---|---|
| Scoped to a data stream / property? | **Not stated by any fetched page.** `support.google.com/analytics/answer/12332343` (Stream ID) defines stream ID and never mentions `client_id`. |
| Scoped to a browser? | "Pseudonymously identifies a browser instance, stored in first-party Analytics cookies with two-year expiration" — `.../collection/ga4/reference/config` |
| Scoped to a domain? | **Write side, doc-stated:** `cookie_domain` defaults to `'auto'` = eTLD+1, so `example.com` and `subdomain.example.com` both write the cookie on `example.com` — `.../collection/ga4/reference/config`. **Read side, INFERENCE — not a doc sentence:** that all subdomains of one registrable domain therefore read the same `_ga` cookie and present the same `client_id` follows from that default but is stated on no fetched page; recorded as a gap. Across **root** domains, doc-stated: "new cookies with new IDs are created for each domain a user visits" unless cross-domain measurement passes the ID via the `_gl` URL parameter — answer/10071811 |
| Cookie name fixed? | No — gtag `cookie_prefix` "Prepends a prefix to analytics cookie names" — `.../collection/ga4/reference/config` |
| Cookie lifespan | `cookie_expires` default 63072000 s (2 years); `cookie_update` default true, so expiry refreshes on each hit. Browsers cap first-party cookie lifespan without a return visit: **400 days Chrome, 7 days Safari** — answer/11397207 |

### 3.5 What GA4 does with an unrecognized `client_id`

**Not documented.** No fetched page states what happens to an unknown, malformed, or fabricated `client_id` —
no documented error, no documented drop behavior, no documented rejection. The troubleshooting page's only
`client_id` guidance is to send the right identifier for the stream type ("Include this ID in the POST body
for the request. This ID uniquely identifies a given user instance of a web client."). The validation server
does not list `client_id` among what it checks, so a `debug/mp/collect` clean response does not prove a
`client_id` is acceptable.

What is stated about the join:

> "Measurement Protocol events are joined with online interactions using `client_id` or `app_instance_id`. …
> If you want a Measurement Protocol event to reflect geographic and device information from a _specific_
> session instead of the latest information for the `client_id` or `app_instance_id`, then include
> `session_id` in the event and send it to Measurement Protocol within 24 hours of the start of the session."
> — `.../protocol/ga4`

That statement covers **geographic and device** information. No fetched page states what happens to
traffic-source or campaign attribution for an MP event, nor what happens when no prior interaction exists for
the `client_id`.

---

## 4. `timestamp_micros`

| Property | Value | Source |
|---|---|---|
| Unit | **microseconds**, explicitly not milliseconds | `.../ga4/reference?client_type=gtag` |
| Epoch | Unix | same |
| Required | Optional | same |
| Staleness window | **72 hours** | same |
| Per-event form | also available inside `events[].params` as `timestamp_micros`, same unit | `.../ga4/reference?client_type=gtag` |
| Precedence | "Can be overridden by `user_property` or event timestamps" | same |
| Intended use | "Should be set only to record events that happened in the past" | same |

> "**Optional**. A Unix timestamp, _microseconds_, not _milliseconds_. Represents the time of the event.
> Should be set only to record events that happened in the past. Can be overridden by `user_property` or event
> timestamps. Events can be backdated up to 72 hours."
> — `.../protocol/ga4/reference?client_type=gtag`

### Consequence of exceeding 72 hours

The event is **not rejected** under default validation — the timestamp is silently moved to the boundary:

> "Events backdatable up to 72 hours; if older, timestamp overridden to the 72-hour mark (unless
> `validation_behavior` set to `ENFORCE_RECOMMENDATIONS`)"
> — `.../protocol/ga4/sending-events`

Under `ENFORCE_RECOMMENDATIONS` the reference states the request "rejects timestamps not within 72 hours".

### A tighter, separate window for joining and for attribution

| Window | Applies to | Source |
|---|---|---|
| **72 hours** | maximum backdating via `timestamp_micros` | `.../ga4/reference?client_type=gtag` |
| **48 hours** | "Events should reach Google Analytics within 48 hours of original client-side timestamp for proper conversion attribution." | `.../ga4/sending-events` |
| **48 hours** | "Events sent using the Measurement Protocol that are intended to be joined or processed in conjunction with events collected by the Google Analytics for Firebase SDK or gtag.js should be received by Google Analytics within 48 hours of the original client-side event timestamp." | `.../ga4/sending-events?client_type=gtag` |
| **24 hours** | to bind an MP event's geo/device info to a *specific* session, send `session_id` within 24 h of session start | `.../protocol/ga4` |

---

## 5. The `purchase` event

### 5.1 Event-level parameters

| Parameter | Type | Required | Doc statement |
|---|---|---|---|
| `currency` | string | **Yes\*** | "Currency of the items associated with the event, in 3-letter ISO 4217 format" |
| `value` | number | **Yes\*** | "The monetary value of the event. Set `value` to the sum of `(price * quantity)` for all items in `items`. Don't include shipping or tax." |
| `transaction_id` | string | **Yes** | "The unique identifier of a transaction. The `transaction_id` parameter helps you avoid getting duplicate events for a purchase." |
| `items` | Array\<Item\> | **Yes** | up to 200 elements |
| `coupon` | string | No | — |
| `shipping` | number | No | — |
| `tax` | number | No | — |
| `customer_type` | string | No | — |

— `developers.google.com/analytics/devguides/collection/ga4/reference/events`

**The `Yes*` footnote**, verbatim: "If you set `value` then `currency` is required for revenue metrics to be
computed accurately." This is the **only** per-parameter omission consequence stated anywhere on the fetched
pages.

Additional currency rules:

> "Set `currency` at the event level when sending `value` (revenue) data."
> — `.../collection/ga4/ecommerce`

> "Transaction ID. Required for purchases and refunds."
> — `.../collection/ga4/ecommerce`

> "Set each ecommerce parameter you have data for, regardless of whether the parameter is optional. / To
> ensure data populates properly in reports, follow the format in this document."
> — `.../collection/ga4/ecommerce`

**Key-event / Google Ads rule on `value`** (this one has a hard consequence):

> "The `value` parameter must be a number (e.g., `50`) and must be accompanied by a `currency` parameter … If
> the parameter is missing or invalid, the event is recorded with the correct count, but it won't be sent to
> Google Ads."
> — `support.google.com/analytics/answer/12844695`

### 5.2 Verbatim `purchase` sample and the `items` shape

```js
gtag("event", "purchase", {
        transaction_id: "T_12345",
        // Sum of (price * quantity) for all items.
        value: 72.05,
        tax: 3.60,
        shipping: 5.99,
        currency: "USD",
        coupon: "SUMMER_SALE",
        customer_type: "new",
        items: [
         {
          item_id: "SKU_12345",
          item_name: "Stan and Friends Tee",
          affiliation: "Google Merchandise Store",
          coupon: "SUMMER_FUN",
          discount: 2.22,
          index: 0,
          item_brand: "Google",
          item_category: "Apparel",
          item_category2: "Adult",
          item_category3: "Shirts",
          item_category4: "Crew",
          item_category5: "Short sleeve",
          item_list_id: "related_products",
          item_list_name: "Related Products",
          item_variant: "green",
          location_id: "ChIJIQBpAG2ahYAR_6128GcTUEo",
          price: 10.01,
          google_business_vertical: "retail",
          quantity: 3
        },
        // ... additional items
        ]
    });
```
— `developers.google.com/analytics/devguides/collection/ga4/reference/events`

| Item field set (doc-listed) |
|---|
| `item_id`, `item_name`, `affiliation`, `coupon`, `discount`, `index`, `item_brand`, `item_category`, `item_category2`, `item_category3`, `item_category4`, `item_category5`, `item_list_id`, `item_list_name`, `item_variant`, `location_id`, `price`, `quantity` |

| Items constraint | Value | Source |
|---|---|---|
| Max elements | 200 | `.../collection/ga4/ecommerce` |
| Item-scoped custom parameters | up to 27 | answer/9267744 |
| Per-item required fields | **not stated on the fetched pages** — `items` itself is marked Required, but no item-level required marking rendered | gap |

### 5.3 `transaction_id` deduplication

| Statement | Source |
|---|---|
| "Google Analytics deduplicates purchase events with the same transaction ID." | answer/12313109 |
| "Transaction ID deduplication only works for data collected through **web streams, not app streams**." | answer/12313109 |
| "Don't send an empty string as the transaction ID. Google Analytics will deduplicate all purchase events that have `transaction_id=\"\"`." | answer/12313109 |
| "If your tag sends Google Analytics the same ID for different transactions, you could significantly undercount your key events. / The same transaction ID shouldn't be used across different users." | answer/12313109 |
| Deduplication time window | **not documented** — no 24-hour or other window stated |
| Whether MP-delivered purchases dedupe the same way | **not documented** — the only statement is the web-stream/app-stream one above |

### 5.4 What a custom event name forfeits versus `purchase`

Doc-stated, positively framed only:

| Statement | Source |
|---|---|
| "Recommended: Standardized events for different business verticals … that unlock prebuilt reporting panels. Examples: `purchase`, `login`, `sign_up`. / Custom: Events that you define yourself because no prepopulated automatic, enhanced, or recommended event fits your needs. Accessible using custom reports." | `.../collection/ga4/events` |
| "You should send recommended events with their prescribed parameters to get the most details in your reports and to benefit from future features and integrations." | answer/9267735 |
| ecommerce events populate the *Ecommerce purchases* report; lead-generation events populate the *Lead acquisition* report | answer/9267735 |
| "It's always better to use an existing event because these events automatically populate dimensions and metrics that are used in your reports." | answer/12229021 |
| "if you mark the event as a key event then it's recommended you set `value`" | `.../protocol/ga4/reference/events` |

**No official page states that a custom event name is forbidden or that it is excluded from standard reports.**
The claim "a custom event name forfeits revenue/ecommerce reports" is an inference from the sentences above,
not a doc statement. Recorded as a gap.

Recommended event names by vertical (`support.google.com/analytics/answer/9267735`):

| Vertical | Events |
|---|---|
| All properties | `ad_impression`, `earn_virtual_currency`, `generate_lead`, `join_group`, `login`, `purchase`, `refund`, `search`, `select_content`, `share`, `sign_up`, `spend_virtual_currency`, `tutorial_begin`, `tutorial_complete` |
| Online sales | `add_payment_info`, `add_shipping_info`, `add_to_cart`, `add_to_wishlist`, `begin_checkout`, `purchase`, `refund`, `remove_from_cart`, `select_item`, `select_promotion`, `view_cart`, `view_item`, `view_item_list`, `view_promotion` |
| Lead generation | `generate_lead`, `qualify_lead`, `disqualify_lead`, `working_lead`, `close_convert_lead`, `close_unconvert_lead` |

**No subscription-specific recommended event name exists** — no `subscribe`, `subscription`, `trial_start`, or
`renewal` appears in any vertical list on that page. (Absence established by a complete read of the vertical
lists, not by an explicit doc statement that none exists.)

The two official pages disagree on the All-properties list: the help article includes `ad_impression`,
`generate_lead`, `purchase`, and `refund` under All properties; the developer reference's All-properties
section lists only `earn_virtual_currency`, `join_group`, `login`, `search`, `select_content`, `share`,
`sign_up`, `spend_virtual_currency`, `tutorial_begin`, `tutorial_complete`.

---

## 6. `consent` and `user_properties`

### 6.1 `consent`

| Key | Type | Required | Allowed values | Doc description |
|---|---|---|---|---|
| `ad_user_data` | string | Optional | `GRANTED` / `DENIED` | "Consent for sending user data from the request's events and user properties to Google for advertising purposes." |
| `ad_personalization` | string | Optional | `GRANTED` / `DENIED` | "Consent for personalized advertising for the user." |

— `.../protocol/ga4/reference?client_type=gtag`

```json
"consent": {
  "ad_user_data": "GRANTED",
  "ad_personalization": "GRANTED"
}
```

**Default when omitted:**

> "If you don't specify `consent`, Google Analytics uses the consent settings from corresponding online
> interactions for the client or app instance."
> — `.../protocol/ga4/reference?client_type=gtag`

No hardcoded granted/denied default is stated, and the docs do not say what applies when there are **no**
corresponding online interactions for that `client_id`.

**Case:** MP uses uppercase `GRANTED`/`DENIED`. gtag.js consent mode uses lowercase `'granted'`/`'denied'`:

```js
gtag('consent', 'default', {
  'ad_storage': 'denied',
  'ad_user_data': 'denied',
  'ad_personalization': 'denied',
  'analytics_storage': 'denied'
});
```
— `developers.google.com/tag-platform/security/guides/consent`

The docs do not state whether MP accepts the lowercase form, nor what an invalid value does.

**Only two consent keys exist in the MP payload.** The other consent-mode types are browser-side gtag.js
types, not MP payload keys: `ad_storage`, `analytics_storage`, `functionality_storage`,
`personalization_storage`, `security_storage`
(`developers.google.com/tag-platform/security/concepts/consent-mode`).

`non_personalized_ads` (top-level boolean) is **deprecated**: "Use the `ad_personalization` field of `consent`
instead."

### 6.2 `user_properties`

Exact nesting — each property name maps to an **object with a `value` key**, never a bare scalar:

```json
"user_properties": {
    "customer_tier": {
      "value": customerTierValue
    }
}
```
— `.../protocol/ga4/user-properties?client_type=gtag`

Optional per-property timestamp:

```json
"user_properties": {
    "customer_tier": {
      "value": customerTierValue,
      "timestamp_micros": customerTierUnixEpochTimeInMicros
    }
}
```
— `.../protocol/ga4/user-properties`

| Constraint | Value | Source |
|---|---|---|
| Per request | 25 max | `.../ga4/reference?client_type=gtag` |
| Per project (registration cap, different scope) | "up to 25 additional user properties per project" | `.../ga4/user-properties?client_type=gtag` |
| Name length | ≤ 24 characters | `.../ga4/reference?client_type=gtag` |
| Value length | ≤ 36 characters | `.../ga4/reference?client_type=gtag` |
| Reserved names | `first_open_time`, `first_visit_time`, `last_deep_link_referrer`, `user_id`, `first_open_after_install` | `.../ga4/reference#reserved_names` |
| Reserved prefixes | `_` (underscore), `firebase_`, `ga_`, `google_` | `.../ga4/reference#reserved_names` |
| Persistence | "Google Analytics uses the most recent value of a user property for each user" | `.../ga4/user-properties` |

Note that `user_id` is reserved as a **user property name**; the user ID is sent as a top-level payload field,
not inside `user_properties`.

The two count limits (25 per request vs 25 per project) are stated with different scopes and are not
reconciled by the docs.

---

## 7. Limits and quotas

### 7.1 Request and payload

| Limit | Value | Source |
|---|---|---|
| JSON POST body size | **< 130 kB** | `.../ga4/reference?client_type=gtag` |
| Events per request | 25 | `.../ga4/reference?client_type=gtag` |
| Parameters per event | 25 | `.../ga4/reference?client_type=gtag` |
| User properties per request | 25 | `.../ga4/reference?client_type=gtag` |
| Event name length | 40 characters | `.../ga4/reference?client_type=gtag` |
| Parameter name length | 40 characters | `.../ga4/reference?client_type=gtag` |
| Parameter value length | 100 characters (standard) / 500 characters (GA 360) | `.../ga4/reference?client_type=gtag` |
| Parameter value exceptions | `page_title` 300, `page_referrer` 420, `page_location` 1,000 | answer/9267744 |
| User property name length | 24 characters | `.../ga4/reference?client_type=gtag` |
| User property value length | 36 characters | `.../ga4/reference?client_type=gtag` |
| User-ID value length | 256 characters | answer/9267744, answer/9213390 |
| `items` array elements | 200 | `.../collection/ga4/ecommerce` |
| Item-level custom parameters | 27 | answer/9267744 |
| Backdating window | 72 hours | `.../ga4/reference?client_type=gtag` |

**The one limit with a stated over-limit consequence** — parameters per event:

> "Make sure your Google Analytics events don't exceed the limit of 25 parameters per event. This may cause the
> event value to be dropped, leading to inconsistencies between client-side and server-side properties."
> — `support.google.com/analytics/answer/12229021`

Every other limit in this table has **no** stated consequence for exceeding it (see §7.7).

### 7.2 Rate

| Limit | Value | Source |
|---|---|---|
| Non-conversion requests per hour, per property | **100,000,000** | `.../ga4/sending-events?client_type=gtag` |

> "You can send at most 100 million non-conversion requests per hour for each property, where a request is a
> non-conversion request if none of the events in the request is a key event for which there is a conversion in
> Google Ads."
> — `.../protocol/ga4/sending-events`

No per-second, per-minute, or burst limit is stated. No documented 429, no `Retry-After`, no backoff guidance,
no separate quota for conversion requests. `.../protocol/ga4/limitations` returns **HTTP 404** — there is no
published MP limitations page at that path.

### 7.3 Per-user collection ceilings (`support.google.com/analytics/answer/9267744`)

| Ceiling | Value |
|---|---|
| Events per user per day | 100,000 |
| Conversions per user per day | 10,000 |
| Distinct sessions per user per day | 2,000 |
| Distinctly named events | no limit for **web** data streams (500 per app user for app streams) |

The docs do not state whether these ceilings apply to Measurement Protocol traffic specifically or only to
on-device collection.

### 7.4 Reserved names (`.../protocol/ga4/reference#reserved_names`)

| Kind | Values |
|---|---|
| Reserved **event** names | `ad_activeview`, `ad_click`, `ad_exposure`, `ad_query`, `ad_reward`, `adunit_exposure`, `app_clear_data`, `app_exception`, `app_install`, `app_remove`, `app_store_refund`, `app_update`, `app_upgrade`, `dynamic_link_app_open`, `dynamic_link_app_update`, `dynamic_link_first_open`, `error`, `firebase_campaign`, `firebase_in_app_message_action`, `firebase_in_app_message_dismiss`, `firebase_in_app_message_impression`, `first_open`, `first_visit`, `notification_dismiss`, `notification_foreground`, `notification_open`, `notification_receive`, `notification_send`, `os_update`, `session_start`, `user_engagement` |
| App-stream only | `ad_impression`, `in_app_purchase`, `screen_view` |
| Reserved **parameter** name | `firebase_conversion` |
| Reserved **parameter** prefixes | `_` (underscore), `firebase_`, `ga_`, `google_`, `gtag.` |
| Reserved **user property** names | `first_open_time`, `first_visit_time`, `last_deep_link_referrer`, `user_id`, `first_open_after_install` |
| Reserved **user property** prefixes | `_` (underscore), `firebase_`, `ga_`, `google_` |

> "Some event and parameter names are reserved for use through automatic collection and cannot be sent through
> the Measurement Protocol."
> — `.../protocol/ga4`

### 7.5 Other stated limits

| Limit | Value | Source |
|---|---|---|
| Key events per property | 30 standard / 50 GA 360 | answer/13128484 |
| API secrets per data stream | 10 | answer/9814495 |
| Properties per account | 2,000 | answer/9744165 |
| Cross-domain conditions | 100 | answer/10071811 |
| User-scoped custom dimensions | 25 standard / 100 GA 360 | answer/10075209 |
| Event-scoped custom dimensions | 50 standard / 125 GA 360 | answer/10075209 |
| Item-scoped custom dimensions | 10 standard / 25 GA 360 | answer/10075209 |
| Custom metrics | 50 standard / 125 GA 360 | answer/10075209 |
| Calculated metrics | 5 standard / 50 GA 360 | answer/10075209 |
| Custom dimension slot reuse | 48-hour wait after deleting before adding | answer/10075209 |

### 7.6 Data retention (`support.google.com/analytics/answer/7667196`)

| Data | Options |
|---|---|
| User-level data and key events | 2 months, 14 months |
| All other event data | 2 months, 14 months, 26 months (360 only), 38 months (360 only), 50 months (360 only) |

> "The data retention setting does not affect standard aggregated reports (including primary and secondary
> dimensions)"

Age, gender, and interest data are always retained 2 months regardless of the setting; Google signed-in data
expires after 26 months. UI path: **Admin > PROPERTY column > Data Settings > Data Retention**.

### 7.7 What the docs do NOT say about limit violations

For every limit **except parameters-per-event**, the docs never state whether a payload that exceeds it
(26 events, a 41-character event name, a 101-character parameter value) drops the **offending item** or the
**entire request**. The one exception is the 25-parameters-per-event limit, where answer/12229021 states the
event *value* "may" be dropped (quoted in §7.1) — and even there, "may" is the doc's own hedge and nothing is
said about the rest of the event. Under `RELAXED` the
reference says over-limit parameters are ignored; under `ENFORCE_RECOMMENDATIONS` it says the request is
rejected. Nothing is stated about what happens when the 100M/hour rate limit is exceeded.

---

## 8. Policy — what must NOT be sent

| Rule | Verbatim | Source |
|---|---|---|
| No data identifying an individual | "You must not upload any data that allows Google to personally identify an individual (such as certain names, Social Security Numbers, email addresses, or any similar data)" | `.../protocol/ga4/policy` |
| No permanent device identifiers | "data that permanently identifies a particular device (such as a unique device identifier if such an identifier cannot be reset)" | `.../protocol/ga4/policy` |
| No un-consented session stitching | "You must not session stitch authenticated and unauthenticated sessions of your end users unless your end users have consented" | `.../protocol/ga4/policy` |
| Rights and notice | "You must have the full rights to use this service, including the necessary authorizations from both the rights holder(s) of the data you transmit … You must give your end users proper notice about the implementations and features of Google Analytics that you use" | `.../protocol/ga4/policy` |
| Blanket PII mandate | "Google policies mandate that no data be passed to Google that Google could use or recognize as personally identifiable information (PII)." | answer/6366371 |
| PII examples | "PII includes, but is not limited to, information such as email addresses, personal mobile numbers, and social security numbers." Also names, non-resettable device identifiers, and fine-grained location (areas under 1 square mile or specific zip codes) | answer/6366371 |
| `user_id` constraint | "Your user ID must not contain information that a third party could use to determine a user's identity." | answer/9213390 |
| `user_id` responsibility | "You're responsible for ensuring that your use of the user ID is in accordance with the Google Analytics Terms of Service. This includes avoiding the use of impermissible personally identifiable information, and providing appropriate notice of your use of identifiers in your Privacy Policy." | answer/9213390 |
| Blank/dummy `user_id` | "Repeatedly setting a blank or dummy user ID can lead to inaccurate data (including permanent data loss) and hinder your ability to analyze user activity." | answer/9213390 |
| Cardinality | "Setting custom dimensions based on user IDs leads to dimensions with too many unique values...causes issues with Google Analytics data and reporting accuracy." High-cardinality dimensions "may negatively impact your reports and explorations, and cause data to be condensed under the (other) row" | `.../collection/ga4/user-id`, answer/10075209 |

### Consequence

> "Violations of this policy may result in termination of your Google Analytics account(s) and loss of your
> Google Analytics data"
> — `.../protocol/ga4/policy`

This is the **only** page fetched that states an enforcement consequence. answer/6366371 states the mandate
without a consequence.

No page fetched states an explicit rule that `user_id` may not be an email address (the connection runs
through the general PII prohibition), and no hashing guidance, salt requirement, or statement on whether a
hashed email is acceptable was found on any fetched page.

---

## 9. Validation and verification

### 9.1 The debug endpoint

```
https://www.google-analytics.com/debug/mp/collect?measurement_id=MEASUREMENT_ID&api_secret=API_SECRET
```
— `.../protocol/ga4/validating-events?client_type=gtag`

App variant: `?firebase_app_id=FIREBASE_APP_ID&api_secret=API_SECRET`

> "All other request fields are the same"
> — `.../protocol/ga4/validating-events?client_type=gtag`

**It does not record.**

> "Events sent to the validation server don't show up in reports."
> — `.../protocol/ga4/validating-events`

**It does not check the credentials.**

> "The validation server does *not* validate the `api_secret` or `firebase_app_id`."
> — `.../protocol/ga4/validating-events`

> "The validation server does not verify `api_secret` or `measurement_id` values. Carefully review those
> values to make sure they are correct."
> — `.../protocol/ga4/validating-events?client_type=gtag`

Strict checks are opt-in:

> "Use strict validation checks during development using either of the following options: Validate requests
> with the Event Builder. Send requests to the validation server with `validation_behavior` set to
> `ENFORCE_RECOMMENDATIONS`."
> — `.../protocol/ga4/validating-events`

Verbatim debug request (web/gtag):

```js
const measurementId = "MEASUREMENT_ID";
const apiSecret = "API_SECRET";

fetch(`https://www.google-analytics.com/debug/mp/collect?measurement_id=${measurementId}&api_secret=${apiSecret}`, {
  method: "POST",
  headers: {
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    client_id: "CLIENT_ID",
    validation_behavior: "ENFORCE_RECOMMENDATIONS",
    events: [{
      name: "level_up",
      params: {
        level: 2,
        character: "MyHero"
      }
    }]
  })
});
```
— `.../protocol/ga4/validating-events?client_type=gtag`

### 9.2 Response shape, verbatim

```json
{
  "validationMessages": [
    {
      "fieldPath": "string",
      "description": "string",
      "validationCode": "string"
    }
  ]
}
```
— `.../protocol/ga4/validating-events`

Concrete example:

```json
{
  "validationMessages": [
    {
      "fieldPath": "events",
      "description": "Event at index: [0] has invalid name [_badEventName]. Names must start with an alphabetic character.",
      "validationCode": "NAME_INVALID"
    }
  ]
}
```
— `.../protocol/ga4/validating-events?client_type=gtag`

| Field | Doc description |
|---|---|
| `fieldPath` | "The path to the field that was invalid" |
| `description` | "A description of the error" |
| `validationCode` | "A code corresponding to the error type" |

| `validationCode` | Doc description |
|---|---|
| `VALUE_INVALID` | "The value provided for a fieldPath was invalid" |
| `VALUE_REQUIRED` | "A required value for a fieldPath was not provided" |
| `NAME_INVALID` | "The name provided was invalid" |
| `NAME_RESERVED` | "The name provided was one of the reserved names" |
| `VALUE_OUT_OF_BOUNDS` | "The value provided was too large" |
| `EXCEEDED_MAX_ENTITIES` | "There were too many parameters in the request" |
| `NAME_DUPLICATED` | "The same name was provided more than once" |

The doc does not state that this list is exhaustive. `INTERNAL_ERROR` does **not** appear on the page — do not
code against it as a documented value.

### 9.3 DebugView

Two parameters inside `events[].params` route an event to DebugView: `debug_mode` and `engagement_time_msec`.

> "enable debug mode in some test events by including the following parameters in the params collection so you
> can monitor and review the events in DebugView"
> — `.../protocol/ga4/verify-implementation`

Verbatim web/gtag DebugView payload:

```json
{
  "client_id": "CLIENT_ID",
  "events": [{
    "name": "refund",
    "params": {
      "currency": "USD",
      "value": "9.99",
      "transaction_id": "ABC-123",
      "engagement_time_msec": 1200,
      "debug_mode": true
    }
  }]
}
```
— `.../protocol/ga4/verify-implementation?client_type=gtag`

| Fact | Statement | Source |
|---|---|---|
| Disabling | "setting the parameter to false doesn't disable debug mode" — remove the parameter entirely | answer/7201382 |
| UI path | **Admin > Data display > DebugView** | answer/7201382 |
| Time streams | Seconds stream = last 60 seconds; Minutes stream = archives of the last 30 minutes | answer/7201382 |
| Attribution caveat | "Like the Realtime report, the DebugView report performs limited attribution analysis" | answer/7201382 |

### 9.4 Realtime and standard-report latency

| Surface | Latency | Source |
|---|---|---|
| Realtime report (**Reports > Realtime**) | "Events typically show up within a few seconds" | `.../protocol/ga4/verify-implementation` |
| Realtime (freshness page) | "Typically a few minutes" | answer/11198161 |
| Standard intraday | 2–6 hours | answer/11198161 |
| Standard daily | 12 hours | answer/11198161 |
| 360 intraday | ~1 hour | answer/11198161 |
| Processing | "Data processing can take 24-48 hours. During that time, data in your reports may change." | answer/11198161 |
| Newly marked key event → standard reports | up to 24 hours | answer/13128484 |

Those figures are "typical times", explicitly "not a guarantee, nor an SLA or an SLO" (answer/11198161).
Neither Measurement Protocol page states standard-report latency; the 24–48 hour figure comes from the
separate Data freshness help page.

### 9.5 Verification order, and what to do when the event does not appear

The two facts that make an explicit procedure necessary are already established above: production returns 2xx
for anything it receives (§1.3), and the validation server "does not verify `api_secret` or `measurement_id`
values" (§9.1). Together they mean a wrong credential pair produces a clean debug response **and** a 2xx from
production, with the events landing in another property or nowhere. Run the steps in this order:

| # | Step | What it proves |
|---|---|---|
| 1 | POST the payload to `/debug/mp/collect` and require an error-free `validationMessages` response | The payload shape is valid. Proves **nothing** about the credentials, and the event was **not** recorded ("Events sent to the validation server don't show up in reports") |
| 2 | POST the same payload to production `/mp/collect` with `debug_mode: true` inside `events[].params`, and watch **Admin > Data display > DebugView** (§9.3) | The event was received and attributed to the property whose credentials you used |
| 3 | If nothing appears in DebugView, check **Reports > Realtime** for the event name | Guards against the DebugView device-picker question, which the docs do not address (§11) |

**Wait bound before concluding the send failed.** The docs give two conflicting Realtime figures — "Events
typically show up within a few seconds" (`.../protocol/ga4/verify-implementation`) and "Typically a few
minutes" (answer/11198161). No page reconciles them and no page states a wait bound for concluding a send
failed. Take the **longer** of the two as the operational wait — a few minutes, and treat ~10 minutes with no
appearance as failed. That bound is a reconciliation of the two figures for operational use, **not** a doc
statement; recorded as a gap.

**If nothing appears after that wait, the credentials are the only remaining unchecked variable.** Step 1
proved the payload; step 1 explicitly did not test `api_secret` or `measurement_id`; step 2's 2xx proves
nothing. Re-read both values against the property confirmed via the property selector in §1.3.1 and §1.4 —
a pair copied from a different property produces exactly this symptom with no error anywhere.

---

## 10. Downstream — key events and Google Ads import

### 10.1 Terminology and object flow

> "A key event is an event that measures an action that's particularly important to the success of your
> business. … A conversion is created from a Google Analytics event and provides a consistent way of measuring
> important actions in both Google Analytics and Google Ads."
> — answer/13965727

Flow: **Event → Key Event (Analytics) → Conversion (Google Ads)**. "A linked Google Ads account is required to
create a new Google Analytics conversion from a key event." (answer/14710559)

### 10.2 Marking a key event

| Case | Path | Role |
|---|---|---|
| Mark an existing event | **Admin > Data display > Events**, click the star icon next to it | Editor or above (property) |
| Create + mark at creation | **Admin > Data display > Events > + Create event**, name it, toggle **Mark as key event** | Marketer or above (property) |

— answer/13128484

**Caveat on the second row for a Measurement Protocol event.** GA4's "Create event" is an event-*generation*
rule, and `.../protocol/ga4` states: "Rules for generating or renaming events aren't triggered by events sent
with the Measurement Protocol" (quoted in §1.6). A derived key event built this way will therefore not fire
for an MP-sent event, and an MP-sent event cannot be renamed by a modification rule either. An MP-originated
event must be marked via the **star-icon path on the event GA4 has already received** — the first row.

**If the event name is not in the Events list.** The star-icon path presupposes a row that only exists once GA
has collected and processed the event, so a newly-invented server-sent event name will not be there on the
first look. What the fetched pages do **not** state: how long after the first send the name appears in the
Events list (the 24-hour figure below is stated about **standard reports**, not this list), and whether
"+ Create event" can pre-register a name GA has never collected — answer/13128484 as extracted does not
resolve it, and the caveat above makes it the wrong tool for an MP event regardless. Both recorded as gaps.
Operationally: send the event to production (§9.5), confirm it in DebugView, then return to the Events list.

| Fact | Statement |
|---|---|
| Cap | 30 key events (standard) / 50 (GA 360) |
| Latency | "allow for up to 24 hours for it to show in standard reports" |
| Retroactivity | "Marking an event as a key event affects reports from time of creation. It doesn't change historic data" |
| No code change needed | "you can mark the events as key events without needing to change your website or app setup" (answer/12844695) |

**Which of the two import flows to use is not stated.** §10.3 (Analytics side) and §10.4 (Google Ads side)
are two complete, different paths to the same object. No fetched page says which is recommended, whether they
are equivalent, or what results from running both — recorded as a gap. One overlap is doc-stated and matters
here: the §10.3 flow marks the events it imports as key events in Analytics ("Events selected from the
'Events' section will be marked as key events in Google Analytics"), so running §10.3 makes the §10.2 marking
redundant for those events. Whether performing both duplicates the conversion action is **not stated**.

**Prerequisites for both flows have no click path in this document.** "Link Google Analytics and Google Ads"
and "Enable auto-tagging in your Google Ads account" are hard blockers — an unlinked account makes every step
in §10.3 and §10.4 unreachable — and neither page was fetched. Recorded as gaps.

### 10.3 Import — from the Analytics side

**"Advertising" is not located by any fetched page.** Unlike **Admin** (documented as "lower left"), no
fetched page states where the Analytics-side **Advertising** section sits in the GA4 navigation, nor where
"Tools" sits within it. Recorded as a gap — verify against the live UI.

> "In Advertising, under 'Tools', select Conversion management … Click New conversion, then Next … Select the
> Google Ads account in which you want to create conversions … Select the events or key events you want to
> create as conversions in Google Ads … If prompted, select the Conversion category for your selected events
> and key events … Click Next to review your selected conversions, then Save"
> — answer/10632359

Prerequisites: "Link Google Analytics and Google Ads … Enable auto-tagging in your Google Ads account … Be an
administrator or editor of the Google Analytics property"; "at least Marketer access to import key events as
conversions into Google Ads" (answer/10632359).

"Events selected from the 'Events' section will be marked as key events in Google Analytics" — the import flow
can do the marking. Conversion actions created from Analytics land as **secondary** in Google Ads: "Google Ads
marks a conversion as 'secondary' when your Google Ads account already has goals from an Analytics property."

### 10.4 Import — from the Google Ads side

> "Go to Summary within the Goals menu … Click + Create conversion action … Select the Google Analytics
> property you'd like to use … Select the Google Analytics event that you'd like to use to measure your
> conversions, then click Select events … Click Save and continue"
> — `support.google.com/google-ads/answer/2375435`

Prerequisites: linked accounts, auto-tagging on, at least Marketer in Analytics plus admin access, and "the
Google Click Identifier (GCLID) isn't being altered or dropped by your website". The event must already be
"marked as a 'key event' in your Google Analytics property".

| Fact | Statement | Source |
|---|---|---|
| Import latency | "It can take up to 24 hours before conversion data is available in Google Ads after importing a Google Analytics key event." | google-ads/answer/2375435 |
| Picker contents | "All key events that you set up in the Google Analytics property appear in the list" | google-ads/answer/9520128 |
| Attribution inheritance | "When you select attribution to Paid and organic channels, this setting is inherited from Google Analytics settings" | google-ads/answer/9520128 |
| Google Ads data → Analytics | "It can take 48 hours for Google Ads data to appear in Analytics." | answer/13367418 |
| Reporting | "Google Ads conversions don't appear in standard Google Analytics reports" | answer/12844695 |
| Availability | "This feature may not be available to your Google Analytics property. The Google Analytics team is actively working to expand this feature to more properties." | answer/14710559 |

### 10.5 What the docs state — and do NOT state — about MP-originated events

**Stated (the only explicit exclusion found, and it is event-specific):**

> "An `ad_impression` sent using the Measurement Protocol will not be included in exports to other advertising
> platforms such as Google Ads."
> — `.../protocol/ga4/reference/events`

**Stated (the strongest positive signal, and it is indirect — a rate-limit definition):**

> "You can send at most 100 million non-conversion requests per hour for each property, where a request is a
> non-conversion request if none of the events in the request is a key event for which there is a conversion in
> Google Ads."
> — `.../protocol/ga4/sending-events`

That wording presupposes MP events can be key events with a Google Ads conversion. It is an inference from a
rate-limit definition, not an endorsement.

**NOT stated by any fetched page:**

| Open point | Status |
|---|---|
| Any general rule permitting or forbidding MP-originated events being imported into Google Ads as conversions | **Silent.** google-ads/answer/2375435, /9520128, /10632359, analytics/answer/14710559 and answer/9900444 do not mention the Measurement Protocol at all |
| Whether `gclid` must have been present on the original session for an MP conversion to attribute to a Google Ads click | **Silent.** Adjacent statements only: auto-tagging must be on and the gclid must not be "altered or dropped"; MP events join client-side data via `client_id`/`session_id`, and the overview describes that join as carrying **geographic and device** information — not traffic source or gclid |
| Whether GA4 accepts a `gclid` passed directly as an MP event parameter | **Silent** |
| Whether a newly marked key event is immediately available in the Google Ads import picker | **Silent.** Two adjacent 24-hour latencies are stated (key event → standard reports; import → Ads data) |
| Whether a conversion built from an MP-originated key event is eligible for Smart Bidding, or subject to modeling | **Silent.** Only the "secondary" default is stated |

`support.google.com/analytics/answer/11053456` ("Grow offline sales"), the page most directly about MP-sent
offline conversions, is labeled **[Legacy]** (UA→GA4) and states only: "You can import offline event data…and
associate it with the user's previous online attribution and activity (using either user ID or client ID to
join the data)."

---

## 11. Gaps — not answered by the official docs

Each item is an open question. None was filled with a guess.

**`client_id`**
- Which dot-separated segments of the `_ga` cookie value are the client ID? The `GA1.1.X.Y` layout is stated on **no** reachable Google page; the page that carried it (`.../collection/analyticsjs/cookies-user-id`) 404s with a Universal-Analytics-sunset notice. The MP reference's answer is to send the full cookie value.
- What should a backend send as `client_id` when no browser-generated GA client ID was ever captured? The docs name only browser-side sources and never address synthesis.
- What does GA4 do with an unrecognized, malformed, or fabricated `client_id` — drop, accept as a new user, or attribute to `(not set)`?
- Is a `client_id` captured on one data stream or property valid when sent to a different one?
- Does session stitching require the `client_id` to match a real prior session, and what happens when no prior interaction exists?
- Is there a character-length or charset limit on `client_id`? (answer/9356035 says "no character limit" but phrases it about the device ID dimension; only `user_id` is documented as UTF-8 only.)
- Does the **same `client_id` follow a user across subdomains** of one registrable domain — i.e. does an app subdomain present the `client_id` a marketing site captured? Only the *write* side is doc-stated (`cookie_domain: 'auto'` = eTLD+1, so both write the cookie on the registrable domain). The read-side consequence is an inference from that default, stated in no fetched sentence. This is the load-bearing question for a marketing-site-plus-app-subdomain integration (see §3.4).

**Credentials**
- What is the format of an `api_secret` (length, character set, prefix)? Never stated — read the real value from the admin UI.
- Is an `api_secret` rejected when paired with a different stream's `measurement_id`? Only the creation path implies stream scoping; no sentence states the rejection.
- Can the secret value be retrieved again after creation from the UI? No support page says one-time vs persistent display. The Admin API's `secretValue` is "Output only" on a resource with `get` and `list`, which implies API-side readability; no UI-side statement was found.
- Is `measurement_id` formally Required for web streams? Its reference row is not marked Required the way `api_secret` is.
- Is the User Data Collection Acknowledgement a one-time per-property acceptance or per-stream/per-secret? answer/9814495 says only "If necessary".

**Roles and access**
- What is the GA4 role hierarchy? Whether **Marketer** ranks above or below **Editor** is stated on no fetched page, so the procedures in §1 and §10 cannot be reduced to one "maximum role needed" entry (see §1.3.1).
- answer/10632359 states both "Be an administrator or editor of the Google Analytics property" and "at least Marketer access" in the same prerequisite block, and google-ads/answer/2375435 phrases it as "at least a Marketer role in Google Analytics and admin access". No page reconciles them.
- What does a reader see, and what should they do, when they lack the required role? Never stated — so a reader who must request access cannot state what to ask for beyond the role names in §1.3.1.
- Creating an **Analytics account** (as opposed to a property) is out of scope for this document; answer/9304153's step-1 branch to its "Create an Analytics account" section was not extracted.

**Response and error handling**
- What HTTP status does `/debug/mp/collect` return, and what does a *clean* payload look like — empty `validationMessages` array, empty body, or no key at all?
- Is the 7-value `validationCode` list exhaustive?
- Does the debug endpoint validate all 25 events in a request or stop at the first failure? Does it enforce the same rule set as production?
- Does a limit violation drop the offending item or the entire request? Unstated for **every** limit except parameters-per-event, where answer/12229021 says the event *value* "may" be dropped (§7.1) — and even there, nothing is stated about the rest of the event.
- How long should a sender wait before concluding an event never arrived? No page states a bound, and the two Realtime figures conflict ("a few seconds" vs "a few minutes"). §9.5's ~10-minute figure is a reconciliation for operational use, not a doc statement.
- What happens when the 100M non-conversion requests/hour limit is exceeded — drop, throttle, or no change in response?
- Is there any retry guidance, idempotency mechanism, deduplication key, per-request ID, reconciliation API, or delivery receipt for MP? None documented; production always returns 2xx, so a failed send cannot be detected at request time and a retry cannot be made safe from the protocol side.
- What are the timeout expectations, expected latency, and keep-alive behavior of the endpoint?
- Is `validation_behavior: ENFORCE_RECOMMENDATIONS` honored or silently ignored on production `/mp/collect`?

**Payload semantics**
- What consent state applies when `consent` is omitted **and** there are no corresponding online interactions for that `client_id`?
- Does MP accept lowercase `granted`/`denied`? What does an invalid consent value do — reject, ignore, or treat as denied?
- Do `user_properties` set via MP persist across subsequent events, or must every request resend them?
- May `user_properties` values be non-string types (numbers, booleans)?
- How do the two user-property caps reconcile — 25 per request vs 25 per project?
- What are the character-set rules for user property names beyond the 24-char limit and reserved prefixes?
- What is the effect of omitting `engagement_time_msec`? No default or minimum is stated.
- Is `session_id` required for an MP event to be attributed to a session?
- Does `debug_mode` have any effect on the validation server, and does an MP event with `debug_mode` need a matching device selection in the DebugView device picker?

**`purchase` and ecommerce**
- What breaks when `transaction_id` or `items` is omitted? The **only** stated omission consequence anywhere is the currency/value one. The common claim that omitting `items` suppresses item reports is not doc-backed.
- Is one of `item_id` or `item_name` required per item element? No item-level required marking rendered on the fetched pages.
- Is `value` expressed in major currency units? The samples show `value: 72.05` and `price: 10.01`, and `value` is defined as the sum of `price * quantity`; no page states the unit convention explicitly, and no minor-unit/cents form is documented.
- Are `purchase` events delivered via the Measurement Protocol to a **web** stream deduplicated by `transaction_id` the same way tagged web-stream purchases are? The only dedup scope statement is web-streams-not-app-streams; MP is not addressed.
- What is the deduplication time window? None stated.
- Does a fully custom event name forfeit revenue/ecommerce reports? No page states an exclusion; only positive framing ("unlock prebuilt reporting panels", "always better to use an existing event").
- Is there any subscription-specific recommended event name? None appears in any vertical list; absence is established by reading the lists, not by an explicit statement.
- Why do the two official pages disagree on the All-properties recommended-event list?

**Downstream**
- Is there any general rule about importing Measurement-Protocol-originated events into Google Ads as conversions? Every Google Ads import page is silent on MP. The only explicit exclusion is `ad_impression`; the only positive signal is a rate-limit definition.
- Must `gclid` have been present on the original session for a server-sent MP conversion to attribute to an ad click? Traffic-source/campaign inheritance for MP events is never stated.
- Can `gclid` be passed directly as an MP event parameter?
- Is a conversion built from an MP-originated key event eligible for Smart Bidding, or subject to modeling?
- How long after marking a key event does it become available for import in the Google Ads picker?
- How long after the first send does a new event name appear in **Admin > Data display > Events**, so it can be starred? Not stated — the 24-hour figure in §10.2 is about standard reports, not that list.
- Can **+ Create event** pre-register a name GA4 has never collected? answer/13128484 as extracted does not resolve it. (Moot for MP events regardless: event-generation rules are not triggered by Measurement Protocol events — §1.6, §10.2.)
- Which import flow should be used — §10.3 (Analytics side) or §10.4 (Google Ads side)? Whether they are equivalent, and what running both produces, is stated on no fetched page.
- The Admin path to **link a Google Ads account** to an Analytics property was **not fetched** — it is a stated prerequisite of both import flows with no click path in this document.
- The **Google Ads auto-tagging** setting path was **not fetched** — same status: stated prerequisite, no click path here.
- Where the Analytics-side **Advertising** section (and "Tools" within it) sits in the GA4 navigation is stated on no fetched page, in contrast to **Admin** ("lower left").

**Documentation hygiene**
- `support.google.com` pages show no last-updated date; their currency cannot be established.
- `.../protocol/ga4/reference/config`, `.../protocol/ga4/limitations`, `.../collection/ga4/consent`, `.../collection/ga4/uid`, and `.../protocol/ga4/verifying-implementation` all 404. Any spec citing them cites a dead URL.
- `support.google.com/analytics/answer/9539598` still shows the older "Property Settings" admin label; no old-label-to-new-label mapping is published.
- The exact Google Ads menu labels for the import sub-flow appear only in search snippets, not in the fetched page body — verify against the live UI. The same caveat extends to the Analytics-side labels **"Advertising" > "Tools"** (§10.3) and the Google Ads **"Goals" > "Summary"** menu (§10.4): neither is located within its UI by any fetched page.
- The developer recommended-events reference truncated after the "Online sales" section on all three fetch attempts; per-vertical names came from answer/9267735 instead.
- No Ruby sample exists in any of these docs; all samples are JavaScript `fetch` or a raw HTTP skeleton.
- Only `region1` (EU) is documented as a regional host; no others were listed anywhere.

---

## 12. Sources

### developers.google.com — Measurement Protocol

| URL | Fetched | Note |
|---|---|---|
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4` | OK | Overview. 2026-06-08 UTC |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events` | OK | **Firebase/app tab by default.** 2026-06-11 UTC |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events?client_type=gtag` | OK | Web/gtag tab — the correct one for Rails |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference` | OK | **Firebase/app tab by default; no `client_id` row.** 2026-06-08 UTC |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference?client_type=gtag` | OK | Authoritative body reference for a web stream |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference?client_type=gtag#client_id` | OK | Anchored fetch for client_id / timestamp / reserved names / consent / response |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference#reserved_names` | OK | Reserved names section |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference/config` | **404** | **Does not exist.** Content lives on `/reference` |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference/events` | OK | Source of the `ad_impression` Google-Ads-export exclusion |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/validating-events` | OK | 2026-06-08 UTC |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/validating-events?client_type=gtag` | OK | Web tab |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/verifying-implementation` | **404** | **Dead slug.** Live page is `verify-implementation` |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/verify-implementation` | OK | 2026-06-15 UTC |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/verify-implementation?client_type=gtag` | OK | Web tab |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/troubleshooting` | OK | 2026-06-08 UTC |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/use-cases` | OK | 2026-06-09 UTC |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/policy` | OK | 2026-06-08 UTC. **States no numeric limits at all** |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/limitations` | **404** | No published MP limitations page at that path |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/user-properties` | OK | Firebase tab. 2026-06-08 UTC |
| `https://developers.google.com/analytics/devguides/collection/protocol/ga4/user-properties?client_type=gtag` | OK | Web tab |

### developers.google.com — GA4 collection, gtag, Admin API

| URL | Fetched | Note |
|---|---|---|
| `https://developers.google.com/analytics/devguides/collection/ga4` | OK | Landing page; no snippet |
| `https://developers.google.com/analytics/devguides/collection/ga4/events` | OK | Event category definitions. June 9 2026 UTC |
| `https://developers.google.com/analytics/devguides/collection/ga4/reference/events` | OK | `purchase` table + sample. **Body truncated after "Online sales" on all 3 fetches**; no date captured |
| `https://developers.google.com/analytics/devguides/collection/ga4/ecommerce` | OK | 2026-06-25 UTC |
| `https://developers.google.com/analytics/devguides/collection/ga4/reference/config` | OK | gtag config: `client_id`, `cookie_domain`, `cookie_prefix`, `cookie_flags`, `cookie_expires`, `cookie_update`. 2026-05-14 UTC |
| `https://developers.google.com/analytics/devguides/collection/ga4/user-id` | OK | gtag page; no MP sample, no length limit, no PII rule. 2026-06-03 UTC |
| `https://developers.google.com/analytics/devguides/collection/ga4/uid` | **404** | Moved; reference now points at answer/9213390 |
| `https://developers.google.com/analytics/devguides/collection/ga4/cookies-user-id` | OK | Generic page; **no `_ga` structure**. 2026-07-22 UTC |
| `https://developers.google.com/analytics/devguides/collection/analyticsjs/cookies-user-id` | **404** | "Universal Analytics has sunset … as of July 1, 2024". This is the page that historically documented the `_ga` value layout |
| `https://developers.google.com/gtagjs/reference/api` | OK | `gtag('get')` + MP sample. 2026-04-17 UTC |
| `https://developers.google.com/tag-platform/gtagjs/reference` | OK | Same content as above |
| `https://developers.google.com/tag-platform/gtagjs/reference/parameters` | OK | Control parameters only; **no cookie parameters**. 2024-10-09 UTC |
| `https://developers.google.com/tag-platform/gtagjs/install` | OK | Only fetched page with the full gtag.js snippet |
| `https://developers.google.com/tag-platform/security/guides/consent` | OK | 2026-07-30 UTC |
| `https://developers.google.com/tag-platform/security/concepts/consent-mode` | OK | 2026-07-30 UTC |
| `https://developers.google.com/analytics/devguides/config/admin/v1/rest/v1beta/properties.dataStreams.measurementProtocolSecrets` | OK | 2026-04-14 UTC |

### support.google.com — Analytics Help (none display a last-updated date)

| URL | Fetched | Note |
|---|---|---|
| `https://support.google.com/analytics/answer/12270356` | OK | Measurement ID format + current admin path |
| `https://support.google.com/analytics/answer/9539598` | OK | **Stale admin label** ("Property Settings") |
| `https://support.google.com/analytics/answer/9304153` | OK | Property + web stream creation steps |
| `https://support.google.com/analytics/answer/9744165` | OK | Tag placement, 2,000 properties, 30-min latency |
| `https://support.google.com/analytics/answer/9814495` | OK | **Authoritative api_secret click path** (8 steps, 10-per-stream cap) |
| `https://support.google.com/analytics/answer/9900444` | OK | MP overview; links out to 9814495; the `(not set)`/`session_id` note |
| `https://support.google.com/analytics/answer/9304776` | OK | Per-action permission levels |
| `https://support.google.com/analytics/answer/10252712` | OK | Property selector; column labels NOT in the fetched render |
| `https://support.google.com/analytics/answer/9355659` | OK | Data stream definition, 3 types |
| `https://support.google.com/analytics/answer/9679158` | OK | Account structure; single-web-stream recommendation |
| `https://support.google.com/analytics/answer/9216061` | OK | Enhanced measurement events + toggle path |
| `https://support.google.com/analytics/answer/10071811` | OK | Cross-domain; same-tag-ID requirement; `_gl` |
| `https://support.google.com/analytics/answer/10327750` | OK | Self-referral detection |
| `https://support.google.com/analytics/answer/12332343` | OK | Stream ID; **does not mention client_id** |
| `https://support.google.com/analytics/answer/11397207` | OK | `_ga` / `_ga_<container-id>`; browser lifespan caps. **No value structure** |
| `https://support.google.com/analytics/answer/9356035` | OK | Device ID from "the client ID property of the `_ga` cookie" |
| `https://support.google.com/analytics/answer/11593727` | OK | Client ID stored in `_ga`; not stored when analytics storage denied |
| `https://support.google.com/analytics/answer/10607999` | OK | **[Legacy]** UA→GA4. Only page stating subdomains share a property automatically |
| `https://support.google.com/analytics/answer/10269537` | OK | **NOT GA4** — Universal Analytics property setup, [Legacy]. Contributed nothing |
| `https://support.google.com/analytics/answer/9267735` | OK | Recommended events by vertical |
| `https://support.google.com/analytics/answer/12313109` | OK | transaction_id deduplication |
| `https://support.google.com/analytics/answer/12229021` | OK | Custom events; 25-param consequence |
| `https://support.google.com/analytics/answer/9267744` | OK | Per-user collection ceilings; value-length exceptions |
| `https://support.google.com/analytics/answer/6366371` | OK | PII mandate + examples; **no consequence stated** |
| `https://support.google.com/analytics/answer/9213390` | OK | User-ID 256 chars; identity prohibition |
| `https://support.google.com/analytics/answer/10075209` | OK | Custom dimension/metric limits |
| `https://support.google.com/analytics/answer/7667196` | OK | Data retention |
| `https://support.google.com/analytics/answer/13316687` | OK | Event naming rules |
| `https://support.google.com/analytics/answer/7201382` | OK | DebugView |
| `https://support.google.com/analytics/answer/11198161` | OK | Data freshness |
| `https://support.google.com/analytics/answer/9267568` | OK | Key events, **conceptual only** — no steps, limits, or latency |
| `https://support.google.com/analytics/answer/13128484` | OK | **Actual key-event marking steps**, 30/50 cap, 24-h latency |
| `https://support.google.com/analytics/answer/12844695` | OK | Create/modify key events; the value+currency → Google Ads rule |
| `https://support.google.com/analytics/answer/13965727` | OK | Conversions vs key events (the rename) |
| `https://support.google.com/analytics/answer/14710559` | OK | Creating and managing conversions |
| `https://support.google.com/analytics/answer/13367418` | OK | Missing Google Ads data; auto-tagging/gclid |
| `https://support.google.com/analytics/answer/11053456` | OK | **[Legacy]** Grow offline sales |
| `https://support.google.com/analytics/answer/10632359` | OK | GA-side import flow (also served as Google Ads Help) |

### support.google.com — Google Ads Help

| URL | Fetched | Note |
|---|---|---|
| `https://support.google.com/google-ads/answer/2375435` | OK | Ads-side conversion creation; 24-h import latency |
| `https://support.google.com/google-ads/answer/9520128` | OK | Measuring web key events from GA properties |

### Other

| URL | Fetched | Note |
|---|---|---|
| `https://business.safety.google/adscookies/` | OK | `_ga`: 2 years, "Set from partner domain", Analytics. No value structure |
