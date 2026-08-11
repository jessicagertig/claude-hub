# Spec review round 2 — findings and disposition

39 findings across 11 review angles. 33 applied, 6 not applied (see `REJECTED.md`). Every codebase claim was
re-verified against `/Users/jessica/wrk/wrk-corp/inflow-ats` on branch `server-side-conversion-events` before
any edit. Findings that named the same defect from different angles are collapsed into one row and applied once.

## BLOCKER

**B1 — Faraday adapter never registered.** SPEC.md never directed `client.adapter Faraday.default_adapter`
inside the memoized `client` block. Faraday 0.17.5 installs no middleware and no adapter when a connection is
built with a configuration block (`connection.rb:75-77` passes `RackBuilder` an empty block; `rack_builder.rb:52-61`
installs the default stack only when no block was given and `@handlers.empty?`). All three clients would have
issued no HTTP request and returned a response whose `status` is nil. *Applied* — new paragraph in the
"API client services" bullet.

**B2 — the service-spec stubbing mechanism erases what it then asserts.** Stubbing the private memoized
`client` with an `instance_double(Faraday::Connection)` removes every header and query parameter, since SPEC.md
puts all of them on the connection; roughly a third of the named assertions were unreachable. The spec also
never said what the stubbed `post` returns, so `response.status` would raise on nil. *Applied* — mechanism
replaced with `allow_any_instance_of(Faraday::Connection).to receive(:post)` and a block, whose first argument
is the receiving connection (`rspec-mocks` `yield_receiver_to_any_instance_implementation_blocks` defaults to
true), returning an `instance_double(Faraday::Response)` stubbed with `status` and `body`.

## HIGH

**H1 — "every existing Google integration in this codebase authenticates" this way** is false.
`Job#ping_google_index` uses `Google::Auth::ServiceAccountCredentials.make_creds` (`app/models/job.rb:1435`),
and SPEC.md itself cites that file. *Applied* — both integrations named.

**H2 — `SendGoogleAdsConversionJob` argument list unwritable.** Four positional parameters against three
enqueues described as passing a subscription event id "with no organization id"; the literal enqueue binds the
`SubscriptionEvent` id to `organization_id`. *Applied* — keyword arguments, following
`EngagementReport::GeneratorJob#perform`. All five enqueue descriptions updated.

**H3 — Devise controller specs directed to stub methods that do not exist.** `current_user` and
`set_sentry_context` live only on `Api::V1::BaseController`; both Devise controllers inherit
`DeviseController` → `ApplicationController`. With `verify_partial_doubles` true, every example in two of ten
spec files errors in setup. *Applied* — stub list scoped to the organizations controller spec.

**H4 — the Google SSO invite claim is inverted.** `GoogleSSOButton` is rendered unconditionally inside
`AuthForm` (`AuthForm.tsx:143`), which is the invite-accept form (`Auth.tsx:72`). Invited teammates can sign
up through it. *Applied* — claim rewritten; the suppression question recorded as REVIEW-FINDINGS Q5.

**H5 — GA4 credential state asserted four incompatible ways**, and the non-hedged version is false: both
constants are an uncommitted working-tree edit on a branch zero commits ahead of `develop`. *Applied* — stated
once, unconditionally, in Configuration.

**H6 — transaction id and amount threaded three incompatible ways**; under the job row as written
`transactionId` never appears in any payload. *Applied* — client row, job row and both test bullets now agree.

**H7 — "no snake_case spelling of these five names exists anywhere in the code"** is false and
self-contradicted; those are the live enum keys, `when` literals, PostHog event names and credentials keys.
*Applied* — replaced with the derivation prohibition plus an explicit statement that the snake_case forms stay.

**H8 — a frozen hash constant captures the ten pending nil values at class load**, so `stub_const` cannot
reach it and every Google Ads example hits the credential guard. *Applied* — private `conversion_action_id`
with an explicit `case` read at call time, plus a frozen array of recognized names.

