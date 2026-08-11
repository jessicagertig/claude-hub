# Organization Model Inventory — inflow-ats @ `ai-credit-posthog-events`

## 1. Full file chain traced

```
app/models/organization.rb
  → db/schema.rb (organizations, organization_users, jobs, job_applications, candidates,
                  organization_ai_credit_balances, organization_ai_credit_purchases,
                  subscription_events, users, careers_pages)
  → app/models/organization_user.rb          (counter_culture users_count)
  → app/models/user.rb                       (User#organization, attribution_properties, from_omniauth)
  → app/models/concerns/created_via_able.rb  (created_via enum, shared Org/User)
  → app/services/plan_feature_gate.rb        (user_limit / job_limit / credit allocation per plan)
  → app/services/stripe/subscription_status_checker.rb (PAID_PLANS, in_good_standing?)
  → app/models/subscription_event.rb
      → app/interactors/create_subscription_event.rb
      → app/interactors/create_subscription_event_from_stripe.rb
      → app/jobs/posthog_track_job.rb → app/services/posthog/track.rb
  → app/jobs/posthog_identify_job.rb → app/services/posthog/identify.rb
  → app/jobs/track_new_sso_owner_signup_job.rb
  → config/initializers/posthog.rb (POSTHOG_CLIENT)
  → app/models/organization_ai_credit_purchase.rb (posthog_properties)
  → app/jobs/stripe_webhook_handler_job.rb   (main writer of subscription columns)
  → app/jobs/org_setup_job.rb                (completed_setup)
  → app/services/engagement_report/report_generator.rb (existing org attribute snapshot)
  → app/services/bad_actor_organization_takeover.rb

Serializers:
  app/serializers/base_serializer.rb
  app/serializers/api/v1/organization_serializer.rb
  app/serializers/api/v1/shallow_organization_serializer.rb
  app/serializers/api/v1/mini_organization_serializer.rb
  app/serializers/api/v1/admin_organization_serializer.rb
  app/serializers/api/v1/admin_organization_shallow_serializer.rb
  app/serializers/api/v1/organization_user_serializer.rb      (embeds MiniOrganizationSerializer)
  app/serializers/api/v1/session_serializer.rb                (organization_id)
  app/serializers/api_public/v1/hire/organization_serializer.rb

Creation paths:
  app/controllers/api/v1/organizations_controller.rb
  app/controllers/api/v1/admin/organizations_controller.rb
  app/controllers/api/v1/public/unregistered_job_controller.rb
  app/controllers/api_public/v1/hire/unregistered_job_controller.rb
  app/site_scrapers/boards_scraper.rb
  db/seeds.rb
  spec/support/api_factories.rb, spec/support/ai_credits_test_helpers.rb

Identifier/URL chain:
  config/routes.rb:144, :347, :391, :483, :505
  app/javascript/shared/queryHooks/useOrganization.ts
  app/javascript/shared/queryHooks/jobBoard/useJobBoard.ts
  app/controllers/api/v1/public/jobs_controller.rb
  app/controllers/api/v1/base_controller.rb (current_organization)
  app/javascript/ats/src/views/layouts/AppAuthRouter.tsx
  app/javascript/shared/PostHogContext.tsx → app/javascript/shared/lib/posthog.ts
```

---

## 2. Every column on `organizations`, quoted from `db/schema.rb:1033-1101`

`create_table "organizations", force: :cascade do |t|` — bigint PK `id`, implicit, `NOT NULL`. Every column below is nullable unless the line says `null: false`.

