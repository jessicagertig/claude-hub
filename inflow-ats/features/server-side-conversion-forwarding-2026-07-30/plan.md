# Implementation plan — server-side conversion forwarding

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## How to use this plan

`SPEC.md` in this directory is binding in its entirety — every section, not only "Don't fuck with this".
Read it in full before writing a line. This plan does not restate the spec's payload field tables, its
failure-behaviour rules or its rationale; it names, for each task, the analog file to copy from, the deltas
from that analog, and the `SPEC.md` section that governs the fields. Where this plan and `SPEC.md` appear to
differ, `SPEC.md` wins.

`RATIONALE.md` holds the reasoning behind each closed decision. Read it before proposing any change to the
spec — every "wouldn't it be better if" has already been answered there.

**There is no test section.** Repo rule 0a (`/Users/jessica/wrk/wrk-corp/inflow-ats/.claude/CLAUDE.md` line 29)
forbids writing RSpec specs. Do not write one, do not add examples to an existing one, do not add a Cypress
test. If you believe something needs coverage, put it in the final report.

**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`, branch `server-side-conversion-events` (already checked
out, created off `develop` at `04a5c2d57`).

**Git:** do not create branches, do not push, do not commit. Leave every change unstaged in the working tree
when you finish. `config/initializers/01_variables.rb` and `config/credentials.yml.enc` already carry
uncommitted changes from Jessica — do not stage, revert, stash or reformat them.

**Branch-conflict check (run at plan time, 2026-07-31):** `gh pr list --state open` returns 17 open PRs, the
most recently updated on 2026-06-05 — none inside the three-week window and none touching
`app/services/`, `app/jobs/`, `app/models/subscription_event.rb`, the three controllers or the two `.tsx`
files this work modifies. No coordination needed.

---

## Summary

Four milestones the application already records — two signup/setup events and two paid-conversion events — are
forwarded from Rails to three advertising destinations: the GA4 Measurement Protocol, the Google Ads Data
Manager API, and the AdRoll server-to-server events API. Every value sent already exists in a column; nothing
new is measured and no schema changes. The work is six new files (three API client services and three
background jobs, sharing nothing), `perform_later` lines added at six existing dispatch sites in four backend
files, and the removal of the two browser-side `hirePlanPurchase` dataLayer pushes that the server-side paid
conversion replaces.

---

## Pattern precedents

Every precedent below was read in full during planning. Line numbers are as of `04a5c2d57` plus the
uncommitted `01_variables.rb` change.

### API client services — module + `Client` class in one file

| File | Traits shared with what this work builds |
|---|---|
| `app/services/webflow_api.rb` | `# frozen_string_literal: true`, `require 'oj'`, `module` + `class Client`, `API_ENDPOINT` constant on `Client` (line 6), `attr_reader` for base URL + credential (line 8), `initialize(access_token: nil, api_base_url: API_ENDPOINT)` raising `'Must Set access_token' if access_token.nil?` (lines 12-13), memoized private `client` building the Faraday connection with `client.request :json` then `client.adapter Faraday.default_adapter` then header assignments (lines 179-187), private `request` inspecting `response.status.between?(200, 299)` (lines 189-193), error classes subclassing `Faraday::ClientError` with `initialize(message, response)` and `super(message \|\| 'Internal error.', response)` (lines 232-236). **This is the named analog for all three new services.** |
| `app/services/what_jobs_api.rb` | Same module+`Client` shape; `API_ENDPOINT` (line 9); keyword-argument `initialize` defaulting to a `Variables::` constant and to `API_ENDPOINT` (line 14) — **the constructor-default form for all three new services**; and `create_listing`'s retry (lines 35-64): `max_retries = 3` and `retry_count = 0` in locals, a `begin` wrapping the `request` call, `sleep_duration = 2**retry_count`, one `Rails.logger.warn` per attempt carrying `#{retry_count}/#{max_retries}`, one `Rails.logger.error` naming the attempt count on final failure, then `raise`. **This is the named retry analog for all three new services.** |
| `app/services/wwr_api.rb` | Third instance of the same module+`Client`+`API_ENDPOINT`+memoized-`client`+private-`request`+`error_class` shape (lines 4-14, 95-125), confirming it as convention rather than one file's improvisation. |
| `app/services/cloudflare_client.rb` | Fourth instance of the Faraday block ordering — `client.request :json`, `client.adapter Faraday.default_adapter`, then headers (lines 15-21). |
| `app/services/engagement_report/google_sheets_sender.rb` | `require 'googleauth'` at the top (line 4), `SCOPES` frozen array (line 8), and `build_authorization` (lines 115-122) constructing `Google::Auth::UserRefreshCredentials.new(client_id:, client_secret:, refresh_token:, scope:)` and calling `fetch_access_token!` on it. **This is the named OAuth analog for `GoogleDataManagerApi::Client#access_token`.** |

### Jobs — find a record, guard, delegate

| File | Traits shared with what this work builds |
|---|---|
| `app/jobs/posthog_track_job.rb` | The whole file: `< ApplicationJob`, `queue_as :default`, `find_by(id:)`, a bare `return unless`, one delegation line (lines 3-12). **This is the named analog for all three new jobs.** |
| `app/jobs/export_organization_candidates_to_csv_job.rb` | Lines 22-25 — the method-level `rescue StandardError => e` at the end of `perform` writing `Rails.logger.error e`, then an `ap` label string naming the failure, then `ap e`. **This is the named rescue-block analog for all three new jobs.** |
| `app/jobs/engagement_report/generator_job.rb` | `perform(organization_id, trigger:, new_plan_lookup_key: nil)` — mixed required and optional keyword arguments on a job, enqueued through `perform_later` with keywords at `app/models/organization.rb` line 1057. **This is the named keyword-argument analog for `SendGoogleAdsConversionJob`.** |
| `app/jobs/discord/notify_trial_converted_to_paid_job.rb` | Same job skeleton, constructs its destination client (`DiscordNotifierBot`) directly rather than routing through a model instance method, and is enqueued from the same `when` branch the new enqueues join. Its rescue writes two `Rails.logger.error` lines and no `ap` — **it is NOT the rescue analog** (see `SPEC.md`, "Existing patterns to follow"). |
| `app/jobs/track_new_sso_owner_signup_job.rb` | Fifth job read; confirms `find_by` + bare `return unless` + method-level rescue. **Not modified by this work.** |

### Delayed enqueue — duration written inline at the call site

