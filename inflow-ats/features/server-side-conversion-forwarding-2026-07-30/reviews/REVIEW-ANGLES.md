# Review angles — server-side conversion forwarding

Sixteen adversarial angles against
`/Users/jessica/claude-hub/inflow-ats/features/server-side-conversion-forwarding-2026-07-30/SPEC.md`.

One fresh reviewer per angle. A reviewer holds only its own checklist and reads only what that checklist
needs. Broad "check everything" reading is what these angles exist to prevent.

## Rules binding every reviewer

- **READ-ONLY on the source repo.** `/Users/jessica/wrk/wrk-corp/inflow-ats`, branch
  `server-side-conversion-events`. Read, Grep, Glob and read-only git only. No app runs, no `rails runner`,
  no `psql`, no tests, no writes anywhere except this `reviews/` directory.
- **The branch has no commits ahead of `develop`.** `git diff --stat develop...HEAD` is empty; the only
  changes are working-tree modifications to `config/initializers/01_variables.rb` and
  `config/credentials.yml.enc`. Every claim that a constant "already exists" is a claim about the working
  tree, not about committed code (pipeline rule 15). State which you verified.
- **Verify, do not infer.** Open every file a claim names. A claim about a line number is wrong until the
  line is read. Report the trace chain (`A.rb → B.rb → C.rb`) with each finding.
- **These are Jessica's rulings and are not open for relitigation** — flagging a consequence is fine,
  proposing a different choice is not: the destination/event matrix; camelCase event names; the
  user-credential OAuth path for Google Ads (no service account, no domain-wide delegation, no key JSON);
  plain REST over Faraday rather than a Google client gem; **no abstraction of any kind shared across the
  three destinations**.
- **Severity.** BLOCKER = the spec as written produces code that cannot work or silently never fires.
  HIGH = spec contradicts the codebase, a cursor_rules rule, a research file, or a stated constraint.
  MED = ambiguity an implementer would resolve wrongly. LOW = wording.
  A spec-to-codebase mismatch is never MED (hub CLAUDE.md, "Spec-implementation mismatch is never MED").
- **Findings go in your own angle file**, never into SPEC.md or REVIEW-FINDINGS.md.

---

## 1. `conventions-core-critical-rules`
### Root `cursor_rules/core_critical_rules.md`, held as the whole checklist

Read `/Users/jessica/wrk/wrk-corp/inflow-ats/cursor_rules/core_critical_rules.md` and walk its fifteen
numbered rules plus the "File Naming Conventions", "Variable Naming for Records" and "Coding Styles"
sections against SPEC.md, one rule at a time. Nothing else is in scope for this angle.

Specific surfaces:

- **Rule 3** — `ap`, never `pp`. Every logging instruction in the spec's Failure behavior section.
- **Rule 8** — guard clauses return bare, never `false`/`nil`/`{}`. The spec describes guards in all three
  jobs and a credential-presence skip in all three services; check none is described as returning a value.
- **Rule 10** — never fabricate a fallback. Audit every literal the spec puts in a payload:
  `engagement_time_msec: 100`, `eventSource: 'WEB'`, `currency: 'USD'`, `validateOnly: false`,
  `event_name: 'purchase'`, the `page_location` billing URL, `user_id` as a stringified `users.id`. Which
  are protocol constants and which are substitutes for data the app does not hold? REVIEW-FINDINGS D7
  admits `engagement_time_msec` deliberately; D4 admits `page_location` and `ip`. Judge each against the
  rule's text, not against the admission.
- **Rule 11** — no bang methods. `fetch_access_token!` is a `googleauth` method already used at
  `app/services/engagement_report/google_sheets_sender.rb`; decide whether calling it is inside the rule's
  scope and say so either way.
- **Rule 7** — backend snake_case. The spec introduces camelCase string literals (`ownerSignedUp`,
  `convertedToPaidSubscription`) as job arguments and log labels in Ruby. Jessica has ruled the naming;
  report only whether the spec is explicit about where those strings live and how they are cased at each
  use site.
- **File naming** — services never contain "service"; jobs are `{action}_{resource}_job.rb`. Check all six
  new filenames in the spec's "New files" table.
