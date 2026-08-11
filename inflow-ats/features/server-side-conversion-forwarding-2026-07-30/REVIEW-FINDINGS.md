# Review findings — server-side conversion forwarding

Everything SPEC.md excludes: open questions awaiting Jessica's ruling, accepted risks with their blast radius,
alternatives considered and set aside, and discrepancies between the inherited briefing and the live code.

---

## Open questions awaiting a ruling

Each is currently proceeding on a default. The default is written into SPEC.md; changing the ruling changes
the spec.

### Q1. Which events go to AdRoll?

**Ruled:** three events — `convertedToPaidSubscription` and `trialConvertedToPaidSubscription` as `purchase`
with a value, and `trialStarted` as `signupTrial` with no value. SPEC.md carries this.

**Still open:** whether `ownerSignedUp` and `ownerCreatedOrganization` should follow. AdRoll's event-name
enumeration has plausible slots for both — `formFill` or `gatedContent` — so the wider set is mechanically
available. The cost of adding them is that every additional event is another live call against
the single production server access token, and AdRoll publishes no response contract at all, so a
misconfigured field on a high-volume event is invisible until audience data looks wrong. Cost of leaving them
out: AdRoll sees no signup signal and cannot optimize toward signups.

### Q2. Should the paid conversions reach Google Ads through the Data Manager API or through GA4?

**Proceeding with:** the Data Manager API, sending the conversion directly to a Google Ads conversion action.

**The alternative:** send the paid conversions to GA4 through the Measurement Protocol instead, mark them as
key events in GA4, and let GA4's event-scoped attribution credit them back to the original click through its
90-day key-event lookback window, with the key event imported into Google Ads as a conversion.

Both are viable per the research and the two paths are mutually exclusive in practice — running both would
double-count the same conversion in Google Ads. The Data Manager path is the default because it posts the
conversion straight to a Google Ads conversion action and depends on nothing undocumented, while the GA4
path's credit rests on a composition of documented links that no Google statement and no practitioner report
has ever walked end to end for a weeks-delayed event. The Measurement Protocol's 72-hour backdating limit and
its 48-hour joining guidance are not what separates the two: both govern the exact-session stitching path,
which sends `session_id` and `timestamp_micros`, and the GA4 alternative here sends neither. The GA4 path's
appeal is that it
needs no new Google Cloud project, no new OAuth credential and no new conversion action — the GA4 credentials
already exist — and its known ceiling is the same one the Data Manager path has: the Google Ads conversion
action's click-through window.

The GA4 path's specific risk is Q2a below.

### Q3. Does `architecture.md` rule 2's PostHog exception cover the three advertising destinations?

**Proceeding with:** each job constructing its destination's client directly, the shape `PosthogTrackJob`
uses.

**The alternative:** routing each dispatch through a `User` or `SubscriptionEvent` instance method that wraps
the client.

`cursor_rules/backend/architecture.md` rule 2 requires Model Callback → Background Job (passes IDs) → Model
Instance Method → Service → External API, and names exactly one exception: "PostHog service methods are not
limited to a single model."

The three named house API `Client` classes are all constructed outside a job — `WwrApi::Client` in
`app/models/board_wwr_listing.rb`, `CloudflareClient` in `app/models/careers_page.rb` and
`app/interactors/create_custom_domain.rb`, `SendGridClient` in `app/models/user.rb`, and
`WhatJobsApi::Client` in `app/services/what_jobs_listing.rb`. But external side-effect dispatch generally does
not take rule 2's route: `PosthogTrackJob` constructs `Posthog::Track`,
`Discord::NotifyTrialConvertedToPaidJob` and the other `Discord::` notification jobs construct
`DiscordNotifierBot`, `EngagementReport::GeneratorJob` constructs `EngagementReport::ReportGenerator`, and
`RegisteredWebhooks::NewJobApplicationJob` calls `Faraday.post` inline. `Discord::NotifyTrialConvertedToPaidJob`
reads a single model, `Organization`, and is enqueued from the same `when` branch these new enqueues join, so
single-model ownership is not what decides the shape in practice.

