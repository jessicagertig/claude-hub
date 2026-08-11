# Server-side conversion forwarding

## Summary

Four events that the application already records — two signup/setup milestones and two paid-conversion
milestones — are forwarded from the Rails backend to three advertising and analytics destinations: the GA4
Measurement Protocol, the Google Ads Data Manager API, and the AdRoll server-to-server events API.

Each destination gets its own service and its own job. They share no base class, no adapter, no registry and
no common payload builder.

## Stack scope

Backend only.

**Frontend changes:** three browser-side dataLayer pushes are removed. The server-side conversions replace
them.

- `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBilling.tsx` line 81 — `hirePlanPurchase`
- `app/javascript/ats/src/views/jobApplications/JobStripeCheckoutRedirectHandler.tsx` line 42 —
  `hirePlanPurchase`
- `app/javascript/ats/src/views/sessions/NewOrganization.tsx` line 33 — `newOrganization`

Both `hirePlanPurchase` pushes carry a `transactionId` of `Date.now().toString()`, a hardcoded
`transactionValue` of `"119"` and the user's email, and both fire only when the browser returns to a Stripe
redirect page. `newOrganization` carries the same fabricated `transactionId`, a `transactionValue` of `"5"`
and the user's email. `ownerCreatedOrganization` replaces it.

The GTM tags listening for `hirePlanPurchase` and `newOrganization` in container `GTM-N6H844WJ` are left for
Jessica to remove; nothing in this work edits the container.

The `ctaClick` push in `app/javascript/ats/src/views/jobs/JobList.tsx` line 175 is not touched.

The existing browser-side PostHog call `trackEvent("organization_created")` in
`app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx` is not touched, not moved, and not
duplicated — the new server-side dispatch for that milestone goes to the destinations the table below names,
and never to PostHog.

**No data model changes.** No migration, no new column, no new table, no new enum value. Every value sent is
read from an existing column: `ga_client_id`, `ga_session_id`, `google_click_id`, `adroll_click_id` and
`adroll_first_party_cookie` on `users` and `organizations`, `users.id`,
`users.created_at`, `users.current_sign_in_ip`, `organizations.created_at`, `subscription_events.id`,
`subscription_events.amount` and `subscription_events.created_at`.

**No new gems.** `faraday` 0.17.5 is the house HTTP client and is already in the bundle. `googleauth` 1.8.1 is
already in the bundle and already used for a user-credential OAuth refresh in
`app/services/engagement_report/google_sheets_sender.rb`; the Google Ads path reuses it.

**No API changes.** No new route, no new endpoint, and no change to any HTTP method, request parameter or
response shape. The four controller actions modified here gain `perform_later` lines only. `sign_up_params` in
`Api::V1::RegistrationsController` is unchanged: the magic-link gate reads `invite_token` off raw `params`.

**No authorization changes.** No Pundit policy is created or modified.

## Events and destinations

Four events. The names below are the names this work uses for the four milestones, written in camelCase. Only
`ownerSignedUp` and `ownerCreatedOrganization` are carried on a wire, as the GA4 `events[0].name`. Google Ads
carries no event name — a conversion is identified there by its numeric conversion action ID — and AdRoll
carries the literal `purchase`. The other two names appear only as job arguments and log labels. The
internal PostHog event names for the same four milestones —
`organization_owner_signed_up`, `organization_created`, `converted_to_paid_subscription` and
`trial_converted_to_paid_subscription` — are unchanged and continue to be
sent to PostHog exactly as they are today.

| Destination-facing name | Fired from | GA4 | Google Ads | AdRoll |
|---|---|---|---|---|
| `ownerSignedUp` | three signup sites in two controllers | yes | secondary, no value | no |
| `ownerCreatedOrganization` | `Api::V1::OrganizationsController#create` | yes | secondary, no value | no |
| `convertedToPaidSubscription` | `SubscriptionEvent` `converted_to_paid_subscription` branch | no | primary, with value | yes, with value |
| `trialConvertedToPaidSubscription` | `SubscriptionEvent` `trial_converted_to_paid_subscription` branch | no | primary, with value | yes, with value |

The `trial_started` `SubscriptionEvent` branch is not touched. That milestone is forwarded to no destination;
its PostHog event and its Discord enqueue are unchanged.

### Trigger sites

`ownerSignedUp` fires from the three server-side sites that already dispatch the PostHog
`organization_owner_signed_up` event. Two of the three new dispatches are gated so that an invited teammate
does not produce an owner-signup conversion; the Google SSO dispatch carries no gate, no invite token reaching
that site:

- `app/controllers/api/v1/registrations_controller.rb` line 57, the email path. The existing PostHog call is
  already gated by `if @invite.nil?`; the new dispatch carries the same gate.
- `app/controllers/api/v1/registrations_controller.rb` line 216, the magic-link path. The new dispatch is
  gated by `if params[:invite_token].blank?`. The existing PostHog call is left exactly as it is.
- `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` line 45, the Google SSO path, inside the
  `if user.new_user_created_via_google_sso` branch alongside the existing
  `TrackNewSsoOwnerSignupJob.perform_later` call. No gate is applied.

`ownerCreatedOrganization` fires from `Api::V1::OrganizationsController#create`, inside the
`if @organization.save` branch, after `organization_user.org_owner!` and before `render_one`. The dispatch is
bound to this controller action rather than to `Organization#complete_setup_workers`, the model's existing
`after_commit` on create.

The two paid conversions fire from the existing `case event_type` in
`SubscriptionEvent#handle_after_commit_on_create`. Each new `perform_later` call is added inside the `when`
branch that already exists for that event type — `converted_to_paid_subscription` and
`trial_converted_to_paid_subscription`. The `trial_converted_to_paid_subscription` branch already holds a
`Discord::NotifyTrialConvertedToPaidJob` enqueue and the new enqueues sit beside it; the
`converted_to_paid_subscription` branch holds only its `event_properties['$set']` assignment, and the new
enqueues are the whole of its dispatch. The `PosthogTrackJob.perform_later` call is the trailing line after
the `case`, and no new enqueue is placed beside it. The `trial_started` branch is not touched.

