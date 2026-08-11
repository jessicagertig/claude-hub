# Rationale — server-side conversion forwarding

Justification, argument and background removed from `SPEC.md`. Nothing here is an instruction. Each heading
names the `SPEC.md` section the passage came from and the exact item — field, constant, method or decision —
it explains. Passages are verbatim.

## Summary

### Summary — nothing new is measured

Nothing new is measured. The events already fire, the attribution identifiers are already captured at landing
time and already stored on `users` and `organizations`, and the monetary amount is already stored on
`subscription_events`. This is transport work: read what is stored, shape it into each destination's payload,
and post it from a background job.

### Summary — why the sends exist at all

The purpose is credit for delayed conversions. A person clicks a Google ad, signs up the same day, starts a
trial, and pays fourteen to thirty days later. The browser is long gone by the time the money moves, so the
only way the ad platform learns that the click converted is a server-to-server send keyed on the click
identifier captured at landing.

### Summary — why the three destinations share no base class, adapter, registry or payload builder

> The three payload shapes have nothing in common beyond the records they read from, and a shared abstraction
> would be invented ahead of any evidence of what the shapes have in common.

## Stack scope

### Stack scope — why no new frontend capture is needed

> Every identifier these payloads need is already captured browser-side by `adPlatformIdentifiers` in
> `app/javascript/shared/lib/utils.js` and already submitted to the server at signup.

### Stack scope — why `sign_up_params` is unchanged

> …which is where `Api::V1::RegistrationsController#create` already reads it at line 11 and where the permit
> list has never carried it.

### Stack scope — why no Pundit policy changes

> The only authorized action touched is `Api::V1::OrganizationsController#create`, whose
> `authorize @organization` call at line 46 and whose `OrganizationPolicy#create?` are both untouched; the
> three Devise actions authorize nothing today and continue to authorize nothing.

## Events and destinations

### Events and destinations — why the destination-facing names are camelCase

> …written in camelCase so that Polymer's events are distinguishable at a glance from Google's own snake_case
> event names.

### Trigger sites — why the magic-link dispatch is gated on `params[:invite_token]`

> The existing PostHog call there is unconditional, but the path is reached by invited teammates as well as by
> owners: `AuthForm` sends `inviteToken` to `/magic_login`, and for a brand-new invited user this path creates
> the record and falls through to line 216 without accepting the invite, which the invites controller does
> later.

### Trigger sites — why the Google SSO dispatch carries no gate

> `GoogleSSOButton` renders hidden inputs for the tracking parameters and none for `invite_token`, and
> `google_oauth2` reads only `session[:oauth_tracking]` and `request.env['omniauth.params']`, so the invite is
> not visible at this site — while the button itself is rendered unconditionally inside `AuthForm`, which is
> the form on the invite-accept page, so an invited teammate who clicks Continue with Google reaches this
> branch and does produce an `ownerSignedUp` conversion. The existing `TrackNewSsoOwnerSignupJob` PostHog
> dispatch already behaves the same way.

### Trigger sites — why the SSO dispatch is in the controller and not in `TrackNewSsoOwnerSignupJob`

> The SSO dispatch goes in the controller rather than inside `TrackNewSsoOwnerSignupJob` because that job's
> guard clause `return unless POSTHOG_CLIENT` sits above every one of its `capture` calls.

### Trigger sites — why `ownerCreatedOrganization` is a new dispatch site

> This is the one genuinely new dispatch site: organization creation is currently reported only from the
> browser. The thirteen attribution identifiers are copied from `current_user` onto the organization at lines
> 32 to 44, before the save, so both records hold the same values by the time the dispatch runs; copying
> preserves absence, and the job guards decide whether a send happens.

### Trigger sites — why `ownerCreatedOrganization` is bound to the controller action and not to `Organization#complete_setup_workers`

> …because that callback fires for every organization row — the boards scraper, the admin organizations
> controller and the two unregistered-job controllers all create organizations that no owner signed up for.

### Trigger sites — why nothing is enqueued beside `PosthogTrackJob.perform_later`

> The `PosthogTrackJob.perform_later` call is in no `when` branch: it is the trailing line after the `case`,
> reached by every event type that does not fall to the bare `return`, and no new enqueue is placed beside it.

### Trigger sites — why a branch written against `converted_to_paid` or `trial_converted_to_paid` would fail silently

> The `else` branch of that `case` is a bare `return`, so a branch written against a wrong enum key executes
> never and reports nothing.