Two live chains do take rule 2's route end to end, so the practice is split rather than uniform:
`SyncWhatJobsListingJob#perform` calls `BoardWhatJobsListing#sync_with_what_jobs`
(`app/jobs/sync_what_jobs_listing_job.rb:13` → `app/models/board_what_jobs_listing.rb:100`), whose
`create_on_what_jobs` and `update_on_what_jobs` call `WhatJobsListing.new` with the model instance
(`app/models/board_what_jobs_listing.rb:208,215`), and `JobPingGoogleIndexJob` calls `Job#ping_google_index`
(`app/jobs/job_ping_google_index_job.rb:10` → `app/models/job.rb:1424`), which builds and sends the Google
Indexing request from the model itself. Job-board and search-index dispatch takes rule 2's route;
notification and analytics dispatch does not.

The open question is therefore not whether the spec's shape matches a precedent in the codebase — it matches
the notification and analytics precedent — but whether rule 2's written exception should be widened from
PostHog to external analytics and advertising dispatch generally, so that the rules file stops contradicting
half the practice. That is a rules-file amendment, not a spec change.

### Q4. A yearly subscription sends a full year's payment as one conversion value

**Proceeding with:** `subscription_events.amount` as recorded, whatever the billing interval. A yearly plan
therefore reports roughly ten to twelve times the conversion value of the same plan billed monthly, and
Google Ads value-based bidding treats them as different-sized outcomes; AdRoll sees the same asymmetry once
its value field is settled.

**The alternative:** read `subscription_events.billing_interval` and normalize — divide a yearly amount to a
monthly equivalent, or annualize a monthly one — so both intervals report a comparable figure.

Sending the amount as recorded is the only option that reports a number the application actually charged;
every alternative reports a computed figure that matches no invoice.

### Q5. Should the Google SSO `ownerSignedUp` dispatch be suppressed for a user with a pending invite?

**Proceeding with:** no gate on the SSO site. `SendGa4EventJob` and `SendGoogleAdsConversionJob` fire for
every new user created through Google SSO, invited teammates included.

**The alternative:** look up a pending `Invite` on the new user's email inside
`Api::V1::Users::OmniauthCallbacksController#google_oauth2` and skip both enqueues when one exists.

An invited teammate never reaches the Google SSO screen. Clicking the invite link verifies their email and
takes them into the application, so the `/auth` page carrying `GoogleSSOButton` is not on their route.
Separately, no invite token is visible at that site in any case — `GoogleSSOButton` renders hidden inputs for
the tracking parameters and none for `invite_token` (`GoogleSSOButton.tsx` lines 77-118), and `google_oauth2`
reads only `session[:oauth_tracking]` and `request.env['omniauth.params']`.

This question therefore concerns only a genuinely new user who happens to have a pending invite on their
email and signs up through Google SSO without using the invite link.

### Q6. Our paid conversions are reported to AdRoll as ecommerce purchases

**Proceeding with:** `purchase` as the AdRoll `event_name` for both `convertedToPaidSubscription` and
`trialConvertedToPaidSubscription`. SPEC.md carries this.

**The alternative:** `signupPlan`.

`signupPlan` is documented as "a user has completed a signup process for a specific plan or subscription",
which describes both of our paid conversions exactly; `purchase` is a B2C ecommerce event. On semantics
`signupPlan` is the closer match and `purchase` is the looser one.

`purchase` is retained because it is the only event in the thirteen with documented `conversion_value`
support — all eight of AdRoll's B2B/ABM events, `signupPlan` included, carry "Optional attributes: None".
Choosing `signupPlan` would mean either sending an undocumented field on it or sending the two paid
conversions with no monetary value at all.

The cost of retaining `purchase`: AdRoll's reporting, audiences and any event-type-driven optimization see
Polymer's subscription conversions as ecommerce purchases, alongside no other purchase-type events. If AdRoll
segments or bids differently on `purchase` than on `signupPlan`, that difference applies to us on the
ecommerce side of the line. Nothing in AdRoll's documentation states whether it does.

### Q2a. The GA4 attribution chain has never been observed end to end

