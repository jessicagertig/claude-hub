# Backend PostHog Integration — Full Trace

Repo: `/Users/jessica/wrk/wrk-corp/inflow-ats` · branch `ai-credit-posthog-events` (HEAD `3af005159` "Track AI credit purchases in PostHog")

---

## 1. File chain traced

**Client construction**
```
config/application.rb:82 (config.x.RailsCredentialsEnv)
  → config/initializers/01_variables.rb:35-36 (Variables::POSTHOG_API_KEY, Variables::POSTHOG_HOST)
    → config/initializers/posthog.rb:5-11 (POSTHOG_CLIENT)
      → [gem] posthog-ruby-2.11.0/lib/posthog/client.rb:31-66 (#initialize), :104-114 (#capture), :122-125 (#identify), :136-139 (#group_identify)
        → [gem] posthog-ruby-2.11.0/lib/posthog/field_parser.rb:15-41 (parse_for_capture), :46-62 (parse_for_identify), :64-88 (parse_for_group_identify), :122-153 (parse_common_fields)
```

**Job/service layer**
```
app/jobs/application_job.rb
  → app/jobs/posthog_track_job.rb → app/services/posthog/track.rb → POSTHOG_CLIENT.capture
  → app/jobs/posthog_identify_job.rb → app/services/posthog/identify.rb → POSTHOG_CLIENT.identify
  → app/jobs/track_new_sso_owner_signup_job.rb → POSTHOG_CLIENT.capture  (direct; bypasses Posthog::Track)
```

**Direct call sites**
```
app/controllers/api/v1/sessions_controller.rb:10-11
app/controllers/magic_links_controller.rb:23-24
app/controllers/auth/invites_controller.rb:49-50, :79-84
app/controllers/api/v1/registrations_controller.rb:51-57, :212-216
app/controllers/api/v1/users/omniauth_callbacks_controller.rb:43-48 → app/models/user.rb:379-424 (from_omniauth), :495-511 (attribution_properties)
app/controllers/api/v1/billing_controller.rb:115, :213, :311
app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:76
app/services/email_processor.rb:83-87
```

**Indirect (model `after_commit`) call sites and their upstream producers**
```
app/models/subscription_event.rb:26 (after_commit :handle_after_commit_on_create) :31-62 → PosthogTrackJob
  ← app/interactors/create_subscription_event.rb:37-46
      ← app/models/organization.rb:1131 (trial_started), :1236-1240 (log_assigned_free_plan_event)
  ← app/interactors/create_subscription_event_from_stripe.rb:50-59
      ← app/jobs/stripe_webhook_handler_job.rb:215-218 (customer.subscription.deleted), :313-316 (invoice.paid)
  ← db/data/20260727185945_create_subscription_events_for_existing_paid_organizations.rb:37-45 (backfill)

app/models/organization_ai_credit_purchase.rb:71 (after_commit :handle_after_commit_on_update) :73-93 → PosthogTrackJob
  ← app/jobs/stripe_webhook_handler_job.rb:290 (finalize_stripe_payment), :505-509, :135-142, :192-195
  ← app/interactors/apply_ai_credit_subscription.rb:54-62
  ← app/interactors/apply_ai_credit_upgrade.rb:68-73
  ← app/interactors/apply_ai_credit_refund.rb:36-42
  ← app/services/sync_ai_credit_purchases_with_stripe.rb:105-107
  ← app/models/organization_ai_credit_purchase.rb:307 (sync_one_off_with_stripe)
```

**Supporting model definitions read**
```
app/models/user.rb (organization:206-208, attribution_properties:495-511, current_organization_user:38)
app/models/organization.rb (belongs_to :owner:41, enum plan:94-117)
app/models/organization_user.rb (enum role:39-45)
```

**Frontend (shares the same credential, separate SDK)**
```
app/views/layouts/application.html.erb:78-79 → app/javascript/shared/PostHogContext.tsx → app/javascript/shared/lib/posthog.ts
```

---

## 2. Client instantiation and configuration

`config/initializers/posthog.rb` (entire file):