## GA4 Measurement Protocol

### GA4 — why the two paid conversions are not sent

> They reach Google through the Data Manager API instead, posted straight to a Google Ads conversion action.
> Sending them to GA4 as well would buy no Google Ads credit that path does not already deliver, and a GA4 key
> event imported into Google Ads alongside the same Data Manager conversion would count that conversion twice.
> The Data Manager API's own 72-hour recency rule applies to Google Analytics destinations only and not to
> Google Ads.

### GA4 — what a 2xx from the Measurement Protocol proves

> …so the HTTP status is not a validation signal and nothing about a 2xx proves the event landed.

The endpoint answers 2xx for any request it receives, including one whose payload is malformed or whose
credentials are wrong. The parallel debug endpoint `https://www.google-analytics.com/debug/mp/collect` returns
`validationMessages` and is the only way to see payload errors, which makes it a manual verification tool: a
production send that routed through it would validate the payload and deliver nothing.

### GA4 — `client_id`

> Required, and load-bearing — this is the documented key by which Google joins a Measurement Protocol event
> to the earlier online interactions recorded for the same client instance.

### GA4 — `user_id`

> Stable across devices. Improves user-scoped joining; carries no attribution by itself.

### GA4 — `events[0].name`

> Both are legal GA4 event names: 40 characters or fewer, alphanumeric only, starting with a letter. Neither
> is a reserved name.

### GA4 — `events[0].params.session_id`

> Google documents this parameter as binding the event to a specific session's geographic and device
> information; what it does for traffic-source and campaign attribution is documented nowhere. Without it
> these events report `(not set) / (not set)`, and sending `session_id` with a valid value is Google's
> documented fix for exactly that symptom.

### GA4 — `events[0].params.engagement_time_msec`

> `events[].params` is optional and this parameter carries no Required marking. Google's guidance is that
> `session_id` and this parameter together are what keep session and engagement metrics accurate in reports;
> what omitting this one alone costs is not documented. `100` is the value Google's own samples use…

### GA4 — why a `session_id` from another property is not used

> …a session identifier belonging to any other property is meaningless to this one, so when no entry carries
> that name the parameter is omitted.

### GA4 — where the 24-hour bound on `session_id` comes from

> Google's own bound on the parameter is to send `session_id` within 24 hours of the start of the session.

### GA4 — why no `session_id` is ever substituted or synthesized

> …a `session_id` GA4 does not recognize opens a new, sourceless session in the property, which is worse than
> sending none.

### GA4 — why `timestamp_micros` is omitted

> Both are enqueued in the same request as the action they report, with no scheduled delay, and no retry path
> exists that could defer a send into a later hour — a failed send is logged and dropped rather than
> re-attempted. Ingestion time is therefore the event time to within seconds, and supplying the field would
> only expose an already-correct timestamp to the 72-hour backdating rule and to the server clock.

### GA4 — why `consent` is omitted

> …no column, no setting and no stored decision holds a value for `ad_user_data` or `ad_personalization`, and
> the only `consent` anywhere in the application is the job-board candidate's data-deletion checkbox, which is
> a different subject entirely. Omitting the object is also the correct choice and not merely the available
> one — when the field is absent Google applies the consent settings already recorded for the same `client_id`
> from that client's browser-side interactions, and any hardcoded `GRANTED` or `DENIED` would overwrite that
> real state with an assertion this application is in no position to make.

### GA4 — why neither `GA4_MEASUREMENT_ID` nor `GA4_API_SECRET` can be validated at runtime

> Neither value can be validated by any HTTP response — a single wrong character produces a clean 2xx and the
> event silently never lands.

### GA4 — why the by-hand key-event marking matters

> …the source and medium of a non-key event are `(not set)` whatever the payload carries, so without the
> marking the `session_id` extracted above buys nothing.

## Google Ads Data Manager API

### Google Ads — why the click-through conversion window is 90 days and is set before the clicks it counts

> …a trial that converts on day thirty falls outside 30 days, and a window change applies only to conversions
> recorded after it is made, so it is set before the clicks it is meant to count.

### Google Ads — why the two secondary conversion actions must record no value

> …so any default configured on them would be booked as revenue on every signup and every organization
> creation.

### Google Ads — why the conversion action ID constants are read at call time and never captured in a class-level constant

> …a frozen hash constant would fix the mapping at class load rather than reading each `Variables::` constant
> at call time, so no later change to a constant would reach it.

