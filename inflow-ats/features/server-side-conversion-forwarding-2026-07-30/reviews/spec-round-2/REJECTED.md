# Spec review round 2 — findings not applied

No finding in this round was factually wrong about the codebase. Six were not applied because a competing
finding named the same defect and proposed a resolution the codebase supports better, or because the proposed
fix went beyond what the defect required. Each is recorded with the file:line evidence that decided it.

## 1. "Write the owner-then-organization gclid preference inline in the job" — fix direction not taken

**Findings:** the two `SendGoogleAdsConversionJob` gclid findings whose fix reads "through the same
owner-then-organization comparison written inline against the found organization when an organization id was
given" / "the same owner-then-organization if/elsif written inline".

**The defect they name is real and was fixed** — SPEC.md stated the resolution three incompatible ways. It was
fixed in the other direction: `ownerCreatedOrganization` reads `user.google_click_id` directly, with no
organization fallback.

**Evidence for the other direction:** `app/controllers/api/v1/organizations_controller.rb:43` —
`@organization.google_click_id = current_user.google_click_id` — sits inside the unconditional attribution
block at lines 32-44, before `@organization.save` at line 48. A newly created organization therefore cannot
hold a `google_click_id` the user does not already hold, so the fallback branch is unreachable in production
and the assertion "the organization's when only it does" can only be produced by hand-writing a state the
application never creates.

Writing the preference inline in the job would also duplicate `SubscriptionEvent#attribution_value`
(`app/models/subscription_event.rb:126-134`) into a second location, which is the kind of shared logic the
no-abstraction constraint is meant to keep in one place, and would put value-selection logic in a job where
`cursor_rules/backend/background_jobs.md` rule 3 puts it in a model or service.

SPEC.md now states explicitly that `attribution_value` is not copied, wrapped, moved or reimplemented.

## 2. "Pass an explicit positional `nil` in the organization id slot" — fix direction not taken

**Findings:** the two `SendGoogleAdsConversionJob` argument findings whose fix keeps four positional
parameters and directs callers to pass `nil` in the third slot.

**The defect they name is real and was fixed** — with keyword arguments instead.

**Evidence:** `grep -rn "def perform(.*:" app/jobs/` returns seven jobs with keyword `perform` signatures,
including `app/jobs/engagement_report/generator_job.rb:6` (`def perform(organization_id, trigger:,
new_plan_lookup_key: nil)`, a required positional mixed with required and optional keywords) and
`app/jobs/job_application_notifications/destroy_notifications_job.rb:6` (all-optional keywords). That job is
already enqueued with keyword arguments through `perform_later` at `app/models/organization.rb:1057`. One of
the two findings concedes the point directly: `perform_later(.*, nil` returns zero hits across `app/`, so the
explicit-positional-nil form the alternative fix requires appears nowhere in this codebase.

Keyword arguments make the defect unexpressible rather than merely documented, which is the smaller change to
get wrong.

## 3. `require 'oj'` on all three service files — narrowed to one

**Finding:** the JSON-encoding finding whose fix appends "The file opens with `# frozen_string_literal: true`
and `require 'oj'`" to the `ga4_measurement_protocol.rb` and `adroll_s2s_api.rb` rows as well.

**Applied only to `google_data_manager_api.rb`.** `Oj` is needed to read a response body. Google Ads is the
only destination whose response body is read: SPEC.md parses `requestId` and `fieldWarnings` out of it. GA4's
client writes the raw response body to the log on a non-2xx and parses nothing; AdRoll's client raises
`ApiError` carrying the raw body and parses nothing — AdRoll publishes no response contract at all
(`ADROLL-S2S-CREDENTIALS.md` §2). Requiring a parser in two files that never parse is scaffolding.

## 4. Keeping the `instance_double(Faraday::Connection)` and asserting the connection separately

**Finding:** the services.md-angle finding whose fix keeps the `instance_double` for `post` arguments and adds
a second assertion path that calls the real private `client` on an unstubbed instance to read its `params` and
`headers`.

**Not applied — the BLOCKER's single-mechanism fix was taken instead.** Both are workable; the two-path version
requires every service spec to construct two client instances per behaviour and to reason about which one
carries which assertion, and it leaves the `post`-argument path blind to the connection that actually issued
the request. `allow_any_instance_of(Faraday::Connection).to receive(:post)` with a block captures the real
connection and the `post` arguments in one place, and the real connection is still fully built, so
`url_prefix`, `params` and `headers` are all observable. Verified:
`rspec-mocks-3.13.7/lib/rspec/mocks/configuration.rb:7` sets
`@yield_receiver_to_any_instance_implementation_blocks = true` by default, and `spec/spec_helper.rb` does not
override it.

## 5. Asserting the GA4 `Content-Type` header

**Finding:** the GA4 service spec bullet originally required asserting the `Content-Type` header, and no
finding removed it.

**Removed as a consequence of B1/H11.** `Content-Type: application/json` is set by
`FaradayMiddleware::EncodeJson` on the request env
(`faraday_middleware-0.14.0/lib/faraday_middleware/request/encode_json.rb:33-35`), not on the connection's
`headers`, so it is not observable from the captured connection and there is no line of ours to delete that
would falsify it. SPEC.md's own rule against unfalsifiable assertions applies. The Google Ads `Authorization`
and `x-goog-user-project` assertions are unaffected — those are connection headers.

## 6. Restating the `page_location` licence in the Failure behavior section

**Finding:** the core_critical_rules finding's fix text for the Failure behavior opening enumerates the three
constants and adds "they are not removed", which was applied; a second finding additionally proposed
repeating the AdRoll `page_location` justification in that section.

**Not applied.** SPEC.md's form rule states each fact once, in the section that owns it. The AdRoll payload
table owns `page_location`'s source and its justification; the Failure behavior section names it only as one
of the three sanctioned constants.