```ruby
t.string   "name"
t.string   "logo"
t.string   "description"
t.integer  "owner_id"
t.boolean  "completed_setup", default: false
t.jsonb    "settings", default: {}, null: false
t.integer  "users_count", default: 0
t.datetime "created_at", null: false
t.datetime "updated_at", null: false
t.string   "website_url"
t.boolean  "is_scrapable", default: false
t.boolean  "is_claimed", default: false
t.string   "thirdparty_jobboard_url"
t.string   "scraped_from_url"
t.string   "clearbit_logo_url"
t.string   "clearbit_website_url"
t.integer  "scraper_type", default: 0
t.string   "thirdparty_ats_identifier"
t.string   "twitter_handle"
t.boolean  "is_manually_verified", default: false
t.integer  "kind", default: 0
t.integer  "plan", default: 101
t.integer  "jobs_count", default: 0
t.integer  "remoteness", default: 0
t.string   "stripe_customer_id"
t.string   "stripe_subscription_id"
t.string   "stripe_checkout_session_id"
t.datetime "stripe_current_period_end_at"
t.datetime "subscription_canceled_at"
t.string   "public_logo_url"
t.string   "logo_blob_key"
t.string   "wwr_company_statement"
t.text     "wwr_company_bio"
t.integer  "created_via", default: 0
t.string   "stripe_subscription_status"
t.boolean  "stripe_default_payment_method_on_file", default: false
t.integer  "published_jobs_count", default: 0
t.string   "stripe_promo_code"
t.integer  "flipper_group", default: 0
t.uuid     "zapier_api_key"
t.integer  "connect_users_count", default: 0, null: false
t.boolean  "can_send_bulk_messages", default: false
t.datetime "linkedin_basic_jobs_changed_at"
t.bigint   "linkedin_company_id"
t.string   "google_click_id"
t.datetime "x_hiring_changed_at"
t.boolean  "enable_x_hiring", default: false
t.text     "heard_about_us_from"
t.boolean  "can_enable_linkedin", default: false
t.integer  "fraud_rating", default: 0, null: false
t.integer  "partner_source"
t.boolean  "white_label_job_board_enabled", default: false, null: false
t.integer  "hud_display_visibility", default: 0, null: false
t.boolean  "stripe_cancel_at_period_end", default: false, null: false
t.boolean  "free_plan_paid_features_enabled", default: false, null: false
t.string   "utm_source"
t.string   "utm_campaign"
t.jsonb    "utm_data"
t.string   "internal_ref"
t.string   "adroll_click_id"
t.string   "adroll_first_party_cookie"
t.string   "ga_client_id"
t.string   "ga_session_id"
t.string   "fbclid"
t.string   "fbp"
t.string   "fbc"
t.string   "li_fat_id"
```

Notable: the table declares **no indexes at all** and appears in no `add_foreign_key` line as the child side. `NOT NULL` columns: `settings`, `created_at`, `updated_at`, `connect_users_count`, `fraud_rating`, `white_label_job_board_enabled`, `hud_display_visibility`, `stripe_cancel_at_period_end`, `free_plan_paid_features_enabled`.

---

## 3. UUID / slug / primary key — what identifies an Organization

**There is no `hash_id`, no `slug`, and no public UUID on `organizations`.** The only `uuid` column is `zapier_api_key` (`db/schema.rb:1073`), which is a secret API credential, not an identifier — it is looked up in `app/controllers/api/v1/integrations/zapier_integrations_controller.rb:41`:

```ruby
@organization = Organization.find_by(zapier_api_key: api_key)
```

`Organization` does **not** include the `Friendlyable` concern that gives other models a `hash_id` (`app/models/user.rb:5` and `app/models/organization_user.rb:4` do include it; `app/models/organization.rb:4` has FriendlyId commented out: `# extend FriendlyId`). Because of that, none of the Organization serializers inherit `BaseSerializer` (whose `id` returns `object.hash_id`, `app/serializers/base_serializer.rb:5-7`) — they all inherit `ActiveModel::Serializer` directly, so `:id` is the raw integer PK.

**In API payloads today: the integer PK.** `app/serializers/api/v1/organization_serializer.rb:4` and `:68-70`:

```ruby
attributes :id, :organization_id, :owner_id, :name, ...

def organization_id
  object.id
end
```

`app/serializers/api/v1/session_serializer.rb:54-56`:

```ruby
def organization_id
  object&.current_organization_user&.organization_id
end
```

**In authenticated app URLs: the integer PK** — `app/javascript/shared/queryHooks/useOrganization.ts:11,32,43,65`:

```ts
path: `/organizations/${id}`,
```

…though the server ignores it. `app/controllers/api/v1/organizations_controller.rb:122-124`:

```ruby
def set_organization
  @organization = current_user.organization
end
```

and `app/controllers/api/v1/base_controller.rb:24-26`:

```ruby
def current_organization
  @current_organization ||= current_user.organization
end
```

**In public/careers-page URLs: the `careers_pages.slug`, not an organization identifier.** `app/javascript/shared/queryHooks/jobBoard/useJobBoard.ts:6` sends `organizationSlug`, and `app/controllers/api/v1/public/jobs_controller.rb:14` resolves it:

