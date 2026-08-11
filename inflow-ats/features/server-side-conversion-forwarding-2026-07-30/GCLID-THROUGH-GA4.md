# gclid through GA4 — attributing a days-to-weeks-delayed server-side conversion to its originating Google Ads campaign

Scope: GA4 Measurement Protocol only. Property 313449782, measurement ID `G-FKDT1J0YB6`, GTM container `GTM-N6H844WJ`.
Google Ads offline conversion import is out of scope by owner decision and is not covered anywhere in this file.

---

## 0. The one-paragraph answer

The gclid does not travel in the Measurement Protocol payload. There is no `gclid`, `gbraid`, or `wbraid` field
anywhere in the MP schema, and no practitioner has verified any carrier that GA4 actually consumes. The gclid is
**already inside GA4**, recorded from the landing page's `page_location` at click time and keyed to a `client_id`.
The delayed conversion reaches its campaign by arriving under **that same `client_id`**, being **marked as a key
event**, and being credited by GA4's **event-scoped attribution model** looking back across the user's whole
touchpoint path within the **90-day key-event lookback window**. Session-scoped source/medium on that event will
read `(not set)` or Unassigned — that is expected and is not the failure signal. The credit shows up in
Advertising → Attribution and in the Google Ads conversion column, and the hard ceiling on how late the conversion
can be is the **Google Ads conversion action's own click-through window, which defaults to 30 days and must be
raised to 90**.

Load-bearing official sentence for the join:

> "Advertising identifiers such as GBRAID/WBRAID collected during online interactions are automatically joined with
> Measurement Protocol events using `client_id` or `app_instance_id`."
> — developers.google.com/analytics/devguides/collection/protocol/ga4 (OFFICIAL)

No time bound is stated on that sentence. The stated time bounds live elsewhere and are the reason the exact-session
path cannot work for us (§1.2, §4.1).

---

## 1. The method

### 1.1 Method A — identity join + lookback window (PRIMARY; strongest evidence, every link official)

This is the method to build. Every step is documented by Google; the only unverified part is the end-to-end
composition (§4.1).

**Prerequisites — must already be true, or nothing below can work.**

1. Auto-tagging ON at the Google Ads account level: Google Ads → **Settings** (account level, not campaign) →
   **Account settings** → **Auto-tagging** → "Tag the URL that people click through from my ad". Without it there
   is no gclid on the landing URL and GA4 has nothing to join to.
2. The GA4 tag fires on the ad landing page with the click ID intact in `page_location`. The gclid is
   **case-sensitive** — any redirect, sanitizer, or normalizer that lowercases it breaks Ads attribution silently.
3. The `ga_client_id` we stored is the same `_ga` value that browser session was recorded under. Cross-browser
   signup, incognito, or cookie clearing between click and signup breaks the join and no payload correctness
   recovers it.
4. GA4 property 313449782 is linked to the Google Ads account: GA4 **Admin → Product links → Google Ads links**.

**Step 1 — Set the key-event lookback window to its maximum.**
GA4 **Admin → Data display → Events → Attribution settings → Key event lookback window**.
- "Acquisition conversion events" (`first_open`, `first_visit`): 30 days default, 7 days alternative. Irrelevant to us.
- **"All other conversion events": 90 days default, alternatives 30 and 60. Confirm it reads 90.**
This is the window that makes a click from weeks ago still eligible for credit. Official: *"Users can trigger key
events days or weeks after interacting with your ad. The conversion window determines how far back in time a
touchpoint is eligible for attribution credit."*
Note: a **model** change applies retroactively to historical data; a **lookback window** change applies going forward only.

**Step 2 — Set channel eligibility.**
Same screen: **Channels that can receive credit** → "Google paid channels" (the default for Ads links created after
June 2023) or "Paid and organic channels". "Google paid channels last click" *"attributes 100% of the key event
value to the last Google Ads channel that the customer clicked through before converting"* — which is exactly the
outcome we want.
Also on the same screen: **Reporting attribution model** → data-driven (the default). First click, linear, time
decay, and position-based were removed in November 2023.

**Step 3 — Rely on the direct-exclusion rule rather than fighting the session.**
Official: *"All attribution models exclude direct visits from receiving attribution credit, unless the path to key
event consists entirely of direct visits."* The source-less session our MP event lands in therefore does not steal
the credit from the earlier ad click.

**Step 4 — Create the MP API secret.**
GA4 **Admin → Data collection and modification → Data streams → [the web stream] → Measurement Protocol API secrets
→ Create**. Endpoint:
`POST https://www.google-analytics.com/mp/collect?measurement_id=G-FKDT1J0YB6&api_secret=<SECRET>`
EU variant if ever needed: `https://region1.google-analytics.com/mp/collect`

**Step 5 — Send the event at real time, not backdated.**
Omit `timestamp_micros` entirely and let server receipt time stand. Backdating is capped at 72 hours: under the
default `RELAXED` validation behavior GA4 silently rewrites an older timestamp to 72-hours-ago; under
`ENFORCE_RECOMMENDATIONS` it rejects the event. There is nothing to gain by trying.

