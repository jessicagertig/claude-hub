# Spec review round 4 — findings and disposition

8 findings across 4 review angles. 7 applied, 1 not applied (see `REJECTED.md`). Every codebase claim was
re-verified against `/Users/jessica/wrk/wrk-corp/inflow-ats` on branch `server-side-conversion-events` before
any edit. This was the convergence pass; no finding required a new decision from Jessica, and the one open
question a finding touched (Q3) already existed in `REVIEW-FINDINGS.md` and was sharpened rather than added.

## HIGH

**H1 — `require 'googleauth'` justification.** Claimed `app/models/job.rb` does not require `googleauth`.
*Not applied* — the claim is false. See `REJECTED.md`.

**H2 — "external side-effect dispatch in this codebase does not take that route" is false.** SPEC.md's only
justification for the job-constructs-client shape asserted that no external side-effect dispatch takes
`cursor_rules/backend/architecture.md` rule 2's Model Callback -> Job -> Model Instance Method -> Service
route. Two live chains take it end to end: `SyncWhatJobsListingJob#perform` ->
`BoardWhatJobsListing#sync_with_what_jobs` (`app/jobs/sync_what_jobs_listing_job.rb:13` ->
`app/models/board_what_jobs_listing.rb:100`) -> `WhatJobsListing.new.create_listing(self)` /
`update_listing(self)` (`app/models/board_what_jobs_listing.rb:208,215`) -> `WhatJobsApi::Client`, the service
being handed the model instance and its own header comment reading "Internal service class - only called from
BoardWhatJobsListing model instance methods" (`app/services/what_jobs_listing.rb:3`); and
`JobPingGoogleIndexJob` -> `Job#ping_google_index` (`app/jobs/job_ping_google_index_job.rb:10` ->
`app/models/job.rb:1424`), which builds and sends the Indexing API request from the model.
`REVIEW-FINDINGS.md` Q3 hedged the same claim with "generally"; SPEC.md dropped the hedge. *Applied* — SPEC.md
now states that the codebase does both, names the two rule-2 chains, and attributes the shape it follows to
the notification and analytics precedent. Q3 in `REVIEW-FINDINGS.md` gained the two chains so the ruling is
made against the split practice rather than a uniform one.

## MED

**M1 — guard ordering in `ingest_events` left the programming-error signal unreachable.** SPEC.md required an
unrecognized event name and a pending conversion action ID to log differently, while also saying each
service's public method "begins by checking that every constant it needs is present". All ten Google Ads
constants are blank in every environment for the whole pending period (`config/initializers/01_variables.rb`
declares only `GA4_MEASUREMENT_ID` and `GA4_API_SECRET`, lines 62-63), so a shared-constant guard placed first
turns every unrecognized event name into a pending-credential skip. *Applied* — the `ingest_events` paragraph
now fixes the order (recognized-name array first, five shared constants next, the event's own conversion
action ID last) and the missing-credential paragraph reads "checks that every constant it needs is present
before it assembles a request". The Google Ads service-spec bullet now asserts the unrecognized-name example
with the constants blank as well as present, which is the only form that falsifies the ordering.

**M2 — `SubscriptionEvent#attribution_value`'s signature never stated.** SPEC.md named the method in four
places without saying what it takes. The live method is `attribution_value(owner_value, organization_value)`
(`app/models/subscription_event.rb:126`), a two-argument comparison over values the caller has already read —
not a lookup by column name and not a method that reads records itself; `posthog_properties` calls it thirteen
times in that form (`app/models/subscription_event.rb:107-119`). "Resolves the gclid through
`SubscriptionEvent#attribution_value`" left a wrong-arity call or a forbidden wrapper open. *Applied* — the
"Existing patterns to follow" bullet now states the two-argument contract and names which pair each job reads
and passes.

**M3 — "fixed protocol constants ... required unconditionally" contradicted two of its own three examples.**
Google Ads' `currency` is conditional: SPEC.md's payload table sends it only alongside `conversionValue`, and
`conversionValue` is omitted whenever `subscription_events.amount` is nil and never sent for the three
secondary conversion actions, which are configured to record no value. `engagement_time_msec` is not required
— `events[].params` is marked Optional (`GA4-MEASUREMENT-PROTOCOL-REFERENCE.md:335`). Under the Data Manager
API's fast-fail model one bad record fails the whole request (`DATA-MANAGER-API.md:305`). The enumeration was
also incomplete against its own criterion. *Applied* — the paragraph now enumerates all six fixed literals and
carries the two qualifications instead of the false universal.

**M4 — GA4 job spec bullet contradicted the constructor contract.** The bullet directed assertions about how
the client is *constructed* with the stored `ga_client_id`, while SPEC.md states all three `Client` classes are
constructed with no arguments and that `send_event` takes `client_id`, `user_id` and `event_name`. It also
dropped the `event_name` pass-through, which no other spec file covers for GA4. *Applied* — the bullet now
asserts `send_event` call arguments and states that no example asserts construction.

**M5 — request-path assertion is a ghost.** Each endpoint constant is the complete URL and is what the
memoized `client` builds the connection with, so the path argument to `post` is the empty string — the form
`WhatJobsApi::Client` uses (`app/services/what_jobs_api.rb:11,41,147`). `expect(path).to eq('')` passes
whether or not the client targets the right endpoint, and the same paragraph already asserts `url_prefix.to_s`
against the constant. *Applied* — the specs assert the body only, with the reason stated.