The enum keys `converted_to_paid` and `trial_converted_to_paid` are retroactive-only. They were created by a
backfill, they appear in no `when` branch, and they must not be used.

## GA4 Measurement Protocol

Two events, `ownerSignedUp` and `ownerCreatedOrganization`.

Both paid conversions are deliberately not sent to GA4.

**Transport.** An HTTPS POST to `https://www.google-analytics.com/mp/collect`, with `measurement_id` and
`api_secret` as query-string parameters and `Content-Type: application/json`. The endpoint returns a 2xx
status for any request it receives. `https://www.google-analytics.com/debug/mp/collect` is not called from
application code.

**Payload fields.**

| Field | Source | Notes |
|---|---|---|
| `client_id` | `users.ga_client_id` | Top level. Required. |
| `user_id` | `users.id`, as a string | Top level. |
| `events[0].name` | `ownerSignedUp` or `ownerCreatedOrganization` | |
| `events[0].params.session_id` | `users.ga_session_id`, reduced to its numeric session identifier | Event-level. The protocol requires a value of digits and nothing else, which the stored column does not hold; the extraction rule below is what produces one. Absent, out of shape, or naming a session whose start is more than 24 hours before the send, the parameter is omitted and the rest of the send proceeds — `client_id` is the only GA4 value whose absence stops a send. |
| `events[0].params.engagement_time_msec` | the constant `100` | Not required by the protocol. Sent as a fixed constant, not as a measurement. |

**Extracting `session_id`.** The stored `users.ga_session_id` is not a session identifier by itself.
`gaSessionIdFromCookies` in `app/javascript/shared/lib/utils.js` collects every browser cookie whose name
begins with `_ga_` — GA4 writes one per property — renders each as its name, an equals sign and its value, and
joins them with a semicolon and a space. `Ga4MeasurementProtocol::Client` reverses that assembly. It splits
the stored string on the semicolon-and-space separator and takes the one entry whose name is `_ga_` followed
by `Variables::GA4_MEASUREMENT_ID` with its leading `G-` removed, which is `_ga_FKDT1J0YB6` for the property
this work writes to; when no entry carries that name the parameter is omitted. Within the matching entry the
value is everything after the first equals sign, and the session identifier is the third dot-separated segment
of that value — the first field after the `GS1.1` prefix that opens it. That segment is both the value the
protocol requires and the session's start time in Unix seconds, so it carries its own age. It is sent only
when it is a run of digits and nothing else and when that instant is within 24 hours of the send. A nil or
blank column, a stored string with no matching entry, a value of fewer than three dot-separated segments, a
third segment holding anything but digits, and a third segment naming an instant more than 24 hours before the
send all omit the parameter. Nothing is ever substituted for it and no session identifier is ever synthesized.
The raw cookie string is never sent.

Deliberately absent from the payload:

- `timestamp_micros`. Neither event is backdated.
- `consent`. The application records no advertising-consent state for anyone.
- `user_data`. No hashed email is sent to any destination in this work.
- `value` and `currency`. Neither of the two GA4 events is monetary.

**Credentials.** `Variables::GA4_MEASUREMENT_ID` and `Variables::GA4_API_SECRET`, both in place. The
measurement ID is `G-FKDT1J0YB6` on property `313449782`.

**By-hand GA4 configuration.** `ownerSignedUp` and `ownerCreatedOrganization` are each marked as a key event
at Admin → Data display → Events, once the first event of that name has arrived. Neither is set nor read by
any code.

## Google Ads Data Manager API

All four events, as three conversion actions in the Google Ads account. Both paid events resolve to the same
conversion action — Google Ads has no use for the distinction and splitting them would halve the volume in
each. The `SubscriptionEvent` ledger and PostHog keep the two apart.

**Primary, carrying monetary value:** the paid conversion action, which both `convertedToPaidSubscription`
and `trialConvertedToPaidSubscription` resolve to.

**Secondary, carrying no value:** `ownerSignedUp` and `ownerCreatedOrganization`.

Primary and secondary is a per-conversion-action setting in the Google Ads interface, not a payload field.
Each of the three is created by hand with type `UPLOAD_CLICKS` and its numeric ID held in a configuration
constant. Nothing in the code sets or reads the primary/secondary designation.

Three further settings are set by hand at creation and are neither set nor read by any code. The click-through
conversion window is 90 days on all three. Count is **One** on all three, not the **Every** default that
Google Ads applies to import conversion actions. Value applies only to the paid conversion action: **Use
different values for each conversion**, with a default value and currency the interface requires. No upload
ever reaches that default — every conversion sent to it carries `conversionValue`. The two secondary actions
record no value at all. A newly created conversion action needs four to six hours before it accepts uploads.

The event name reaches `GoogleDataManagerApi::Client` as a string and is resolved there to its conversion
action ID by a private `conversion_action_id` method holding an explicit `case` on the event name. Its `when`
clauses are the verbatim camelCase strings `ownerSignedUp`, `ownerCreatedOrganization`,
`convertedToPaidSubscription` and `trialConvertedToPaidSubscription`, each returning its
`Variables::GOOGLE_ADS_CONVERSION_ACTION_*` constant — the last two both returning
`GOOGLE_ADS_CONVERSION_ACTION_PAID_SUBSCRIPTION`. Every constant is read inside the method, at call time, and
is never captured in a class-level constant. The frozen array constant `RECOGNIZED_EVENT_NAMES` on the
`Client` class holds the same four verbatim strings and is what the unrecognized-event-name check tests.