**Step 6 — Key the event on `client_id`. This is the load-bearing field.**
`client_id` = our stored `ga_client_id`. It is the documented join key for the advertising-identifier join and for
geo/device enrichment. Everything else in the payload is secondary to getting this right.

**Step 7 — Decide `session_id` by AGE, not by habit.**
- Stored `ga_session_id` **under ~48 hours old** → send it as an event param. It stitches to the real session and
  the event inherits that session's source/medium. This is the documented fix for MP events reporting
  `(not set) / (not set)`.
- Stored `ga_session_id` **older than that** (our normal case) → **do not send the stale value**. An unrecognized or
  expired `session_id` opens a new session anyway, and the stale-id path is exactly what the known ~7-day SaaS
  failure did. Omit it and accept a source-less session; credit comes from Step 1–3, not from session stitching.
  (A fresh numeric `session_id` is the alternative arm — see the test in §4.2.)

**Step 8 — Mark the event as a key event. Non-optional.**
GA4 **Admin → Data display → Events** → toggle "Mark as key event" on our conversion event name.
Official: *"The source and medium for non-key events are '(not set)'."* A conversion event that is not marked as a
key event will report Unassigned no matter how perfect the payload is. This is the single most likely cause of a
false negative when testing.

**Step 9 — Create the Google Ads conversion action from the key event.**
GA4 **Advertising → Conversion management → New conversion** → select the Google Ads account → select the key event
→ choose the conversion category → Save.
(Equivalent from the Ads side: Google Ads → **Goals → Summary → + Create conversion action → Google Analytics 4
property → Select events**.)
Import can take up to 24 hours to first appear.

**Step 10 — Raise the Google Ads conversion window. This is the real ceiling.**
Google Ads → the imported conversion action → **click-through conversion window**. Default is **30 days**; imported
GA4 conversions accept **7 to 90 days**. Set 90. Google Ads cookies expire 90 days after the click, so 90 is the
maximum meaningful value. A conversion 45 days after the click is attributed correctly by GA4 and then dropped by
Ads if this is left at 30. Window changes apply only to conversions recorded after the change.

**Step 11 — Judge the result in the right report.**
- **Do not** judge by Reports → Traffic acquisition (session-scoped) or by "First user source/medium" (user-scoped,
  frozen at acquisition). Both are explicitly unaffected by the attribution model and will not show the credited
  campaign.
- **Do** judge by the event-scoped unprefixed dimensions — `Source`, `Medium`, `Campaign`, `Session default channel
  group`'s event-scoped counterpart — in a key-event exploration, by **Advertising → Attribution**, and by the
  Google Ads campaign conversion column.
- Google Ads books the conversion back to the **click date**, so widen the Ads date range to cover the click weeks
  earlier, not the conversion date.
- Allow up to 7 days before treating a result as final: *"Conversions can be reattributed for up to 7 days after the
  conversion."*

**Step 12 — Keep `ga_session_id` fresh on every visit.**
Re-capture on each authenticated page view via `gtag('get', 'G-FKDT1J0YB6', 'session_id', cb)` or by parsing the
`_ga_FKDT1J0YB6` cookie (format `GS1.1.<timestamp>.<session_number>....`; the session id is the part after the
second dot). Costs nothing, and it moves every conversion that happens within a day or two onto Method B's exact
stitching path instead of the lookback path.

---

### 1.2 Method B — exact-session stitching (only when the conversion is under ~48 hours old)

Same payload as Method A plus:
- `events[0].params.session_id` = the stored `ga_session_id`
- `timestamp_micros` = the real event time, **if and only if** it is within 72 hours

The event then inherits the original session's source/medium/campaign directly — the cleanest possible result, and
the one Simo Ahava tested and confirmed. It is unusable for our primary case because two official limits fence it in:

> "Events and user properties can be backdated up to 72 hours."
> "Events sent using the Measurement Protocol that are intended to be joined or processed in conjunction with events
> collected by the Google Analytics for Firebase SDK or gtag.js should be received by Google Analytics within
> 48 hours of the original client-side event timestamp. Events received later than this may not be processed as
> expected, particularly for purposes like conversion attribution."
> — developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events (OFFICIAL)

Note the 48-hour clock is measured from the **original client-side event timestamp**, not from send time. A
conversion weeks after the click is always outside it. Wording is "should" / "may not", not a hard reject.

Build the age branch anyway — Step 7 above — because trials that convert fast get the strictly better attribution
for free.

---

### 1.3 Method C — supply the campaign ourselves (fallback ONLY when there is no gclid)

If `google_click_id` is present, **do not** replay `utm_source` / `utm_campaign` on the MP event. Official caution:

> "Including manual campaign values alongside existing Google Click ID (GCLID) values can lead to misattribution,
> incorrectly attributing events to UTM instead of the expected Google Ads (google/cpc) source."
> — support.google.com/analytics/answer/11080067 (OFFICIAL)

