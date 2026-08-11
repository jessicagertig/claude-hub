# Spec review round 3 — findings

Seven findings. All seven verified against the live codebase and applied.

---

## F1 (MED) — House file skeleton stated for one of six new files; job superclass never stated

**Location:** SPEC.md "New files" table, `app/services/google_data_manager_api.rb` row; and the paragraph
beginning "Each job declares `queue_as :default`".

**Defect:** `# frozen_string_literal: true` was named only in the `google_data_manager_api.rb` row, where it
sat incidentally alongside that file's two `require` lines — the asymmetry read as "this file needs the magic
comment, the other five do not." The jobs' superclass was named nowhere: the only structural sentence about
the three jobs said they "declare `queue_as :default`," a bare `ActiveJob::Base` API that does not imply
`ApplicationJob`.

**Verification:**
- `app/jobs/application_job.rb:3` — `class ApplicationJob < ActiveJob::Base`.
- All 91 non-`ApplicationJob` job classes under `app/jobs/` (including the `Discord::`, `Notification::`,
  `Slack::` and `RegisteredWebhooks::` subdirectories) subclass `ApplicationJob`. Zero exceptions.
- 91 of 92 files under `app/jobs/` open with `# frozen_string_literal: true`; the one exception is
  `app/jobs/notification/daily_summary_job.rb`.
- 78 of 79 files under `app/services/` open with it; the one exception is
  `app/services/discord_notifier_bot.rb`.

**Applied:** struck the magic comment from the `google_data_manager_api.rb` row; added a sentence to the end
of the constructor-contract paragraph covering all six new files; changed the job paragraph to open "Each job
subclasses `ApplicationJob`, declares `queue_as :default` …".

**Deviation from the proposed fix:** the finding proposed the justification "as every file in `app/services/`
and `app/jobs/` already does." That is false by two files (see counts above), so SPEC.md instead reads "the
house form throughout `app/services/` and `app/jobs/`."

---

## F2 (HIGH) — False mechanism stated for the AdRoll `ip` conversion

**Location:** SPEC.md, AdRoll payload table, `ip` row.

**Defect:** the spec justified `current_sign_in_ip.to_s` with "passed through unconverted it serializes as an
object of instance variables rather than an address." It does not. The directive is correct; the stated
mechanism was false.

**Verification:**
- `faraday_middleware-0.14.0/lib/faraday_middleware/request/encode_json.rb` — `def encode(data); ::JSON.dump
  data; end`. That is the encoder SPEC.md mandates via `client.request :json`.
- `activesupport-6.1.7.7/lib/active_support/core_ext/object/json.rb:223-227` —
  `class IPAddr` / `def as_json(options = nil)` / `to_s`.
- The instance-variables serialization the spec described is what `Object#instance_values` returns, which is
  ActiveSupport's generic `Object#as_json`. `IPAddr` has an explicit override, so nothing on this path
  produces it.

**Applied:** the row now reads "an explicit conversion rather than a corrective one, since ActiveSupport
6.1.7.7 already defines `IPAddr#as_json` as `to_s`." The `.to_s` directive is unchanged.

---

## F3 (MED) — REVIEW-FINDINGS.md R10 contradicts SPEC.md on whether `session_id` is sent

**Location:** REVIEW-FINDINGS.md R10.

**Defect:** R10 stated "SPEC.md omits the field" about the GA4 `session_id` parameter and titled the stored
column "unusable." SPEC.md sends the parameter and specifies the full extraction rule that reduces the stored
cookie string to the numeric session identifier of the `_ga_FKDT1J0YB6` entry. Two live artifacts contradicted
each other on whether a payload field is sent at all.

**Verification:** SPEC.md GA4 payload table, `events[0].params.session_id` row, plus the "Extracting
`session_id`" paragraph immediately below it.

**Applied:** R10 retitled to "`ga_session_id` is a cookie string, not a GA4 `session_id`" and its body
rewritten to describe what SPEC.md actually does, keeping the warning against sending the column unreduced.
SPEC.md unchanged by this finding.

---

## F4 (MED) — Undocumented inference presented as fact in the `session_id` row

**Location:** SPEC.md, GA4 payload table, `events[0].params.session_id` row.

**Defect:** the row opened "Event-level, and what binds the event to the session that carries its source and
medium." The authoritative reference records the opposite.