**M6 — manual-verification paragraph delegated to `HANDOFF.md`.** That file declares AdRoll out of scope and
forbids building it (`HANDOFF.md:12`) and carries a branch name, a base commit hash and a merged PR number
(`HANDOFF.md:4`). The same paragraph already states the harness inline. *Applied* — the pointer is deleted.

---

# Round 4, second batch — findings and disposition

7 findings, of which two (M2 and M3 below) are the same defect reported twice by two angles. All applied;
nothing rejected. Every codebase claim re-verified against `/Users/jessica/wrk/wrk-corp/inflow-ats` on branch
`server-side-conversion-events` before any edit.

## HIGH

**H1 — the subscription trigger-site paragraph misdescribed both neighbouring dispatches.** SPEC.md placed the
three new enqueues "alongside the Discord and PostHog dispatches already there" inside the `when` branches.
`PosthogTrackJob.perform_later` is not in any `when` branch — it is the trailing line after the `case`
(`app/models/subscription_event.rb:61`), reached by every event type that does not fall to the bare `return`
at line 58 — and `converted_to_paid_subscription` (line 48) has no Discord dispatch at all; only
`trial_started` (line 43, `Discord::NotifyFreeTrialStartedJob`) and `trial_converted_to_paid_subscription`
(line 46, `Discord::NotifyTrialConvertedToPaidJob`) do. A planning agent reading "alongside the PostHog
dispatch" could place the enqueues beside line 61, firing them for `canceled_subscription` and `upgraded_plan`
too — the exact regression the spec's own `spec/models/subscription_event_spec.rb` example exists to catch.
*Applied* — the paragraph now states which branch holds what and that no new enqueue is placed beside the
trailing `PosthogTrackJob` call. The now-redundant sentence re-listing the three branches was folded into it.

## MED

**M1 — the magic-link controller examples could not reach the dispatch site.**
`Api::V1::RegistrationsController#magic_create` defaults `login_intent` to `'connect'`
(`app/controllers/api/v1/registrations_controller.rb:86`), resolves `organization` from a `CareersPage` slug
(line 89), then takes the `login_intent == 'connect' && organization.nil?` branch (line 93) whose hash reads
`organization.id` (line 101) — `NoMethodError` on nil. An example posting only `email` and `invite_token`
raises before line 216. `create_credit_test_organization` no-ops `complete_setup_workers`
(`spec/support/ai_credits_test_helpers.rb:56-58`), so no `CareersPage` exists for helper-built organizations
and `organization_slug` is not a route out. `sign_up_params` permits `:login_intent` at the top level (line
334) and `AuthForm` sends `loginIntent: "hire"`
(`app/javascript/ats/src/views/sessions/components/AuthForm.tsx:101`), snake-cased by `allKeysToSnake` in
`app/javascript/shared/queryHooks/api.ts:51`. *Applied* — the registrations spec bullet now directs both
magic-link examples to post `login_intent` with the value `'hire'` and states why. The nil dereference itself
is recorded under "Pre-existing defects noted and left alone" in `REVIEW-FINDINGS.md`.

**M2 / M3 — `SendGa4EventJob` was given an organization id it does not take** (reported by two angles). The
organizations controller spec bullet attached one three-item argument list — user id, organization id, event
name — to both enqueued jobs. `SendGa4EventJob` "Takes `user_id` and `event_name`" (New files table), and the
Modified files row scopes `organization_id: @organization.id` to `SendGoogleAdsConversionJob` alone. An
implementer following the bullet would either write an unpassable matcher or widen the job's signature away
from its `PosthogTrackJob` analog shape (`app/jobs/posthog_track_job.rb:6`,
`def perform(user_id, event, properties = {})`). The two sibling bullets state it correctly, so this was the
lone outlier. *Applied* — the assertion now splits the two jobs' arguments.

**M4 — the GA4 failure-log contents and `send_event` return contract were stated twice.** The New files row
and the Failure behavior paragraph carried the same five-field list and the same return contract near-verbatim
— the duplication class round 4's first batch removed for the Google Ads response logging and the job rescue
shape. *Applied* — the New files row keeps the full statement and gained the destination label `GA4`; the
Failure behavior paragraph now defers to it and keeps only what it owns, that a GA4 failure leaves no other
trace.

**M5 — a document-wide quoting convention lived inside one destination's payload-table cell.** The
single-quote rule naming `GOOGLE_ADS`, `WEB`, `USD`, `purchase`, the five camelCase event names and the header
names sat in the AdRoll `page_location` row, where nobody writing `Ga4MeasurementProtocol::Client` or
`GoogleDataManagerApi::Client` would read it. *Applied* — moved to the New files cross-file conventions
sentence beside `# frozen_string_literal: true`; the `page_location` row keeps only its own interpolation fact.

**M6 — `REVIEW-FINDINGS.md` still demanded a change SPEC.md had already made.** The section
`## OPEN — session_id must be parsed and sent, not omitted` opened "The spec must change" and asserted that
SPEC.md omits `session_id`. SPEC.md sends it: the payload table row, plus the full extraction rule, the four
absence cases and the never-synthesize rule. A fix agent reading the file would re-amend a compliant spec.
*Applied* — the section is deleted. R10 already carries the retained warning against sending the stored column
unreduced, so nothing is lost.