```ruby
exists(CareersPage.where(slug: params[:organization_id]), 'no careers_page found') do |careers_page|
```

`careers_pages.slug` is `null: false` with a unique index (`db/schema.rb:385, 415`), and `Organization#careers_page_slug` (`app/models/organization.rb:1383-1385`) delegates to it. It is one-per-org in practice (`default_careers_page` = `careers_pages.first`, `organization.rb:1375-1377`) but the association is `has_many`, so it is not guaranteed unique-per-org by schema.

**Group-key conclusion:** the only stable, guaranteed-unique, non-null organization identifier is `organizations.id` (integer PK). It is already what both the server-side and browser-side PostHog identify calls send as `organization_id` (see §7).

---

## 4. Plan / subscription state

### Column `plan` (integer, default `101`) — enum, `app/models/organization.rb:94-117`

```ruby
enum plan: {
  plan_no_plan: 101, # Default value on organization creation (no associated Stripe subscription)
  plan_simple_ats_free: 10, # Original value for our "free" cutomers, set during complete organization setup, legacy value (had no associated Stripe subscription)
  # Legacy plans (10-19)
  plan_simple_ats_paid: 11, # Paid, Can do all ATS things (orginal unlimited jobs plan)
  plan_simple_ats_per_job: 12, # Paid Per Job (original per job plan)

  # Legacy ATS tiers (20-29)
  plan_ats_tier_apollo: 21, # Paid, Apollo ATS. UInlimited users, unlimited jobs, no gates except possibly on new features

  # Legacy gated ATS tiers v1 (29-39) --> Unlimited Users
  plan_ats_tier_free: 29, # Free version of gated plans "v1", now treating it as equivalent to v2
  plan_ats_tier_starter: 30, # --> limit of 5 jobs
  plan_ats_tier_growth: 31, # --> limit of 20 jobs
  plan_ats_tier_scale: 32, # --> limit of 50 jobs
  # Current ATS tiers v2 (40-49) --> Most features NOT gated, limited jobs, limited users
  plan_ats_tier_free_v2: 40, # Free version, messages & LinkedIn gated, 1 job and 1 user
  plan_ats_tier_starter_v2: 41, # 5 jobs and 10 Users
  plan_ats_tier_growth_v2: 42, # 20 jobs and 20 Users
  plan_ats_tier_scale_v2: 43, # 50 jobs and 50 Users

  # Enterprise (1000+) - "Contact us" plan for custom deals
  plan_ats_tier_enterprise: 1000
}
```

### Column `stripe_subscription_status` (string, free-form, mirrors Stripe)

Not an enum. Written verbatim from Stripe. The values the code branches on, `app/services/stripe/subscription_status_checker.rb:110`:

```ruby
['trialing', 'active', 'incomplete', 'past_due', 'unpaid'].include?(@organization.stripe_subscription_status)
```

plus `'canceled'` and `'paused'` (`subscription_status_checker.rb:100-101`), and `nil` for orgs that never had a subscription.

### Derived plan predicates (all delegate to `Stripe::SubscriptionStatusChecker`)

`app/models/organization.rb:678-718`:

```ruby
def stripe_subscription_in_good_standing
  Stripe::SubscriptionStatusChecker.new(self).in_good_standing?
end
alias active_plan? stripe_subscription_in_good_standing
...
def paid_plan?
  Stripe::SubscriptionStatusChecker.new(self).paid_plan?
end

def active_paid_plan?
  paid_plan? && stripe_subscription_in_good_standing
end
```

`PAID_PLANS` (`subscription_status_checker.rb:50-61`): `plan_simple_ats_paid, plan_simple_ats_per_job, plan_ats_tier_apollo, plan_ats_tier_starter, plan_ats_tier_growth, plan_ats_tier_scale, plan_ats_tier_starter_v2, plan_ats_tier_growth_v2, plan_ats_tier_scale_v2, plan_ats_tier_enterprise`.
`FREE_PLANS_WITH_ONE_JOB` (`:63-66`): `plan_ats_tier_free, plan_ats_tier_free_v2`.

### Other subscription columns

`stripe_customer_id`, `stripe_subscription_id`, `stripe_checkout_session_id`, `stripe_current_period_end_at`, `stripe_cancel_at_period_end` (`null: false`, default `false`), `stripe_default_payment_method_on_file` (default `false`), `stripe_promo_code`, `subscription_canceled_at`, `free_plan_paid_features_enabled` (`null: false`, default `false`).