- **Variable naming for records** — the spec's job descriptions say "finds both records", "the record id".
  Does the spec direct `subscription_event`, `user`, `organization` as variable names, or leave an
  implementer free to write `event`, `record`, `sub`?
- **"Do not automate edits to `app/models/organization.rb`"** — confirm nothing in the spec requires
  touching that file.

## 2. `conventions-backend-base`
### `cursor_rules/backend/_base.md`, held as the whole checklist

Read `/Users/jessica/wrk/wrk-corp/inflow-ats/cursor_rules/backend/_base.md` (nine rules) and hold only it.

- Rules 1–6: no begin blocks; rescue `StandardError` as the fallback and never bare `Exception`; never
  rescue at class or module level; never leave a rescue empty; `=> e`; avoid `ensure`. Check every rescue
  the spec describes — three jobs, three services, and the existing `resolve_from_plan`.
- **Rule 8, no `reload` in application code** — confirm no described flow re-reads a record it already has.
- **Rule 9, variable names match model names.** Same surface as angle 1's naming item; hold this file's
  wording.
- **Rule 7, single quotes for string literals.** The spec's payload literals are written in prose with
  backticks. Does the spec say anywhere which quote style the literals take, and does any literal
  interpolate (the AdRoll `page_location`, built from `Variables::AtsRootUrl`, must interpolate)?

## 3. `conventions-services`
### `cursor_rules/backend/services.md`, held as the whole checklist

Read `/Users/jessica/wrk/wrk-corp/inflow-ats/cursor_rules/backend/services.md` and hold only it against
SPEC.md's three service descriptions and its "Existing patterns to follow" section.

- **Rule 1** — no "Service" in the class name. `Ga4MeasurementProtocol::Client`,
  `GoogleDataManagerApi::Client`, `AdrollS2sApi::Client`.
- **Rule 2** — descriptive public method names, never `call`/`execute`. `send_event` (twice, in two
  different modules) and `ingest_events`. The rule says API clients get "one method per endpoint" —
  assess whether `send_event` names an endpoint or an action.
- **Rules 3, 4, 5, 6** — IDs when called from background jobs, objects in the request cycle, simple values
  passed directly, keyword arguments, `find_by` not `find`. The spec's jobs find the records and then call
  the client: what does the client actually receive, and does the spec say? This is the load-bearing gap —
  the spec names no initializer signature for any of the three clients.
- **Naming & location** — "API Clients: single file with module + Client", at `app/services/<api_name>.rb`.
  Existing files: `webflow_api.rb`, `what_jobs_api.rb`, `wwr_api.rb` (module + Client) versus
  `cloudflare_client.rb`, `stream_client.rb`, `send_grid_client.rb` (flat class). Judge
  `ga4_measurement_protocol.rb` — which has neither `_api` nor `_client` in its name — against both forms.
- **Error handling** — method-level rescue for silent failure; raise to trigger retry; rescue specific
  exceptions; log with both `ap` and `Rails.logger.error`. The spec has two clients raising `ApiError` and
  one client raising nothing. Is each consistent with this file?
- **Memoization** and **guard clauses with early returns** sections.
- The file's closing line: calling other services or queueing jobs from a service must be stated explicitly
  to the user. Does any described service do either?

## 4. `conventions-background-jobs`
### `cursor_rules/backend/background_jobs.md`, held as the whole checklist

Read `/Users/jessica/wrk/wrk-corp/inflow-ats/cursor_rules/backend/background_jobs.md` and hold only it
against the spec's three new jobs and the three modified dispatch sites.

- **0a naming** — `{action}_{resource}_job.rb`, action verb first. All three names.
- **1** — pass IDs, not objects. Check every `perform_later` argument list the spec specifies, including
  the camelCase event-name strings and the optional-nil subscription event id.
- **2** — `find_by(id:)` plus a guard clause.
- **3, jobs orchestrate and do not contain business logic.** This is the sharp one. The spec has
  `SendGoogleAdsConversionJob` guarding "on a gclid being present … from either the owner or the
  organization" and `SendAdrollConversionJob` guarding on `owner.current_sign_in_ip` and on at least one
  AdRoll identifier. Is resolving the owner-then-organization preference and assembling payload inputs
  business logic sitting in a job?