```ruby
require 'posthog-ruby'

POSTHOG_CLIENT = if Variables::POSTHOG_API_KEY.present?
  PostHog::Client.new(
    api_key: Variables::POSTHOG_API_KEY,
    host: Variables::POSTHOG_HOST,
    on_error: proc { |_status, msg| Rails.logger.error("[PostHog] #{msg}") }
  )
end
```

A single global constant `POSTHOG_CLIENT`, **nil when the API key is blank** — every consumer guards with `return unless POSTHOG_CLIENT`.

Variables registry entries (`config/initializers/01_variables.rb:35-36`) — the two exact constant names:

```ruby
POSTHOG_API_KEY = ENV['POSTHOG_API_KEY'] || Rails.application.credentials.dig(Rails.configuration.x.RailsCredentialsEnv, :posthog, :api_key)
POSTHOG_HOST = ENV['POSTHOG_HOST'] || 'https://us.i.posthog.com'
```

`Rails.configuration.x.RailsCredentialsEnv` is `config/application.rb:82`: `Rails.env.test? ? :development : Rails.env.to_sym`.

Not configured: `personal_api_key`, `test_mode`, `before_send`, feature-flag polling. Gem: `posthog-ruby (2.11.0)` (`Gemfile:122` declares `'~> 2.0'`, `Gemfile.lock:371` resolves 2.11.0).

Initializer load order is alphabetical, so `01_variables.rb` precedes `posthog.rb`.

---

## 3. Exact signatures

**`app/jobs/posthog_track_job.rb`** (entire file):
```ruby
class PosthogTrackJob < ApplicationJob
  queue_as :default

  def perform(user_id, event, properties = {})
    user = User.find_by(id: user_id)
    return unless user

    Posthog::Track.new(user: user, event: event, properties: properties.deep_symbolize_keys).track
  end
end
```

**`app/jobs/posthog_identify_job.rb`** (entire file):
```ruby
class PosthogIdentifyJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    Posthog::Identify.new(user: user).identify
  end
end
```

**`app/jobs/track_new_sso_owner_signup_job.rb:6`** and its private helper `:23`:
```ruby
  def perform(user_id, base_timestamp)
...
  def capture(user, event, timestamp, extra_properties = {})
    POSTHOG_CLIENT.capture({
                             distinct_id: user.id.to_s,
                             event: event,
                             properties: { email: user.email }.merge(extra_properties),
                             timestamp: timestamp
                           })
  end
```

**`app/services/posthog/track.rb:4`** and `:13-17`:
```ruby
  def initialize(user:, event:, properties: {})
...
    POSTHOG_CLIENT.capture({
                             distinct_id: @user.id.to_s,
                             event: @event,
                             properties: default_properties.merge(@properties)
                           })
```
`default_properties` (`:24-31`):
```ruby
    {
      email: @user.email,
      organization_id: @user.organization&.id,
      organization_name: @user.organization&.name,
      plan: @user.organization&.plan
    }
```

**`app/services/posthog/identify.rb:4`** and `:11-21`:
```ruby
  def initialize(user:)
...
    POSTHOG_CLIENT.identify({
                              distinct_id: @user.id.to_s,
                              properties: {
                                email: @user.email,
                                created_at: @user.created_at&.iso8601,
                                organization_id: @user.organization&.id,
                                organization_name: @user.organization&.name,
                                plan: @user.organization&.plan,
                                organization_user_role: @user.current_organization_user&.role
                              }
                            })
```

Note the shape constraint: `Posthog::Track` builds the capture hash inline with only `distinct_id`, `event`, `properties`. `PosthogTrackJob`'s third positional argument lands in `properties` — **there is no parameter today by which a caller can reach the gem's `groups:` key.**

---

## 4. Every call site

### Direct `perform_later` sites