- `app/models/job.rb` line 707 — `ExtractJobCriteriaJob.set(wait: 30.seconds).perform_later(...)`
- `app/services/submit_resume_to_textract.rb` line 27 — `GetResumeTextFromTextractJob.set(wait: 2.minutes).perform_later(...)`
- `lib/active_storage_svg_sanitizer/svg_sanitizer.rb` line 19 — `SanitizeSvgJob.set(wait: 10.seconds).perform_later self`

All three write the duration inline. `app/jobs/export_job_resumes_to_zip_job.rb` line 26 is the only
`set(wait:)` reading a constant, and it is a job re-enqueuing itself — not the model here.

### Environment ternary

- `app/controllers/auth/invites_controller.rb` line 11 — `Rails.env.development? ? 2.minutes.ago : 1.day.ago`
- `app/models/organization_data_export.rb` line 37 — `Rails.env.development? ? 10.minutes : 7.days`

### Dispatch inside the `SubscriptionEvent` callback

`app/models/subscription_event.rb` lines 41-62 — `case event_type` with `Discord::NotifyFreeTrialStartedJob.perform_later` (line 43) and `Discord::NotifyTrialConvertedToPaidJob.perform_later` (line 46) already sitting inside their `when` branches, each branch ending with its `event_properties['$set']` assignment, and `PosthogTrackJob.perform_later` as the trailing line after the `case` (line 61).

### Owner-then-organization identifier preference

`app/models/subscription_event.rb` lines 126-134 — `attribution_value(owner_value, organization_value)`, public, already used by `posthog_properties` for all thirteen attribution columns (lines 110-122).

### Configuration constants

`config/initializers/01_variables.rb` lines 61-81 (uncommitted) — the `GA4_`, `ADROLL_`, `GOOGLE_DATA_MANAGER_` and `GOOGLE_ADS_` blocks, already written in the `ENV['STAGING_…'] || Rails.application.credentials.dig(...)` form the file's other credentials use.

### Verified library facts these tasks depend on

Checked against the installed gems during planning; do not re-derive.

- `faraday` **0.17.5** — `post(url = nil, body = nil, headers = nil)` (`connection.rb:172`). `build_exclusive_url` sets `url = nil if url.respond_to?(:empty?) and url.empty?` (`connection.rb`), so `client.post('', body)` against a connection built on the full endpoint URL posts to that URL — the form `WhatJobsApi::Client` already uses in production.
- `Faraday::Connection#params` is an `attr_reader` on a `Utils::ParamsHash` (`connection.rb:18`, `:70`), so `client.params['key'] = value` inside the memoized block puts the pair in every request's query string.
- `Faraday::TimeoutError` and `Faraday::ConnectionFailed` exist as top-level constants, both `< Faraday::ClientError` (`faraday/error.rb`).
- `Faraday::Error#exc_msg_and_response` keeps the second constructor argument as `response` when the first is a String. Pass the **raw** `response.body`, never `Oj.load(response.body)`.
- `faraday_middleware` **0.14.0** — `client.request :json` is `FaradayMiddleware::EncodeJson`; it sets `Content-Type: application/json` itself and encodes with `::JSON.dump` any body that does not respond to `to_str`, which includes AdRoll's one-element Array. Do not hand-encode and do not set `Content-Type` by hand.
- `googleauth` **1.8.1**, `oj` **3.10.6**, Ruby **3.1.6**.
- `users.current_sign_in_ip` is `t.inet` (nullable). `users` and `organizations` both carry `ga_client_id`, `ga_session_id`, `google_click_id`, `adroll_click_id`, `adroll_first_party_cookie`. `subscription_events` carries `amount` (nullable integer) and no currency column.
- `.rubocop.yml` disables `Style/FrozenStringLiteralComment`, `Layout/LineLength` and the `Metrics/*` cops. The pre-commit hook is `bash bin/run-cypress-precommit && lint-staged`; `lint-staged` runs `spec/requests/api_public/` specs only when files under `app/controllers/api_public`, `app/serializers/api_public`, `app/policies/api_public` or `spec/requests/api_public` change — none of which this work touches.

---

## Files to create or modify

### Create — six files, sharing nothing

| Path | What it holds |
|---|---|
| `app/services/ga4_measurement_protocol.rb` | `Ga4MeasurementProtocol::Client`. Public `send_event`; private `session_id_from_ga_session_id`, `client`, `request`. No error class. |
| `app/services/google_data_manager_api.rb` | `GoogleDataManagerApi::Client` and `GoogleDataManagerApi::ApiError`. Public `ingest_events`; `RECOGNIZED_EVENT_NAMES`; private `conversion_action_id`, `access_token`, `client`, `request`. |
| `app/services/adroll_s2s_api.rb` | `AdrollS2sApi::Client` and `AdrollS2sApi::ApiError`. Public `send_event`; private `client`, `request`. |
| `app/jobs/send_ga4_event_job.rb` | `SendGa4EventJob`, keyword arguments `user_id:` and `event_name:`. |
| `app/jobs/send_google_ads_conversion_job.rb` | `SendGoogleAdsConversionJob`, keyword arguments `user_id:`, `event_name:`, `organization_id: nil`, `subscription_event_id: nil`. |
| `app/jobs/send_adroll_conversion_job.rb` | `SendAdrollConversionJob`, keyword argument `subscription_event_id:`. |

### Modify — six files

| Path | Change |
|---|---|
| `app/models/subscription_event.rb` | Four `perform_later` lines inside two existing `when` branches of `handle_after_commit_on_create`. |
| `app/controllers/api/v1/registrations_controller.rb` | Two enqueues beside line 57 (email path, same `if @invite.nil?` gate); two enqueues beside line 216 (magic-link path, gated `if params[:invite_token].blank?`). |
| `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` | Two enqueues inside the `if user.new_user_created_via_google_sso` branch at line 45, beside `TrackNewSsoOwnerSignupJob.perform_later`. No gate. |
| `app/controllers/api/v1/organizations_controller.rb` | Two enqueues inside `create`'s `if @organization.save` branch, after `organization_user.org_owner!` (line 52) and before `render_one` (line 54). |
| `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBilling.tsx` | Remove the `hirePlanPurchase` dataLayer push (lines 81-88), its two comments (lines 79-80), and `currentUser` from the `useCurrentSession()` destructure (line 27). |
| `app/javascript/ats/src/views/jobApplications/JobStripeCheckoutRedirectHandler.tsx` | Remove the `hirePlanPurchase` push (lines 42-49), its two comments (lines 40-41), the whole `if` block it is the body of (lines 39-50), the `useCurrentSession` import (line 10) and its call (line 19). |