If Q2 is ruled toward GA4, this is the risk being accepted. The chain is: a delayed Measurement Protocol event
arrives under the same `client_id` the browser session was recorded against, is marked as a key event, and is
credited by GA4's event-scoped attribution looking back across the whole touchpoint path within the 90-day
lookback window. Every individual link is documented by Google. The composition is documented by nobody, and
no practitioner write-up confirms it pays out.

The load-bearing sentence — *"Advertising identifiers such as GBRAID/WBRAID collected during online
interactions are automatically joined with Measurement Protocol events using `client_id` or
`app_instance_id`"* — carries no time bound, while adjacent pages state a 48-hour joining window for
Measurement Protocol events. Those two statements are not reconciled anywhere. Session-scoped source and
medium on the delayed event will read `(not set)`, which is expected and is not the failure signal, so a
failure of this chain looks identical to a success until the Google Ads conversion column is compared against
known paid conversions weeks later.

### Q7. Should `Ga4MeasurementProtocol::Client` write a retry-exhaustion line on the transport path?

**Default in SPEC.md:** no. The client writes no exhaustion `Rails.logger.error` at all. On a status the
failure line `send_event` writes carries the response's status and body; on a transport failure surviving all
three attempts the Faraday exception propagates to `SendGa4EventJob`'s method-level rescue, which writes
`Rails.logger.error e`, an `ap` label naming the destination and the user id, and `ap e`.

**What is lost on that one path:** the attempt count. The destination, the user id and the exception are all
recorded by the job's rescue; nothing states that three attempts were made rather than one, beyond the two
`Rails.logger.warn` retry lines that precede it.

**The alternative:** have `request` write the same destination-and-attempt-count `Rails.logger.error` the
other two clients write, on the transport path only, before re-raising. It costs one line per failure and
makes the exhaustion explicit in the one place the GA4 client currently stays silent. It also gives
`Ga4MeasurementProtocol::Client` a logging shape neither of the other two has — a line written in `request` on
one failure path and in `send_event` on the other.

---

## Decisions taken in the spec that are reversible

Each of these was decided in order to produce a complete spec. None is settled beyond challenge.

### D1. "Four conversion actions" is arithmetically five

The briefing says the Google Ads destination takes **four** conversion actions, then enumerates five events:
two paid conversions as primary, and `trialStarted`, `ownerSignedUp`, `ownerCreatedOrganization` as secondary.
SPEC.md specifies five conversion actions, one per event, because that is what the enumeration lists and
because one action per event is what keeps the two paid conversions distinguishable in Google Ads reporting.

The reading that makes "four" correct is that both paid conversions feed a single `SUBSCRIBE_PAID` conversion
action. That is defensible — it is one commercial outcome — and it removes one hand-created conversion action
and one configuration constant. It also makes new-paid and trial-converted indistinguishable in Google Ads.

### D2. No hashed email is sent to any destination

The research recommends sending a SHA-256 hashed email alongside the gclid to Google Ads, and Google's own
sample payloads do it. SPEC.md sends the gclid alone. Reasons: sending user-provided data engages the Enhanced
Conversions settings and the Google Ads customer data terms, whose current state on the account is unknown;
it pulls in a 63-day maximum upload age that the gclid-only path does not have; and the normalization rules
(lowercase, gmail dot and plus stripping, whitespace removal, SHA-256, hex) have no Ruby implementation in any
official library, so they would have to be written from prose and would have to be written twice, once per
destination, because a shared helper across destinations is exactly the abstraction that is ruled out.

Cost of the omission: no cross-device fallback. When the gclid is missing or has aged past 90 days, the
conversion is not sent at all rather than matched on email. Practitioner match rates for PII matching sit
around 30–45%, so the fallback would have recovered a minority of otherwise-lost conversions.

The same decision applies to GA4's `user_data.sha256_email_address`, where it also removes a policy surface —
GA4 forbids sending personally identifying data and `user_data` is the only sanctioned channel for it.

### D3. Both AdRoll paid conversions arrive as `purchase`

AdRoll accepts thirteen event names and no custom values. `purchase` is the only monetary one, so both paid
conversions collapse to it and AdRoll cannot tell a new paid subscription from a trial conversion. Whether
`purchase` is the right name for either of them is Q6.

### D4. AdRoll's two required fields with no true server-side source

`page_location` and `ip` are both required by AdRoll and neither has an honest value at the moment a Stripe
webhook creates a paid conversion.