Since the entire goal is Google Ads credit, sending our stored UTMs on a gclid-bearing user is actively
counterproductive. Reserve this method for the no-gclid case (organic, referral, non-Ads paid), where it is the only
way to get any source onto the event.

Two forms, both documented, both usable together:

**(a) On the conversion event itself** — params `source`, `medium`, `campaign` (plus `term`, `content`). A
practitioner test matrix confirms this populates the **event-scoped** Source/Medium/Campaign correctly even with no
`session_id` at all, while session scope stays `(not set)`. Event scope is the scope that credits key events, so
this is the useful half.

**(b) A `campaign_details` event** — params `campaign_id`, `campaign`, `source`, `medium`, `term`, `content`. Not a
reserved event name, so MP accepts it. Official semantics: *"Use this event to send campaign details that will be
applied to events with a timestamp greater than or equal to the timestamp of the `campaign_details` event."* Place
it **earlier in the same `events[]` array** than the conversion event. Caveat, official: *"The `campaign_details`
event won't be visible in Google Analytics reports or DebugView"* — it is verifiable only via the BigQuery export,
and Google's only worked example of it is an app/SKAdNetwork scenario, so its behavior on a **web** stream is
unverified (§4.4).

---

### 1.4 Method D — put the gclid in `page_location` (UNDOCUMENTED; run as a test, do not ship blind)

GA4 does keep an event-scoped click ID internally: the BigQuery export schema defines
`collected_traffic_source.gclid` — *"The Google click identifier that was collected with the event"* — alongside
`manual_source`, `manual_medium`, `manual_campaign_id`, `dclid`, `srsltid`. It is collected **from the URL**.

The one practitioner recipe for getting a gclid into an MP hit follows from that: set
`events[0].params.page_location` to the full stored landing URL **including `?gclid=<google_click_id>`**. Nobody has
published a verification that GA4 parses it out of an MP `page_location` into `collected_traffic_source.gclid`.

This is cheap to settle and we have the means (§4.3). Until it is settled, treat it as a test arm, not as the method.

---

### 1.5 Method E — server-side GTM as an alternative transport (UNDOCUMENTED; evaluate before committing)

Not part of Method A and not required for it. Recorded because it is the only path found where a stored gclid can
plausibly do real work in an automated server pipeline.

The sGTM GA4 tag does nothing special with click identifiers — click-ID logic lives in the **Google Ads** tags. sGTM
offers a **Google Ads Conversion Tracking** tag that transmits straight to Google Ads servers, bypassing GA4. Its
fields are Conversion ID, Conversion Label, Conversion Value, Currency Code — **there is no GCLID input field**. It
obtains the click ID from the `FPGCLAW` first-party cookie, which the server-side **Conversion Linker** tag writes
*"if the page URL has the `gclid` parameter, or if there are Google Ads' first-party cookies in the request."*

The opening: a server-to-server request into the container (sGTM **Measurement Protocol client** with an
**Activation Path**) carrying `page_location` with `?gclid=<stored gclid>` supplies the linker exactly what it looks
for. Unverified, and there is a concrete reason to doubt it — the Conversion Linker writes `FPGCLAW` to the
**response**, which may put it out of reach of a tag firing in the same request. Settle it in sGTM Preview before
spending anything on it (§4.5).

Out of scope: community sGTM tags named "Google Ads Offline Conversion" are a different mechanism entirely and are
not part of this pipeline.

---

### 1.6 What is reported to FAIL — do not build these

| Approach | Why it fails |
|---|---|
| Reusing the stored `ga_session_id` weeks later | The session is long expired. An unrecognized `session_id` opens a **new** session; the near-identical SaaS case did exactly this at a 7-day gap and went Unassigned. |
| Backdating `timestamp_micros` to the click | Capped at 72 hours. `RELAXED` silently clamps to 72h-ago; `ENFORCE_RECOMMENDATIONS` rejects. |
| Sending `gclid` as an MP field and expecting attribution | No such field exists in the MP schema at any level. It is accepted only as a free-form event parameter and lands inert. A commercial CDP (MetaRouter) shipped an event-level gclid mapping and **removed** it: *"gclid and dclid are no longer mapped at the event level. These identifiers are handled via session-level linking."* |
| Using the gclid as `client_id` | Seen in the wild (engerlina/trvel-website). Fabricates a client_id that matches no real GA4 user and destroys the only working join. |
| Replaying `utm_source`/`utm_campaign` when a gclid exists | Officially cautioned against — misattributes google/cpc to the UTM values. |
| `user_id` alone with no traffic source | One community report: landed as "direct", with source/campaign visible in BigQuery but never in reports. |
| Judging success by session-scoped source/medium | Session scope is expected to be `(not set)`/Unassigned for these hits. Not the metric that decides campaign credit. |

---

## 2. What we send

`POST https://www.google-analytics.com/mp/collect?measurement_id=G-FKDT1J0YB6&api_secret=<SECRET>`

### 2.1 Field mapping — our stored values