### Google Ads — why no developer token and no `login-customer-id` header are sent

> …the Data Manager API has no such concepts, and account relationships live in the JSON body instead.
> Google's own instruction not to set request headers on an ingestion request names those Google Ads
> account-selection headers, whose function moved into `Destination`; it does not reach `Authorization` or
> `x-goog-user-project`, both of which appear in Google's quickstart request for this endpoint.

### Google Ads — why `Google::Auth::UserRefreshCredentials` and not a service account

> The application has two server-side Google integrations and they authenticate differently:
> `EngagementReport::GoogleSheetsSender#build_authorization` uses `Google::Auth::UserRefreshCredentials`, and
> `Job#ping_google_index` uses `Google::Auth::ServiceAccountCredentials.make_creds` with a JSON key. The Data
> Manager path follows the user-credential one.

### Google Ads — why `access_token` returns the credentials object's reader and not the object or the token hash

> That method returns the credentials object, which is what the Sheets client library consumes; the REST path
> needs a string. […] Neither the credentials object nor the token hash `fetch_access_token!` returns is
> usable as the header value.

### Google Ads — why plain REST over Faraday and not a Google client library

> Every current release of both official Data Manager gem families requires Ruby 3.2 or newer; this
> application is Ruby 3.1.6. `googleauth` 1.8.1 is already in the bundle and is all the REST path needs.

### Google Ads — `destinations[0].operatingAccount.accountId`

> The Google Ads interface displays the customer ID hyphenated, so […] a value entered in either form is sent
> correctly.

### Google Ads — why `accountId` and `productDestinationId` are JSON strings

Both are shown quoted in the Data Manager request-body schema and are typed as strings by the API. Both hold
nothing but digits, and both are read out of a UI field into a `Variables::` constant that holds a String, so
the only way either becomes a JSON number is a deliberate `to_i` in the client. A JSON number in either field
is rejected outright and every conversion upload fails.

### Google Ads — the Value setting's default value and default currency

The interface requires both to be entered when **Use different values for each conversion** is selected, and
the Data Manager documentation stops at "supply a default value and default currency as the fallback" without
naming either. The default is reachable only by an upload that omits `conversionValue`, which the paid
conversion action never receives — every send to it carries a value, zero included. `0` and `USD` therefore
record that a reached default would be a defect rather than a number to be read as revenue, and `USD` matches
the `currency` every upload carries.

### Google Ads — `events[0].eventTimestamp`

> …`User#organization`, which returns `current_organization_user&.organization` and reflects whichever
> organization the user is switched into at the moment the delayed job runs.

### Google Ads — `events[0].conversionValue` when `amount` is nil

The conversion action's Value setting is **Use different values for each conversion**, which requires a
default value and a default currency to be entered in the interface. That default applies to any upload that
omits `conversionValue` — so an omitted key does not report nothing, it reports the default, and revenue the
application never charged lands in Google Ads reporting attributed to a real click. Sending `0.0` reports the
truth: a paid conversion whose recorded amount is unknown.

The presence guard is kept even though `nil.to_i / 100.0` already yields `0.0`, so that the zero is written
where a reader can see it rather than arriving as a side effect of `nil.to_i`. The rest of the form is what
`SubscriptionEvent#posthog_properties` already uses at `app/models/subscription_event.rb` line 104 —
`amount.present? ? amount.to_i / 100.0 : nil` — with `nil` replaced by `0.0`.

> Integer division truncates silently: `4999 / 100` is `49`, discarding 99 cents, and prorated
> `subscription_update` invoices routinely produce non-round cents. […] `BigDecimal` is not used, because
> `::JSON.dump` never calls `as_json` and the JSON gem serializes a `BigDecimal` through `to_s`, sending the
> value as the quoted string `"0.4999e2"`.

### Google Ads — `events[0].currency`

`currency` is sent on every paid conversion because `conversionValue` is now sent on every paid conversion,
and Google Ads rejects a value with no currency on an account whose conversion action declares one.

> `subscription_events` has no currency column, and no application code sets a currency on a plan
> subscription — the plan checkout session at `app/controllers/api/v1/billing_controller.rb` line 108 sets no
> currency key and inherits it from the Stripe price. Every currency literal in the application is `usd`, so
> the application charges in one currency and `USD` is a fixed statement about the account rather than a
> substitute for a stored value.

### Google Ads — `events[0].transactionId`