- **4** — method-level `rescue StandardError` at the end of `perform`, and the logging directive "in rescue
  blocks: use BOTH `ap` and `Rails.logger.error`". Note that the analog SPEC.md cites for this,
  `app/jobs/discord/notify_trial_converted_to_paid_job.rb`, writes `Rails.logger.error` twice and no `ap`
  at all. Which does the spec direct, and does its citation support what it directs?
- **5** — `after_commit` over `after_save`. Already satisfied by the existing callback; confirm the spec
  does not move or duplicate the callback.
- **Job Structure / Basic Pattern** — `queue_as :default`, guard order, "Don't re-raise".
- The delayed-enqueue form. Open `app/models/job.rb` line 707 and
  `app/services/submit_resume_to_textract.rb` line 27 (both cited by the spec) and confirm the
  `set(wait: …).perform_later` shape the spec is telling an implementer to copy.

## 5. `conventions-architecture`
### `cursor_rules/backend/architecture.md`, held as the whole checklist

Read `/Users/jessica/wrk/wrk-corp/inflow-ats/cursor_rules/backend/architecture.md` and hold only it.

- **Rule 2, "Jobs Call Model Instance Methods — Not Services Directly"**, with its explicit flow
  `Model Callback → Background Job (passes IDs) → Model Instance Method → Service → External API` and its
  single stated exception ("PostHog service methods are not limited to a single model"). All three of the
  spec's jobs construct a service client directly. Decide whether the PostHog exception covers advertising
  destinations, whether the spec should route through a model instance method, or whether this is a
  deviation Jessica must rule on. Do not soften it: state the rule, state what the spec does, state the
  gap.
- **Rule 1, controller actions over 15 lines of business logic must use an interactor.** Read
  `Api::V1::OrganizationsController#create` (lines 26–62) and both dispatch sites in
  `Api::V1::RegistrationsController`. Count what is already there and what the spec adds.
- **Rule 3, `after_create` for synchronous setup, `after_commit` for async side effects**, and the
  "Record Setup/Initialization" flow. The spec adds enqueues inside an existing `after_commit`; confirm
  placement and that nothing new lands in an `after_create`.
- The "Background Processing → Example: External API Sync" walkthrough (`board_what_jobs_listing.rb` →
  `sync_what_jobs_listing_job.rb` → `what_jobs_listing.rb`) is this file's canonical shape for exactly what
  this feature does. Diff the spec's shape against it.

## 6. `conventions-code-style-and-structure`
### `cursor_rules/backend/code_style_and_structure.md`, held as the whole checklist

Read `/Users/jessica/wrk/wrk-corp/inflow-ats/cursor_rules/backend/code_style_and_structure.md` (54 lines)
and hold only it. Its content is thin and largely defers elsewhere; that is the point — read it literally
and check each line.

- **"Error Handling by Context"**: Jobs "log errors and sometimes update status or trigger retry";
  Services "log, propagate meaningful error or status". `Ga4MeasurementProtocol::Client` is specified to
  raise nothing and log only. Does that satisfy "propagate meaningful error or status", and does its caller
  learn anything?
- **"When to Use Rescue"**: "Only for expected/possible errors" and "No blanket rescue without specific
  handling". The spec puts a blanket `rescue StandardError` at the end of all three `perform` methods.
  Reconcile against `background_jobs.md` rule 4, which mandates exactly that; if the two rules files
  conflict, say so rather than picking one silently.
- **"File & Directory Structure"** — every path in the spec's New files table.
- **"Method Return Patterns"** — "Use guard clauses only for early exits without values", "Never use guard
  clauses to return a value", "Rely on Ruby's implicit return". Check the described credential-skip returns
  and the client `request` methods.

## 7. `trigger-site-placement`
### `cursor_rules/backend/controllers/*.md` plus the correctness of all four dispatch sites

Hold `cursor_rules/backend/controllers/controller_error_handling.md` and
`cursor_rules/backend/controllers/controller_patterns_and_crud.md` as the rules checklist, and read all
four dispatch sites in full:

- `app/controllers/api/v1/registrations_controller.rb` around line 57 (email path) and line 216
  (magic-link path)
- `app/controllers/api/v1/users/omniauth_callbacks_controller.rb` around line 45
- `app/controllers/api/v1/organizations_controller.rb#create`, the `if @organization.save` branch

Checks:

- Are the cited line numbers right, and is the described surrounding structure right (the `if @invite.nil?`
  gate, the `resource.active_for_authentication?` nesting, the `if user.new_user_created_via_google_sso`
  branch, the position relative to `organization_user.org_owner!` and `render_one`)?
- The magic-link site is specified with **no** invite gate. Read that path's `created_via` /
  `add_connect_user` handling and decide whether every user reaching it is genuinely an organization owner,
  or whether the existing unconditional PostHog `organization_owner_signed_up` call is itself the thing
  being copied without question.
- **Argument sufficiency per event.** The spec's Google Ads payload table sources `eventTimestamp` from
  "the `User` for `ownerSignedUp`; the `Organization` for `ownerCreatedOrganization`". Then
  `SendGoogleAdsConversionJob` is specified to take "a user id, an event name, and an optional subscription
  event id". Trace, for each of the five events routed through that job, whether the argument list can
  actually produce every field the payload table requires. Same exercise for `SendGa4EventJob` and
  `SendAdrollConversionJob`.
- Is the identifier the payload needs populated on the record at the moment of dispatch? Trace
  `ga_client_id` and `google_click_id` onto `users` at each signup path and onto `organizations` in
  `#create` (lines 31–44).
- Controller rules: no begin blocks, method-level rescue only, one params method per controller, and
  whether an added enqueue can raise into the request (see angle 13).
- Confirm the spec's two "deliberately not modified" statements
  (`app/jobs/track_new_sso_owner_signup_job.rb`, `OrganizationForm.tsx`) hold, and that D9's stated reason
  — `return unless POSTHOG_CLIENT` sitting above every `capture` — is actually in that job.

## 8. `codebase-citation-audit`
### Every factual claim SPEC.md makes about the repository

Open every file, line, method, constant, column and gem version SPEC.md names and verify it. Produce a
table: claim → what the file actually says → SAME / DIFFERENT / NOT FOUND. This angle asserts nothing about
design.

Claims to verify, at minimum:

- `SubscriptionEvent` enum keys and integers; `handle_after_commit_on_create`'s `case`/`else`/bare `return`;
  `posthog_properties` and `attribution_value` (public? `.compact`? which identifiers?).
- `config/initializers/01_variables.rb` — the GA4 pair at lines 62–63 and the exact form of the
  `GOOGLE_INTERNAL_SHEETS_*` trio (REVIEW-FINDINGS discrepancy 1 says the trio has no `STAGING_` prefix;
  confirm). Note whether these are committed or working-tree only.
- `app/services/engagement_report/google_sheets_sender.rb` — `build_authorization`,
  `credentials_configured?`, the `append_row` skip, `SCOPES`.
- `app/models/organization.rb` line 833 (`currency: 'usd'`), `app/models/job.rb` line 707,
  `app/services/submit_resume_to_textract.rb` line 27, `config/environments/test.rb` line 64.
- `Variables::AtsRootUrl` — exact constant name and casing, and whether a billing-URL constant already
  exists alongside `ATS_PREFERENCES_URL`.
- `users.current_sign_in_ip` — the column exists and its type is `inet`, which Rails returns as an
  `IPAddr`, not a `String`. The spec says "as a string"; check it says how.
- `subscription_events` columns and types (`amount` — integer? nullable?), and the absence of a currency
  column and any invoice id (REVIEW-FINDINGS discrepancy 6).
- Thirteen versus fourteen attribution identifiers, in `OrganizationsController#create`, in
  `posthog_properties`, and in `User#attribution_properties`.
- `app/javascript/shared/lib/utils.js` — `adPlatformIdentifiers`, `gaSessionIdFromCookies`, and the claimed
  shape of the stored `ga_session_id`.