The mapping is never derived from the event name by `underscore`, `camelize`, `const_get` or any other string
transformation: the four names are written out as camelCase string literals, and no code converts a
destination-facing name into a constant name or a conversion action ID. The snake_case forms `trial_started`,
`converted_to_paid_subscription` and `trial_converted_to_paid_subscription` remain in place as the
`SubscriptionEvent` enum keys, as the `when` literals in `handle_after_commit_on_create` and as the PostHog
event names; nothing in this work renames them, and none of them is ever used as a `when` clause of
`conversion_action_id`. No event-to-destination table is created in any layer.
`SendGoogleAdsConversionJob` holds no mapping of its own and never sees a conversion action ID.

**Transport.** An HTTPS POST to `https://datamanager.googleapis.com/v1/events:ingest`, with
`Authorization: Bearer <access token>`, `x-goog-user-project: <cloud project id>` and
`Content-Type: application/json`. No developer token and no `login-customer-id` header.
`x-goog-user-project` names the Cloud project the request is billed and quota-counted against, and is sent on
every request.

**Authentication.** The user-credential OAuth path — a client ID, a client secret, and a long-lived refresh
token exchanged for a short-lived bearer token at call time. Not a service account, not domain-wide
delegation, and not a downloaded service-account key file. The exchange itself is
`Google::Auth::UserRefreshCredentials` from the `googleauth` gem, constructed with the client ID, client
secret, refresh token and scope exactly as `EngagementReport::GoogleSheetsSender#build_authorization`
constructs it. The scope is `https://www.googleapis.com/auth/datamanager`.

The private `access_token` method calls `fetch_access_token!` on the credentials object and returns that
object's own `access_token` reader — the string interpolated into `Authorization: Bearer`.

The transport is plain REST over Faraday rather than a Google client library.

**Payload fields.** One event per request.

| Field | Source | Notes |
|---|---|---|
| `destinations[0].operatingAccount.accountType` | the literal string `GOOGLE_ADS` | |
| `destinations[0].operatingAccount.accountId` | the Google Ads customer ID constant | A JSON string of digits only. `GoogleDataManagerApi::Client` sends `Variables::GOOGLE_ADS_CUSTOMER_ID` with hyphens removed and never converts it to an Integer. |
| `destinations[0].productDestinationId` | the conversion action ID for this event, resolved inside `GoogleDataManagerApi::Client` | A JSON string. The bare digits read from the `ctId` query parameter in the Google Ads conversion detail URL, never the `customers/{id}/conversionActions/{id}` resource-name form, and never converted to an Integer. |
| `validateOnly` | `Variables::GOOGLE_DATA_MANAGER_VALIDATE_ONLY` | The environments other than production set it true so their conversions are validated and discarded rather than recorded in the live Google Ads account. Absent from the environment it is false, and the send is live. |
| `events[0].adIdentifiers.gclid` | `google_click_id` | Sent raw, never hashed, case preserved exactly as stored. |
| `events[0].eventTimestamp` | `created_at` of the source record, in RFC 3339 | The `SubscriptionEvent` for the two paid conversions; the `User` for `ownerSignedUp`; the `Organization` named by the organization id the job was enqueued with for `ownerCreatedOrganization`. The job never derives an organization from `User#organization`. The value entering the body hash is an RFC 3339 String formatted inside `GoogleDataManagerApi::Client`, never the `ActiveSupport::TimeWithZone` itself. |
| `events[0].eventSource` | the literal string `WEB` | Required for the Google Ads offline use case. |
| `events[0].conversionValue` | `subscription_events.amount` divided by `100.0` | Paid conversions only, and always present on one. The column is a nullable integer of cents; this field is currency units, not micros. The presence guard comes first and the float division second — `amount.present? ? amount.to_i / 100.0 : 0.0` — so a nil amount sends `0.0` rather than omitting the key and letting the conversion action's configured default value stand in. The result is a Ruby `Float` emitted as a JSON number; `BigDecimal` is not used. |
| `events[0].currency` | the literal string `USD` | Paid conversions only, always alongside `conversionValue`, and therefore always present on one. Absent from the JSON entirely for `ownerSignedUp` and `ownerCreatedOrganization`, never null. |
| `events[0].transactionId` | `subscription_events.id`, as a string | The two paid conversions only. For `ownerSignedUp` and `ownerCreatedOrganization` the key is absent from the JSON entirely, never null. |

`loginAccount` is omitted; it defaults to `operatingAccount`. The request-level `encoding` field is omitted.
`userData` is not sent at all. No key whose value is absent appears in the request body carrying a JSON null;
every conditional field is omitted from the hash before it is serialized.

For `google_click_id` on the two paid conversions the owner's value is preferred and the organization's
is the fallback, via the existing `SubscriptionEvent#attribution_value` called on the `SubscriptionEvent` the
job loaded. For `ownerSignedUp` and `ownerCreatedOrganization` the value is read from the user directly, with
no organization fallback. `attribution_value` stays exactly where it is,
a public instance method on `SubscriptionEvent`. It is not copied into a job, not wrapped in a helper, not
moved into a concern and not reimplemented anywhere. The `organization_id` argument on the
`ownerCreatedOrganization` dispatch is carried only as the `eventTimestamp` source.

**Enqueue delay.** Every Google Ads send is enqueued with a delay — both `ownerSignedUp` sites in
`Api::V1::RegistrationsController`, the `ownerSignedUp` site in `Api::V1::Users::OmniauthCallbacksController`,
the `ownerCreatedOrganization` site in `Api::V1::OrganizationsController#create`, and both paid
`SubscriptionEvent` branches — six sites. The delay is seven hours, two minutes in development, and none at
all in test. A delay of none means no wait value at all: the test environment's inline queue adapter cannot
schedule, and any real duration raises there.

Each call site determines the duration itself, following `app/models/job.rb` line 707,
`app/services/submit_resume_to_textract.rb` line 27 and
`lib/active_storage_svg_sanitizer/svg_sanitizer.rb` line 19, which all keep it at the call site. No constant
is declared for it and no call site reads one from another class. The delay applies to all four events.