| file:line | job | event name | distinct_id source | properties passed at the call site |
|---|---|---|---|---|
| `app/controllers/api/v1/sessions_controller.rb:10` | PosthogIdentifyJob | `$identify` | `user.id` (Devise `create` block arg) | — |
| `app/controllers/api/v1/sessions_controller.rb:11` | PosthogTrackJob | `user_logged_in` | `user.id` | none (defaults only) |
| `app/controllers/magic_links_controller.rb:23` | PosthogIdentifyJob | `$identify` | `@magic_link.user.id` | — |
| `app/controllers/magic_links_controller.rb:24` | PosthogTrackJob | `user_logged_in` | `@magic_link.user.id` | `{ method: 'magic_link' }` |
| `app/controllers/auth/invites_controller.rb:49` | PosthogIdentifyJob | `$identify` | `invite.recipient.id` | — |
| `app/controllers/auth/invites_controller.rb:50` | PosthogTrackJob | `user_logged_in` | `invite.recipient.id` | `{ method: 'invite' }` |
| `app/controllers/auth/invites_controller.rb:79` | PosthogIdentifyJob | `$identify` | `resource.id` (new user) | — |
| `app/controllers/auth/invites_controller.rb:83` | PosthogTrackJob | `user_signed_up` | `resource.id` | `attribution_properties.merge(method: 'invite', '$set_once' => attribution_properties)` |
| `app/controllers/auth/invites_controller.rb:84` | PosthogTrackJob | `invited_user_signed_up` | `resource.id` | `{ method: 'invite', '$set_once' => { originally_signed_up_as_owner: false } }` |
| `app/controllers/api/v1/registrations_controller.rb:51` | PosthogIdentifyJob | `$identify` | `resource.id` | — |
| `app/controllers/api/v1/registrations_controller.rb:55` | PosthogTrackJob | `user_signed_up` | `resource.id` | `attribution_properties.merge(method: 'email', '$set_once' => attribution_properties)` |
| `app/controllers/api/v1/registrations_controller.rb:56` | PosthogTrackJob | `invited_user_signed_up` | `resource.id` | `{ method: 'invite', '$set_once' => { originally_signed_up_as_owner: false } }` — only `if @invite.present?` |
| `app/controllers/api/v1/registrations_controller.rb:57` | PosthogTrackJob | `organization_owner_signed_up` | `resource.id` | `attribution_properties.merge(method: 'email', '$set_once' => { originally_signed_up_as_owner: true })` — only `if @invite.nil?` |
| `app/controllers/api/v1/registrations_controller.rb:212` | PosthogIdentifyJob | `$identify` | `resource.id` (magic_create) | — |
| `app/controllers/api/v1/registrations_controller.rb:215` | PosthogTrackJob | `user_signed_up` | `resource.id` | `attribution_properties.merge(method: 'magic_link', '$set_once' => attribution_properties)` |
| `app/controllers/api/v1/registrations_controller.rb:216` | PosthogTrackJob | `organization_owner_signed_up` | `resource.id` | `attribution_properties.merge(method: 'magic_link', '$set_once' => { originally_signed_up_as_owner: true })` |
| `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:43` | PosthogIdentifyJob | `$identify` | `user.id` | — |
| `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:45` | TrackNewSsoOwnerSignupJob | 4 events (below) | `user.id` | `(user.id, Time.current)` — fires only `if user.new_user_created_via_google_sso` |
| `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:47` | PosthogTrackJob | `user_logged_in` | `user.id` | `{ method: 'google_sso' }` — the `else` branch |
| `app/controllers/api/v1/billing_controller.rb:115` | PosthogTrackJob | `subscription_checkout_started` | `current_user.id` | `{ price_id: price_id, checkout_mode: checkout_mode }` |
| `app/controllers/api/v1/billing_controller.rb:213` | PosthogTrackJob | `paid_subscription_created` | `current_user.id` | `{ price_id: price_id, plan: current_organization.plan }` |
| `app/controllers/api/v1/billing_controller.rb:311` | PosthogTrackJob | `change_subscription_stripe_portal_opened` | `current_user.id` | `{ price_id: determine_price_id }` |
| `app/controllers/api/v1/organization_ai_credit_purchases_controller.rb:76` | PosthogTrackJob | `ai_credit_subscription_checkout_started` | `current_user.id` | `{ stripe_price_lookup_key: lookup_key, credits_per_period: credits_per_period }` |
| `app/services/email_processor.rb:83` | PosthogTrackJob | `candidate_message_received` | `tracking_user.id` (`channel_message.user`) | `{ organization_id: job_application.job&.organization_id, job_id: job_application.job_id, candidate_id: job_application.candidate_id }` |
| `app/models/subscription_event.rb:61` | PosthogTrackJob | the `event_type` string (see below) | `organization.owner.id` | `posthog_properties` + `$set` |
| `app/models/organization_ai_credit_purchase.rb:83` | PosthogTrackJob | `ai_credit_top_up_purchased` | `organization.owner.id` | `posthog_properties` |
| `app/models/organization_ai_credit_purchase.rb:91` | PosthogTrackJob | `paid_ai_credit_subscription_created` | `organization.owner.id` | `posthog_properties` |

