# Spec review round 1 — findings and disposition

44 findings across 11 review angles (conventions per rules file, codebase citation audit, trigger-site
placement, analog structural matching, money handling, failure/absence, the no-abstraction constraint, the
enum-literal trap, payload fidelity against the research files, spec form, test requirements).

Every finding was verified against the source repo on branch `server-side-conversion-events` before being
applied. Three were rejected — see `REJECTED.md`.

---

## HIGH — applied

| # | Finding | Where in SPEC.md |
|---|---|---|
| H1 | `currency: USD` justified by `app/models/organization.rb` line 833, which is `currency: 'usd'` on an `organization_ai_credit_purchases.create!` inside `setup_ai_credit_test_subscription` (`return unless Rails.env.test?`) — not a checkout session, not the plan path. The plan checkout session at `billing_controller.rb:108` sets no currency at all. Raised by three angles. | Google Ads payload table, `events[0].currency` row; also REVIEW-FINDINGS discrepancy 6 |
| H2 | `SendGoogleAdsConversionJob` could not reach the `Organization` whose `created_at` the payload requires for `ownerCreatedOrganization`. The only route, `User#organization`, is `current_organization_user&.organization` — mutable, resolved seven hours after enqueue. Raised by four angles. | New files job row; `eventTimestamp` row; Modified files organizations_controller row; Failure behavior guard list |
| H3 | `access_token` following `GoogleSheetsSender#build_authorization` returns the credentials object, not a token string. `.tap(&:fetch_access_token!)` returns the credentials; `fetch_access_token!` returns a hash. `Bearer #<Google::Auth::UserRefreshCredentials…>` 401s every request. | Google Ads Authentication; New files service row |
| H4 | Faraday 0.17.5 defines `post` as `(url, body, headers)` (`connection.rb:173-174`), so the analogs' `request(… params:)` sends params as the body. GA4's `measurement_id`/`api_secret` and AdRoll's `advertisable` had no home. Query params go on the connection. | Existing patterns, API client services bullet |
| H5 | `conversionValue` arithmetic form unpinned. `4999 / 100` is `49` in Ruby. House form is `amount.to_i / 100.0` (`subscription_event.rb:104`). The spec's own 4900 example passes under either. `BigDecimal` would emit a quoted string. | `conversionValue` row; service spec assertions |
| H6 | Magic-link `ownerSignedUp` had no invite gate. `AuthForm` sends `inviteToken` to `/magic_login`; a new invited teammate falls to the else branch, is created, and reaches line 216 where the PostHog call is unconditional. Invited teammates carry a `ga_client_id`, so GA4 would fire. | Trigger sites; Modified files registrations_controller row; REVIEW-FINDINGS D12 |
| H7 | The three Client classes had no stated initializer signature, and the two named analogs contradict each other — `WhatJobsApi::Client` takes credentials as kwargs, `WebflowApi::Client#initialize` opens `raise 'Must Set access_token' if access_token.nil?`, which would raise on every Google Ads send while its constants are pending. | New files, paragraph below the table |
| H8 | Google Ads conversion-action manual setup omitted the click-through window (default 30 days, not retroactive), Count (default Every), and Value (needed for the spec's own "configured default value applies" rule). | Google Ads section, after the primary/secondary paragraph |
| H9 | The GA4 omission rationale asserted as settled two things the research records as unresolved: the 48-hour rule's scope (§4.6) and that ingestion-time placement is itself disqualifying — the research's own Method A prescribes exactly that. Real support is §4.1: no one has walked the chain end to end. | GA4 Measurement Protocol, second paragraph |
| H10 | No controller specs for any of the four dispatch sites, including the one genuinely new site and the invite gate. Pipeline rule 3 forbids silent omission. On-point analogs existed and were deleted 2026-07-28. | Test requirements, three new spec-file bullets plus the Devise/controller-stub paragraph |
| H11 | The stubbing mechanism was one clause and not implementable: the analog's `client` is private, `verify_partial_doubles` is true, and every Google Ads positive-path example would hit the missing-credential skip because all ten constants are nil. | Test requirements, stubbing paragraph |
| H12 | `architecture.md` rule 2 (Job → Model Instance Method → Service) names PostHog as its only exception; all three jobs skip both layers. No job in the codebase constructs a house API client. | New files paragraph; REVIEW-FINDINGS Q3 |
| H13 | AdRoll monetary value stated once inside the deferred-lookup paragraph and absent from the payload table, the client row, the job row, the guard list and the test plan. | AdRoll payload table, new row; test plan |

## MED — applied

- Service-level log sites named no mechanism. All four now write both `ap` and `Rails.logger.error`
  (`core_critical_rules.md` rule 3, `background_jobs.md:299-301`, `services.md:211-220`).
- `Discord::NotifyTrialConvertedToPaidJob` cited as the rescue analog writes two `Rails.logger.error` lines
  and no `ap`. Replaced with `export_organization_candidates_to_csv_job.rb:22-25`.
- Event-name → conversion-action-ID mapping had no stated owner. Now an explicit frozen hash constant on
  `GoogleDataManagerApi::Client`, keys verbatim camelCase, no `const_get`/`underscore` derivation, no
  event-to-destination table in any layer.
- Record variable naming undirected while `event` meant both the name string and the `SubscriptionEvent`.
- Rescue blocks named no exception variable and logged no `e.message` (`_base.md` rules 4 and 5).
- Configuration-constants bullet pointed at the unprefixed `GOOGLE_INTERNAL_SHEETS_*` trio while the
  Configuration section mandates `STAGING_`.
- `Ga4MeasurementProtocol::Client` had no stated return value (`code_style_and_structure.md:20-21`). Now
  returns the HTTP status.
- The seven-hour delay was restated in the `subscription_event.rb` row only, reading as though the three
  controller sites were exempt — the two events the delay exists for.
- "Three `perform_later` calls" enumerated five.
- The `subscription_event.rb` row named no enqueue arguments; no `when` branch has the owner in scope.
- Why the `ownerCreatedOrganization` dispatch is not in `Organization#complete_setup_workers` (four other
  organization-creation paths) was absent.
- Interactor-extraction scope fence added for the four >15-line controller actions.
- Attribution copies happen at lines 32-44, before `@organization.save` — not inside the branch — and copying
  preserves absence.
- `subscription_event_spec` negative list named five of the nine non-dispatching types, omitting
  `assigned_free_plan_on_creation`, the type `log_assigned_free_plan_event` writes for a fresh organization.
- Stack scope column list named `stripe_subscription_id` (sent nowhere) and omitted `users.id`,
  `users.created_at`, `organizations.created_at` and `subscription_events.id`.
- `users.current_sign_in_ip` is `t.inet` (`schema.rb:1268`); the attribute is an `IPAddr` and needs `.to_s`.
- GA4 constants described as "already present" are working-tree-only; the branch is 0 commits ahead of
  develop. Reworded to verify-then-add; constant count changed to fifteen.
- Credentials-file instruction said to create `ga4_measurement_id` / `ga4_api_secret`, which exist.
- Google Ads credential guard was all ten constants; the analog checks exactly what the call needs. Now five
  shared plus the one conversion action ID for the event being sent.
- `currency` and `transactionId` stated scope but not serialization; a nil in a Ruby hash becomes JSON null,
  which the fast-fail model rejects untraceably.
- `client_id` described as joining to "the browser session"; the documented join is to the client instance's
  online interactions.
- "`purchase` is the only monetary one" appears nowhere in the research; `signupPlan` and `signupTrial` are
  the other candidates.
- "The names ... exist only in the payloads sent to these three destinations" contradicted the spec's own
  tables — only two names reach a wire.
- AdRoll deferred-lookup paragraph carried process instruction and self-classification; trimmed to the facts,
  with the unit added as a third unresolved item.
- Five passages carrying rejected-alternative rationale (SSO placement, `userData`, uniform delay, `dry_run`,
  test-coverage boundary) trimmed to the decision.
- `have_enqueued_job(...).at(...)` compares scheduled times exactly (`rspec-rails-6.1.5/.../active_job.rb:167`)
  and no time-freezing helper is configured in `rails_helper.rb`; the delay assertion now allows five seconds.
- The queue-adapter `around` block was scoped to `SubscriptionEvent` and controller examples; creating an
  `Organization` fires `complete_setup_workers`, and `Discord::NotifyNewOrganizationJob` has no
  `Rails.env.test?` guard, unlike its Slack sibling. Now every new spec file.
- Record construction now directed through `spec/support/ai_credits_test_helpers.rb`, which no-ops
  `complete_setup_workers` per instance. There is no factory library in the bundle.
- Executed baseline run required before writing specs; `spec/examples.txt` names 60+ deleted files and 149
  failures and is not a baseline (pipeline rule 37).
- Which layer divides cents was unstated and the two test bullets pointed different ways. The client divides.
- 0-vs-nil for `conversionValue` was a stated rule with no assertion pinning the 0 half.
- `require 'googleauth'` — the gem is transitive (Gemfile declares only `google-api-client`), and both
  existing `Google::Auth` sites require it explicitly.

## Applied to REVIEW-FINDINGS.md only

- Discrepancy 6 — currency citation corrected.
- R9 — blast radius was wrong in the direction that overstates risk. No live paid conversion can carry 0:
  `CreateSubscriptionEventFromStripe:14` returns when `amount_paid.to_i <= 0`. The zeros sit only on backfill
  rows under the two retroactive-only keys, which are never forwarded. Retitled to the real exposure.
- D5 — extended from two unresolved AdRoll items to three (the unit), plus which event names carry a value.
- New Q3 — does `architecture.md` rule 2's PostHog exception cover the three advertising destinations.
- New Q4 — a yearly subscription sends a full year's payment as one conversion value.
- New D12 — the magic-link invite gate diverges from the unconditional PostHog call at the same site.
- New D13 — `SendGoogleAdsConversionJob` gains an optional organization id parameter.