**Response handling.** A 200 is a receipt, not a success. The synchronous response carries a
`requestId` and a `fieldWarnings` array. `GoogleDataManagerApi::Client` parses the response body with
`Oj.load` inside its private `request` method and logs there; the job never sees a response. The `requestId`
is written with `ap` and `Rails.logger.info`. A `fieldWarnings` array that is present and non-empty is
additionally written with `ap` and `Rails.logger.error`. `Rails.logger.error` is otherwise written on three
paths only: the client's unrecognized-event-name line, its retry-exhaustion line, and the enclosing job's
method-level rescue. Raising `ApiError` writes no line of its own. A clean send leaves no error-level line,
and `Rails.logger.warn` is written only by a retry. The status-polling endpoint `requestStatus:retrieve` is not called from
application code in this work — the logged `requestId` is the handle for polling by hand when a send needs
investigating.

**Configuration constants.** Nine constants in `config/initializers/01_variables.rb`: four credentials under
`GOOGLE_DATA_MANAGER_` — a cloud project ID, an OAuth client ID, an OAuth client secret and a refresh token —
the `GOOGLE_DATA_MANAGER_VALIDATE_ONLY` boolean, and four non-secret literals under `GOOGLE_ADS_` — a customer
ID and three conversion action IDs. They are listed by name under Configuration.

## AdRoll server-to-server

Two events, `convertedToPaidSubscription` and `trialConvertedToPaidSubscription`. Both send the same AdRoll
event name, so nothing distinguishes them on the wire.

**Transport.** An HTTPS POST to `https://srv.adroll.com/api`, with the advertisable EID as a required
`advertisable` query-string parameter, `Authorization: Token <server access token>` — the scheme is literally
`Token`, not `Bearer` — and `Content-Type: application/json`.

**Payload fields.** One event per request. The request body is a top-level JSON array holding exactly one
event object, and the fields below are that object's.

| Field | Source | Notes |
|---|---|---|
| `advertisable_eid` | `Variables::ADROLL_ADVERTISABLE_EID` | Required in the body as well as in the query string. |
| `pixel_eid` | `Variables::ADROLL_PIXEL_EID` | Required. |
| `event_name` | the literal string `purchase` | AdRoll accepts a closed enumeration of thirteen event names and no custom values. |
| `conversion_value` | `subscription_events.amount` divided by `100.0`, then rendered as a string | Always present. The column is a nullable integer of cents and the field is major currency units, so the presence guard comes first and the float division second — `amount.present? ? amount.to_i / 100.0 : 0.0` — and a nil amount sends zero rather than omitting the key. The `Float` is then rendered by `format` with the `%.2f` directive and sent as a JSON string, not as a bare number: an `amount` of 4999 sends `"49.99"`, an `amount` of 0 and a nil `amount` both send `"0.00"`. |
| `currency` | the literal string `USD` | Always present, alongside `conversion_value`. An uppercase three-letter ISO 4217 code. |
| `page_location` | `"#{Variables::AtsRootUrl}/hire/settings/billing"` | Required. Assembled inside the client as a double-quoted interpolated string. The house form is `app/mailers/stripe_subscription_mailer.rb` line 21, without that line's `?utm_source=appEmail` suffix. |
| `ip` | `users.current_sign_in_ip` of the organization owner | Required. The column is `inet`, so the attribute is an `IPAddr` and is sent as `current_sign_in_ip.to_s`. The column is nullable; when it holds no value the send is skipped at the job's guard clause, exactly as an absent identifier pair is. Nothing is synthesized. |
| `identifiers.adct` | `adroll_click_id` | Omitted when absent. |
| `identifiers.first_party_cookie` | `adroll_first_party_cookie` | Omitted when absent. |

AdRoll requires at least one of `identifiers.first_party_cookie` and `identifiers.adct`. Both are read through
`SubscriptionEvent#attribution_value`, preferring the owner's value over the organization's. When both are
absent the send is skipped.

`dry_run` is not sent.

**Credentials.** `Variables::ADROLL_S2S_API_KEY`, `Variables::ADROLL_ADVERTISABLE_EID` and
`Variables::ADROLL_PIXEL_EID`.

## New files

Six files. Three services and three jobs, sharing nothing.

All three services follow `app/services/webflow_api.rb`: a single file holding a module and a `Client` class,
an endpoint constant, a memoized private `client`, a private `request`, and an error class subclassing
`Faraday::ClientError` with the same `initialize(message, response)` shape. Only the deltas from it are
specified below and under Failure behavior. All three jobs follow `app/jobs/posthog_track_job.rb` — `find_by`,
a bare guard, delegation — with the rescue block from
`app/jobs/export_organization_candidates_to_csv_job.rb` lines 22 to 25.

Each has an `initialize` taking its credentials and its base URL as keyword arguments defaulting to the
`Variables::` constants and to `API_ENDPOINT`, with `attr_reader`s for them, and raising when a credential is
nil. The keyword-argument defaults are the form of `WhatJobsApi::Client#initialize`, which raises nothing; the
raise is the form of `WebflowApi::Client#initialize`'s opening `raise 'Must Set access_token' if access_token.nil?`,
written once per credential.
`GoogleDataManagerApi::Client`'s credentials are the four `GOOGLE_DATA_MANAGER_` credential constants and no
others — `GOOGLE_DATA_MANAGER_VALIDATE_ONLY`, the customer ID and the three conversion action IDs are read
inside the methods that send them, as stated above.

Deltas shared by all three services, each forced by something these destinations do that Webflow does not:

- `request` takes no `http_method:` or `endpoint:` and does no `public_send` dispatch. Each destination has
  exactly one endpoint and one method; the analog's dispatch exists to serve its many endpoints.
- One error class, so no `error_class` case statement. None of the three destinations distinguishes its
  failures in a way the caller acts on differently.