### AI-credit subscription state (separate models, not columns on `organizations`)

- `has_one :organization_ai_credit_balance, dependent: :restrict_with_error` (`organization.rb:28`)
- `has_many :organization_ai_credit_purchases, dependent: :restrict_with_error` (`organization.rb:31`)
- `app/models/organization.rb:1005-1007`:

```ruby
def active_ai_credit_subscription
  organization_ai_credit_purchases.subscription.where(subscription_status: :active).first
end
```

- Balance helpers (`organization.rb:977-999`): `daily_ai_credits_remaining`, `monthly_ai_credits_remaining`, `addon_subscription_ai_credits_remaining`, `addon_ai_credits_remaining`, `total_ai_credits_remaining`, `ai_credits_available?`.

### Other enums on the model

`fraud_rating` (`:63-69`, `_prefix: true`): `none: 0, low: 100, medium: 200, high: 300, definite: 1000`.
`scraper_type` (`:71-78`), `kind` (`:80-85`: `kind_claimed: 0, kind_wrk_managed: 1, kind_scrapable: 2`), `remoteness` (`:87-92`), `flipper_group` (`:119-122`), `partner_source` (`:124-127`, `_prefix: true`: `none: 0, wwr: 1`), `hud_display_visibility` (`:129-133`, `_prefix: :hud`), and `created_via` from `CreatedViaAble` (`app/models/concerns/created_via_able.rb:7-15`): `created_via_signup: 0, created_via_invite: 1, created_via_god_admin: 2, created_via_unregistered_job: 3, created_via_weworkremotely_referral: 4, created_via_connect_registration: 5, created_via_connect_invite: 6, created_via_product_hunt_ad: 7`.

---

## 5. Seat count / user count

**Denormalized column `users_count`, maintained by `counter_culture` on `OrganizationUser` — `app/models/organization_user.rb:9`:**

```ruby
counter_culture :organization, column_name: 'users_count'
```

It counts **all** `organization_users` rows, including discarded and inactive ones — there is no conditional `column_name` proc, unlike the job counters. It is exposed only via `Api::V1::MiniOrganizationSerializer` (`app/serializers/api/v1/mini_organization_serializer.rb:10`), which is embedded in `Api::V1::OrganizationUserSerializer:16`.

Live-count associations available instead:

- `app/models/organization.rb:9-10`: `has_many :organization_users, dependent: :destroy` / `has_many :users, through: :organization_users`
- Non-discarded org_users, used by the main serializer (`organization_serializer.rb:76-78`): `object.organization_users.kept.includes([:user]).order(created_at: :asc)`
- Admins only (`organization.rb:899-902`):

```ruby
def all_admins
  organization_users.actives.where(role: [:org_owner, :org_admin, :god_admin])
end
```

**Seat limit** is not a column — it comes from the plan: `app/models/organization.rb` has no `user_limit` wrapper, but `PlanFeatureGate#user_limit` (`app/services/plan_feature_gate.rb:43-45`) does:

```ruby
def user_limit
  plan_rules[@plan]&.dig(:user_limit) || 1
end
```

Per-plan values (`plan_feature_gate.rb:142-245`): `plan_no_plan` 1, `plan_simple_ats_free` 1, `plan_ats_tier_free` 10_000, `plan_ats_tier_starter/growth/scale` 10_000, `plan_ats_tier_free_v2` 1, `plan_ats_tier_starter_v2` 5, `plan_ats_tier_growth_v2` 15, `plan_ats_tier_scale_v2` 10_000, `plan_ats_tier_enterprise` 10_000, legacy plans 10_000. Note `PlanFeatureGate#initialize` (`:25-28`) downgrades `@plan` to `'plan_no_plan'` when the subscription is not in good standing.

### Job / application counts

- `jobs_count` — Rails `counter_cache`, `app/models/job.rb:26`: `belongs_to :organization, counter_cache: true, inverse_of: :jobs`
- `published_jobs_count` — `counter_culture`, `app/models/job.rb:29`:

```ruby
counter_culture :organization, column_name: proc { |model| model.published? ? 'published_jobs_count' : nil }, column_names: { ['jobs.status = ?', 1] => 'published_jobs_count' }
```