| Our stored value | MP field | Notes |
|---|---|---|
| `ga_client_id` | top-level `client_id` | **Required, load-bearing.** The `_ga` cookie value with the `GA1.1.` prefix stripped — the two dot-separated numbers, e.g. `1234567890.1234567890`. This is the documented join key. |
| `ga_session_id` | `events[0].params.session_id` | **Conditional.** Send only when the stored session is under ~48 hours old. Older → omit (see §1.1 Step 7). |
| `google_click_id` | **no MP field exists** | Not sent in the primary payload. Optional test arms only: as `events[0].params.gclid` (inert, requires a registered custom dimension to be visible at all), or inside `events[0].params.page_location` as `?gclid=<value>` (§1.4). Preserve case exactly. |
| amount | `events[0].params.value` + `events[0].params.currency` | `value` numeric (major units, e.g. `49.0`), `currency` ISO-4217 (`"USD"`). |
| our user identifier | top-level `user_id` | Stable across devices. Improves matching; does not by itself carry attribution. |
| user email | `user_data.sha256_email_address[]` | We hash it ourselves — MP does **not** hash for us (gtag.js does). Normalize first: trim, lowercase, strip periods from the local part for gmail addresses, then SHA-256, hex-encoded. Same normalization/hashing as Google Ads API Enhanced Measurement. Up to 3 values accepted. |

### 2.2 Primary payload — the weeks-delayed case (gclid present, session stale)

```json
{
  "client_id": "<ga_client_id>",
  "user_id": "<our stable user id>",
  "consent": {
    "ad_user_data": "GRANTED",
    "ad_personalization": "GRANTED"
  },
  "user_data": {
    "sha256_email_address": ["<sha256 hex of normalized email>"]
  },
  "events": [
    {
      "name": "<our conversion event name>",
      "params": {
        "value": 49.0,
        "currency": "USD",
        "engagement_time_msec": 100
      }
    }
  ]
}
```

- No `timestamp_micros` — real send time.
- No `session_id` — the stored one is stale (over ~48h).
- No `gclid`, no `utm_source`, no `utm_campaign`.
- `engagement_time_msec: 100` is the practitioner-standard value; GA4 may ignore the event in standard reports
  without it. Official: *"To ensure accurate session and user engagement metrics in your reports … include the
  `session_id` and `engagement_time_msec` parameters with your events."*

### 2.3 Fast-path payload — conversion under ~48 hours old

Same as above, plus inside `events[0].params`:

```json
"session_id": "<ga_session_id>"
```

and optionally top-level `"timestamp_micros": <real event time in MICROseconds>` when within 72 hours
(microseconds, not milliseconds — a common and silent error).

### 2.4 No-gclid fallback payload (organic / referral / non-Ads paid)

Add to `events[0].params`: `"source": "<utm_source>"`, `"medium": "<utm_medium>"`, `"campaign": "<utm_campaign>"`.
Optionally prepend a `campaign_details` event in the same `events[]` array with `source`, `medium`, `campaign`,
`campaign_id`.

### 2.5 Validation and limits

- Validate every payload shape against `https://www.google-analytics.com/debug/mp/collect?measurement_id=G-FKDT1J0YB6&api_secret=<SECRET>`
  with top-level `"validation_behavior": "ENFORCE_RECOMMENDATIONS"`. **The production endpoint returns 2xx for
  invalid data** — the debug endpoint is the only way to see `validationMessages`. Google's GA4 Event Builder
  (Google Analytics Demos and Tools) builds the same payloads interactively.
- Limits: 25 events per request, 25 params per event, parameter values ≤100 chars (500 on 360 — a gclid fits
  either way), post body <130 kB, 100M non-conversion requests/hour per property.
- Reserved names: parameter names may not begin with `_`, `firebase_`, `ga_`, `google_`, or `gtag.`; the only
  reserved *parameter* name is `firebase_conversion`. So `gclid` is a legal custom parameter name — legal, and inert.
- `firebase_campaign` is the one GA4 event whose schema carries `gclid`/`aclid`/`cp1`/`anid`, and it is a **reserved
  event name** — MP cannot send it. This is the dead end everyone finds first.

---

## 3. GA4 settings to change

| # | Setting | Exact UI path | Set to |
|---|---|---|---|
| 1 | Key event lookback window | Admin → Data display → Events → **Attribution settings** | "All other conversion events" = **90 days** (default; verify it was not lowered) |
| 2 | Channels that can receive credit | Admin → Data display → Events → **Attribution settings** | **Google paid channels** (or Paid and organic channels) |
| 3 | Reporting attribution model | Admin → Data display → Events → **Attribution settings** | **Data-driven** (default) |
| 4 | Mark conversion event as key event | Admin → Data display → **Events** → toggle "Mark as key event" | **ON** — without it, event-scoped source/medium are `(not set)` |
| 5 | Measurement Protocol API secret | Admin → Data collection and modification → Data streams → [web stream] → **Measurement Protocol API secrets** → Create | one secret, stored in the app's credentials |
| 6 | Google Ads link | Admin → Product links → **Google Ads links** | property 313449782 linked to the Ads account |
| 7 | Ads conversion action created from the key event | Advertising → Conversion management → **New conversion** → select Ads account → select key event → Save | created |
| 8 | Ads click-through conversion window | Google Ads → the imported conversion action | **90 days** (default is 30 — this is the real ceiling) |
| 9 | Conversion attribution settings (channel eligibility, Ads-facing) | Advertising → Conversion management → **Conversion attribution settings** | Google Paid Channels / Paid and Organic Channels |
| 10 | Custom dimension for `gclid` — **only if** we ship the inert-param test arm | Admin → Custom definitions → **Custom dimensions** → Create | Scope **Event**, event parameter name `gclid`. Reporting/debug visibility only; register nothing if we do not send the param. |
| 11 | BigQuery export (needed to settle §4.3 and §4.4) | Admin → Product links → **BigQuery links** | linked, daily or streaming |