| Path | Class or module | What it does |
|---|---|---|
| `app/services/ga4_measurement_protocol.rb` | `Ga4MeasurementProtocol::Client` | Public `send_event`, taking keyword arguments `client_id:`, `ga_session_id:`, `user_id:` and `event_name:`. `ga_session_id` arrives as the stored cookie string and is reduced to the protocol's numeric `session_id` by the private `session_id_from_ga_session_id`. Delta: no error class at all — a non-2xx is never raised, because the endpoint answers 2xx to anything it receives. `request` returns the final Faraday response; `send_event` reads `status` and `body` off it and, on a status outside 200 to 299, writes the failure line to both `ap` and `Rails.logger.error` with the destination `GA4`, the event name, the user id, the response status and the response body. That line is written in `send_event`, not in `request`. `send_event` returns the response's integer status. `SendGa4EventJob` does not read that return value and adds no log line of its own. |
| `app/services/google_data_manager_api.rb` | `GoogleDataManagerApi::Client` and `GoogleDataManagerApi::ApiError` | Public `ingest_events`, taking keyword arguments `event_name:`, `gclid:`, `event_timestamp:`, and `transaction_id: nil` and `amount_cents: nil`, both supplied for the two paid conversions only. It resolves the event name to its conversion action ID through its private `conversion_action_id`, assembles `conversionValue` and `currency` only for `convertedToPaidSubscription` and `trialConvertedToPaidSubscription` — the event name and not the amount's nil-ness is what decides that — applying the presence guard and the `100.0` division described under Google Ads Data Manager API, assembles the request body and posts it. Private `conversion_action_id`, and a private `access_token` performing the `Google::Auth::UserRefreshCredentials` refresh and returning the credentials object's `access_token` string. `ApiError` is raised as `ApiError.new(response.body, response)` — immediately for a status below 500, and for a 429 or 5xx once the retries are exhausted. The file adds `require 'googleauth'`, matching `app/services/engagement_report/google_sheets_sender.rb`. |
| `app/services/adroll_s2s_api.rb` | `AdrollS2sApi::Client` and `AdrollS2sApi::ApiError` | Public `send_event`, taking keyword arguments `ip:`, `amount_cents:`, `adroll_click_id: nil` and `adroll_first_party_cookie: nil`; whichever of the two identifier arguments is nil is omitted from the `identifiers` object rather than sent as null. It sends the literal `purchase` as `event_name` and assembles `conversion_value` and `currency`, applying the presence guard, the `100.0` division and the `%.2f` string rendering described under AdRoll server-to-server. Delta: the request body is a one-element Array rather than a Hash. `ApiError` is raised as `ApiError.new(response.body, response)` — immediately for a status below 500, and for a 429 or 5xx once `request` has exhausted its retries. |
| `app/jobs/send_ga4_event_job.rb` | `SendGa4EventJob` | Takes the keyword arguments `user_id:` and `event_name:`. Finds the user with `find_by` and, once the guards under Failure behavior pass, delegates to `Ga4MeasurementProtocol::Client`. It passes `ga_session_id` through exactly as the column holds it and parses nothing. |
| `app/jobs/send_google_ads_conversion_job.rb` | `SendGoogleAdsConversionJob` | Takes the keyword arguments `user_id:`, `event_name:`, `organization_id:` defaulting to nil and `subscription_event_id:` defaulting to nil, following `EngagementReport::GeneratorJob#perform`, which already mixes required and optional keyword arguments and is already enqueued with keyword arguments through `perform_later` at `app/models/organization.rb` line 1057. Finds each supplied record with `find_by` and applies the guards under Failure behavior. Resolves the gclid through `SubscriptionEvent#attribution_value` when a subscription event id was given, and from `user.google_click_id` alone otherwise. Passes to `GoogleDataManagerApi::Client` the event name, the gclid, the source record's `created_at`, the subscription event's `id` as the transaction id when a subscription event id was given, and the subscription event's `amount` in cents only for `convertedToPaidSubscription` and `trialConvertedToPaidSubscription`. No amount and no transaction id is passed for `ownerSignedUp` or `ownerCreatedOrganization`. It performs no arithmetic on the amount and never sees a conversion action ID. |
| `app/jobs/send_adroll_conversion_job.rb` | `SendAdrollConversionJob` | Takes the keyword argument `subscription_event_id:`. Both events it is enqueued for send the same AdRoll event name, so it carries no event name. Finds the subscription event with `find_by` and, once the guards under Failure behavior pass, delegates to `AdrollS2sApi::Client` with the subscription event's `amount` in cents. It performs no arithmetic on the amount. |

Each service holds its endpoint URL as a constant on its `Client` class, following `WebflowApi::Client` and
`WhatJobsApi::Client`. Every initializer keyword argument defaults to its `Variables::` constant or to
`API_ENDPOINT`, so each job constructs its client with no arguments at the call site.
Each public method takes keyword arguments carrying simple values only, never an Active Record
object; each job constructs its client and calls its one public method, and no record crosses that boundary.
All six new files open with `# frozen_string_literal: true`, the house form throughout `app/services/` and
`app/jobs/`. Every verbatim payload literal in these three clients — `GOOGLE_ADS`, `WEB`, `USD`, `purchase`,
the four camelCase event names and the header names — is a single-quoted Ruby string; the only double-quoted
interpolated strings are AdRoll's `page_location`, the two `Authorization` header values, and every `ap` and
`Rails.logger` label carrying a record id, an event name, a response status or a response body.

Each job constructs its destination's client directly rather than routing through a model instance method. No
`send_ga4_event`, `send_google_ads_conversion` or `send_adroll_conversion` method is added to `User`,
`Organization` or `SubscriptionEvent`.