- Live-query counts, `app/models/organization.rb:1395-1429`: `hidden_jobs_count`, `archived_jobs_count`, `draft_jobs_count`, `published_jobs?`, `has_ever_published_job?`, `first_published_job`, `first_published_job_applications_count`.
- **There is no `job_applications_count` or `candidates_count` column on `organizations`.** Only the associations `has_many :job_applications, through: :jobs` (`organization.rb:16`) and `has_many :candidates` (`:12`) — counting them is a live query across `jobs`.
- `connect_users_count` (`null: false`, default 0) has **no writer anywhere in `app/` or `lib/`** — a dead counter column.

---

## 6. Trial state

There is **no trial column** on `organizations`. Trial is entirely derived from `stripe_subscription_status == 'trialing'`.

`app/models/organization.rb:1188-1204`:

```ruby
def subscription_started_trial_after_commit?
  return unless saved_changes.key?('stripe_subscription_status')

  previous_status = saved_changes['stripe_subscription_status'][0]
  current_status = saved_changes['stripe_subscription_status'][1]

  previous_status != 'trialing' && current_status == 'trialing'
end

def trial_converted_to_paid_after_commit?
  return unless saved_changes.key?('stripe_subscription_status')

  previous_status = saved_changes['stripe_subscription_status'][0]
  current_status = saved_changes['stripe_subscription_status'][1]

  previous_status == 'trialing' && current_status == 'active'
end
```

Trial eligibility, `app/models/organization.rb:699-710`:

```ruby
def eligible_for_free_trial?
  stripe_subscription_status.blank? || free_plan_eligible_for_free_trial?
end

def free_plan_eligible_for_free_trial?
  return unless free_plan_with_one_job?
  return unless stripe_customer_id.present?

  total = 0
  Stripe::Invoice.list(customer: stripe_customer_id, limit: 100).auto_paging_each { |inv| total += inv.amount_paid }
  total.zero?
end
```

`eligible_for_free_trial` is serialized (`organization_serializer.rb:56, 92-94`) — note it makes a paginated Stripe API call per serialization for free-plan orgs. Ending a trial: `Organization#stripe_end_trial` (`organization.rb:486-488`).

The only persisted trial trace is the `SubscriptionEvent` ledger row `trial_started: 8` (`app/models/subscription_event.rb:14`), created at `organization.rb:1128-1134`.

---

## 7. Organization attributes already sent to PostHog

There is **no PostHog group / `group_identify` / `$groups` usage anywhere** in `app/` or `config/` — grep for `group_identify|groups:|$groups|group_type` returns only an unrelated Slack OAuth scope comment. Everything is person-scoped on `distinct_id = user.id.to_s`.

**Server-side identify — `app/services/posthog/identify.rb:11-21`:**

```ruby
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

**Server-side default event properties — `app/services/posthog/track.rb:24-31`:**

```ruby
def default_properties
  {
    email: @user.email,
    organization_id: @user.organization&.id,
    organization_name: @user.organization&.name,
    plan: @user.organization&.plan
  }
end
```

**Browser-side identify — `app/javascript/shared/lib/posthog.ts:32-38`, called from `app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:168-175`:**

```ts
ph.identify(String(user.id), {
  email: user.email,
  organization_id: user.organizationId,
  organization_name: user.organizationName,
  plan: user.plan,
  organization_user_role: user.organizationUserRole,
});
```

**Subscription-event properties — `app/models/subscription_event.rb:101-123`** add, on top of the row's own columns (`amount`, `stripe_subscription_id`, `from_plan`, `to_plan`, `billing_interval`), these organization-sourced values via `attribution_value(owner_value, organization_value)` (owner wins, org is the fallback — `subscription_event.rb:126-134`):

`stripe_customer_id` (org only), `utm_source`, `utm_campaign`, `utm_data`, `internal_ref`, `google_click_id`, `adroll_click_id`, `adroll_first_party_cookie`, `fbclid`, `fbp`, `fbc`, `li_fat_id`, `ga_client_id`, `ga_session_id`.

**Person-level `$set` flags — `subscription_event.rb:41-61`:** `is_trialing`, `is_paying` (set on `trial_started`, `trial_converted_to_paid_subscription`, `converted_to_paid_subscription`, `canceled_subscription`). These are the properties most obviously mis-located on the person rather than the group.

**AI credit purchase properties — `app/models/organization_ai_credit_purchase.rb:95-105`:** `stripe_customer_id` is the only organization attribute (`organization.stripe_customer_id`).

**`$set_once` attribution — `app/controllers/api/v1/registrations_controller.rb:55-57, 215-216`** and `app/jobs/track_new_sso_owner_signup_job.rb:13-14` — sourced from `User#attribution_properties` (`app/models/user.rb:495-511`), never from the organization.