- `page_location` is set to the application billing URL, `AtsRootUrl` followed by `/hire/settings/billing`.
  That is the page in the application where a plan purchase is completed, so it is the closest true statement
  available, but it is not a URL the user was on when the conversion was recorded.
- `ip` is set to the organization owner's `current_sign_in_ip`, a real recorded value that may be days old and
  may not be the address they held when they clicked the ad. The send is skipped when it is absent rather
  than substituting anything.

If either is judged too loose, the alternative is to capture and store a conversion-time page and address,
which is a data model change and outside this work.

### D5. The four AdRoll payload lookups are complete

The four details SPEC.md previously deferred are resolved against `apidocs.nextroll.com` and written into
SPEC.md literally: the field is `conversion_value`, the unit is major currency units, the accompanying field
is `currency` as an uppercase three-letter ISO 4217 code, and the body is a top-level array. RATIONALE.md
carries the documentation each rests on. Nothing about the AdRoll payload remains a lookup.

One of the four was decided rather than read, because the documentation contradicts itself. The array-versus-
bare-object conflict is recorded under the RATIONALE.md heading "AdRoll — the body is a one-element array":
both canonical schema blocks show an array, all thirteen per-event examples and AdRoll's own linked example
client show a bare object, and SPEC.md sends the array. If AdRoll rejects it, the bare object is the fallback
and the change is one line in `AdrollS2sApi::Client`. AdRoll publishes no response contract, no status codes
and no auth-failure shape, so a rejection may not be visible in the response.

### D6. GA4 `consent` is omitted

The application holds no consent-state record for any user. Sending `ad_user_data: GRANTED` and
`ad_personalization: GRANTED` would assert something about the user that no stored value supports. Omitting
the block means GA4 applies its own default handling. If a consent mechanism exists that this reading missed,
this decision should be revisited.

### D7. `engagement_time_msec: 100` is a synthetic constant

It is a protocol requirement rather than a measurement — GA4 may leave an event with no engagement time out
of standard reports — and 100 is the value Google's own samples use. It is the one value in any payload that
does not come from a stored record. Recorded here explicitly because it sits close to the rule against
fabricating values for absent data, and is admitted deliberately rather than by oversight.

### D8. A uniform seven-hour delay on every Google Ads send, two minutes in development

Google rejects an upload whose click is less than six hours old with `TOO_RECENT_CLICK`, and `ownerSignedUp`
and `ownerCreatedOrganization` occur minutes after the click that produced them. Without a delay, those two
secondary conversion actions would be rejected for essentially every ad-originated signup.

The delay is applied to all five events rather than only the two that need it, because a seven-hour delay on a
conversion that is already days old changes nothing and one rule has no branch to get wrong. The cost is that
a paid conversion appears in Google Ads seven hours later than it could, and that a Sidekiq queue outage
inside that window drops the send with no retry.

In development the delay is two minutes, so that a send can be watched to completion inside a session. The
value lives in one place, `SendGoogleAdsConversionJob::ENQUEUE_DELAY`, because six call sites read it. Two
minutes is a pick, not a measurement: any value short enough to observe and long enough to still exercise the
delayed path would do.

The mitigation is untested. The six-hour figure is Google Ads Help for offline imports generally, not a Data
Manager API page, and the actual behaviour has not been observed.

### D9. The SSO signup dispatch moved out of `TrackNewSsoOwnerSignupJob`

The briefing names `app/jobs/track_new_sso_owner_signup_job.rb` line 14 as the third `ownerSignedUp` trigger
site, which is correct for the existing PostHog dispatch. SPEC.md places the new dispatch in
`Api::V1::Users::OmniauthCallbacksController` instead, beside the `TrackNewSsoOwnerSignupJob.perform_later`
call at line 45.

The reason is a guard-ordering trap: that job's second guard clause is `return unless POSTHOG_CLIENT`, and it
sits above every one of its `capture` calls. A Google Ads or GA4 dispatch placed below it would be silently
suppressed whenever the PostHog client is absent, which has nothing to do with whether Google should receive
the conversion. Placing it in the controller also puts all three signup dispatch sites in the same layer and
leaves the job untouched.