Each job subclasses `ApplicationJob`, declares `queue_as :default` and ends `perform` with a method-level
`rescue StandardError => e` shaped exactly like
`app/jobs/export_organization_candidates_to_csv_job.rb` lines 22 to 25 —
`Rails.logger.error e`, then an `ap` label string naming the destination and the record the send was for,
then `ap e`. `SendGa4EventJob` and `SendGoogleAdsConversionJob` each name the destination-facing event name
they were enqueued with alongside the user id; `SendAdrollConversionJob`, enqueued with no event name, names
the subscription event id alone. The exception object goes to both writers, not only `e.message`. No
job declares `retry_on` or `discard_on`: the retry belongs to the client's private `request`, described under
Failure behavior, so a failure reaching the job has already been retried at the destination. This rescue is
the last record the failure produces and the only one written outside the client.

Record variables use the full model name in snake_case at every layer: `subscription_event` for a
`SubscriptionEvent` — never `event`, `record`, `subscription` or `sub_event` — `user` for a `User`,
`organization` for an `Organization`, and `owner` only for `organization.owner`. The bare word `event` is
never used as a variable name in this work: the destination-facing name is always `event_name`, and the record
is always `subscription_event`.

## Modified files

| Path | Change |
|---|---|
| `app/models/subscription_event.rb` | Four `perform_later` calls added inside two existing `when` branches of `handle_after_commit_on_create`. The `converted_to_paid_subscription` and `trial_converted_to_paid_subscription` branches each gain a `SendGoogleAdsConversionJob` enqueue and a `SendAdrollConversionJob` enqueue. Each `SendGoogleAdsConversionJob` enqueue passes `user_id: organization.owner.id`, `event_name:` the destination-facing event name and `subscription_event_id: id`, and omits `organization_id:` entirely; each `SendAdrollConversionJob` enqueue passes `subscription_event_id: id`. The `trial_started` branch is not touched. No branch is added, no branch is reordered, no existing line is changed, and the trailing `PosthogTrackJob.perform_later` call is untouched. |
| `app/controllers/api/v1/registrations_controller.rb` | Two sites. At line 57, beside the existing `organization_owner_signed_up` PostHog dispatch and carrying the same `if @invite.nil?` gate, a `SendGa4EventJob` enqueue and a `SendGoogleAdsConversionJob` enqueue for `ownerSignedUp`. At line 216, in the magic-link path, the same two enqueues gated by `if params[:invite_token].blank?`. Both sites pass `user_id: resource.id` and `event_name: 'ownerSignedUp'` to `SendGoogleAdsConversionJob` and omit `organization_id:`. |
| `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` | Inside the `if user.new_user_created_via_google_sso` branch at line 45, beside `TrackNewSsoOwnerSignupJob.perform_later`, a `SendGa4EventJob` enqueue and a `SendGoogleAdsConversionJob` enqueue for `ownerSignedUp`, the latter passing `user_id: user.id` and `event_name: 'ownerSignedUp'` and omitting `organization_id:`. |
| `app/controllers/api/v1/organizations_controller.rb` | Inside `create`, in the `if @organization.save` branch after `organization_user.org_owner!` and before `render_one`, a `SendGa4EventJob` enqueue and a `SendGoogleAdsConversionJob` enqueue for `ownerCreatedOrganization`, the latter passing `user_id: current_user.id`, `event_name: 'ownerCreatedOrganization'` and `organization_id: @organization.id`. |
| `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBilling.tsx` | The `hirePlanPurchase` dataLayer push at lines 81 to 88 is removed, with the two comments at lines 79 to 80 and `currentUser` from the `useCurrentSession()` destructure at line 27, whose only use is the removed push. The `if (checkout === "success" && session_id != undefined)` block at line 78 stays — it still holds the two `queryClient.invalidateQueries` calls. Nothing else in the file changes. |
| `app/javascript/ats/src/views/jobApplications/JobStripeCheckoutRedirectHandler.tsx` | The `hirePlanPurchase` dataLayer push at lines 42 to 49 is removed, with the two comments at lines 40 to 41, the `if (checkout === "success" && session_id != undefined)` block at lines 39 to 50 that the push is the whole body of, and the `useCurrentSession` import at line 10 and its `const { currentUser } = useCurrentSession();` call at line 19, whose only use is the removed push. Nothing else in the file changes. |
| `app/javascript/ats/src/views/sessions/NewOrganization.tsx` | The `newOrganization` dataLayer push at lines 33 to 40 is removed. `currentUser` stays in the `useCurrentSession()` destructure at line 21 — `OrganizationForm` still takes it at line 63. Nothing else in the file changes. |

No interactor extraction and no restructuring of `Api::V1::OrganizationsController#create`,
`Api::V1::RegistrationsController#create`, `Api::V1::RegistrationsController#magic_create` or
`Api::V1::Users::OmniauthCallbacksController#google_oauth2` is in scope; every change to
these four files is the addition of `perform_later` lines beside the PostHog dispatches already present.

`app/jobs/track_new_sso_owner_signup_job.rb`,
`app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx` and the `ctaClick` push in
`app/javascript/ats/src/views/jobs/JobList.tsx` are deliberately not modified.

## Configuration

All thirteen constants are declared in `config/initializers/01_variables.rb` and hold values.

Credential constants take an environment variable with a `STAGING_` prefix, falling back to
`Rails.application.credentials.dig(Rails.configuration.x.RailsCredentialsEnv, <namespace>, <key>)`, the form
the two GA4 constants above them already use. `config/credentials.yml.enc` holds those values per environment
and is edited through `rails credentials:edit`.

Under `# Google Analytics 4 - Measurement Protocol`:

- `GA4_MEASUREMENT_ID`, from `STAGING_GA4_MEASUREMENT_ID` or `google` / `ga4_measurement_id`
- `GA4_API_SECRET`, from `STAGING_GA4_API_SECRET` or `google` / `ga4_api_secret`

Under `# AdRoll - server-to-server events`:

- `ADROLL_S2S_API_KEY`, from `STAGING_ADROLL_S2S_API_KEY` or `adroll` / `s2s_api_key`
- `ADROLL_ADVERTISABLE_EID`, from `STAGING_ADROLL_ADVERTISABLE_EID` or `adroll` / `advertisable_eid`
- `ADROLL_PIXEL_EID`, from `STAGING_ADROLL_PIXEL_EID` or `adroll` / `pixel_eid`