**H9 — "none of these dispatches can fail the request or the callback"** is false; under the Sidekiq adapter
`perform_later` is a synchronous Redis write and nothing rescues it. *Applied* — guarantee scoped to the
destination HTTP call, real enqueue exposure stated as identical to the pre-existing PostHog enqueues.

**H10 — the AdRoll `event_name` was an undecided conditional inside SPEC.md** with rejected alternatives beside
it. *Applied* — deleted; the choice lives in REVIEW-FINDINGS D3/D5.

**H11 — no encoder and no parser named** while the spec required `conversionValue` "emitted as a JSON number"
and required reading `requestId`/`fieldWarnings`. *Applied* — `client.request :json` on all three connections;
`require 'oj'` and `Oj.load` on `google_data_manager_api.rb` only.

## MED

**M1** — "Nothing is ever fabricated to fill a gap" contradicted by `engagement_time_msec: 100`, AdRoll's
`page_location` and `currency: 'USD'`. *Applied* — all three named as fixed protocol constants, never
conditional, not removed.

**M2** — `page_location` described in prose without the `Variables::` namespace and without saying the value
is interpolated; `_base.md` rule 7 applied literally ships a non-interpolating single-quoted literal.
*Applied* — row carries the interpolated form; the AdRoll spec bullet asserts the value, not mere presence.

**M3** — gclid resolution for `ownerCreatedOrganization` stated three ways. *Applied* — resolved to
user-direct with no organization fallback (see `REJECTED.md` for the fix direction not taken).

**M4** — the architecture.md rule 2 justification is false for two of the three jobs. *Applied* — rewritten to
the real codebase precedent; REVIEW-FINDINGS Q3 corrected and re-aimed at the rules file.

**M5** — job rescue directed to log `e.message` only; the named analog writes the exception object to both
writers. *Applied* in both places.

**M6** — Google Ads success-path logging at error level unconditionally. *Applied* — `requestId` at
`Rails.logger.info`, non-empty `fieldWarnings` at `Rails.logger.error`.

**M7** — two skip reasons both surfacing as a nil conversion action ID, directed to log differently with no
stated discriminator. *Applied* — the frozen array is tested before the constant is read.

**M8** — `Ga4MeasurementProtocol::Client#send_event`'s return value justified twice by a caller that never
reads it. *Applied* — re-justified as the manual-verification signal.

**M9** — the `conversionValue` row quoted `amount.to_i / 100.0` and called it the `posthog_properties` form;
the real form is `amount.present? ? amount.to_i / 100.0 : nil` (`subscription_event.rb:104`). *Applied* to
both monetary rows.

**M10** — the "Use different values for each conversion / supply a default" setting generalized onto all five
conversion actions would book revenue on every signup, organization creation and trial start. *Applied* —
scoped to the two primary actions.

**M11** — `AdrollS2sApi::Client#send_event` was the only public method with an unnamed parameter list.
*Applied* — four named keyword arguments.

**M12** — `engagement_time_msec` called "a protocol requirement" with an omission consequence the research
records as unanswered. *Applied*.

**M13** — "Sending [`ga_session_id`] would be rejected" unsupported; default `RELAXED` ignores. *Applied*.

**M14** — `x-goog-user-project` sent and made a blocking credential without addressing the research's verbatim
"Don't set request headers in an IngestionService request". *Applied* — one reconciling sentence.

**M15** — the AdRoll unresolved-lookup set enumerated twice, both times as "three", disagreeing. *Applied* —
stated once as four; REVIEW-FINDINGS D5 updated.

**M16** — nine lines arguing why the GA4 path was rejected, duplicating REVIEW-FINDINGS Q2/Q2a. *Applied* —
compressed to three sentences.

**M17** — the seven-hour delay asserted only in the model spec, not at the four controller sites where it is
load-bearing. *Applied* to all three controller spec bullets.

**M18** — the JSON-number and absent-key assertions are not achievable against a captured Ruby Hash.
*Applied* — both directed against `JSON.generate` of the captured body.