> Stable across job retries, unique per conversion, and therefore the correct deduplication key.

### Google Ads — why `loginAccount` and the request-level `encoding` are omitted

> `loginAccount` […] defaults to `operatingAccount`, which is correct for direct account access. The
> request-level `encoding` field is omitted because it declares the encoding of hashed user identifiers and no
> hashed identifier is sent.

### Google Ads — why `ownerSignedUp` and `ownerCreatedOrganization` read the gclid from the user with no organization fallback

> `Api::V1::OrganizationsController#create` copies `google_click_id` from `current_user` onto the organization
> at line 43, before the save, so at dispatch time a newly created organization can hold no value the user
> does not already hold. […] the two non-subscription events have no owner-versus-organization decision to
> make.

### Google Ads — why the enqueue delay is seven hours

> Google rejects an upload whose click is less than six hours old with `TOO_RECENT_CLICK`, and `ownerSignedUp`
> and `ownerCreatedOrganization` routinely occur minutes after the click that produced them.

`TOO_RECENT_CLICK` is the Data Manager API's name for the rejection; its Google Ads sibling `TOO_RECENT_EVENT`
is the one that states the six-hour figure. The delay is applied to all four events rather than only to the
two that need it, including the two whose conversions are already days old, because a per-event exemption
would put a second duration and a second environment check at the call sites.

### Google Ads — why the enqueue delay is two minutes in development

Seven hours makes the Google Ads path unobservable in development: the enqueue is verifiable but the send is
not, within any session. Two minutes is short enough to watch a send land and long enough that the job is
still exercised as a delayed one. `Rails.env.development?` is the house switch for exactly this — the same
ternary appears at `app/controllers/auth/invites_controller.rb` line 11 (`2.minutes.ago` against
`1.day.ago`) and at `app/models/organization_data_export.rb` line 37 (`10.minutes` against `7.days`).

### Google Ads — why a 200 from `events:ingest` is only a receipt

> Record validation happens asynchronously, and the API uses a fast-fail model in which one bad record fails
> the whole request.

## AdRoll server-to-server

### AdRoll — where the `Content-Type` comes from

> The content type is not stated anywhere in AdRoll's documentation and is the obvious inference from the JSON
> body.

### AdRoll — the body is a one-element array

AdRoll's documentation conflicts with itself on the body shape. The "Request Body" section of
`https://apidocs.nextroll.com/server-to-server-api/reference.html` and the "Event format" section of
`https://apidocs.nextroll.com/server-to-server-api/events.html` both show a top-level JSON array, `[{ … }]`,
introduced by "A single request can send more than one event". All thirteen per-event examples show a bare
object, and AdRoll's own linked example client at `github.com/AdRoll/server-to-server` posts a bare object.

The array wins: it is what both canonical schema blocks show, and it is the only shape that supports the
multi-event capability the same sentence documents. A server that accepts the array must accept a one-element
array; a server that accepts only the bare object could not honour its own multi-event sentence.

### AdRoll — `advertisable_eid`

> The same value appears twice per request under two spellings.

### AdRoll — `event_name`

AdRoll accepts a closed enumeration of thirteen event names and no custom values: `pageView`, `homeView`,
`productSearch`, `addToCart`, `purchase`, `highValuePage`, `gatedContent`, `demoRequest`, `signupPlan`,
`signupTrial`, `contactSales`, `liveChat` and `formFill`.

> Both paid conversions arrive under the same AdRoll event name and are not distinguishable from each other on
> AdRoll's side.

`AdrollS2sApi::Client` writes the literal `purchase` itself rather than taking an event name from
`SendAdrollConversionJob`, for the same reason the Google Ads conversion action mapping lives in
`GoogleDataManagerApi::Client`: the destination's own vocabulary is the destination client's business, and a
job that never holds a destination event name cannot send one this spec did not name.

### AdRoll — `conversion_value`, its unit and its JSON type

`conversion_value` is documented twice: under the page-wide "Optional Fields" heading, and again under the
`purchase` event's own "Optional attributes". It is the only monetary field AdRoll documents for any event.

The unit is major currency units, not cents. AdRoll's canonical example is `"conversion_value": "113.56"`, a
figure that reads as dollars and cents and cannot be a cent count. `subscription_events.amount` is an integer
of cents, so it is divided by 100. The Google Ads unit was not assumed to carry over and was checked
independently.