### D10. No status polling, no retries

`requestStatus:retrieve` is not called from application code. The `requestId` and any `fieldWarnings` are
logged so a send can be traced by hand. Polling requires a second endpoint, a minimum 30-minute wait, a
processing window of up to 24 hours, and somewhere to persist the request ID — which would be a data model
change.

No job declares `retry_on`, and every job ends `perform` with a method-level `rescue StandardError`. That
rescue also means Sidekiq never sees a failure and therefore never retries on its own. A failed advertising
send is logged and dropped. This matches `PosthogTrackJob` and the Discord notification jobs, and it
guarantees that no advertising destination can fail a signup request or a subscription callback.

### D11. camelCase names were extended to the two paid conversions

The briefing gives camelCase names for `ownerSignedUp`, `ownerCreatedOrganization` and `trialStarted`, and
refers to the paid conversions only by their enum keys. SPEC.md names them `convertedToPaidSubscription` and
`trialConvertedToPaidSubscription` for consistency with the stated convention.

Those two names have no external effect. Google Ads identifies a conversion by its numeric conversion action
ID and carries no event name in the payload, and AdRoll requires `purchase` from its own enumeration. The two
names appear only as job arguments and log labels.

### D12. The magic-link `ownerSignedUp` dispatch is gated on the invite token; the existing PostHog call is not

`Api::V1::RegistrationsController#create` gates its `organization_owner_signed_up` PostHog call on
`if @invite.nil?`. `#magic_create` does not: its call at line 216 is unconditional, and the path is reachable
by invited teammates — `AuthForm` sends `inviteToken` to `/magic_login` (`AuthForm.tsx` line 84), and a
brand-new invited user falls to the else branch at line 181, is created, and reaches line 216 without invite
acceptance, which the invites controller performs later.

SPEC.md gates the two new enqueues on `if params[:invite_token].blank?` rather than copying the unconditional
PostHog call. Without the gate every invited teammate produces a false `ownerSignedUp` conversion. The GA4
send is the live blast radius: an invited teammate has no `google_click_id`, so the Google Ads job
guard-skips, but they do have a `ga_client_id` from the ordinary GA cookie, so `SendGa4EventJob` fires and
inflates the signup step of the funnel with people who never clicked an ad.

The existing PostHog call is left untouched, so PostHog and the advertising destinations will disagree on the
magic-link owner-signup count. Correcting the PostHog call is a separate change to existing behaviour and is
Jessica's to make.

### D13. `SendGoogleAdsConversionJob` takes an organization id

The Google Ads `eventTimestamp` for `ownerCreatedOrganization` is the organization's `created_at`, so the job
needs the organization. The only other route is `User#organization`, which is
`current_organization_user&.organization` (`app/models/user.rb` line 206) — a mutable pointer rewritten by
`OrganizationUser#handle_after_create` whenever the user joins or switches organizations, and therefore
resolvable to the wrong organization seven hours after the enqueue. SPEC.md adds an optional organization id
parameter defaulting to nil; only the `Api::V1::OrganizationsController#create` enqueue passes it.

---

## Accepted risks

### R1. The Google Ads click-through conversion window is 30 days by default and changes are not retroactive

This is the single setting that decides whether a day-fourteen-to-thirty trial conversion counts at all, and
it must be set to 90 days on every one of the conversion actions **before** the clicks that are intended to
count. Google documents only the narrowing direction of the retroactivity rule; the safe reading is
forward-only in both directions. A conversion that fell outside the window when it happened is not rescued by
widening the window afterwards.

Blast radius if missed: every trial that converts after day 30 is invisible in Google Ads, permanently, with
no error anywhere. The code cannot detect this condition.

### R2. The numeric threshold behind `EVENT_TOO_OLD` is not published

The Data Manager API never states the maximum age it accepts. The discovery document says only *"The
conversion is older than max supported age."* The 90-day gclid retention and 63-day hashed-PII figures come
from Google Ads Help for offline imports generally, not from any Data Manager page.

Cheapest test: send one event carrying a gclid of known age with `validateOnly` false, then read
`errorInfo.errorCounts[]` from `requestStatus:retrieve`. Worth doing once with a deliberately old gclid to
find the real edge.

