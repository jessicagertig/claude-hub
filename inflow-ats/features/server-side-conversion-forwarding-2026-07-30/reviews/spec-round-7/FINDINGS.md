# Spec review round 7 — findings

25 findings across five angles: deferred work and spec form; payload completeness; conventions compliance;
no-abstraction and analog structural matching; money, failure and absence behavior. Several were reported two
or three times by different angles and are consolidated below.

Both abstraction hunts came back clean: no base class, mixin, registry, adapter, shared payload builder or
common interface appears anywhere in the spec, and the five camelCase names are written out independently in
each client.

---

## Applied

### A1 (HIGH) — Configuration handed the implementer a lookup into an encrypted file

SPEC §Configuration told the implementer to open `config/credentials.yml.enc` with `rails credentials:edit`,
"verify both keys under the existing `google` namespace, and add them if absent." The "if absent" branch is
unresolvable — SPEC §GA4 states the Measurement Protocol API secret has not been created, so there is no value
to add — and the spec never said what is written into the thirteen keys whose credentials are still pending.

Applied: the paragraph now states what the file holds and that every key whose credential has not been issued
is written with an empty value, which reads back as nil. Reasoning in RATIONALE under "Modified files — why a
pending credential is written into `config/credentials.yml.enc` with an empty value".

### A2 (HIGH) — `ingest_events` and `send_event` parameters described rather than named

Two of `GoogleDataManagerApi::Client#ingest_events`'s five public parameters existed only as prose ("a
transaction id … and an amount in cents …"), leaving the implementer to invent the keyword names on both sides
of the job/client boundary. `Ga4MeasurementProtocol::Client#send_event` listed its four without colons while
SPEC §New files mandates keyword arguments, and `SendGa4EventJob` was the only one of the three jobs whose
argument form was unstated.

Applied: `ingest_events` takes `event_name:`, `gclid:`, `event_timestamp:`, `transaction_id: nil` and
`amount_cents: nil`; `send_event` takes `client_id:`, `ga_session_id:`, `user_id:` and `event_name:`;
`SendGa4EventJob` takes the keyword arguments `user_id:` and `event_name:`, with the reason under "New files —
why `SendGa4EventJob` takes keyword arguments" in RATIONALE.

### A3 (HIGH) — `SendGoogleAdsConversionJob` call-site count stated as six, enumerated as seven

SPEC §Google Ads "Enqueue delay" enumerates 2 registrations + 1 omniauth + 1 organizations + 3
`SubscriptionEvent` branches = seven, then said "each of the six call sites reads
`SendGoogleAdsConversionJob::ENQUEUE_DELAY`". §New files repeated "six call sites". §Modified files
independently produces seven. An implementer counting to six ships one undelayed upload, rejected as
`TOO_RECENT_CLICK`.

Applied: both occurrences say seven. RATIONALE's two "six call sites" mentions corrected in the same pass.

### A4 (HIGH) — the by-hand Value setting named neither value

"**Use different values for each conversion**, with the default value and default currency the interface
requires" — every other by-hand setting in the same paragraph carries an exact value (90 days, Count **One**).

Applied: a default value of `0` and a default currency of `USD`, with the reasoning under "Google Ads — the
Value setting's default value and default currency" in RATIONALE.

### A5 (HIGH) — the `require 'oj'` analog citation did not resolve

SPEC cited `app/services/engagement_report/google_sheets_sender.rb` and `app/models/job.rb` for both requires.
Neither requires `oj`; `app/models/job.rb` opens with `require 'csv'` and `require 'money'` and its
`require 'googleauth'` sits at line 1420 inside a method. RATIONALE already named the correct `oj` analogs.

Applied: `require 'oj'` cites `app/services/webflow_api.rb` and `app/services/what_jobs_api.rb`;
`require 'googleauth'` cites `google_sheets_sender.rb`.

### A6 (HIGH) — the two `ApiError` classes had no constructor and no message

`ApiError` was specified only as "subclasses `Faraday::ClientError` and is raised on a non-2xx response".
`Faraday::Error#initialize(exc, response = nil)` accepts a bare `raise ApiError`, so a 400 — the path with no
retry, no `Rails.logger.warn` and no client-side error line — would log the class name alone and lose the
destination's rejection reason.

Applied: both rows specify `initialize(message, response)` calling `super(message || 'Internal error.',
response)` as `WebflowApi::ApiError` does, raised as `ApiError.new(response.body, response)`. Both service
spec bullets assert the message and the response reader.

### A7 (HIGH) — the Data Manager API does return 429

SPEC said "`WebflowApi::Client` is not the model — its retry covers one status, 429, which none of these three
destinations returns." DATA-MANAGER-API.md documents `RESOURCE_EXHAUSTED` / HTTP 429 on `IngestionService` at
300 requests/minute per Cloud project. A 429 under the old rule raised `ApiError` on the first attempt and
dropped the conversion permanently.