### Verify only — already done, do not rewrite

| Path | State |
|---|---|
| `config/initializers/01_variables.rb` | All thirteen constants already present and holding values, uncommitted in the working tree (lines 61-81). **Task B1 verifies; it does not create.** |
| `config/credentials.yml.enc` | Already modified with the secret values. Do not open, do not edit. |

### Explicitly not modified

`app/jobs/track_new_sso_owner_signup_job.rb`, `app/models/organization.rb`,
`app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx`, the `newOrganization` push in
`app/javascript/ats/src/views/sessions/NewOrganization.tsx`, the `ctaClick` push in
`app/javascript/ats/src/views/jobs/JobList.tsx`, `sign_up_params` in `Api::V1::RegistrationsController`,
any route, any serializer, any Pundit policy, any migration, `db/schema.rb`, and the GTM container.

---

## Backend changes

Read before starting any backend task: `cursor_rules/core_critical_rules.md`, `cursor_rules/backend/_base.md`,
`cursor_rules/backend/code_style_and_structure.md`. Per-task reads are tagged below.

Style rules that apply to every backend task and are the ones most often missed here: single-quoted string
literals unless interpolating (`backend/_base.md` §7); bare `return` in guard clauses, never `return false`
or `return nil` (`core_critical_rules.md` §8); `rescue StandardError => e`, never `=> error`
(`backend/_base.md` §5); no `begin` block except to wrap a specific subset of operations inside a method
(`backend/_base.md` §1 — the retry blocks in these three services are that exception, and are shaped like
`WhatJobsApi::Client#create_listing`); full model names for record variables — `subscription_event`, `user`,
`organization`, `owner` only for `organization.owner`, and the bare word `event` never used as a variable
name (`backend/_base.md` §9); no `reload` (`backend/_base.md` §8); `ap` never `pp`
(`core_critical_rules.md` §3); no bang methods (`core_critical_rules.md` §11); no fabricated fallback values
— no `|| 0`, no `|| ''` (`core_critical_rules.md` §10); fix lint only on lines you write
(`.claude/CLAUDE.md`, "Linter & Formatting Scope").

### B1. Verify configuration — do not create

Read: nothing.

- [ ] B1.1 Open `config/initializers/01_variables.rb` and confirm all thirteen constants exist and are non-nil at boot: `GA4_MEASUREMENT_ID`, `GA4_API_SECRET`, `ADROLL_S2S_API_KEY`, `ADROLL_ADVERTISABLE_EID`, `ADROLL_PIXEL_EID`, `GOOGLE_DATA_MANAGER_CLOUD_PROJECT_ID`, `GOOGLE_DATA_MANAGER_CLIENT_ID`, `GOOGLE_DATA_MANAGER_CLIENT_SECRET`, `GOOGLE_DATA_MANAGER_REFRESH_TOKEN`, `GOOGLE_ADS_CUSTOMER_ID`, `GOOGLE_ADS_CONVERSION_ACTION_OWNER_SIGNED_UP`, `GOOGLE_ADS_CONVERSION_ACTION_OWNER_CREATED_ORGANIZATION`, `GOOGLE_ADS_CONVERSION_ACTION_PAID_SUBSCRIPTION`.
- [ ] B1.2 Confirm the four `GOOGLE_ADS_` constants are literal single-quoted strings with no `ENV` read and no credentials lookup, and the other nine take `ENV['STAGING_…'] || Rails.application.credentials.dig(...)`.
- [ ] B1.3 Change nothing in this file. If a constant is missing or nil, stop and report it — do not add it, and never touch `.env`.

### B2. `app/services/ga4_measurement_protocol.rb`

Read: `cursor_rules/backend/services.md`. Governing spec sections: "GA4 Measurement Protocol", "New files",
"Failure behavior", "Existing patterns to follow".

Analog: `app/services/webflow_api.rb`. Deltas: no error class at all; `request` takes no `http_method:` or
`endpoint:` and does no `public_send` dispatch; `measurement_id` and `api_secret` are set as connection
query-string params rather than headers.

- [ ] B2.1 Open the file with `# frozen_string_literal: true`. No `require` line — this client parses no response body.
- [ ] B2.2 `module Ga4MeasurementProtocol` / `class Client`. `API_ENDPOINT = 'https://www.google-analytics.com/mp/collect'` on the `Client` class.
- [ ] B2.3 `initialize(measurement_id: Variables::GA4_MEASUREMENT_ID, api_secret: Variables::GA4_API_SECRET, api_base_url: API_ENDPOINT)`, one `raise` per credential in the `WebflowApi::Client#initialize` form (`raise 'Must Set measurement_id' if measurement_id.nil?`), then assign the three instance variables. `attr_reader :measurement_id, :api_secret, :api_base_url`.
- [ ] B2.4 Private memoized `client`: `Faraday.new(api_base_url) do |client| … end` with `client.request :json`, then `client.adapter Faraday.default_adapter`, then `client.params['measurement_id'] = measurement_id` and `client.params['api_secret'] = api_secret`. Assign no `Content-Type` header — the JSON middleware sets it.
- [ ] B2.5 Private `request(body)`: `client.post('', body)` and return the response. No status inspection, no parsing, no logging.
- [ ] B2.6 Private `session_id_from_ga_session_id(ga_session_id)` implementing the extraction rule in `SPEC.md` → "Extracting `session_id`" exactly: return early when the argument is blank; split the stored string on `'; '`; select the one entry whose name is `_ga_` followed by `Variables::GA4_MEASUREMENT_ID` with its leading `G-` removed; return early when no entry matches; take everything after the **first** `=` as the value; split that value on `.` and return early when it has fewer than three segments; take the third segment (index 2); return early unless it is a run of digits and nothing else; return early unless that instant, read as Unix seconds, is within 24 hours of `Time.current`. Return the digit **String** unchanged — do not call `to_i`, do not reformat, never synthesize or substitute a value.
- [ ] B2.7 Public `send_event(client_id:, ga_session_id:, user_id:, event_name:)`. Assemble the body per the `SPEC.md` → "GA4 Measurement Protocol" payload table: top-level `client_id` and `user_id` (the latter `user_id.to_s`), `events` as a one-element Array whose object carries `name` (the `event_name` argument) and `params` with `engagement_time_msec` set to the Integer `100`. Compute `session_id_from_ga_session_id(ga_session_id)` and add `session_id` to `events[0][:params]` only when it is present — when absent, the key is omitted from the hash entirely, never sent as null. Every value in the assembled body is a JSON-native scalar.
- [ ] B2.8 Inside `send_event`, wrap the `request` call in a retry block that uses the locals, backoff and logging of `WhatJobsApi::Client#create_listing` but a `loop do … end` for the repeat. **Ruby's `retry` is legal only inside a `rescue` clause, and a status test is not an exception**, so the analog's `begin`/`retry` shape cannot carry the status-driven half — written that way the file parses clean under `ruby -c` and raises `Invalid retry (SyntaxError)` on load. `max_retries = 3` and `retry_count = 0` in locals before the loop. Inside the loop, `response = request(body)` wrapped in a `begin` whose `rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e` — those two classes and nothing broader — increments `retry_count`, and while `retry_count < max_retries` writes one `Rails.logger.warn` carrying `#{retry_count}/#{max_retries}`, sets `sleep_duration = 2**retry_count`, sleeps it and `retry`s, and otherwise re-raises. After the request returns, `break` unless `response.status` is 429 or between 500 and 599; on a retryable status increment `retry_count`, `break` when `retry_count >= max_retries`, otherwise write the same `Rails.logger.warn`, `sleep(2**retry_count)` and let the loop repeat. Hold no retry state in an instance variable. On exhaustion of a status-driven run, fall through with the final response and write **no** exhaustion line; on exhaustion of a transport-failure run, the re-raised Faraday exception leaves the method.
- [ ] B2.9 After the retry block, when `response.status` is outside 200 to 299, write one failure line to both `ap` and `Rails.logger.error` carrying the destination `GA4`, the event name, the user id, the response status and the response body — build it once into a local double-quoted interpolated string and write that local to both. This line lives in `send_event`, never in `request`.
- [ ] B2.10 `send_event` returns `response.status` (the Integer).