The JSON type is a quoted string, not a bare number. AdRoll's canonical example quotes it, and across all
thirteen per-event examples every price-shaped field is a quoted string while `quantity` is a bare number —
so the quoting is a type decision in the schema, not an inconsistency in one example. The `Float` produced by
the division is rendered with `format` and the `%.2f` directive, which gives the two-decimal form every AdRoll
example shows and renders a whole-dollar or zero amount as `"0.00"` rather than as Ruby's `"0.0"`.

### AdRoll — `currency`

Documented as "The currency of the conversion_value (e.g., USD). Supports three-letter ISO 4217 currency
codes." `USD` for the same reason Google Ads' `currency` is `USD`: the application charges in one currency and
`subscription_events` has no currency column.

### AdRoll — why `conversion_value` sends zero for a nil `amount`

The same reasoning as Google Ads' `conversionValue`, and the two destinations are kept identical deliberately
so that a paid conversion cannot be reported as one figure at one destination and another figure at the other.
An omitted key is not a neutral act at either destination.

### AdRoll — `page_location`

> A Stripe webhook has no page; this is the page in the application where a plan purchase is completed.

### AdRoll — `ip` and its nullability

> …an explicit conversion because `::JSON.dump` never calls `as_json`, and the JSON gem's fallback for an
> `IPAddr` is `to_s`, which yields the same address string; the conversion states the intent rather than
> correcting a defect. This is the owner's most recent sign-in address, which is not necessarily the address
> they held when they clicked the ad.

`users.current_sign_in_ip` is nullable and is populated by Devise's `:trackable` module (`app/models/user.rb`
lines 24 to 25) on sign-in, so the nulls are users who have never signed in. Measured in the development
database: 2 of 118 users and 1 of 135 organization owners. AdRoll requires the field, so an absent value has
to skip the send; the skip is a bare guard-clause return in `SendAdrollConversionJob`, with no log line,
matching the identifier guard beside it and `PosthogTrackJob`'s own bare `return unless`.

### AdRoll — why `dry_run` is not sent

AdRoll documents an optional `dry_run=true` query parameter that validates and logs a payload without
affecting audiences or attribution. It is the documented way to probe the endpoint by hand, and a shipped code
path carrying it would validate every conversion and record none of them.

### AdRoll — why the two EID constants are constants at all

> Only the token is secret. Both EIDs are public identifiers that already appear in the AdRoll pixel snippet
> in the public page source of every page carrying the pixel; they follow the same constant form as the token
> purely for consistency.

## New files

### New files — why the `session_id` extraction lives on `Ga4MeasurementProtocol::Client`

> …which is where the extraction belongs: it needs `Variables::GA4_MEASUREMENT_ID` to pick the entry for this
> property, and that constant is already read here.

### New files — why `Ga4MeasurementProtocol::Client` has no typed error classes

> …the endpoint returns 2xx regardless of payload validity, so a non-2xx is a transport failure, not raised.

### New files — why the GA4 failure line is written in `send_event` rather than in `request`

> …unlike the Google Ads client, whose `requestId` and `fieldWarnings` come out of the response body —
> because the event name and the user id are `send_event` arguments, and widening `request` to carry them
> would take it off the `(http_method:, endpoint:, params:)` shape of `WebflowApi::Client` and
> `WhatJobsApi::Client`.

### New files — why `Ga4MeasurementProtocol::Client#send_event` returns the HTTP status and `SendGa4EventJob` adds no log line

> `SendGa4EventJob` […] adds no log line of its own — the client already writes the only failure record. The
> status is returned so that a `rails runner` verification can tell a delivered send from a failed one, which
> no HTTP response body from this endpoint reveals.

### New files — why `google_data_manager_api.rb` requires `oj` and `googleauth` explicitly

> `require 'oj'` because the JSON request middleware encodes the request only, so the response body arrives as
> a String and `requestId` and `fieldWarnings` are read out of it with `Oj.load`, exactly as
> `WebflowApi::Client` and `WhatJobsApi::Client` do. `require 'googleauth'` matching
> `app/services/engagement_report/google_sheets_sender.rb` and `app/models/job.rb` — the only two places in
> the application that reference `Google::Auth`, both of which require the gem explicitly because
> `googleauth` arrives as a transitive dependency and is not required by `Bundler.require`.

### New files — why each `ApiError` is constructed with the response body and the response