### `TrackNewSsoOwnerSignupJob` — 4 captures, timestamps offset to force funnel ordering (`:13-16`)

```ruby
    capture(user, 'user_signed_up', base_timestamp, attribution_properties.merge(method: 'google_sso', '$set_once' => attribution_properties))
    capture(user, 'organization_owner_signed_up', base_timestamp + 0.001, attribution_properties.merge(method: 'google_sso', '$set_once' => { originally_signed_up_as_owner: true }))
    capture(user, 'organization_owner_email_verified', base_timestamp + 0.002)
    capture(user, 'organization_owner_user_name_submitted', base_timestamp + 0.003)
```
Its properties are `{ email: user.email }` merged with the extras only — it does **not** go through `Posthog::Track#default_properties`, so these four events carry **no `organization_id`, `organization_name`, or `plan`**.

### `SubscriptionEvent#handle_after_commit_on_create` (`app/models/subscription_event.rb:31-62`)

```ruby
    case event_type
    when 'trial_started'
      Discord::NotifyFreeTrialStartedJob.perform_later(organization_id)
      event_properties['$set'] = { is_trialing: true }
    when 'trial_converted_to_paid_subscription'
      Discord::NotifyTrialConvertedToPaidJob.perform_later(organization_id)
      event_properties['$set'] = { is_paying: true, is_trialing: false }
    when 'converted_to_paid_subscription'
      event_properties['$set'] = { is_paying: true, is_trialing: false }
    when 'canceled_subscription'
      if organization.subscription_canceled_at.present?
        Discord::NotifySubscriptionDeletedJob.perform_later(organization_id, organization.subscription_canceled_at.to_i)
      end
      event_properties['$set'] = { is_paying: false, is_trialing: false }
    when 'upgraded_plan'
      ap 'Upgraded plan: no $set'
    else
      return
    end

    PosthogTrackJob.perform_later(organization.owner.id, event_type, event_properties)
```

So exactly **5** of the 12 `event_type` enum values reach PostHog: `trial_started`, `trial_converted_to_paid_subscription`, `converted_to_paid_subscription`, `canceled_subscription`, `upgraded_plan`. The `else → return` swallows `pending`, `assigned_free_plan_on_creation`, `assigned_free_plan`, `converted_to_paid`, `downgraded_to_free`, `downgraded_plan`, `trial_converted_to_paid` — note this contradicts the enum comments at `:9` and `:15` ("Retroactive only — created by the backfill **and sent to PostHog**"); those two values hit the `else` and send nothing.

`posthog_properties` (`:101-124`) — `amount` (dollars, `amount.to_i / 100.0`), `stripe_subscription_id`, `stripe_customer_id`, `from_plan`, `to_plan`, `billing_interval`, plus 13 attribution fields resolved owner-first-then-organization via `attribution_value` (`:126-134`), all `.compact`ed.

### `OrganizationAiCreditPurchase#handle_after_commit_on_update` (`app/models/organization_ai_credit_purchase.rb:73-93`)

One-off branch fires `ai_credit_top_up_purchased` only on the `stripe_invoice_paid` blank→true transition; subscription branch fires `paid_ai_credit_subscription_created` only on the `subscription_status` **nil→active** transition. Consequences: the refund path (`apply_ai_credit_refund.rb:39`, `canceled`) and the drift-sync path (`sync_ai_credit_purchases_with_stripe.rb:87`) never fire; and `sync_subscription_invoice_grant` (`organization_ai_credit_purchase.rb:262`) uses `update_columns(stripe_invoice_id:, stripe_invoice_paid: true)`, which skips callbacks entirely — a webhook-outage backfill grants credits with no PostHog event.