### B3. `app/services/google_data_manager_api.rb`

Read: `cursor_rules/backend/services.md`. Governing spec sections: "Google Ads Data Manager API",
"New files", "Failure behavior", "Existing patterns to follow". Background: `DATA-MANAGER-API.md` §3 — do not
re-research the API.

Analog: `app/services/webflow_api.rb`, plus `EngagementReport::GoogleSheetsSender#build_authorization` for
the OAuth refresh. Deltas: one error class, so no `error_class` case statement; `request` takes no
`http_method:` or `endpoint:`; the bearer token is minted per call.

- [ ] B3.1 Open with `# frozen_string_literal: true`, then `require 'oj'` (the response body is parsed, as in `WebflowApi::Client`) and `require 'googleauth'` (matching `EngagementReport::GoogleSheetsSender` — `googleauth` arrives transitively and is not required by `Bundler.require`).
- [ ] B3.2 `module GoogleDataManagerApi` / `class Client`. `API_ENDPOINT = 'https://datamanager.googleapis.com/v1/events:ingest'`. `SCOPES = ['https://www.googleapis.com/auth/datamanager'].freeze` in the `GoogleSheetsSender` form.
- [ ] B3.3 `RECOGNIZED_EVENT_NAMES` — a frozen Array constant on the `Client` class holding the four verbatim camelCase single-quoted strings `'ownerSignedUp'`, `'ownerCreatedOrganization'`, `'convertedToPaidSubscription'`, `'trialConvertedToPaidSubscription'`.
- [ ] B3.4 `initialize(cloud_project_id: Variables::GOOGLE_DATA_MANAGER_CLOUD_PROJECT_ID, client_id: Variables::GOOGLE_DATA_MANAGER_CLIENT_ID, client_secret: Variables::GOOGLE_DATA_MANAGER_CLIENT_SECRET, refresh_token: Variables::GOOGLE_DATA_MANAGER_REFRESH_TOKEN, api_base_url: API_ENDPOINT)`, one `raise` per credential, `attr_reader` for all five. These four `GOOGLE_DATA_MANAGER_` constants are the client's credentials and no others — the customer ID and the three conversion action IDs are read inside the methods that send them, at call time, and are never captured in a class-level constant.
- [ ] B3.5 Private `access_token`: build `Google::Auth::UserRefreshCredentials.new(client_id:, client_secret:, refresh_token:, scope: SCOPES)` exactly as `build_authorization` does, call `fetch_access_token!` on it, and return the credentials object's own `access_token` reader — the String, not the object and not the token hash.
- [ ] B3.6 Private memoized `client`: `Faraday.new(api_base_url)` with `client.request :json`, `client.adapter Faraday.default_adapter`, then `client.headers['Authorization'] = "Bearer #{access_token}"` and `client.headers['x-goog-user-project'] = cloud_project_id`. No developer token, no `login-customer-id`, no hand-set `Content-Type`.
- [ ] B3.7 Private `conversion_action_id(event_name)`: an explicit `case event_name` whose four `when` clauses are the verbatim camelCase string literals, each returning its `Variables::GOOGLE_ADS_CONVERSION_ACTION_*` constant, with `convertedToPaidSubscription` and `trialConvertedToPaidSubscription` both returning `GOOGLE_ADS_CONVERSION_ACTION_PAID_SUBSCRIPTION`. Every constant is read inside the method. Never derive the mapping with `underscore`, `camelize`, `const_get` or any other string transformation, and build no hash.
- [ ] B3.8 Private `request(body)`: `response = client.post('', body)`; when `response.status` is between 200 and 299, parse the body with `Oj.load` and log there — write the `requestId` with `ap` and `Rails.logger.info`, and when `fieldWarnings` is present and non-empty write it with `ap` and `Rails.logger.error`. Return the response either way. Do not parse a non-2xx body.
- [ ] B3.9 Public `ingest_events(event_name:, gclid:, event_timestamp:, transaction_id: nil, amount_cents: nil)`. First statement: unless `RECOGNIZED_EVENT_NAMES` includes `event_name`, write the unrecognized-event-name line to both `ap` and `Rails.logger.error` naming the event name, and abandon the send with a bare `return`.
- [ ] B3.10 Assemble the body per the `SPEC.md` → "Google Ads Data Manager API" payload table. `destinations` is a one-element Array; `operatingAccount.accountType` is the literal `'GOOGLE_ADS'`; `operatingAccount.accountId` is `Variables::GOOGLE_ADS_CUSTOMER_ID` with hyphens removed and never converted to an Integer; `productDestinationId` is `conversion_action_id(event_name)`, a JSON String of bare digits, never the `customers/{id}/conversionActions/{id}` form and never an Integer; `validateOnly` is `false`; `loginAccount` and the request-level `encoding` are omitted; `userData` is not sent. `events` is a one-element Array carrying `adIdentifiers.gclid` (the `gclid` argument, raw, case preserved), `eventTimestamp` (format `event_timestamp` to an RFC 3339 String here in the client — `event_timestamp.utc.iso8601`, matching the `"2026-07-30T14:22:01Z"` form in `DATA-MANAGER-API.md` §3 — never leave the `ActiveSupport::TimeWithZone` in the hash), and `eventSource` as the literal `'WEB'`.
- [ ] B3.11 Add `conversionValue`, `currency` and `transactionId` only when `event_name` is `'convertedToPaidSubscription'` or `'trialConvertedToPaidSubscription'` — the event name decides this, never the amount's nil-ness. `conversionValue` is `amount_cents.present? ? amount_cents.to_i / 100.0 : 0.0` (presence guard first, float division second, a Ruby `Float`, never `BigDecimal`, never micros). `currency` is the literal `'USD'`. `transactionId` is `transaction_id.to_s`. For the two secondary events all three keys are absent from the hash entirely, never null.
- [ ] B3.12 Wrap the `request` call in the retry block of B2.8 — same `loop do`, same `max_retries`, same `2**retry_count` backoff, same `Rails.logger.warn` per attempt, same two rescued Faraday classes, retry state in locals only. After the loop, write one `Rails.logger.error` naming the destination and the number of attempts made, then raise: `ApiError.new(response.body, response)` for a run that ended on a 429 or a 5xx, or re-raise the Faraday exception for a run that ended on a transport failure.
- [ ] B3.13 For any response status outside 200 to 299 that is neither 429 nor 500-599, raise `ApiError.new(response.body, response)` immediately with no retry, no `Rails.logger.warn` and no error line of its own — the enclosing job's rescue is what records it. Pass the **raw** `response.body`, never `Oj.load(response.body)`.
- [ ] B3.14 `class ApiError < Faraday::ClientError` with `initialize(message, response)` and `super(message || 'Internal error.', response)` — `WebflowApi::ApiError`'s body exactly, without `WhatJobsApi::ApiError`'s `"Upstream API failure: "` prefix.
- [ ] B3.15 Confirm `Rails.logger.error` is written on exactly two paths in this file: the unrecognized-event-name line and the retry-exhaustion line — plus the `fieldWarnings` line, which is the response-handling record described in B3.8. Nothing else in the client writes at error level; the `requestStatus:retrieve` endpoint is not called from application code.