A 4xx is not retried, writes no `Rails.logger.warn` and writes no client-side error line, so the raised
exception is the only carrier of the destination's rejection reason into the job's `Rails.logger.error e` and
`ap e`. `Faraday::Error#initialize(exc, response = nil)` accepts a bare `raise ApiError`, which would produce
a log line reading only the class name and lose the reason — and a 400 is the expected rollout failure for a
wrong conversion action ID, a wrong customer ID or a bad advertisable EID. `WebflowApi::ApiError` and
`WhatJobsApi::ApiError` both take `(message, response)` and are both raised with the response body as the
message; the `super(message || 'Internal error.', response)` body is `WebflowApi::ApiError`'s exactly, without
`WhatJobsApi::ApiError`'s `"Upstream API failure: "` prefix.

### New files — why `SendGa4EventJob` takes keyword arguments

`SendGa4EventJob` has no positional ambiguity of its own — one record id and one event name — but it is
enqueued on the four controller lines directly beside a `SendGoogleAdsConversionJob` enqueue carrying the same
two values by keyword. Matching shapes makes a transposed argument at those sites visible, which is the same
reason `SendAdrollConversionJob` carries them.

### New files — why `SendGoogleAdsConversionJob` takes keyword arguments

> Keyword arguments are load-bearing here rather than stylistic: the two `SubscriptionEvent` enqueues supply
> a subscription event id and no organization id, and with a positional list that id would land in the
> organization slot, load an unrelated `Organization` — both tables carry low sequential ids — pass the guard,
> and upload a conversion stamped with that organization's `created_at`.

### New files — why `SendAdrollConversionJob` takes keyword arguments

`SendAdrollConversionJob` takes its one argument by keyword so that its enqueue reads the same way as the
`SendGoogleAdsConversionJob` enqueue on the adjacent line in each of the two `when` branches.

### New files — why no Active Record object crosses the client boundary

> That boundary is a deliberate deviation from the two analytics services these jobs otherwise follow —
> `Posthog::Track#initialize` takes `user:` and `EngagementReport::ReportGenerator#initialize` takes
> `organization:`, both model instances, and `cursor_rules/backend/architecture.md` rule 2's own diagram reads
> `Service (if needed, passed model instance)` — because each of these three clients needs a fixed handful of
> column values, and a client that never holds a record cannot read a column this spec did not name.

### New files — why each job constructs its client directly rather than routing through a model instance method

> `cursor_rules/backend/architecture.md` rule 2 routes a model callback through a model instance method before
> the service and names one exception, PostHog. The codebase does both. Job-board and search-index dispatch
> takes rule 2's route: `SyncWhatJobsListingJob` calls `BoardWhatJobsListing#sync_with_what_jobs`, which calls
> `WhatJobsListing` — a service whose own header comment records that it is only called from
> `BoardWhatJobsListing` instance methods, and which is handed the model instance — and `JobPingGoogleIndexJob`
> calls `Job#ping_google_index`, which builds and sends the Google Indexing request from the model.
> Notification and analytics dispatch does not: `PosthogTrackJob` constructs `Posthog::Track`,
> `Discord::NotifyTrialConvertedToPaidJob` and the other `Discord::` notification jobs construct
> `DiscordNotifierBot`, `EngagementReport::GeneratorJob` constructs `EngagementReport::ReportGenerator`, and
> `RegisteredWebhooks::NewJobApplicationJob` calls `Faraday.post` inline.
> `Discord::NotifyTrialConvertedToPaidJob` reads a single model, `Organization`, and is enqueued from the same
> `when` branch these new enqueues join, so single-model ownership is not what decides the shape. The three
> new jobs follow that precedent.

### New files — why the rescue block writes the exception object to both writers

> …so the backtrace survives.

## Modified files

### Modified files — why no interactor extraction

> The four controller actions touched here — `Api::V1::OrganizationsController#create`,
> `Api::V1::RegistrationsController#create`, `Api::V1::RegistrationsController#magic_create` and
> `Api::V1::Users::OmniauthCallbacksController#google_oauth2` — each already carry well over fifteen lines of
> business logic.

## Failure behavior

### Failure behavior — why the fixed payload literals are not fallbacks

> Several payload values are fixed literals that no column feeds — GA4's `engagement_time_msec`, AdRoll's
> `page_location` and `event_name`, and Google Ads' `eventSource`, `validateOnly` and `currency`. None of them
> is a fallback for absent data and none is removed.