**Verification:** GA4-MEASUREMENT-PROTOCOL-REFERENCE.md section 3.5 quotes Google's join statement, then
states: "That statement covers **geographic and device** information. No fetched page states what happens to
traffic-source or campaign attribution for an MP event, nor what happens when no prior interaction exists for
the `client_id`." The `(not set) / (not set)` fix in the same row is genuinely documented (reference line 362,
sourced to `support.google.com/analytics/answer/9900444`) and was kept.

**Applied:** the opening clause now names the documented scope (geographic and device) and states that
traffic-source and campaign behavior is documented nowhere. The rest of the cell is unchanged.

---

## F5 (HIGH) — Google Ads service spec's token-refresh stub collides with its transport stub

**Location:** SPEC.md Test requirements, `spec/services/google_data_manager_api_spec.rb` bullet, read against
the transport-stubbing paragraph above it.

**Defect:** the bullet directed asserting "the bearer `Authorization` header built from the stubbed token
refresh" without naming the seam the refresh is stubbed at, and the only stub the spec named collides with it.
A planning agent following the spec literally produces a spec file that cannot pass, or one that makes a live
OAuth call to Google.

**Verification:**
- `googleauth-1.8.1/lib/googleauth/user_refresh.rb:33` — `class UserRefreshCredentials < Signet::OAuth2::Client`.
- `googleauth-1.8.1/lib/googleauth/signet.rb:40-50` — `fetch_access_token!` sets `options[:connection]` only
  from `build_default_connection`, which returns `nil` unless `@connection_info` was configured. The
  `GoogleSheetsSender` constructor SPEC.md directs copying
  (`app/services/engagement_report/google_sheets_sender.rb:115-122`) configures no connection.
- `signet-0.19.0/lib/signet/oauth_2/client.rb:1027` — `client = options[:connection] ||=
  Faraday.default_connection`; lines 1039-1043 — `client.post …` then
  `content_type = response.headers["Content-type"]`. `Faraday.default_connection` is a `Faraday::Connection`,
  so the spec-mandated `allow_any_instance_of(Faraday::Connection).to receive(:post)` intercepts the token
  request, and the response double SPEC.md specifies carries only `status` and `body`.
- `signet-0.19.0/lib/signet/oauth_2/client.rb:715` (`def access_token`) and line 1075
  (`def fetch_access_token!`) — both real public methods, so both verify under `verify_partial_doubles`.

**Applied:** the bullet now specifies stubbing `fetch_access_token!` as a no-op and `access_token` as a fixed
string on `allow_any_instance_of(Google::Auth::UserRefreshCredentials)`, states why the Faraday stub cannot
carry it, and asserts the header against that fixed token.

---

## F6 (MED) — No GA4 service spec example for the failure path or the return contract

**Location:** SPEC.md Test requirements, `spec/services/ga4_measurement_protocol_spec.rb` bullet.

**Defect:** SPEC.md states that the non-2xx log line "is the only trace a GA4 failure ever leaves" and
enumerates the five fields it carries, and that `send_event` returns the integer HTTP status and returns
nothing on a credential skip so that manual verification can tell the three outcomes apart. The GA4 bullet
directed no example for either. The other two service specs each get an explicit failure example.

**Verification:** SPEC.md Failure behavior, `Ga4MeasurementProtocol::Client` paragraph; SPEC.md New files,
`app/services/ga4_measurement_protocol.rb` row; contrast the `ApiError` assertions in the Google Ads and
AdRoll spec bullets.

**Applied:** appended the failure-path and return-contract assertions to the GA4 bullet.

---

## F7 (MED) — Two facts restated near-verbatim in a section that does not own them

**Location:** SPEC.md Failure behavior duplicating Response handling (Google Ads response logging) and
duplicating New files (the job rescue shape).

**Defect:** against the spec-form rule that each fact is stated once in the section that owns it. The Google
Ads `requestId` / `fieldWarnings` logging and the `requestStatus:retrieve`-by-hand statement are fully
specified under Response handling and were restated under Failure behavior, whose only new content was the
error-reason list. The job rescue shape (`Rails.logger.error e`, the `ap` label, `ap e`, exception object not
`e.message`, no `retry_on`/`discard_on`) is fully specified under New files and was restated under Failure
behavior. Duplicated wording is what goes stale when one copy is amended.

**Applied:** Failure behavior now cross-references Response handling for the Google Ads logging and keeps only
the error-reason list, and cross-references New files for the rescue shape while keeping the "no retry and no
re-raise" statement that section needs.

---

## Rejected

None. All seven findings verified. The only deviation from a proposed fix is F1's justification wording,
recorded under F1 above.