Two behaviors worth writing down because they surprise people:
- Changing the **attribution model** re-applies to historical data. Changing the **lookback window** applies going
  forward only.
- Google Ads import can take up to 24 hours to appear, and GA4 reattributes conversions for up to 7 days.

---

## 4. What is uncertain

Each item names the smallest real test that settles it. Nothing here is "impossible" — it is undocumented.

### 4.1 Does the whole Method A chain actually pay out? (the one that matters)

Every link is officially documented — 90-day key-event lookback, direct excluded from credit, GBRAID/WBRAID-to-
`client_id` join, Google-paid-channels-last-click, Ads' own conversion window — but **no Google statement and no
practitioner report walks the whole chain for a weeks-delayed MP event**. The published cases (Stack Overflow
78593388, 73433201, googleanalytics4.co forum) all show GA4 displaying plausible source/medium while Google Ads
counted nothing, and none isolates which join failed.

**Smallest test:** one real conversion, or a synthetic one. Take a `client_id` from a browser session that landed on
a live ad with a gclid. Wait past 72 hours (7 days is a better probe). Send the Method A payload with the event
marked as a key event. Then check three surfaces in order: (a) GA4 event-scoped `Source`/`Medium`/`Campaign` on that
event in an exploration; (b) BigQuery `session_traffic_source_last_click.google_ads_campaign.campaign_name` for the
user; (c) the Google Ads conversion column for that campaign, with the date range covering the **click** date. (a)
without (c) means GA4 attributed it and Ads dropped it — check the conversion window from §3 row 8 first.

### 4.2 Stale `session_id` vs. omitted vs. fresh

Practitioner guidance covers only the within-72h case. Nobody has published which of the three is best once the
session is expired.

**Smallest test:** three synthetic conversions on three distinct `client_id`s from real gclid-bearing sessions, all
sent at the same age (say 7 days), differing only in the `session_id` arm — stored/stale, omitted, freshly generated
numeric. Compare event-scoped Source/Medium and BigQuery `session_traffic_source_last_click`.

### 4.3 Does GA4 parse a gclid out of an MP event's `page_location`?

One Stack Overflow answer asserts the recipe. Nobody verified the result. GA4 definitively has a slot for it —
`collected_traffic_source.gclid` in the BigQuery export.

**Smallest test:** send one MP event with `page_location` = the full landing URL including `?gclid=<value>`, then
query the BigQuery export for that event's `collected_traffic_source.gclid`, `.manual_source`, `.manual_medium`.
Populated → GA4 parsed it, and Method D becomes real. NULL → the field is inert and only the `client_id` join
matters. One query, one event.

### 4.4 Does `campaign_details` function on a WEB stream?

Google's only worked example is an app/SKAdNetwork postback, and one practitioner reported the GA4 event builder
rejecting it as app-only while simultaneously reporting that subsequent web events attributed correctly. The event
is invisible in reports and DebugView by design.

**Smallest test:** send `campaign_details` + a conversion event in one `events[]` array on the web stream, then read
the BigQuery export for the conversion event's `collected_traffic_source.manual_source` / `.manual_campaign_name`.

### 4.5 Can an sGTM Google Ads Conversion Tracking tag pick up a gclid introduced in the same request?

The Conversion Linker writes `FPGCLAW` to the **response**, which suggests a two-request dependency a fire-and-forget
server pipeline cannot satisfy. Also unknown: whether the Ads tag can be triggered from the **Measurement Protocol
client** at all (the official ads-setup page names a GA4 client among prerequisites but does not exclude the MP
client), and whether a server-crafted `Cookie: FPGCLAW=...` header is accepted and in what format.

**Smallest test:** sGTM **Preview** mode. Fire one server-to-server request into the container with `page_location`
containing `?gclid=`. Watch whether Conversion Linker and Google Ads Conversion Tracking fire, and whether the
outgoing hit carries the `gclaw` parameter. Fifteen minutes, no code.

### 4.6 Does the 48-hour rule bite, and measured from what?

Its wording scopes it to events "intended to be joined or processed in conjunction with events collected by …
gtag.js" — i.e. joining to a specific client-side event's timestamp — and it is **not** attached to the
GBRAID/WBRAID-join sentence, which carries no time qualifier. Under the literal reading, every weeks-delayed
conversion is outside it, which would make the ~7-day Unassigned report the expected outcome rather than a
misconfiguration. Google states "should" / "may not", never what happens at hour 49.