### R3. Ruby 3.1 excludes both official Google client library families

`google-ads-data_manager`, `google-ads-data_manager-v1` and `google-apis-datamanager_v1` all require Ruby 3.2
or newer in every current release. This application is Ruby 3.1.6. Pinning to the last 3.1-compatible releases
is possible but means adopting a frozen dependency for a two-call API.

The plain-REST path avoids this entirely and adds no gem: `faraday` 0.17.5 and `googleauth` 1.8.1 are both
already in the bundle. The residual exposure is that `googleauth` releases after 1.17.1 also require Ruby 3.2,
so a future bump of that gem is blocked until the application moves off 3.1 — a constraint that already
applies to the existing Google Sheets integration and is not created by this work.

### R4. The `datamanager` OAuth scope is classified sensitive

The user-credential path can require Google OAuth verification because of it; the service-account path does
not, and Google states verbatim that *"Google OAuth verification isn't required for service accounts."*

Jessica has ruled for the user-credential path on the grounds that every Google integration in this codebase
authenticates that way and that service accounts have been troublesome. This is a credential-provisioning
question, not a design question, and it does not change the spec's chosen auth path. What it may change is how
long it takes to obtain a working refresh token. Raised here so it is not discovered at provisioning time.

### R5. A new conversion action needs a 4–6 hour cool-down before it can receive uploads

Google states that uploading during the first 4–6 hours after creating a conversion action can delay
appearance in reports by up to two days. Separately, there is an undetermined question of whether the
documented 14-day non-biddable trial period for a new conversion action applies to an `UPLOAD_CLICKS` action
used only through the API. Plan for two weeks of data that reports but does not bid, either way.

### R6. There is no automated way to prove an event landed at any destination

GA4 returns 2xx for every request it receives including one with wrong credentials; AdRoll publishes no
response contract; and Google Ads returns a receipt whose real outcome arrives asynchronously up to 24 hours
later. Neither GA4 credential can be validated by any HTTP response — a single mistyped character produces a
clean 2xx and clean debug output while the event silently never lands.

Confirmation is manual and per-destination: GA4 DebugView or Realtime for the two signup events, the Google
Ads conversion column for the five conversion actions, and AdRoll's `dry_run=true` probe for the two paid
conversions.

### R7. AdRoll's server-to-server API is beta, unstable, and has one production token

AdRoll's own documentation carries the notice *"The S2S event API is under active development. Although the
API is generally stable, it may change. Event processing is not yet fully complete."* The help centre
separately describes the path as in beta. There is exactly one server access token, it is the one production
uses, and there is no self-serve way to obtain a second — the documented route is a request to an account
manager delivered through a single-use 1Password link that expires in seven days.

Consequence: development and staging sends land in the same account as production. `dry_run=true` is the only
documented safe probe.

### R8. Nothing under `spec/` has ever covered `SubscriptionEvent`

Four spec files that did were deleted on 2026-07-28. Combined with the bare `return` in the `else` branch of
`handle_after_commit_on_create`, a dispatch written against a wrong enum key executes never and reports
nothing, in every environment. `spec/models/subscription_event_spec.rb` in the test plan exists specifically
to close this, and the negative assertions in it — that `converted_to_paid` and `trial_converted_to_paid`
enqueue nothing — are the ones that matter.

### R9. `plan_simple_ats_per_job` conversion values vary with published job count

Per-job billing is driven by published job count, so a single price is meaningless for them and the backfill
wrote 0. Those zero amounts sit only on rows created by
`db/data/20260727185945_create_subscription_events_for_existing_paid_organizations.rb` under the
retroactive-only keys `converted_to_paid` and `trial_converted_to_paid`, neither of which is forwarded. No
live paid conversion can carry 0: `CreateSubscriptionEventFromStripe` returns at line 14 when
`stripe_object.amount_paid.to_i <= 0`, and otherwise sets `amount` to `invoice.amount_paid`, a positive
integer of cents. SPEC.md's rule — 0 and nil both send zero, at both destinations that carry a value — is
therefore defensive rather than load-bearing today.

The live per-job exposure is that the conversion value is whatever that month's job-count-driven invoice
charged, so value-based bidding sees a per-job organization's conversions vary run to run.