- `app/jobs/posthog_track_job.rb` and `app/jobs/discord/notify_trial_converted_to_paid_job.rb` — do they
  contain what the spec says they contain? (The spec cites the Discord job as the analog for "writing both
  `ap` and `Rails.logger.error`.")
- `Gemfile.lock`: `faraday 0.17.5`, `googleauth 1.8.1`, `rspec-rails`; `.ruby-version`; the absence of
  WebMock and VCR; the contents of `spec/`.
- Zeitwerk: does `app/services/ga4_measurement_protocol.rb` → `Ga4MeasurementProtocol`,
  `adroll_s2s_api.rb` → `AdrollS2sApi` hold under the default inflector with no acronyms configured in
  `config/initializers/inflections.rb`?

## 9. `enum-literal-and-dispatch-matrix`
### The trap that fails silently in every environment

`handle_after_commit_on_create` ends its `case` with `else` → bare `return`. A branch written against an
enum key that is retroactive-only executes never, logs nothing, and no test covers it (REVIEW-FINDINGS R8).

- Confirm from `app/models/subscription_event.rb` that the live keys are `converted_to_paid_subscription`
  (10) and `trial_converted_to_paid_subscription` (11), and that `converted_to_paid` (3) and
  `trial_converted_to_paid` (9) appear in no `when` branch.
- Verify SPEC.md uses the live keys everywhere it names one — the Events table, the Trigger sites section,
  the Modified files table, the Configuration constant names, and the test plan. One stale literal anywhere
  is a BLOCKER (hub CLAUDE.md, rule 6: rename cascades).
- Confirm SPEC.md adds no new `when` branch and reorders none, and that the trailing
  `PosthogTrackJob.perform_later` stays reachable from every branch the spec touches.
- Trace the two live creation paths — `app/interactors/create_subscription_event*.rb` — and confirm they
  write keys 10 and 11 and not 3 and 9, so the branches the spec targets can actually fire in production.
- The spec's negative test assertions name `assigned_free_plan`, `canceled_subscription`, `upgraded_plan`,
  `converted_to_paid`, `trial_converted_to_paid`. Compare against the full twelve-key enum: is the list
  complete enough to catch a wrong-literal regression, and does it name every key that exists?
- Does anything in the spec depend on the event-type string reaching a destination (log labels, job
  arguments)? If a job argument is the camelCase destination name rather than the enum key, a wrong mapping
  between the two is a second silent-failure surface — check the spec pins the mapping.

## 10. `no-abstraction-constraint`
### Three destinations, three services, three jobs, sharing nothing

Jessica has ruled out designing an abstraction ahead of real payloads. Any of the following in SPEC.md is a
defect, regardless of how small: a shared base class or parent job; an adapter, registry, dispatcher or
plugin interface; a shared payload builder or normalizer; a shared HTTP wrapper; a shared error class
across destinations; a shared credential-check helper; a renamed generic `analytics_properties`; a shared
concern or mixin; a single job that branches on destination; a lookup table mapping events to destinations
that lives outside the three call sites.

- Read the New files table, the Modified files table and the three payload sections looking for any of the
  above, including implied sharing: two services described as "the same" in a way that invites an
  implementer to extract a parent.
- Check the inverse failure too: does the spec leave the three implementations so under-specified
  ("following the same shape") that an implementer would naturally unify them? Under-specification that
  invites an abstraction is a finding.
- Confirm `posthog_properties` is neither renamed, generalized, nor consumed by this work, and that
  `attribution_value` is used as the existing public model method rather than copied or wrapped.
- Duplication that the constraint requires — three separate credential checks, two identically-named
  `ApiError` classes in different modules, the same cents-to-currency division written twice — must NOT be
  reported as a defect. Say explicitly that you checked and that the duplication is intended.

## 11. `analog-structural-matching`
### Signatures and structure, not "a service exists"

Build a structural manifest of the analogs, then diff the spec against it row by row. Layer completeness is
not matching (hub CLAUDE.md, rule 14).

Analogs to read in full:

- `app/services/webflow_api.rb` and `app/services/what_jobs_api.rb` — `API_ENDPOINT` constant on `Client`,
  `attr_reader`s, `initialize` keyword-argument signature and where credentials default from
  (`api_token: Variables::WHAT_JOBS_API_TOKEN`), `private`, `def client` memoized as
  `@_client ||= Faraday.new(api_base_url) { |client| … }` including header setup and
  `client.adapter Faraday.default_adapter`, `def request(http_method:, endpoint:, params: {})` dispatching
  via `client.public_send`, `Oj.dump`/`Oj.load`, the `error_class(response)` status dispatch, and the error
  classes subclassing `Faraday::ClientError` with `(message, response)` initializers.
- `app/jobs/posthog_track_job.rb` — a four-line job with `find_by`, a bare `return unless`, delegation, and
  **no rescue and no logging at all**. The spec cites it as the pattern while specifying jobs that do have
  a rescue; state the deviation and whether `background_jobs.md` justifies it.
- `app/services/engagement_report/google_sheets_sender.rb` — `build_authorization` returns the credentials
  object via `.tap(&:fetch_access_token!)`. The REST path needs a bearer **string**. Does the spec say how
  the token string is obtained from that object, and does its private-method name (`access_token`) collide
  with anything?
- Sibling jobs in `app/jobs/` — do any declare `retry_on` / `discard_on` with an exhaustion block? The spec
  declares neither. Report what the domain's jobs actually do (rule 14, job retry/exhaustion patterns).

Also verify the described clients can be built on the installed gems: `faraday 0.17.5` (0.x, not 1.x or
2.x — query-parameter handling, header setup, `response.status`, adapter registration) and
`googleauth 1.8.1` on Ruby 3.1.6. A spec instruction that only works on a Faraday version this app does not
have is a BLOCKER.

## 12. `money-and-value-semantics`
### Cents, currency units, micros, zero and nil

- `subscription_events.amount` is in **cents**. Google Ads `conversionValue` is **currency units, not
  micros** (DATA-MANAGER-API.md §3, verbatim: *"Set to the currency value, not the value in micros"*).
  Confirm SPEC.md says cents ÷ 100 everywhere it mentions value, and never micros.
- Check the arithmetic form. `posthog_properties` uses `amount.present? ? amount.to_i / 100.0 : nil` —
  float division. Integer division (`amount / 100`) silently truncates. Does the spec pin the form or leave
  it open?
- **Amount 0.** `plan_simple_ats_per_job` organizations were written with `amount: 0`. SPEC.md sends 0;
  REVIEW-FINDINGS R9 accepts the consequence. Verify the spec distinguishes 0 from nil at every layer —
  the send, the guard, and the test assertions — and that no `|| 0` or `.presence` construction can turn
  one into the other (core rule 10; pipeline note that `.presence` is not a house form).
- **Amount nil.** The spec omits `conversionValue` and lets the conversion action's default apply. Confirm
  it also omits `currency`, since the research pairs them, and that "omit" means the key is absent rather
  than present-and-null.
- Currency: `USD` literal, sourced from `app/models/organization.rb` line 833. Verify that line, verify no
  currency column exists, and check the case the destinations want (`USD` for Google Ads; AdRoll's
  expectation is unstated).
- AdRoll's monetary field name and its unit are an unresolved lookup (D5). Check the spec commits to cents
  ÷ 100 for it too, and check whether an unknown field name plus a known unit is actually specifiable.
- `billing_interval` — an annual `amount` is a full year of revenue arriving as one conversion value. Is
  that what the conversion action should receive? Report the question; do not decide it.
- Float representation: `49.0` versus `49.00` versus `BigDecimal`, and what JSON serialization produces.

## 13. `failure-and-absence-behavior`
### Missing credentials, absent identifiers, and what must never be fabricated

- **Credential guards.** The analog is `credentials_configured?` + the `append_row` skip in
  `google_sheets_sender.rb`. Check each of the three services is specified to check exactly the constants
  it needs. For Google Ads the spec says the path is inert "until every one of the ten pending constants
  holds a value" — but only one of the five conversion-action IDs is used by any given send. Does an
  over-broad guard mean a correctly configured account still skips? Does an under-broad guard mean a nil
  `productDestinationId` reaches the wire?
- **Identifier guards.** `SendGa4EventJob` on `ga_client_id`; `SendGoogleAdsConversionJob` on
  `google_click_id`; `SendAdrollConversionJob` on the owner, `current_sign_in_ip`, and at least one AdRoll
  identifier. Check the predicate: `.present?` versus `.nil?` versus `.blank?`, and how a stored empty
  string behaves (`attribution_value` uses `.present?`).
- **Nothing fabricated.** Trace every field to a stored value or an admitted constant. No `|| 0`, `|| ''`,
  `|| []`, no synthesized `client_id`, no placeholder IP, no invented transaction id. Cross-check the
  admitted constants against angle 1's list so the two angles agree.
- **Omission versus null.** For every "omitted when absent" field (`identifiers.adct`,
  `identifiers.first_party_cookie`, `conversionValue`, `currency`, `transactionId`), confirm the spec says
  the key is absent from the JSON, not present with a null value.
- **Errors logged and dropped.** Two clients raise `ApiError`; the job's method-level rescue catches; no
  retry, no re-raise. Confirm that is stated for all three and that the log line carries destination, event
  name and record id.
- **Can a dispatch fail its caller?** SPEC.md asserts "none of these dispatches can fail the request or the
  callback that enqueued them." `perform_later` enqueues to Sidekiq/Redis synchronously. Trace what happens
  when Redis is unavailable at `Api::V1::OrganizationsController#create` and inside the `after_commit`
  callback, and whether `set(wait: 7.hours)` changes it. If the assertion does not hold, it is a HIGH.
- The seven-hour delay's failure mode: REVIEW-FINDINGS D8 accepts that a queue outage inside the window
  drops the send. Confirm SPEC.md does not claim otherwise.

## 14. `test-plan-and-ghost-tests`
### Presence, specificity, falsifiability

Hold SPEC.md's "Test requirements" section, hub CLAUDE.md rule 26 (falsifiable assertions), pipeline rules
3 (specs must state test requirements), 31 (queue adapter) and 37 (baseline runs).

- For every proposed assertion, ask: would it still pass if the line it claims to test were deleted?
  Flag reflective assertions, type checks, assigned-but-unasserted variables, and any assertion on a
  constant's presence.
- **Mechanism.** No WebMock, no VCR. `spec/spec_helper.rb` sets `mocks.verify_partial_doubles = true`. The
  spec says "the client's Faraday connection is stubbed" — but `client` is a private memoized method.
  Does the spec say how a private memoized Faraday connection is stubbed under verified partial doubles,
  and would the named approach actually work?
- **Environment facts.** `config/environments/test.rb:64` sets `:inline`; the spec's `around` block
  restores the previous adapter. REVIEW-FINDINGS discrepancy 7 says the precedent file cited by pipeline
  rule 31 no longer exists — confirm, and confirm the mechanism is still specified precisely enough to
  implement without it. Also: with `:inline`, does creating a `SubscriptionEvent` in a model spec fire the
  existing PostHog and Discord jobs for real? Is `from_plan` non-nil in every example (live
  `Stripe::Invoice.list` otherwise)? Does `organization.owner` exist in every fixture
  (`posthog_properties` calls it unconditionally)?
- **Coverage holes.** The spec plans a dispatch-matrix spec for `SubscriptionEvent` but no request spec for
  any of the three controller dispatch sites — the `ownerCreatedOrganization` site is brand new. Is that
  omission stated and reasoned, or silent (pipeline rule 3: "no tests" is acceptable only when explicitly
  documented)?
- **Baseline.** The spec claims no existing spec needs updating and that `spec/models`, `spec/jobs`,
  `spec/services` do not exist. Verify by reading `spec/`. Rule 37 requires an executed baseline run before
  any "must still pass" claim — you may not run tests, so report the baseline requirement as a
  precondition on the implementation phase.
- Do the planned assertions actually pin the things that fail silently: the exact enum-key-to-job matrix,
  the seven-hour delay, the cents ÷ 100 value, the `Token` (not `Bearer`) scheme, the absent keys?

## 15. `payload-fidelity-vs-research`
### Exact field names, casing, reserved names, hashing rules, limits

Hold the four research files as authority. Every field name, header, URL, enum literal and limit in
SPEC.md's three payload sections must trace to a line in them.

- **GA4** (`GA4-MEASUREMENT-PROTOCOL-REFERENCE.md` §1.1–1.3, §2.1–2.2, §3, §4, §7.4, §7.5, §8): endpoint
  and the `measurement_id` / `api_secret` query parameters; `client_id` required and its accepted formats;
  `user_id` constraints (utf-8, 256 chars, no third-party-identifiable data); `events[].name` rules
  (≤ 40 chars, alphanumerics and underscores, must start with a letter, case sensitive) and the reserved
  event-name list — check `ownerSignedUp` and `ownerCreatedOrganization` against both; reserved **parameter
  prefixes** `_`, `firebase_`, `ga_`, `google_`, `gtag.`; `engagement_time_msec`; the ≤ 25 events per
  request cap; the 2xx-for-everything response contract and the debug endpoint; and §8's policy list.
- **Google Ads** (`DATA-MANAGER-API.md` §3, §4, §6): `POST https://datamanager.googleapis.com/v1/events:ingest`;
  `accountType: "GOOGLE_ADS"` from the discovery enum (not `GOOGLE_ADS_ACCOUNT`); digits-only `accountId`;
  bare-numeric `productDestinationId`; `validateOnly`; `adIdentifiers.gclid`; RFC 3339 `eventTimestamp`;
  `eventSource`; `conversionValue`; `currency`; `transactionId`; `loginAccount` omission; the `encoding`
  field's meaning and whether omitting it is correct when no hashed identifier is sent; and the JSON body's
  camelCase versus the proto snake_case. **Resolve the header contradiction inside the research itself**:
  §3 lists `x-goog-user-project` in the request while quoting verbatim *"Don't set request headers in an
  IngestionService request. The Data Manager API ignores headers in an ingestion request."* SPEC.md sends
  the header. Say which reading the spec must commit to. Also the `datamanager` scope string, the 300
  req/min and 100,000/day limits, and the six error reasons the spec names.
- **AdRoll** (`ADROLL-S2S-CREDENTIALS.md` §2, §3, §5): `POST https://srv.adroll.com/api` with the
  `advertisable` query parameter; `Authorization: Token` (never `Bearer`); `advertisable_eid`, `pixel_eid`,
  `event_name`, `page_location`, `ip` as the required body fields; `purchase`'s membership in the
  thirteen-value enum; `identifiers` requiring at least one of `first_party_cookie` / `adct`; the ≤ 100
  events ceiling; the undocumented content type. Confirm SPEC.md names the two unresolved items (the
  monetary field name and the top-level wrapper key) as lookups and guesses neither.
- **Cross-file consistency**: `GCLID-THROUGH-GA4.md` and `GA4-CREDENTIALS-SETUP.md` — does SPEC.md's stated
  reason for keeping the paid conversions out of GA4 match what those files actually say about the 72-hour
  backdating limit and the 48-hour joining guidance?
- Anything SPEC.md asserts that no research file supports is a finding, even when it sounds right.

## 16. `spec-form-and-scope-hygiene`
### What a spec may contain, and what belongs in REVIEW-FINDINGS.md

SPEC.md must read as settled decisions in prose. Defects, each reported with its line:

- **Open questions, hedges, "must be looked up", "not yet known", "TBD", "to be decided", "if X then Y"
  where the ruling is undecided.** The AdRoll section currently tells an implementer that two payload
  details "must be read off" the vendor docs "before the client is written" — judge whether that is an
  unresolved question living inside SPEC.md rather than in REVIEW-FINDINGS.md, and whether the rest of the
  spec has more of the same.
- **Review provenance** — any mention of a review round, a finding, an agent, an alternative considered, a
  risk accepted, or a reason a different option was rejected. All of it belongs in REVIEW-FINDINGS.md.
- **Code blocks.** SPEC.md must name identifiers, not show implementations.
- **Restated research.** Facts already recorded in the five research files should be referenced, not
  re-derived at length inside SPEC.md.
- **Internal consistency and stale references** (hub CLAUDE.md, "Stale references after amendments"):
  "thirteen attribution identifiers" versus "fourteen"; "four conversion actions" in the briefing versus
  five in SPEC.md (REVIEW-FINDINGS D1) — is SPEC.md self-consistent on the count everywhere, including the
  Configuration list; the count of new constants ("Thirteen new constants — ten for Google Ads, three for
  AdRoll") against the enumerated list; the New files count against the table.
- **Scope.** Does SPEC.md propose anything beyond transport — a migration, a new column, a change to the
  PostHog dispatch, an edit to `organization.rb`, an edit to `.env`, a fix to the pre-existing swallowed
  `Interactor::Failure` messages, or a change to `OrganizationForm.tsx`? Every "deliberately not modified"
  line must hold.
- **Contradiction between the two documents.** Read REVIEW-FINDINGS.md against SPEC.md and report any place
  where a decision recorded as reversible in one is stated as settled fact in the other without the spec
  reflecting the chosen default.