### B4. `app/services/adroll_s2s_api.rb`

Read: `cursor_rules/backend/services.md`. Governing spec sections: "AdRoll server-to-server", "New files",
"Failure behavior". Background: `ADROLL-S2S-CREDENTIALS.md` §2-§3 — do not re-research.

Analog: `app/services/webflow_api.rb`. Deltas: one error class; `request` takes no `http_method:` or
`endpoint:`; the request body is a one-element **Array** rather than a Hash; the `Authorization` scheme is
literally `Token`.

- [ ] B4.1 Open with `# frozen_string_literal: true`. No `require` line.
- [ ] B4.2 `module AdrollS2sApi` / `class Client`. `API_ENDPOINT = 'https://srv.adroll.com/api'`.
- [ ] B4.3 `initialize(api_key: Variables::ADROLL_S2S_API_KEY, advertisable_eid: Variables::ADROLL_ADVERTISABLE_EID, pixel_eid: Variables::ADROLL_PIXEL_EID, api_base_url: API_ENDPOINT)`, one `raise` per credential, `attr_reader` for all four.
- [ ] B4.4 Private memoized `client`: `Faraday.new(api_base_url)` with `client.request :json`, `client.adapter Faraday.default_adapter`, `client.headers['Authorization'] = "Token #{api_key}"` — the scheme is `Token`, not `Bearer` — and `client.params['advertisable'] = advertisable_eid`. No hand-set `Content-Type`.
- [ ] B4.5 Private `request(body)`: `client.post('', body)` and return the response. No parsing.
- [ ] B4.6 Public `send_event(ip:, amount_cents:, adroll_click_id: nil, adroll_first_party_cookie: nil)`. Assemble the event object per the `SPEC.md` → "AdRoll server-to-server" payload table: `advertisable_eid`, `pixel_eid`, `event_name` as the literal `'purchase'` written by this client and never taken from the job, `conversion_value` as `format('%.2f', amount_cents.present? ? amount_cents.to_i / 100.0 : 0.0)` — a JSON **String**, so `4999` sends `'49.99'` and both `0` and nil send `'0.00'` — `currency` as the literal `'USD'`, `page_location` as `"#{Variables::AtsRootUrl}/hire/settings/billing"` (a double-quoted interpolated string, the `app/mailers/stripe_subscription_mailer.rb` line 21 form without that line's `?utm_source=appEmail` suffix), and `ip` as `ip.to_s`.
- [ ] B4.7 Build `identifiers` with `adct` from `adroll_click_id` and `first_party_cookie` from `adroll_first_party_cookie`, omitting whichever argument is nil from the object rather than sending it as null. Do not send `dry_run`.
- [ ] B4.8 Wrap the assembled event object in a one-element Array and pass that Array to `request` as a Ruby object — the JSON middleware serializes it. Do not hand-encode.
- [ ] B4.9 Same retry block as B3.12, same exhaustion line, then `raise ApiError.new(response.body, response)` for a 429/5xx run or re-raise the Faraday exception for a transport-failure run. Same immediate raise as B3.13 for any other non-2xx.
- [ ] B4.10 `class ApiError < Faraday::ClientError` with the `WebflowApi::ApiError` body, exactly as B3.14.

### B5. `app/jobs/send_ga4_event_job.rb`

Read: `cursor_rules/backend/background_jobs.md`. Governing spec sections: "New files", "Failure behavior".

Analog: `app/jobs/posthog_track_job.rb`, with the rescue block of
`app/jobs/export_organization_candidates_to_csv_job.rb` lines 22-25.

- [ ] B5.1 `# frozen_string_literal: true`, `class SendGa4EventJob < ApplicationJob`, `queue_as :default`. No `retry_on`, no `discard_on` — the retry lives in the client.
- [ ] B5.2 `def perform(user_id:, event_name:)`.
- [ ] B5.3 `user = User.find_by(id: user_id)`; bare `return unless user`; bare `return unless user.ga_client_id.present?`. No log line on either guard.
- [ ] B5.4 Construct `Ga4MeasurementProtocol::Client.new` with no arguments and call `send_event(client_id: user.ga_client_id, ga_session_id: user.ga_session_id, user_id: user.id, event_name: event_name)`. Pass `ga_session_id` through exactly as the column holds it — parse nothing here. Do not read the return value and add no log line of the job's own.
- [ ] B5.5 Method-level `rescue StandardError => e` at the end of `perform`: `Rails.logger.error e`, then an `ap` label naming the destination `GA4`, the event name and the user id, then `ap e`. The exception object goes to both writers, not `e.message`.

### B6. `app/jobs/send_google_ads_conversion_job.rb`

Read: `cursor_rules/backend/background_jobs.md`. Governing spec sections: "New files", "Failure behavior",
"Google Ads Data Manager API".

Analogs: `app/jobs/posthog_track_job.rb` for the shape,
`app/jobs/engagement_report/generator_job.rb` for the mixed required/optional keyword arguments, and
`app/jobs/export_organization_candidates_to_csv_job.rb` lines 22-25 for the rescue.

- [ ] B6.1 `# frozen_string_literal: true`, `class SendGoogleAdsConversionJob < ApplicationJob`, `queue_as :default`. No `retry_on`, no `discard_on`.
- [ ] B6.2 `def perform(user_id:, event_name:, organization_id: nil, subscription_event_id: nil)`.
- [ ] B6.3 `user = User.find_by(id: user_id)`; bare `return unless user`.
- [ ] B6.4 When `organization_id` is present, `organization = Organization.find_by(id: organization_id)` and bare `return unless organization`. When `subscription_event_id` is present, `subscription_event = SubscriptionEvent.find_by(id: subscription_event_id)` and bare `return unless subscription_event`.
- [ ] B6.5 Resolve the gclid. When a subscription event id was given, call `subscription_event.attribution_value(user.google_click_id, subscription_event.organization.google_click_id)` — `attribution_value` stays exactly where it is, a public instance method on `SubscriptionEvent`; do not copy it, wrap it, move it into a concern or reimplement it. Otherwise read `user.google_click_id` directly with no organization fallback. Bare `return unless` the resolved gclid is present.
- [ ] B6.6 Resolve the `event_timestamp`: `subscription_event.created_at` when a subscription event id was given, `organization.created_at` when an organization id was given, otherwise `user.created_at`. Never derive an organization from `User#organization`.
- [ ] B6.7 Construct `GoogleDataManagerApi::Client.new` with no arguments and call `ingest_events`, passing `event_name:`, the resolved `gclid:`, the resolved `event_timestamp:`, and — only when a subscription event id was given — `transaction_id: subscription_event.id` and `amount_cents: subscription_event.amount`. Pass neither for `ownerSignedUp` or `ownerCreatedOrganization`. Perform no arithmetic on the amount here and never resolve or hold a conversion action ID.
- [ ] B6.8 Method-level `rescue StandardError => e`: `Rails.logger.error e`, then an `ap` label naming the destination `Google Ads`, the event name and the user id, then `ap e`.

### B7. `app/jobs/send_adroll_conversion_job.rb`

Read: `cursor_rules/backend/background_jobs.md`. Governing spec sections: "New files", "Failure behavior",
"AdRoll server-to-server".

- [ ] B7.1 `# frozen_string_literal: true`, `class SendAdrollConversionJob < ApplicationJob`, `queue_as :default`. No `retry_on`, no `discard_on`.
- [ ] B7.2 `def perform(subscription_event_id:)`. The job carries no event name — both events it is enqueued for send the same AdRoll event name, and the client writes it.
- [ ] B7.3 `subscription_event = SubscriptionEvent.find_by(id: subscription_event_id)`; bare `return unless subscription_event`. `owner = subscription_event.organization.owner`; bare `return unless owner`; bare `return unless owner.current_sign_in_ip.present?`. No log line on any guard.
- [ ] B7.4 Resolve both identifiers through `subscription_event.attribution_value(...)` — the owner's and the organization's `adroll_click_id`, then the owner's and the organization's `adroll_first_party_cookie`. Bare `return` when both resolve to absent.
- [ ] B7.5 Construct `AdrollS2sApi::Client.new` with no arguments and call `send_event(ip: owner.current_sign_in_ip, amount_cents: subscription_event.amount, adroll_click_id: <resolved>, adroll_first_party_cookie: <resolved>)`. Perform no arithmetic on the amount.
- [ ] B7.6 Method-level `rescue StandardError => e`: `Rails.logger.error e`, then an `ap` label naming the destination `AdRoll` and the subscription event id — no event name, since the job was enqueued with none — then `ap e`.

### B8. `app/models/subscription_event.rb`

Read: `cursor_rules/backend/background_jobs.md` §5, `cursor_rules/backend/architecture.md`. Governing spec
sections: "Trigger sites", "Modified files".

Add four `perform_later` lines inside two existing `when` branches of `handle_after_commit_on_create`. Add no
branch, reorder no branch, change no existing line. Do not touch the `trial_started` branch, and place nothing
beside the trailing `PosthogTrackJob.perform_later` on line 61.

- [ ] B8.1 In the `when 'trial_converted_to_paid_subscription'` branch (line 45), immediately after the existing `Discord::NotifyTrialConvertedToPaidJob.perform_later(organization_id)` and before the `event_properties['$set']` line, add:
  - [ ] B8.1.1 `SendGoogleAdsConversionJob.set(wait: Rails.env.development? ? 2.minutes : 7.hours).perform_later(user_id: organization.owner.id, event_name: 'trialConvertedToPaidSubscription', subscription_event_id: id)` — no `organization_id:`.
  - [ ] B8.1.2 `SendAdrollConversionJob.perform_later(subscription_event_id: id)` — no delay.
- [ ] B8.2 In the `when 'converted_to_paid_subscription'` branch (line 48), before the `event_properties['$set']` line, add the same two enqueues with `event_name: 'convertedToPaidSubscription'`.
- [ ] B8.3 Confirm the enum keys used in the `when` literals are unchanged and that no new code anywhere references `converted_to_paid` or `trial_converted_to_paid` — those two are retroactive-only, appear in no `when` branch, and a branch written on either would never execute while the `else` bare-returns silently.
- [ ] B8.4 Wrap no enqueue in a rescue, matching the `PosthogTrackJob` and `Discord::` enqueues already at this site.

### B9. `app/controllers/api/v1/registrations_controller.rb`

Read: `cursor_rules/backend/controllers/controller_patterns_and_crud.md`. Governing spec sections: "Trigger
sites", "Modified files". Add `perform_later` lines only — no interactor extraction, no restructuring of
either action, and no change to `sign_up_params`.

- [ ] B9.1 In `create`, immediately after the existing `organization_owner_signed_up` PostHog dispatch (line 57), add two lines each carrying the same `if @invite.nil?` gate as a trailing modifier:
  - [ ] B9.1.1 `SendGa4EventJob.perform_later(user_id: resource.id, event_name: 'ownerSignedUp') if @invite.nil?`
  - [ ] B9.1.2 `SendGoogleAdsConversionJob.set(wait: Rails.env.development? ? 2.minutes : 7.hours).perform_later(user_id: resource.id, event_name: 'ownerSignedUp') if @invite.nil?` — no `organization_id:`.
- [ ] B9.2 In `magic_create`, immediately after the existing `organization_owner_signed_up` PostHog dispatch (line 216), add the same two lines with `resource.id`, each gated by `if params[:invite_token].blank?`. Leave the existing PostHog call on line 216 exactly as it is — do not add a gate to it.

### B10. `app/controllers/api/v1/users/omniauth_callbacks_controller.rb`

Read: `cursor_rules/backend/controllers/controller_patterns_and_crud.md`. Governing spec sections: "Trigger
sites", "Modified files".

- [ ] B10.1 Inside the `if user.new_user_created_via_google_sso` branch (line 44), immediately after `TrackNewSsoOwnerSignupJob.perform_later(user.id, Time.current)` (line 45), add `SendGa4EventJob.perform_later(user_id: user.id, event_name: 'ownerSignedUp')` and `SendGoogleAdsConversionJob.set(wait: Rails.env.development? ? 2.minutes : 7.hours).perform_later(user_id: user.id, event_name: 'ownerSignedUp')`. No gate — no invite token reaches this site. No `organization_id:`.
- [ ] B10.2 Do not modify `app/jobs/track_new_sso_owner_signup_job.rb`.

### B11. `app/controllers/api/v1/organizations_controller.rb`

Read: `cursor_rules/backend/controllers/controller_patterns_and_crud.md`. Governing spec sections: "Trigger
sites", "Modified files".

- [ ] B11.1 Inside `create`'s `if @organization.save` branch, after `organization_user.org_owner!` (line 52) and before `render_one` (line 54), add `SendGa4EventJob.perform_later(user_id: current_user.id, event_name: 'ownerCreatedOrganization')`.
- [ ] B11.2 On the next line add `SendGoogleAdsConversionJob.set(wait: Rails.env.development? ? 2.minutes : 7.hours).perform_later(user_id: current_user.id, event_name: 'ownerCreatedOrganization', organization_id: @organization.id)`.
- [ ] B11.3 Change nothing else — the thirteen attribution copies at lines 32-44, `authorize @organization` at line 46, `OrganizationPolicy` and the `else` branch all stay as they are. Bind nothing to `Organization#complete_setup_workers`; `app/models/organization.rb` is not modified by this work.

---

## Frontend changes

Read before starting: `cursor_rules/frontend/core_critical_rules.md`, `cursor_rules/frontend/_base.md`,
`cursor_rules/frontend/react_hooks.md` (both edits are inside a `React.useEffect`).

Both tasks are pure deletions. Add nothing, reorder nothing, and do not touch the GTM container — removing the
`hirePlanPurchase` tag from `GTM-N6H844WJ` is Jessica's.

### F1. `app/javascript/ats/src/views/accountAdmin/accountBilling/AccountBilling.tsx`

- [ ] F1.1 Delete the two comments at lines 79-80 and the `window.dataLayer.push({ event: "hirePlanPurchase", … })` call at lines 81-88.
- [ ] F1.2 Keep the enclosing `if (checkout === "success" && session_id != undefined) {` block at line 78 — it still holds the two `queryClient.invalidateQueries` calls.
- [ ] F1.3 Change line 27 from `const { currentOrganization, currentUser } = useCurrentSession();` to `const { currentOrganization } = useCurrentSession();`. Keep the `useCurrentSession` import at line 18 — `currentOrganization` still uses it.
- [ ] F1.4 Confirm nothing else in the file changed, and that no reference to `currentUser` remains.

### F2. `app/javascript/ats/src/views/jobApplications/JobStripeCheckoutRedirectHandler.tsx`

- [ ] F2.1 Delete the whole `if (checkout === "success" && session_id != undefined) { … }` block at lines 39-50, including the two comments at lines 40-41 and the push at lines 42-49 — the push is the entire body of that block.
- [ ] F2.2 Delete the `useCurrentSession` import at line 10 and the `const { currentUser } = useCurrentSession();` call at line 19.
- [ ] F2.3 Keep the `session_id` entry in the `queryString.parse` destructure at line 28 and in the `window.logger` call at line 33, and keep `checkout`, still used at line 56. Keep the `syncWithStripe` call at lines 52-61 untouched.
- [ ] F2.4 Confirm nothing else in the file changed, and that no reference to `currentUser` or `useCurrentSession` remains.

---

## Validation and constraints

- **Credential presence — in each client's `initialize`.** Every credential keyword argument raises when nil, in the `WebflowApi::Client#initialize` form, one `raise` per credential. This is not handled anywhere else: the enclosing job's method-level rescue catches it. `GoogleDataManagerApi::Client` validates only the four `GOOGLE_DATA_MANAGER_` constants; the customer ID and the three conversion action IDs are read inside the methods that send them.
- **Unrecognized event name — in `GoogleDataManagerApi::Client#ingest_events`.** Tested against `RECOGNIZED_EVENT_NAMES` before anything else. It is a programming error: log to both `ap` and `Rails.logger.error`, abandon the send, raise nothing.
- **Absent identifiers — at the job guard clauses, before the client is constructed.** `SendGa4EventJob` on a missing user or a blank `ga_client_id`; `SendGoogleAdsConversionJob` on a missing user, a supplied-but-missing organization, a supplied-but-missing subscription event, or no available gclid; `SendAdrollConversionJob` on a missing subscription event, an ownerless organization, an owner with no `current_sign_in_ip`, or both AdRoll identifiers absent. Every one is a bare `return` with no log line, matching `PosthogTrackJob`'s own bare `return unless`. No identifier is ever fabricated, substituted, defaulted or synthesized — no `|| 0`, no `|| ''`, no `|| []`.
- **The monetary value goes the other way.** On a paid conversion an absent `amount` sends zero at both destinations that carry a value — `0.0` as a Google Ads JSON number, `'0.00'` as an AdRoll JSON string — rather than omitting the key, because an omitted key lets each destination's own configured default value stand in. The presence guard comes first and the float division second at both. These are the only zeros this work writes.
- **Conditional keys are omitted from the hash, never sent as null.** GA4's `session_id`; Google Ads' `conversionValue`, `currency` and `transactionId` on the two secondary events, plus `loginAccount`, `encoding` and `userData`; AdRoll's `identifiers.adct` and `identifiers.first_party_cookie`.
- **JSON types are load-bearing.** Google Ads `accountId` and `productDestinationId` are Strings of digits — a JSON number in either is rejected outright and every upload fails. Google Ads `conversionValue` is a `Float` in major currency units, never micros, never `BigDecimal`. AdRoll `conversion_value` is a `%.2f`-rendered String in major units. GA4 `user_id` is a String, `engagement_time_msec` the Integer `100`, `session_id` the extracted digit String. Every value in an assembled body is a JSON-native scalar converted inside the client — `::JSON.dump` never calls `as_json`, so a `TimeWithZone` left in a hash would go out as `2026-07-30 14:22:01 UTC` rather than as RFC 3339.
- **No Active Record object crosses the client boundary.** Each public client method takes keyword arguments carrying simple values only; each job constructs its client and calls its one public method. No `send_ga4_event`, `send_google_ads_conversion` or `send_adroll_conversion` method is added to `User`, `Organization` or `SubscriptionEvent`.
- **No new validation, no new column, no new enum value, no migration, no route, no serializer change, no Pundit policy change.**

---

## Documentation impact

None in the repo — no `docs/` page, no README and no `cursor_rules/` file describes any of the touched
subsystems. The by-hand console work these sends depend on is already written down and is Jessica's:

- GA4 — mark `ownerSignedUp` and `ownerCreatedOrganization` as key events at Admin → Data display → Events once the first event of each name has arrived (`SPEC.md` → "By-hand GA4 configuration"). Neither is set nor read by any code.
- Google Ads — the three `UPLOAD_CLICKS` conversion actions and their four by-hand settings: 90-day click-through window, Count = One, Value = "Use different values for each conversion" on the paid action only, and the 4-6 hour cool-down before a newly created action accepts uploads (`SPEC.md` → "Google Ads Data Manager API"; `DATA-MANAGER-API.md` §2c-§2f). Nothing in the code sets or reads the primary/secondary designation.

---

## Risks and open questions

1. **Where the status test lives, and therefore where `ApiError` is raised.** `SPEC.md` requires that the retry decision be made on the response status rather than by rescuing `ApiError` (`RATIONALE.md` → "why a 5xx is decided on the response status"), and that the retry wrap the `request` call inside the public method. Those two together mean `request` must return the response rather than raise, in all three clients, with the status branch and the raise living in the public method's retry block. B3.8's parse-and-log stays inside `GoogleDataManagerApi::Client#request` as the spec states. This plan directs that shape explicitly so no implementer re-derives it; it is the only arrangement that satisfies every sentence in "Failure behavior".
2. **`Oj.load` is gated on a 2xx.** `SPEC.md` → "Response handling" describes the parse and the `requestId`/`fieldWarnings` log entirely in terms of the 200 response, which is the only response that carries those fields. B3.8 therefore parses only inside the 2xx branch — a non-2xx body from a proxy or gateway is not JSON and would raise `Oj::ParseError` inside `request`. Flagged rather than assumed.
3. **The session-extraction reads `Variables::GA4_MEASUREMENT_ID` directly**, as `SPEC.md` → "Extracting `session_id`" words it, while the client also holds a `measurement_id` reader defaulting to the same constant. The two agree at every call site in this work, since every job constructs its client with no arguments. Named so a reviewer does not read it as a bug.
4. **First Google Ads sends can be rejected as `TOO_RECENT_CLICK` or by the conversion-action cool-down.** Google rejects an upload whose click is under six hours old, and a newly created conversion action needs four to six hours before it accepts uploads (`DATA-MANAGER-API.md` §2d step 21, §4). The seven-hour enqueue delay covers the first; the second is a setup-timing matter for the rollout, and the synchronous 200 will not reveal either — only `requestStatus:retrieve`, polled by hand against the logged `requestId`, will.
5. **The two-minute delay is `Rails.env.development?` only.** On staging and review apps every Google Ads send waits seven hours, so a staging verification cannot observe a send inside one session. That is the spec's decision; recorded here as its operational consequence.
6. **Coverage, per rule 0a.** Nothing in this work is covered by an automated test and none is written. The pieces whose failure modes are invisible without one, in the order they would bite: the `session_id` extraction (six distinct omit paths, all silent); the money conversions (a wrong unit or JSON type is accepted by both destinations and misreports revenue); and the `conversion_action_id` `case` (a typo in one camelCase literal sends a conversion to the wrong action, and Google answers 200 either way). Verification is the `rails runner` harness in `HANDOFF.md` §6 — swap the queue adapter to `:inline`, prepend an echo module on each client to read the outbound body while `super` keeps the real delivery, build the fixture with `from_plan` set to a marker string, and include a `trial_started` control event. `Ga4MeasurementProtocol::Client#send_event` returns the HTTP status for exactly this purpose, since no GA4 response body reveals a delivered send from a failed one.

---

## Estimated scope

| | Count |
|---|---|
| New files | 6 (3 services, 3 jobs) |
| Modified files | 6 (4 backend, 2 frontend) |
| Verified-only files | 1 (`config/initializers/01_variables.rb`, already complete) |
| New lines | ~420 (≈85 GA4 service, ≈130 Google Ads service, ≈105 AdRoll service, ≈25 + ≈45 + ≈30 jobs) |
| Modified backend lines | +12 added, 0 changed, 0 removed |
| Modified frontend lines | ~29 removed, 2 changed, 0 added |
| Migrations | 0 |
| Routes, serializers, policies | 0 |

---

## Finishing

- [ ] Z.1 Run `bundle exec rubocop` on the six new files and the four modified backend files, and fix violations **only on lines you wrote or modified** — do not auto-fix whole files and do not touch pre-existing violations.
- [ ] Z.2 Run Prettier on the two modified `.tsx` files under the repo's own config, same line scope.
- [ ] Z.3 Confirm `git status` shows exactly the six new files and the six modified files, plus the two pre-existing uncommitted config files you did not touch.
- [ ] Z.4 Leave everything unstaged. Do not `git add`, do not commit, do not push, do not stash.