### R10. `ga_session_id` is a cookie string, not a GA4 `session_id`

The stored value is a full cookie string of the form `_ga_<CONTAINER>=GS1.1...`, assembled by
`gaSessionIdFromCookies`, and the Measurement Protocol requires `session_id` to match `^\d+$`. SPEC.md sends
the parameter, reducing the stored string to the numeric session identifier carried by the `_ga_FKDT1J0YB6`
entry and omitting the parameter whenever that reduction does not yield a run of digits. Anyone later tempted
to send the stored column unreduced will produce a rejected or ignored parameter.

### R11. Imported conversions report on the original click's date

Historical Google Ads campaign rows change after the fact as delayed conversions arrive. This reads as a
reporting bug and is not one; the "All conv. (by conv. time)" column shows them by conversion date instead.
Separately, when the Google Ads account attribution setting is "Paid and organic channels" rather than "Google
paid channels", conversion-window and counting changes must be made in Google Analytics rather than Google
Ads — worth checking before assuming the Ads interface controls are live, since GA4 property 313449782 is
linked.

### R12. The fast-fail batching model is neutralized, deliberately

The Data Manager API fails every record in a request when any one record has an error, and its error reporting
carries only a count and a reason — never an identifier for the record that failed. SPEC.md sends one event
per request, which makes every failure attributable and every `requestId` correlatable to a single
`SubscriptionEvent` or `User`. The cost is one HTTP request per conversion, which is nowhere near the
published limits of 300 requests per minute and 100,000 per day.

### R13. The 24-hour duplicate guard limits what can be forwarded

`CreateSubscriptionEvent` and `CreateSubscriptionEventFromStripe` both refuse to create a second event with
the same event type, `to_plan` and `stripe_subscription_id` within 24 hours. No `SubscriptionEvent` means no
forwarded conversion. This is pre-existing behaviour and is not changed by this work; it is recorded because
it is the mechanism by which a genuinely duplicated conversion inside a day would never reach any destination.

---

## Discrepancies between the briefing and the live code

None of these changes the design. All were verified in the source repo on branch
`server-side-conversion-events`.

1. **The Google Sheets credential trio has no `STAGING_` prefix.** The briefing states that
   `GOOGLE_INTERNAL_SHEETS_CLIENT_ID`, `GOOGLE_INTERNAL_SHEETS_CLIENT_SECRET` and
   `GOOGLE_INTERNAL_SHEETS_REFRESH_TOKEN` take the form `ENV['STAGING_…']`. They do not — all three read
   unprefixed environment variables. The `STAGING_` prefix is used by the neighbouring
   `GOOGLE_OAUTH_SSO_*`, `GOOGLE_RECAPTCHA_*` and `GA4_*` constants. SPEC.md uses `STAGING_` for the new
   constants, matching the GA4 pair immediately above them, which is the same feature and the same file
   section. Both forms are house forms; this is a consistency call, not a correctness one.

2. **The refresh-token exchange does exist in the codebase.** The briefing asks the spec to say so plainly if
   it does not. It does: `EngagementReport::GoogleSheetsSender#build_authorization` uses
   `Google::Auth::UserRefreshCredentials` with a client ID, client secret, refresh token and scope, followed
   by `fetch_access_token!`. `googleauth` 1.8.1 is in `Gemfile.lock`.

3. **Thirteen attribution identifiers are copied in `Api::V1::OrganizationsController#create`, not
   fourteen.** Lines 32 through 44 copy `utm_source`, `utm_campaign`, `utm_data`, `internal_ref`,
   `adroll_click_id`, `ga_client_id`, `ga_session_id`, `fbclid`, `fbp`, `fbc`, `li_fat_id`,
   `google_click_id` and `adroll_first_party_cookie`. Line 31 also copies `created_via`, which is not an
   attribution identifier. The same thirteen appear in `SubscriptionEvent#posthog_properties` and in
   `User#attribution_properties`.