**Settled by the same test as §4.1** — that is the whole point of running it at 7 days rather than at 2.

### 4.7 Is gclid inside the "such as" set?

The advertising-identifier set is never enumerated anywhere reachable on google.com. GBRAID/WBRAID may be named
precisely because they are the identifiers that *cannot* be user-scoped, implying gclid rides the ordinary
session-attribution path. Plausible, undocumented, and not separately testable — §4.1's outcome subsumes it.

### 4.8 Things we should verify about our own setup before blaming the mechanism

- Is `ga_client_id` genuinely the `_ga` value from the ad-click browser, or was it captured on a later/different
  device? Silent breaker, no payload fixes it.
- Is `ga_session_id` the real `ga_session_id` number from `_ga_FKDT1J0YB6`, or a synthetic value? A self-generated
  session id sends everything to Unassigned.
- If server-side tagging is ever introduced: sGTM derives `client_id` from `FPID`, not `_ga`. Mixing the two makes
  one human into two GA4 users and silently kills the join.
- GA4 **reporting identity** (Admin → Data display → Reporting identity: Blended / Observed / Device-based) —
  whether it changes MP conversion outcomes is unverified and is flagged, not asserted.

---

## 5. Sources

### OFFICIAL (google.com / google.cn domains)

- https://developers.google.com/analytics/devguides/collection/protocol/ga4 — MP overview. The GBRAID/WBRAID auto-join sentence, no time bound. Sibling bullets: Remarketing, Privacy settings, Geographic and device information (the conditional 24-hour `session_id` rule). Reserved names note. *"While it's possible to send events to Google Analytics solely with the Measurement Protocol, only partial reporting may be available."*
- https://developers.google.cn/analytics/devguides/collection/protocol/ga4?hl=en — same page, second host, used to confirm the verbatim wording independently.
- https://developers.google.com/analytics/devguides/collection/protocol/ga4/sending-events?client_type=gtag — 72-hour backdating cap (`RELAXED` clamps, `ENFORCE_RECOMMENDATIONS` rejects) and the 48-hour join note naming conversion attribution. *"creating a new session_id creates a new session without the need to send session_start."*
- https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference?client_type=gtag — full payload reference. Top-level fields: `api_secret`, `measurement_id`, `client_id`, `user_id`, `timestamp_micros`, `user_properties`, `user_data`, `consent`, `non_personalized_ads`, `user_location`, `ip_override`, `device`, `validation_behavior`, `events[]`. **No click-ID field at any level.** Reserved prefixes and `firebase_conversion`.
- https://developers.google.com/analytics/devguides/collection/protocol/ga4/reference/events — `campaign_details` params (`campaign_id`, `campaign`, `source`, `medium`, `term`, `content`) and its timestamp semantics; `firebase_campaign` (the gclid-bearing event) listed as a reserved event name.
- https://developers.google.com/analytics/devguides/collection/protocol/ga4/changelog — 2022-05-23 `session_id` for session-based reporting; MP + `user_id` events "exported and attributed" to Ads; 2023-01-23 / 2024-09-10 geo+device joined by `client_id`; 2025-12-11 / 2026-02-17 GTM-format session ids accepted.
- https://developers.google.com/analytics/devguides/collection/ga4/uid-data — `user_data` over MP: `sha256_email_address[]`, `sha256_phone_number[]`, `address[]`. MP does not hash for you.
- https://developers.google.com/analytics/devguides/collection/ga4/reference/config — gtag config fields `campaign_id`/`campaign_source`/`campaign_medium`/`campaign_name`/`campaign_term`/`campaign_content`, each overriding the utm_* query param. No gclid field.
- https://support.google.com/analytics/answer/9900444 — *"When session-based Measurement Protocol events are reported as '(not set) / (not set),' send the session_id parameter with a valid value from the client-side event."*
- https://support.google.com/analytics/answer/10597962 — Attribution settings. Exact path Admin → Data display → Events → Attribution settings. Lookback windows 30/7 (acquisition) and 90/30/60 (all other key events). Model change retroactive; lookback change forward-only.
- https://support.google.com/analytics/answer/11080067 — the three dimension scopes; *"The source and medium for non-key events are '(not set)'"*; the caution against manual campaign values alongside a GCLID.
- https://support.google.com/analytics/answer/10596866 — *"All attribution models exclude direct visits from receiving attribution credit…"*; Google paid channels last click; 7-day reattribution.
- https://support.google.com/analytics/answer/16291704 — *"Users can trigger key events days or weeks after interacting with your ad. The conversion window determines how far back in time a touchpoint is eligible for attribution credit."*
- https://support.google.com/analytics/answer/9191807 — *"The session_start event carries the information that determines the attribution of the session, such as the gclid, UTM parameters, and referrer."*
- https://support.google.com/analytics/answer/9756891 — *"Unassigned is the value Analytics uses when there are no other channel rules that match the event data."*
- https://support.google.com/analytics/answer/10632359 — creating Ads conversions from GA4 key events; Google Paid vs Paid and Organic Channels; default is Google Paid Channels for links after June 2023.
- https://support.google.com/analytics/answer/7029846 — BigQuery export schema. `collected_traffic_source.gclid` = *"The Google click identifier that was collected with the event"*, plus `manual_*`, `dclid`, `srsltid`; `session_traffic_source_last_click.google_ads_campaign.*`; `traffic_source` = first-acquisition, immutable.
- https://support.google.com/analytics/answer/13167628 — Google's only worked `campaign_details`-over-MP example (SKAdNetwork postbacks, app stream).
- https://support.google.com/google-ads/answer/2375435 — GA4→Ads conversion import requirements and UI path; *"Google Ads conversions can have a conversion window between 1 and 90 days"*; Ads cookies expire 90 days after the click; GCLID must not be altered or dropped.
- https://support.google.com/google-ads/answer/3123169 — conversion windows: click-through 1–30/60/90 days, **default 30**; engaged-view 3 days; view-through 1 day.
- https://developers.google.com/tag-platform/tag-manager/server-side/ads-setup — sGTM Conversion Linker + Google Ads Conversion Tracking; tag fields are Conversion ID / Label / Value / Currency. No gclid field.
- https://developers.google.com/tag-platform/tag-manager/server-side/send-data — server-to-server ingestion via a Measurement Protocol client with an Activation Path.
- https://developers.google.com/tag-platform/tag-manager/server-side/common-event-data — available server event-data keys: `client_id`, `user_id`, `user_agent`, `ip_override`, `page_location`, `page_referrer`, `user_data.*`. No click-ID key.
- https://developers.google.com/tag-platform/tag-manager/server-side/internal-parameters — internal `x-ga-*`/`x-sst-*` table; `x-ads-apve`, `x-ga-gcd`, nothing for gclid/gbraid/wbraid/_gcl_aw.
- https://support.google.com/analytics/thread/58732374/sending-gclid-parameter-to-measurement-protocol-for-event-automatically-attribute-to-google-cpc — official domain, user-authored, **zero replies** (2020, UA-era). Reports all MP events showing as google/cpc while sending both a session ID and a gclid. Unresolved; the session join is an equally good explanation.
- https://support.google.com/analytics/thread/188566738 — official domain, user-authored. Offline conversions with `user_id` + `client_id` and deliberately no source/medium landed as "direct"; source visible in BigQuery, never in reports.
- https://support.google.com/analytics/thread/361926024 — official domain, user-authored. Self-generated `s{10 digits}` session ids → Unassigned. Recommends `gtag.get()` for the real session id.
- https://support.google.com/analytics/thread/296359732 — official domain, user-authored. GA4 does not derive source/medium from `session_id` alone.