---

## 8. Every path where an Organization gets CREATED

| # | Path | file:line | Notes |
|---|---|---|---|
| 1 | Normal signup / onboarding (React `OrganizationForm`) | `app/controllers/api/v1/organizations_controller.rb:29` — `@organization = Organization.new(organization_params)` | Sets `owner_id`, `created_via`, `is_claimed = true`, and copies **all 14 attribution fields** off `current_user` (`:30-45`). This is the primary production path, for both email and Google-SSO users. |
| 2 | God-admin create | `app/controllers/api/v1/admin/organizations_controller.rb:46` — `@organization = Organization.new(organization_params)` | `owner = User.find_by(email: 'system@inflowhq.com')`; `owner_id = owner.id` (`:45,48`). No `is_claimed`, no attribution. |
| 3 | Unregistered-job public signup (internal API) | `app/controllers/api/v1/public/unregistered_job_controller.rb:58` — `organization = Organization.new(organization_params)` | Inside `ActiveRecord::Base.transaction` (`:14-18`), user + org + job together. Sets `owner_id`, `is_claimed = true`. No attribution copy. |
| 4 | Unregistered-job public signup (public API) | `app/controllers/api_public/v1/hire/unregistered_job_controller.rb:57` — `organization = Organization.new(organization_params)` | Byte-identical duplicate of #3. |
| 5 | Board scraper (unclaimed shell orgs) | `app/site_scrapers/boards_scraper.rb:75` — `organization = Organization.create(` | `is_scrapable: true, kind: 'kind_scrapable'`, owner `system@inflowhq.com`. These are **not customers** — `is_claimed` stays `false`. |
| 6 | Seeds (test env only) | `db/seeds.rb:39` — `Organization.where(name: 'Acme Inc.').first_or_create do |o|` | Guarded by `return unless Rails.env.test?` (`db/seeds.rb:17`). |
| 7 | Spec factories | `spec/support/api_factories.rb:17` — `Organization.create!(`; `spec/support/ai_credits_test_helpers.rb:54` — `Organization.new(org_attrs)` | Test only. |

**SSO does not create an Organization.** `app/controllers/api/v1/users/omniauth_callbacks_controller.rb:22-39` creates only the `User` via `User.from_omniauth`; the org is created afterwards through path #1.

**Invites do not create an Organization.** `User#accept_invite` (`app/models/user.rb:93-124`) pushes the user into `invite.organization.users`, creating an `OrganizationUser` only.

**Nothing creates an Organization inside `Api::V1::RegistrationsController`.** Lines 44 and 206 only *update* `partner_source` on an already-existing org.

### Side effects at create time — `app/models/organization.rb:51-56`

```ruby
# Synchronous credit setup — must be after_create (not after_commit)
# so the ai_credit_balance row exists inside the creating transaction.
# Failure is logged but tolerated to avoid blocking org creation.
# Async workers still fire at after_commit.
after_create  :create_ai_credit_state_if_needed
after_commit  :complete_setup_workers, on: [:create]
```

`complete_setup_workers` (`:180-190`) builds the careers page synchronously and enqueues `OrgSetupJob`, `NotifyNewOrganizationJob`, `Discord::NotifyNewOrganizationJob`. `OrgSetupJob` → `Organization#complete_setup` (`:209-223`) which, for claimed orgs, calls `create_stripe_customer`, `set_default_plan` (writes `plan = 'plan_simple_ats_free'` via `update_columns`, `:225-227`), `set_zapier_api_key`, `set_partner_source_from_owner`, plus `check_clearbit` (writes `clearbit_website_url` / `clearbit_logo_url`).

**Consequence for group-property timing:** at the moment the org row is INSERTed, `plan` is `plan_no_plan` (default 101), `stripe_customer_id` is nil, `users_count` is 0, and `zapier_api_key` is nil. Every one of those is filled in asynchronously by `OrgSetupJob` seconds later, and `plan` moves again to `plan_ats_tier_free_v2` once the free Stripe subscription syncs.

---

## 9. Which organization attributes CHANGE over time, and where

### A. Subscription/plan columns — the highest-churn set