Applied: the retryable set is "429 or 500 to 599"; the exhaustion paragraph says "a run that ended on a 429 or
a 5xx"; the retry test requires a 429 on every attempt to issue exactly three posts; the `WebflowApi::Client`
sentence gives the real reason it is not the model (its counter and backoff live in instance variables set in
`initialize`, and none of these clients takes constructor arguments). RATIONALE's matching "none of the three
destinations here rate-limits a conversion upload" claim corrected.

### A8 (HIGH) — the AdRoll positive examples were unpassable as specified

`current_sign_in_ip` is not one of the thirteen attribution columns, `create_credit_test_user` never writes
it, the column has no default and Devise trackable writes it only on a real sign-in. `SendAdrollConversionJob`
returns when the owner has no `current_sign_in_ip`, so every positive example required of
`spec/jobs/send_adroll_conversion_job_spec.rb` could not pass while the negative one passed trivially.

Applied: the record-setup paragraph writes `current_sign_in_ip` on the owner in every example expecting an
AdRoll send, with the reason in RATIONALE.

### A9 (HIGH) — the money rule was unfalsifiable in both service specs

"The event name and not the amount's nil-ness is what decides" whether the value keys are assembled. Neither
service spec's required assertions could fail under an `amount.nil?` implementation: the Google Ads
secondary-event example named no event and no amount, and the AdRoll `trialStarted` example named no amount.

Applied: both are now a `trialStarted` call carrying an `amount_cents` of 4999 — the only input at either
destination that tells the two implementations apart. Reasoning under "Test requirements — why the
secondary-event money examples carry an `amount_cents` of 4999".

### A10 (MED) — `RECOGNIZED_EVENT_NAMES` was described but never named

Applied at both mentions (§Google Ads and §Failure behavior).

### A11 (MED) — `Rails.logger.error` was said to fire on all three clients' exhaustion, and GA4 writes none

SPEC §Failure behavior said all three follow `WhatJobsApi::Client#create_listing` including "the same distinct
`Rails.logger.error` on final failure", then twenty-seven lines later said GA4 "writes no exhaustion line".
Resolved toward the existing decision: the sentence exempts GA4 by name. The alternative resolution — having
GA4 write the line on the transport path — is Q7 in REVIEW-FINDINGS.md.

### A12 (MED) — AdRoll credential constants described, not named

"Three constants: the server access token, the advertisable EID and the pixel EID", 110 lines from the names,
while the parallel Google Ads payload cell names its constant inline.

Applied: the Credentials line and the `advertisable_eid` / `pixel_eid` payload source cells name
`Variables::ADROLL_S2S_API_KEY`, `Variables::ADROLL_ADVERTISABLE_EID` and `Variables::ADROLL_PIXEL_EID`.

### A13 (MED) — `accountId` and `productDestinationId` stated no JSON type

Both are JSON strings in the Data Manager schema, and both Notes cells read as number-suggesting ("Digits
only", "The bare numeric ID") against a spec rule that every assembled value is a JSON-native scalar converted
inside the client. Applied: both cells state the JSON string type and that neither is converted to an Integer.

### A14 (MED) — the Response handling error-writer list was wrong in both directions

It listed the non-2xx `ApiError` as an error-level writer (raising writes no line) and omitted the
unrecognized-event-name line. Applied: the three paths are named, and raising `ApiError` is stated to write
nothing of its own.

### A15 (MED) — the AdRoll `conversion_value` assertion contradicted itself

"an `amount` of nil and an `amount` of 0 each send `"0.00"`, in every case as `"conversion_value":"49.99"`".
Applied: the quoted-string form is given per value.

### A16 (MED) — five passages of justification prose in SPEC.md

Each already had its own RATIONALE heading, so the reasoning was stated twice and the spec argued for its
instructions: the GA4 debug endpoint and what a 2xx proves; the `TOO_RECENT_CLICK` / `TOO_RECENT_EVENT`
derivation of the seven-hour delay; the `WhatJobsApi` over `WebflowApi` argument; the faraday 0.17.5 class
hierarchy; and why GA4 raises nothing. Applied: each cut to the instruction, with the reasoning moved to or
already present under its RATIONALE heading.

### A17 (HIGH) — the `dry_run` paragraph

"AdRoll documents an optional `dry_run=true` query parameter that validates and logs a payload without
affecting audiences or attribution. It is not part of the shipped code path." Applied: "`dry_run` is not
sent.", with the two sentences moved to RATIONALE under "AdRoll — why `dry_run` is not sent".

---

## Rejected

Two, in REJECTED.md with the refuting evidence.

## Escalated

One, as Q7 in REVIEW-FINDINGS.md.