4. **`GA4_MEASUREMENT_ID` and `GA4_API_SECRET` exist but are uncommitted.** They are present in
   `config/initializers/01_variables.rb` at lines 62 and 63 as working-tree changes on the branch, along with
   a modified `config/credentials.yml.enc`. `git log --oneline develop..HEAD` returns nothing — the branch is
   zero commits ahead of `develop`, and `git show HEAD:config/initializers/01_variables.rb` contains no `GA4_`
   constant at all. `GA4-CREDENTIALS-SETUP.md` §1a states that neither credential exists in the config, which
   was true when it was written. Any review of this work must read the committed diff, not the working tree,
   and a `git checkout` of that file would silently remove both constants.

9. **The GA4 Measurement Protocol API secret has not been created yet.** `GA4-CREDENTIALS-SETUP.md` §0 records
   the property ID and the measurement ID as confirmed and the API secret as outstanding. `GA4_API_SECRET`
   therefore resolves to nil today, so the GA4 path is inert on arrival for the same reason the Google Ads
   path is — a fact SPEC.md states for Google Ads and now states for GA4 as well.

5. **`HANDOFF.md` scopes AdRoll out.** It says AdRoll server-to-server is "Phase 2 — not now. Do not build it,
   do not design for it." The current briefing includes AdRoll as one of three destinations. The current
   briefing governs; `HANDOFF.md` is superseded on that point and remains authoritative on everything else,
   including the verification harness and the enum rename.

6. **`subscription_events` has no currency column and no invoice identifier column.** The table holds
   `organization_id`, `event_type`, `from_plan`, `to_plan`, `stripe_subscription_id`, `amount`,
   `billing_interval` and timestamps. Currency is therefore the literal `USD`, which is safe only because US
   dollars is the sole currency priced in the application: the plan checkout session at
   `app/controllers/api/v1/billing_controller.rb` line 108 sets no currency key and inherits it from the
   Stripe price, and every `currency:` literal in `app/` is `usd`. Line 833 of `app/models/organization.rb`
   is not evidence for this — it sits inside `setup_ai_credit_test_subscription` (line 808), which begins
   `return unless Rails.env.test?`, and it sets the `currency` column on an `organization_ai_credit_purchases`
   row, not a checkout session. The Google Ads `transactionId` uses the `SubscriptionEvent` id rather than a
   Stripe invoice id, because no invoice id is stored.

7. **There is no `around` block precedent for the queue adapter in the current spec suite.** Pipeline rule 31
   cites `spec/requests/.../bulk_ai_job_application_summaries_controller_spec.rb` lines 9–14 as the
   precedent; that file no longer exists. The suite is thirteen request specs under
   `spec/requests/api_public/v1/hire/` and none of them touches the queue adapter. The mechanism is standard
   Active Job and does not need a precedent file, but the cited analog cannot be opened.

8. **Neither WebMock nor VCR is in the bundle.** The test plan uses `rspec-mocks`, which arrives with
   `rspec-rails` 6.1.5, and stubs the Faraday connection directly. The Chatwoot prior art cited in the
   research uses an HTTParty-stub pattern that assumes a stubbing library this bundle does not have.

---

## Pre-existing defects noted and left alone

- **Interactor failure messages are swallowed.** `CreateSubscriptionEvent` and
  `CreateSubscriptionEventFromStripe` both wrap their whole body in `rescue StandardError`, and
  `Interactor::Failure` subclasses `StandardError`. Every deliberate `context.fail!` message — including the
  duplicate-guard message and the no-plan-change message — is replaced with
  `"An error occurred while creating the SubscriptionEvent"`. The guards work; only their diagnostics are
  lost. Out of scope.

- **`posthog_properties` returns a symbol-keyed hash, and `handle_after_commit_on_create` then writes
  `event_properties['$set']` with a string key.** The resulting hash carries mixed key types before
  `PosthogTrackJob` calls `deep_symbolize_keys` on it. Harmless today. Out of scope, and untouched by this
  work, which does not use `posthog_properties` at all.

- **`magic_create` dereferences a nil organization.** `Api::V1::RegistrationsController#magic_create` line 93
  enters the `login_intent == 'connect' && organization.nil?` branch and line 101 reads `organization.id`.
  Production never hits it because `AuthForm` always sends `login_intent: 'hire'`. Out of scope; the new
  controller spec avoids it by sending the same value.