| Column | Writer | file:line |
|---|---|---|
| `plan` | `set_default_plan` (`update_columns`) | `app/models/organization.rb:226` |
| `plan`, `stripe_subscription_id`, `stripe_subscription_status`, `stripe_current_period_end_at`, `stripe_default_payment_method_on_file` | `sync_with_stripe` — batched `update(changes_to_make)` | `app/models/organization.rb:566-601` |
| `plan` (+ test sub fields) | `give_away_for_time`, `setup_*_test_subscription` | `organization.rb:769-876` |
| `stripe_current_period_end_at`, `stripe_subscription_status`, `stripe_cancel_at_period_end` | `customer.subscription.updated` webhook | `app/jobs/stripe_webhook_handler_job.rb:155-159` |
| `stripe_customer_id`, `stripe_subscription_id` | `checkout.session.completed` webhook | `app/jobs/stripe_webhook_handler_job.rb:76-80` |
| `stripe_current_period_end_at` | `invoice.paid` webhook | `app/jobs/stripe_webhook_handler_job.rb:304` |
| `subscription_canceled_at` (`update_column`) | `customer.subscription.deleted` webhook | `app/jobs/stripe_webhook_handler_job.rb:208` |
| `stripe_subscription_status` | Billing controller customer fetch | `app/controllers/api/v1/billing_controller.rb:589-592` |
| `stripe_checkout_session_id` | Checkout session creation | `app/controllers/api/v1/billing_controller.rb:113` |
| `stripe_promo_code` | Promo code apply | `app/controllers/api/v1/billing_controller.rb:507` |
| `stripe_default_payment_method_on_file` | `handle_checkout_setup_intent` | `app/models/organization.rb:648` |
| all Stripe columns → nil | `stripe_delete_customer` (non-production only) | `app/models/organization.rb:498-506` |
| `stripe_customer_id` → nil | `destroy_stripe` | `app/models/organization.rb:762-767` |
| `stripe_subscription_status` / `plan` | Cypress test endpoints | `app/controllers/cypress/organizations_controller.rb:14, 36-39` |

### B. Feature/flag columns flipped by the subscription-status callback

`app/models/organization.rb:1117-1120`:

```ruby
if current_status == 'active'
  update_column(:can_send_bulk_messages, true) unless can_send_bulk_messages
  update_column(:can_enable_linkedin, true) unless can_enable_linkedin
end
```

### C. Identity / profile columns (user-editable in the app)

`app/controllers/api/v1/organizations_controller.rb:89` — `@organization.update(temp_params)`, permitting (`:128`): `name`, `default_from_email`, `website_url`, `logo`, `social_share_image`, `remoteness`, `wwr_company_statement`, `wwr_company_bio`, `linkedin_company_id`, `enable_x_hiring`, `white_label_job_board_enabled`, `hud_display_visibility`, `heard_about_us_from`, plus the whole `settings` jsonb (18 keys).

`settings` is also rewritten by `Organization#update_settings` (`organization.rb:1334-1342`), `add_default_settings` (`:1329-1331`), `add_new_default_settings` (`:1319-1326`), `delete_unused_settings` (`:1345-1353`), and by `transfer_ownership_to_organization_user` (`:279`) and `OrgOwnerUpdateJob` (`app/jobs/org_owner_update_job.rb:16`).

Admin-editable (`app/controllers/api/v1/admin/organizations_controller.rb:67`, permit list `:181-200`): `name`, `website_url`, `description`, `completed_setup`, `is_scrapable`, `is_claimed`, `is_manually_verified`, `thirdparty_jobboard_url`, `thirdparty_ats_identifier`, `scraped_from_url`, `clearbit_logo_url`, `clearbit_website_url`, `scraper_type`, `kind`, `plan`, `twitter_handle`, `flipper_group`, `can_send_bulk_messages`, `can_enable_linkedin`, `fraud_rating`.

### D. `before_update` side-writes — `app/models/organization.rb:1012-1021`

```ruby
def handle_before_update
  # fix_settings
  update_column(:website_url, nav_url(website_url)) unless website_url.nil?

  update_column(:linkedin_basic_jobs_changed_at, DateTime.current) if linkedin_company_id_changed?

  update_column(:x_hiring_changed_at, DateTime.current) if enable_x_hiring_changed?
rescue StandardError => e
  Sentry.capture_exception(e)
end
```