### PRACTITIONER

- https://www.simoahava.com/analytics/session-attribution-with-ga4-measurement-protocol/ — tested trio: `client_id`, `session_id`, timestamp ≤72h in the past. Event inherits the session's source/medium. Explicitly did **not** test the expired-session case.
- https://www.simoahava.com/analytics/google-ads-server-side-tagging-google-tag-manager/ — the definitive sGTM click-ID writeup. Conversion Linker sets `FPGCLAW` in the **response** when the page URL has `gclid` or Ads first-party cookies are present; outgoing hit carries the click ID as `gclaw`; `FPGCLAW` expires in 3 months.
- https://www.analyticsmania.com/post/unassigned-in-google-analytics-4/ — active session needs `client_id` + `session_id`; expired-but-<72h session additionally needs `timestamp_micros`; beyond that → `(not set)` → Unassigned. MP *"is designed to enrich the data you have collected on a website, not to initiate new sessions."*
- https://www.bounteous.com/insights/2025/12/05/ga4-attribution-issues-explained-not-set-unassigned-and-more/ — MP checklist (same `client_id`, reuse active `session_id`, timestamp within 72h); wait 24h before judging.
- https://medium.com/@deepakatanalytics/ga4-measurement-protocol-e6e8c76f8d18 — the most useful test matrix found. Case 2 (no `session_id`, source/medium/campaign as event params): session scope `(not set)`, **event scope correctly attributed**. Case 3 (with `session_id` + params): session scope = real session, event scope = sent values. Case 1: `campaign_details` on web errored in the event builder, invisible in reports, present in BigQuery, subsequent events attributed.
- https://stackoverflow.com/questions/78593388/ga4-measurement-protocol-event-attribution-not-working-with-event-one-week-late — the near-identical SaaS case. `client_id` + `user_id` + `session_id` + `non_personalized_ads`; trial attributed, subscription-paid one week later Unassigned.
- https://stackoverflow.com/questions/73433201/conversions-from-google-ads-send-via-measurement-protocol-google-analytics-4-a — MP purchases correct in GA4, "No recent conversions" in Ads; fixed by adding `session_id` (short-gap case). Establishes GA4 MP has no gclid field.
- https://stackoverflow.com/questions/72281552/send-google-ad-id-gclid-to-google-analytics-4-ga4-using-measurement-api — asks exactly how to put gclid in an MP event; accepted answer: enable auto-tagging, *"GA will automatically pick it up for you."*
- https://stackoverflow.com/questions/74735243/get-gclid-thru-measurement-protocol — the only named carrier recipe: *"You can include `?gclid=` parameter in the URL (page_location) to include it."* Unverified.
- https://stackoverflow.com/questions/72784667/sending-session-id-via-measurement-protocol — store `cid` AND `sid` at capture time; random session ids create new sessions; `gtag('get', 'G-XXXXXXXX', 'session_id', cb)`.
- https://docs.metarouter.io/docs/google-analytics-4-measurement — strongest negative evidence: *"gclid and dclid are no longer mapped at the event level. These identifiers are handled via session-level linking through the Google Gtag sync."*
- https://stape.io/blog/unassigned-and-not-set-traffic-source-in-ga4 — the `_ga` vs `FPID` client-id mismatch that silently doubles users; `_ga_<measurementId>` session id is the part after the second dot.
- https://github.com/stape-io/ga4-advanced-tag/blob/master/template.js — exhaustive map of the sGTM GA4 wire payload. Campaign block is `cs`/`cm`/`cn`/`cc`/`ck`/`ccf`; the only occurrence of "gclid" is `_rnd`, commented "Gclid Deduper". **No gclid slot.**
- https://github.com/adswerve/GA4-Measurement-Protocol-Typescript/blob/master/src/library.ts — allowed-params table showing `firebase_campaign` as the only GA4 event carrying `gclid`/`aclid`/`cp1`/`anid`.
- https://github.com/adswerve/GA4-Measurement-Protocol-Python — beta MP client library; transport only.
- https://github.com/ray-xuanruilee/GA4_Measurement-Protocol_Python — POS / offline transaction MP example.
- https://github.com/zwhitchcox/hitchcoxaesthetics.com/blob/main/app/utils/ga4-measurement-protocol.server.ts — module header: *"the protocol has no gclid field. Events older than ~72 hours are dropped by GA4."*
- https://github.com/alvarotrigo/webbodas/blob/main/docs/CONVERSION_TRACKING.md — closest working shape to ours (Stripe webhook → MP purchase). Reuses `_ga` and `_ga_<stream>` *"para que GA4 enlace el evento con la sesión que llevaba el gclid"*; falls back to a first-party id + captured gclid only when the cookies are missing.
- https://github.com/andredezzy/maccing/blob/main/skills/growth/google-ads/SKILL.md — *"gclid is NOT a GA4 MP field. Attribution via session stitching (client_id + session_id)"*; `engagement_time_msec: 100` required; production endpoint always 2xx, use the debug endpoint.
- https://github.com/superformlabs/ga4dataform-community/blob/main/includes/core/modules/ga4/config.js — verification tooling: click-ID classification from `collected_traffic_source`, `is_measurement_protocol_hit` column, `DATA_IS_FINAL_DAYS = 3`.
- https://community.stape.io/t/google-ads-conversions-third-party-domain/3693 — *"FPGCLAW is set by server Conversion Linker if the gclid parameter is sent in the url"*; cross-domain failure mode.
- https://adriennevermorel.com/notes/google-ads-enhanced-conversions-server-side/ — Conversion Linker fires on every page view; server-set cookie survives Safari ITP's 7-day cap; Ads tag fields confirmed.
- https://aelmgren.com/guides/server-side/measurement-protocol-offline-conversions — 72h backdate + 48h join windows; *"An absent or mismatched session_id spawns an unintended new session."* Timestamp priority: event-level → request-level → server receipt.
- https://jsndesign.co.uk/blog/ga4-measurement-protocol-v2-key-updates-and-considerations/ — events older than 72h *"are often marked as Unassigned"*; recommends *"having a mechanism to frequently pull the session_id value and refresh at the system of record."*
- https://datajournal.datakyu.co/integrating-measurement-protocol-client-data-ga4/ — cookie formats: `_ga` = `GA1.1.<p1>.<p2>`; `_ga_<measurement-id>` = `GS1.1.<timestamp>.<session_number>...`.
- https://medium.com/sparkline/ga4-tip-the-page-location-parameter-89727ab04b4c — *"The gclid is case sensitive. If you change it to lowercase … you will NOT be able to correctly attribute the traffic source and conversions."*
- https://www.mbadv.agency/google-analytics-4/ga4-for-ppc-and-lead-generation — an imported GA4 key event *"is counted under Google Ads' own attribution model and conversion window settings."*
- https://www.idimension.com/2021/11/attribution-of-imported-ga4-conversions-in-google-ads/ — imported GA4 conversions expose value, count, click-through window (7–90 days), and attribution model as editable Ads-side attributes.
- https://googleanalytics4.co/forums/discussion/troubleshooting-conversion-visibility-issues-for-google-ads-through-measurement-protocol-with-ga4/ — same failure mode as SO 73433201; no confirmed resolution.