Under `# Google Data Manager API`:

- `GOOGLE_DATA_MANAGER_CLOUD_PROJECT_ID`, from `STAGING_GOOGLE_DATA_MANAGER_CLOUD_PROJECT_ID` or `google` /
  `data_manager_cloud_project_id`
- `GOOGLE_DATA_MANAGER_CLIENT_ID`, from `STAGING_GOOGLE_DATA_MANAGER_CLIENT_ID` or `google` /
  `data_manager_client_id`
- `GOOGLE_DATA_MANAGER_CLIENT_SECRET`, from `STAGING_GOOGLE_DATA_MANAGER_CLIENT_SECRET` or `google` /
  `data_manager_client_secret`
- `GOOGLE_DATA_MANAGER_REFRESH_TOKEN`, from `STAGING_GOOGLE_DATA_MANAGER_REFRESH_TOKEN` or `google` /
  `data_manager_refresh_token`
- `GOOGLE_DATA_MANAGER_VALIDATE_ONLY`, from `GOOGLE_DATA_MANAGER_VALIDATE_ONLY`, true only when that
  environment variable is the string `true`. It has no credentials fallback and no `STAGING_` prefix — it is
  set in every environment except production, and absent it is false. The credentials keys keep their existing
  `data_manager_` names because they already sit under the `google` section.

Under `# Google Ads - conversion actions`. These are not credentials and not secrets — a customer ID and three
numeric conversion action IDs, each read from the Google Ads conversion detail URL's `ctId` parameter. Each is
a literal string assigned directly in the file, with no environment variable and no credentials lookup:

- `GOOGLE_ADS_CUSTOMER_ID`
- `GOOGLE_ADS_CONVERSION_ACTION_OWNER_SIGNED_UP`
- `GOOGLE_ADS_CONVERSION_ACTION_OWNER_CREATED_ORGANIZATION`
- `GOOGLE_ADS_CONVERSION_ACTION_PAID_SUBSCRIPTION`, which both paid events resolve to

The `.env` file is Jessica's. Nothing in this work writes to it.

## Failure behavior

No identifier is ever fabricated to fill a gap. An absent identifier is an absent identifier: the send does
not happen, and no substitute, placeholder, empty string or zero stands in for it. The monetary value is not
an identifier and goes the other way: on a paid conversion an absent `amount` sends zero at both destinations
that carry a value rather than omitting the key, which would let each destination's own configured default
value stand in.

**An unrecognized event name is a programming error.** `ingest_events` tests `RECOGNIZED_EVENT_NAMES` before
anything else and, on a miss, writes to both `ap` and `Rails.logger.error` naming the unrecognized event name
and abandons the send. A missing credential is not handled here: each client's `initialize` raises on a nil
credential, and the enclosing job's method-level rescue catches it.

**An absent identifier skips the send at the job's guard clause,** before the service is constructed:

- `SendGa4EventJob` returns when the user is not found or `ga_client_id` is blank.
- `SendGoogleAdsConversionJob` returns when the user is not found, when an organization id was given but no
  such record exists, when a subscription event id was given but no such record exists, or when no
  `google_click_id` is available.
- `SendAdrollConversionJob` returns when the subscription event is not found, when its organization has no
  owner, when the owner has no `current_sign_in_ip`, or when both `adroll_click_id` and
  `adroll_first_party_cookie` are absent.

**A transport-level failure is retried inside the client,** following
`WhatJobsApi::Client#create_listing` — the retry wraps the `request` call inside the public method, with
`max_retries` of 3 in a local, `2**retry_count` backoff, one `Rails.logger.warn` per attempt carrying the
attempt count, and one `Rails.logger.error` on final failure. `WebflowApi::Client`'s retry is not the model:
it counts in instance variables set in `initialize`, where these clients count in locals inside the public
method and hold no retry state on the instance.

Retried: a post raising `Faraday::TimeoutError` or `Faraday::ConnectionFailed`, and a response status of 429
or 500 to 599. The rescue names those two classes and nothing broader. Every other status outside 200 to 299
is not retried.

**After the retries the send is logged and dropped.** `GoogleDataManagerApi::Client` and `AdrollS2sApi::Client`
write one `Rails.logger.error` naming the destination and the number of attempts made, then raise: a run that
ended on a 429 or a 5xx raises that client's own `ApiError`, which is also what any other response outside 200
to 299 raises immediately without retrying, and a run that ended on a transport failure re-raises the Faraday
exception. Either way the enclosing job's method-level rescue, described under New files, catches it and the
send is dropped. No new enqueue is wrapped in a rescue, matching the `PosthogTrackJob` and
`Organization#complete_setup_workers` enqueues that already sit at these sites.

`Ga4MeasurementProtocol::Client` raises no error class of its own: on exhaustion it returns the final response
to `send_event` and writes no exhaustion line. A transport failure surviving all three attempts propagates out
of it as it does out of the other two.

For Google Ads specifically, a 200 does not mean the conversion was accepted — see Response handling for what
is logged.

## Don't fuck with this

Each of these is a decision already made. Changing one is a defect, not an improvement.

- **No abstraction across the three destinations.** No base class, no mixin, no registry, no shared payload
  builder, no common interface, no shared parent job. The three clients resemble each other and stay separate
  anyway.
- **The live enum keys are `converted_to_paid_subscription` and `trial_converted_to_paid_subscription`.**
  `converted_to_paid` and `trial_converted_to_paid` are retroactive-only and appear in no `when` branch. A
  branch written on either never executes, the `else` bare-returns, and nothing reports it.
- **Money units differ per destination.** The column is cents. Google Ads takes major units as a JSON number,
  never micros. AdRoll takes major units rendered `%.2f` as a JSON string, never a bare number. Neither is the
  other.