`engagement_time_msec` carries the one qualification stated in the section that owns it: it is not required by
the Measurement Protocol and is sent as a fixed constant rather than as a measurement. Google Ads' `currency`
and AdRoll's `currency` are sent on every paid conversion, and Google Ads' is absent from both
secondary-conversion requests, which is a statement about which events are monetary, not about which values
are known.

### Failure behavior — why a nil `amount` sends zero rather than omitting the key

The rule against fabricating values covers identifiers, where a substitute changes who the conversion is
attributed to. A monetary value is not an identifier, and at both destinations an omitted value key is not
neutral: Google Ads applies the conversion action's configured default value, and AdRoll's own reporting has
no documented behaviour for a `purchase` with no value. Zero reports that the amount is unknown; omission
reports whatever the destination was configured to invent.

### Failure behavior — why `SendGa4EventJob` guards on `ga_client_id`

> GA4 requires `client_id`, and a synthesized one would create a brand-new user in the property with no click
> history — the opposite of the purpose.

### Failure behavior — why `SendGoogleAdsConversionJob` guards on the gclid

> With no gclid and no user data there is no identifier to attribute against and the request would be invalid.

### Failure behavior — why the retry lives in the client's `request` and not in a job `retry_on`

> Both house API clients retry inside their own `request` — `WebflowApi::Client` for a 429 and
> `WhatJobsApi::Client` for transient failures — and a retry there costs one connection, keeps the assembled
> body and the resolved bearer token in hand, and leaves no trace outside the log. A job-level `retry_on`
> would re-run the whole job: the record lookups, the guard clauses, the credential checks and, for Google
> Ads, a fresh OAuth token exchange, all to repeat a request that failed on the wire. It would also compound
> onto the enqueue delay every Google Ads send already carries. The four AI jobs that do declare `retry_on`
> — `GenerateAiJobApplicationSummaryJob`, `ExtractJobCriteriaJob`, `BulkGenerateAiSummariesJob` and
> `GetResumeTextFromTextractJob` — are a dependent pipeline whose downstream steps wait on the result; nothing
> waits on an advertising conversion.

### Failure behavior — why `WhatJobsApi::Client` and not `WebflowApi::Client` is the retry model

> `WebflowApi::Client` retries exactly one status, 429, through a dedicated `RateLimitError`, with its counter
> and backoff held in instance variables set in `initialize` and a sleep that grows by five seconds an
> attempt. None of the three clients here holds that state in an instance variable — each initializer sets
> only credential and base-URL readers — and a dedicated
> error class per retryable status is a second error class per client this does not need — the one destination
> that documents a 429, the Data Manager API (`RESOURCE_EXHAUSTED`, at 300 requests/minute per Cloud project on
> `IngestionService`), is covered by the same status test that covers a 5xx. `WhatJobsApi::Client#create_listing`
> is the one that already
> separates retryable from non-retryable failures, backs off exponentially and logs the attempt count, which
> is the whole of what this needs.

### Failure behavior — why a 5xx is decided on the response status rather than by rescuing `ApiError`

> Deciding on the status keeps one error class per client and one retry rule across all three, including GA4,
> which raises no error class at all. Deciding by error class would need a second class per client to separate
> a 5xx from a 4xx, since `Faraday::TimeoutError`, `Faraday::ConnectionFailed` and each `ApiError` are all
> `Faraday::ClientError` subclasses in faraday 0.17.5 and cannot be told apart by a rescue clause. Reading the
> status back off a rescued `ApiError` is not a way around that: `Faraday::Error#exc_msg_and_response` keeps
> the second constructor argument as `response` only when the message is a String, and replaces it with the
> message itself when the message is a Hash — the form `WebflowApi::Client` uses.

### Failure behavior — what a dropped send costs, and why no enqueue is wrapped in a rescue

> A dropped advertising conversion is a reporting loss, not a data loss — the `SubscriptionEvent` row and the
> PostHog event are unaffected. A destination's HTTP failure happens inside the job and can never reach the
> request or the callback that enqueued it. The enqueue itself is a different matter: under the Sidekiq
> adapter `perform_later` is a synchronous Redis write, for the delayed Google Ads sends exactly as for the
> immediate GA4 ones, so a Redis outage raises out of `perform_later` into the caller. […] matching the
> `PosthogTrackJob` and `Organization#complete_setup_workers` enqueues that already sit at these sites and
> already carry that same exposure.

### Failure behavior — why `Ga4MeasurementProtocol::Client` raises nothing