### E. Counter columns (change on child-record lifecycle, no Organization save)

`users_count` (`app/models/organization_user.rb:9`), `jobs_count` (`app/models/job.rb:26`), `published_jobs_count` (`app/models/job.rb:29`). These change **without any `Organization` callback firing**, so nothing on `Organization` can observe them — a refresh keyed on Organization `after_commit` will miss every seat and job-count change.

### F. Miscellaneous

- `owner_id` — `transfer_ownership_to_organization_user` via `update_columns` (`organization.rb:275`), which **skips callbacks**.
- `completed_setup` — `OrgSetupJob` via `update_columns` (`app/jobs/org_setup_job.rb:12`), also callback-skipping.
- `zapier_api_key` — `set_zapier_api_key` (`organization.rb:456`).
- `partner_source` — `set_partner_source_from_owner` (`organization.rb:232`), `registrations_controller.rb:44, 206`.
- `fraud_rating` — `app/models/channel_message.rb:246, 249, 252, 255`.
- `linkedin_company_id` → nil, `enable_x_hiring` → false — `app/services/bad_actor_organization_takeover.rb:83-86`.
- `clearbit_website_url` / `clearbit_logo_url` — `check_clearbit` via `update_columns` (`organization.rb:316, 329`).
- `free_plan_paid_features_enabled` — **no writer exists in `app/` or `lib/`**; read-only at `organization.rb:1637` and `plan_feature_gate.rb:91`. Set by hand (console/SQL).
- `connect_users_count` — no writer anywhere.

**Refresh-trigger caveat:** the `update_column` / `update_columns` writers above (`plan` in `set_default_plan`, `subscription_canceled_at` in the webhook, `can_send_bulk_messages`, `can_enable_linkedin`, `owner_id`, `completed_setup`, the clearbit fields, `linkedin_basic_jobs_changed_at`, `x_hiring_changed_at`) bypass callbacks entirely — an `after_commit`-based group-property refresh will never see them.

---

## 10. `after_commit` callbacks on Organization today

`app/models/organization.rb:51-61` — the complete callback block, quoted verbatim:

```ruby
  # Synchronous credit setup — must be after_create (not after_commit)
  # so the ai_credit_balance row exists inside the creating transaction.
  # Failure is logged but tolerated to avoid blocking org creation.
  # Async workers still fire at after_commit.
  after_create  :create_ai_credit_state_if_needed
  after_commit  :complete_setup_workers, on: [:create]
  before_update :handle_before_update
  # after_update  :handle_after_update
  after_commit :handle_after_commit_on_update, on: [:update]

  before_destroy :wait_dont_do_that
```

Two `after_commit` callbacks. There is **no unconditional `after_commit`** (no `on: [:create, :update]` form) and none on `:destroy`.

`app/models/organization.rb:1023-1029`:

```ruby
  def handle_after_commit_on_update
    handle_subscription_status_change_after_commit
    handle_plan_change_after_commit
    handle_name_change_after_commit
    handle_linkedin_company_id_change_after_commit
    handle_cancellation_scheduled_after_commit
  end
```

`app/models/organization.rb:180-190`:

```ruby
  def complete_setup_workers
    # ap "COMPLETE ORG SETUP - #{name}"
    create_careers_page # need this to happen on main thread so it's ready to go

    OrgSetupJob.perform_later(id) # calls complete_setup
    # Slack Notification
    NotifyNewOrganizationJob.perform_later(id) # if id_changed?
    # Discord Notification
    Discord::NotifyNewOrganizationJob.perform_later(id)
    # send_welcome_email
  end
```

The five branch methods gate on `saved_changes` for exactly these columns: `stripe_subscription_status` (`:1105`), `plan` (`:1074`), `name` (`:1066`), `linkedin_company_id` (`:1207`), `stripe_cancel_at_period_end` (`:1215`). Any group-property refresh hung off `handle_after_commit_on_update` gets those five for free and nothing else — notably **not** `users_count`, `jobs_count`, `published_jobs_count`, or `stripe_current_period_end_at`.

The one existing precedent for pushing organization-shaped data to PostHog from a commit hook is `SubscriptionEvent#handle_after_commit_on_create` (`app/models/subscription_event.rb:26, 31-62`), which fires `PosthogTrackJob.perform_later(organization.owner.id, event_type, event_properties)` — always addressed to `organization.owner.id`, never to the organization.