- **The conversion action ID is resolved by an explicit `case` on the four verbatim camelCase strings.** Never
  by `underscore`, `camelize`, `const_get` or any other transformation of the event name into a constant name.
- **Retry lives in the client's public method, following `WhatJobsApi::Client#create_listing`.** No job
  declares `retry_on` or `discard_on`. The four AI jobs that use `retry_on` are a dependent pipeline requiring
  synchronous handling; they are not the analog for this work.
- **No fallback value is ever fabricated for absent data.** No `|| 0`, no `|| ''`, no `|| []`. An absent
  identifier means the send does not happen. The only zeros written are the ones this spec names explicitly.
- **The `session_id` extraction matches the container to our measurement ID.** Not the first `_ga_` entry.
  The cookie value is everything after the *first* `=`.
- **No tests, no specs, no test section.** This project does not write them.
- **`app/jobs/track_new_sso_owner_signup_job.rb` and
  `app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx` are not touched.** Neither is
  `app/models/organization.rb`.
- **The six Google Ads call sites each determine their own delay.** No constant, nothing declared on the job
  class, no call site reading a value from another class.
- **The four camelCase event names are written out as string literals wherever they appear.** No name is
  derived from another.

## Existing patterns to follow

- **API client services**: `app/services/webflow_api.rb` and `app/services/what_jobs_api.rb`. Both are a
  single file holding a module plus a `Client` class, with an endpoint constant, a memoized private `client`
  building the Faraday connection and setting its headers, a private `request` that dispatches by HTTP method
  and inspects `response.status`, and error classes subclassing `Faraday::ClientError`. Their constructor and
  credential handling are the model — see the constructor contract under New files. Faraday 0.17.5's `post` signature is
  `(url, body, headers)`, so the analogs' `params:` keyword becomes the request body on a POST and cannot
  carry query parameters; query-string parameters are set on the connection inside the memoized `client`
  block alongside the header assignments, where Faraday copies them into every request.
  `Ga4MeasurementProtocol::Client` sets `client.params['measurement_id']` and `client.params['api_secret']`,
  and `AdrollS2sApi::Client` sets `client.params['advertisable']`.

  Each memoized `client` block registers `client.request :json` and `client.adapter Faraday.default_adapter`
  before the header and query-parameter assignments, exactly as `WebflowApi::Client` and `CloudflareClient`
  do. `client.request :json` is `FaradayMiddleware::EncodeJson` from
  `faraday_middleware` 0.14.0, already in the bundle through `slack-ruby-client`; it serializes the body with
  `JSON.dump` and sets `Content-Type: application/json` itself, so none of the three clients assigns a
  `Content-Type` header by hand and each `request` passes its assembled body to `post` as a Ruby object —
  a Hash for GA4 and Google Ads, a one-element Array for AdRoll — never as a pre-encoded string. Every value in an assembled body is a JSON-native scalar — String, Integer,
  Float, true or false — converted inside the client. `WhatJobsApi::Client` is not the model for this.
- **Google user-credential OAuth refresh**: `app/services/engagement_report/google_sheets_sender.rb`. Its
  `build_authorization` constructs `Google::Auth::UserRefreshCredentials` with the client ID, client secret,
  refresh token and scope, and calls `fetch_access_token!` on it.
- **A job that finds a record and delegates to a service**: `app/jobs/posthog_track_job.rb`. Three lines:
  `find_by`, a bare `return unless`, and the delegation.
- **Job-level error logging**: `app/jobs/export_organization_candidates_to_csv_job.rb` lines 22 to 25. A
  method-level `rescue StandardError => e` at the end of `perform` writing `Rails.logger.error e`, an `ap`
  label naming the failure, and `ap e`. `app/jobs/discord/notify_trial_converted_to_paid_job.rb` has the same
  rescue placement but writes two `Rails.logger.error` lines and no `ap`, so it is not the model for the
  rescue block.
- **A delayed enqueue**: `app/models/job.rb` line 707, `app/services/submit_resume_to_textract.rb` line 27 and
  `lib/active_storage_svg_sanitizer/svg_sanitizer.rb` line 19. All three write the duration inline at the call
  site. `app/jobs/export_job_resumes_to_zip_job.rb` line 26 is the only `set(wait: …)` in the codebase that
  reads a constant, and it is a job re-enqueuing itself — a different thing, and not the model here.
- **Configuration constants**: `config/initializers/01_variables.rb`. The two `GA4_` constants are the form
  the credential constants take — an `ENV['STAGING_…']` read with a
  `Rails.application.credentials.dig(Rails.configuration.x.RailsCredentialsEnv, :google, …)` fallback. The
  `GOOGLE_INTERNAL_SHEETS_CLIENT_ID` / `GOOGLE_INTERNAL_SHEETS_CLIENT_SECRET` /
  `GOOGLE_INTERNAL_SHEETS_REFRESH_TOKEN` trio in the same block is the model for the OAuth credential trio's
  naming and for its `:google` credentials namespace only; its environment variable names carry no `STAGING_`
  prefix and are not copied.
- **The dispatch shape inside the callback**: `app/models/subscription_event.rb`, where
  `Discord::NotifyFreeTrialStartedJob.perform_later` and `Discord::NotifyTrialConvertedToPaidJob.perform_later`
  already sit inside their `when` branches. New enqueues sit beside them; no external call is ever made
  inline from the callback.
- **The owner-then-organization identifier preference**: `SubscriptionEvent#attribution_value`, already
  public and already used by `posthog_properties` for all thirteen attribution columns. It takes two
  arguments — the owner's value and the organization's value, both already read from their records by the
  caller — and returns the first of the two that is present. It is never passed a column name, a `User` or an
  `Organization`, so each job reads both columns itself and passes the pair: `SendGoogleAdsConversionJob`
  passes the user's `google_click_id` alongside the subscription event's organization's `google_click_id`,
  and `SendAdrollConversionJob` passes the owner's and the organization's `adroll_click_id`, then the owner's
  and the organization's `adroll_first_party_cookie`.