> …because the Measurement Protocol answers 2xx for every request it receives. […] That log line is the only
> trace a GA4 failure ever leaves, which is why it carries the same identifying fields the other two
> destinations' job-level rescues write.

A response outside 200 to 299 from that endpoint is therefore a transport-level failure rather than a payload
rejection, which is why a 5xx there is retried on the same rule as the other two and why every other non-2xx
is logged and returned rather than raised. No exhaustion line is written in `request`: on a status the failure
line `send_event` writes already carries that response's status and body, and on a transport failure surviving
all three attempts the exception propagates to `SendGa4EventJob`'s method-level rescue, whose `ap` label names
the destination and the user id.

### Failure behavior — why no record-level error reason ever reaches the Google Ads log

> No record-level error reason ever reaches that log: the synchronous response carries only `requestId` and
> `fieldWarnings`, and reasons such as `EVENT_TOO_OLD`, `CLICK_NOT_FOUND`, `INVALID_GCLID`, `DUPLICATE_GCLID`,
> `CONVERSION_PRECEDES_CLICK` and `TOO_RECENT_CLICK` are returned only by `requestStatus:retrieve`, polled by
> hand against the logged `requestId`.

## Existing patterns to follow

### Existing patterns — why `client.request :json` and `client.adapter Faraday.default_adapter` are both required

> Both lines are load-bearing rather than decorative. Faraday 0.17.5 installs no middleware and no adapter
> when a connection is built with a configuration block — `Faraday::Connection#initialize` hands `RackBuilder`
> an empty block precisely so it does not assume the default stack — so a block omitting the adapter produces
> a connection that issues no HTTP request at all and returns a response whose `status` is nil, in every
> environment and without an error.

`FaradayMiddleware::EncodeJson` encodes any body that does not respond to `to_str`, so AdRoll's one-element
Array is serialized by the same middleware as the two Hash bodies and needs no hand-encoding of its own.

### Existing patterns — why every value in an assembled body must already be a JSON-native scalar

> Because `::JSON.dump` bypasses ActiveSupport's encoder entirely, `as_json` is never called on anything in
> that hash and the JSON gem falls back to `to_s` for every value it does not natively encode. […] no
> attribute object is left for the middleware to serialize, and a `TimeWithZone` left in the hash would go out
> as `2026-07-30 14:22:01 UTC` rather than as RFC 3339.

### Existing patterns — why `WhatJobsApi::Client` is not the model for the encoding

> …it registers no request middleware, hand-encodes with `Oj.dump` and posts a URL-encoded `data=` field,
> which would send `conversionValue` as characters in a form field rather than as a JSON number.

## Google Ads Data Manager API — the six-hour figure and its two error names

### The six-hour figure — why the threshold is carried over from a different API

> Two separate enums in two separate APIs describe the same condition. The Google Ads API's
> `ConversionUploadError` carries `TOO_RECENT_EVENT`, whose own description states the number verbatim: "The
> click associated with the given identifier or iOS URL parameter occurred less than 6 hours ago. Retry after
> 6 hours have passed." In v6 and v8 that same enum slot was named `TOO_RECENT_GCLID`, worded "try uploading
> again after 6 hours have passed since the click occurred", and was renamed when gbraid, wbraid and the iOS
> URL parameters were added.
>
> The Data Manager API — the one this work targets — carries `PROCESSING_ERROR_REASON_TOO_RECENT_CLICK`, whose
> complete description is "The click occurred too recently." No hour count appears anywhere on that reference
> page. No enum named `TOO_RECENT_CLICK` exists in the Google Ads API at any version from v6 through v25.
>
> So the error name in the spec is the one this API will actually return, and the six-hour figure is inferred
> from its Google Ads sibling.

### The six-hour figure — why it is not the conversion-action cool-down

> `TOO_RECENT_CONVERSION_ACTION` is a sibling value in the same Google Ads enum list — "Can't import events to
> a conversion action that was just created. Try importing again in 6 hours", historically worded "4-6 hours"
> to match support/answer/7012522. Two documented errors, listed side by side. The per-click minimum is not a
> misreading of the setup cool-down.

### The six-hour figure — why Google enforces it at all

> Never stated on any page reached. The wording carries the shape of the reason: every one of these errors says
> retry after N hours rather than describing a prohibition, and `TOO_RECENT_CALL` was 12 hours in v6 through
> v10 and is 6 hours now. A threshold that halves over time reads as click data propagating into the
> conversion-matching index, not as policy. That reading is inference, not documentation.