`posthog_properties` (`:95-106`): `amount` (dollars), `currency`, `stripe_price_lookup_key`, `stripe_subscription_id`, `stripe_invoice_id`, `stripe_customer_id`, `credits`, `credits_per_period`, `.compact`ed.

---

## 5. `groups:` and `group_identify` — definitive answer

**No, neither is used anywhere today — backend or frontend.**

A repo-wide grep for `group_identify`, `groups:`, `$groups`, `.group(` across `app/`, `config/`, `lib/`, `spec/` returns exactly four hits, none PostHog-related: `app/models/job_application_notification.rb:20` (ActiveRecord `.group(:job_id)`), `app/services/engagement_report/organization_analyzer.rb:68` (`.group("DATE_TRUNC…")`), `config/initializers/omniauth.rb:5` (Slack scope string `groups:write` in a comment), `lib/tasks/one_off_tasks.rake:1120` (`.group(:spam_score)`).

- `POSTHOG_CLIENT.group_identify` — **zero call sites**. The method exists at `posthog-ruby-2.11.0/lib/posthog/client.rb:136-139`, unused.
- `groups:` on `capture` — **never passed**. The only three capture call sites (`app/services/posthog/track.rb:13`, `app/jobs/track_new_sso_owner_signup_job.rb:24`, plus the gem's internal `$feature_flag_called` at `client.rb:239-250`, which is dead here because no feature-flag API is called) pass only `distinct_id`, `event`, `properties`, and — in the SSO job — `timestamp`.
- Frontend: `app/javascript/shared/lib/posthog.ts` exposes only `identifyUser`, `trackEvent`, `resetUser`; no `posthog.group(...)` anywhere in `app/javascript`.

For reference, the gem's contract if groups are added later — `field_parser.rb:25-28`:
```ruby
        if groups
          check_is_hash!(groups, 'groups')
          properties['$groups'] = groups
        end
```
and `parse_for_group_identify` (`:64-88`) requires `group_type` + `group_key`, defaulting `distinct_id` to `"$#{group_type}_#{group_key}"`.

---

## 6. What is used as `distinct_id`

**The `User` primary key, stringified.** Three places, identical:

- `app/services/posthog/track.rb:14` — `distinct_id: @user.id.to_s,`
- `app/services/posthog/identify.rb:12` — `distinct_id: @user.id.to_s,`
- `app/jobs/track_new_sso_owner_signup_job.rb:25` — `distinct_id: user.id.to_s,`

Not email, not `hash_id`, not a UUID. The frontend matches: `app/javascript/shared/lib/posthog.ts:32` — `ph.identify(String(user.id), {…})`.

For the two model-callback events the identity used is the **organization owner**, not the acting user: `organization.owner.id` (`subscription_event.rb:61`, `organization_ai_credit_purchase.rb:83` and `:91`), where `owner` is `belongs_to :owner, class_name: 'User'` (`app/models/organization.rb:41`). The controller sites use the acting `current_user`, so `ai_credit_subscription_checkout_started` and `paid_ai_credit_subscription_created` can land on two different distinct_ids for the same purchase.

---

## 7. Is `organization_id` already an event property?

**Yes — under the exact key `organization_id`, on every event that goes through `Posthog::Track`.**

- `app/services/posthog/track.rb:27` — `organization_id: @user.organization&.id,` in `default_properties`, merged into every capture at `:16` (`default_properties.merge(@properties)`). `User#organization` is `current_organization_user&.organization` (`app/models/user.rb:206-208`), so it is nil for a user with no current organization membership.
- `app/services/posthog/identify.rb:16` — `organization_id: @user.organization&.id,` as a **person** property on `$identify`.
- `app/services/email_processor.rb:86` — explicitly passes `organization_id: job_application.job&.organization_id` in the caller properties; since caller properties win the merge, this overrides the default for `candidate_message_received`.
- Frontend `app/javascript/shared/lib/posthog.ts:34` — `organization_id: user.organizationId` in `ph.identify`.

Alongside it, `organization_name` (`track.rb:28`, `identify.rb:17`) and `plan` (`track.rb:29`, `identify.rb:18`) are also already present. **Exception:** the four `TrackNewSsoOwnerSignupJob` events carry none of these — that job builds its own properties hash (`track_new_sso_owner_signup_job.rb:27`) and never touches `default_properties`.

---

## 8. Enqueue pattern, queue, retry, error handling

- **Queue:** all three jobs declare `queue_as :default` (`posthog_track_job.rb:4`, `posthog_identify_job.rb:4`, `track_new_sso_owner_signup_job.rb:4`). In `config/sidekiq.yml` `default` has weight 2 (behind `critical` at 6).
- **Base class:** `app/jobs/application_job.rb` is the entire file:
  ```ruby
  class ApplicationJob < ActiveJob::Base
  end
  ```
  No `retry_on`, no `discard_on`, no `rescue_from` — and none of the three PostHog jobs declares any either.
- **Adapter:** `:sidekiq` in development (`config/environments/development.rb:108`) and production (`config/environments/production.rb:109`); **`:inline` in test** (`config/environments/test.rb:64`), so any test hitting these paths executes the job synchronously. Sidekiq's own `:max_retries: 3` (`config/sidekiq.yml`).
- **Error handling is swallow-and-log, never re-raise**, so Sidekiq's retry effectively never engages on a PostHog failure:
  - `app/services/posthog/track.rb:18-20` — `rescue StandardError => e` / `Rails.logger.error("[PostHog] Track failed: #{e.message}")`
  - `app/services/posthog/identify.rb:22-24` — `rescue StandardError => e` / `Rails.logger.error("[PostHog] Identify failed: #{e.message}")`
  - `app/jobs/track_new_sso_owner_signup_job.rb:17-19` — method-level `rescue StandardError => e` / `Rails.logger.error("[PostHog] SSO owner signup funnel track failed: #{e.message}")` (this one wraps the whole `perform`, unlike the other two whose rescue lives in the service and does **not** cover `User.find_by` or `properties.deep_symbolize_keys` in the job body)
  - Client-level: `on_error: proc { |_status, msg| Rails.logger.error("[PostHog] #{msg}") }` (`config/initializers/posthog.rb:9`) handles async transport failures on the gem's worker thread.
- **Missing-user guard:** every job does `user = User.find_by(id: user_id); return unless user` — a deleted user silently drops the event rather than raising.
- **Nil-client guard:** `return unless POSTHOG_CLIENT` at `posthog/track.rb:11`, `posthog/identify.rb:9`, `track_new_sso_owner_signup_job.rb:9`. The client is nil whenever `Variables::POSTHOG_API_KEY` is blank.
- **Serialization note:** `PosthogTrackJob#perform` calls `properties.deep_symbolize_keys`, so the string keys `'$set'` / `'$set_once'` written at the call sites arrive as symbols and serialize to JSON as `$set` / `$set_once` as PostHog expects.

---

## 9. Test/spec coverage

**None.** Zero test or spec files reference PostHog in any form.

Verified: `grep -rli "posthog"` over `spec/`, `test/`, `cypress/`, and all `*_spec.rb` / `*_test.rb` / `*.cy.js` / `*.test.ts` / `*.test.tsx` files returns nothing. There is no `spec/jobs/` directory. The complete inventory of Ruby test files in the repo:

- `spec/requests/api_public/v1/hire/` — 13 request specs (candidates, comments_and_reviews, customer_jobs, html_sanitization, job_application_actions, job_applications_apply, job_applications_apply_files, job_applications_import, job_applications, job_resume_exports, organization, organization_users, shared_list_behaviors)
- `test/mailers/magic_link_mailer_test.rb`
- `test/models/` — 10 model tests (candidate_private_note, careers_page, careers_page_subscription, comment, comment_template, discord_channel_integration, magic_link, organization_user, slack_channel_integration, support_message)

None of these touch `PosthogTrackJob`, `PosthogIdentifyJob`, `TrackNewSsoOwnerSignupJob`, `Posthog::Track`, `Posthog::Identify`, `POSTHOG_CLIENT`, or either of the two `after_commit` callbacks that enqueue PostHog jobs.