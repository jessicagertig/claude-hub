# Outbound Webhook Infrastructure — The `RegisteredWebhook` System

**Topic:** The publish-job webhook (`new_published_job`) as the spine of the entire outbound webhook system. This is THE analog to copy for the three new hiring-stage-move webhooks.

**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats.hiring-stage-move-webhooks`

## FILE CHAIN TRACED

Trigger spine (publish):
```
app/models/job.rb
  before_update :handle_before_update (line 60)
    -> handle_before_update (line 476) -> handle_status_change (line 514)
      -> handle_status_changed_to_published (line 545)
        -> organization.registered_webhooks.find_by(kind: :new_published_job)  (line 558)
        -> RegisteredWebhooks::NewJobPublishedJob.perform_later(id, webhook.id) (line 559)
          -> app/jobs/registered_webhooks/new_job_published_job.rb
            -> Job.find / RegisteredWebhook.find
            -> Api::V1::RegisteredWebhooks::PublishedJobSerializer (app/serializers/api/v1/registered_webhooks/published_job_serializer.rb)
            -> Faraday.post(url, serializer)
```

Models / associations:
```
app/models/registered_webhook.rb  (enum kind, polymorphic owner)
app/models/organization.rb:23  has_many :registered_webhooks, as: :owner
db/migrate/20230615000906_create_registered_webhooks.rb  ->  db/schema.rb:1138
```

Application-side CRUD:
```
config/routes.rb:328  resources :registered_webhooks (create/update/index/destroy + collection PUT :all)
app/controllers/api/v1/registered_webhooks_controller.rb
app/policies/registered_webhook_policy.rb
app/serializers/api/v1/registered_webhook_serializer.rb        (the management serializer: id, url, kind)
app/javascript/shared/types/registeredWebhooks.ts
app/javascript/shared/queryHooks/useRegisteredWebhooks.ts
app/javascript/ats/src/views/accountAdmin/accountIntegrations/AccountIntegrationsPolymerWebhooks.tsx
```

Second analog (new applicant) — same shape, different trigger/payload:
```
app/models/job_application.rb:230  organization.registered_webhooks.find_by(kind: :new_job_application)
app/models/job_application.rb:231  RegisteredWebhooks::NewJobApplicationJob.perform_later(id, webhook.id)
app/jobs/registered_webhooks/new_job_application_job.rb
app/serializers/api/v1/registered_webhooks/job_application_serializer.rb
  -> Api::V1::ZapierIntegrations::CandidateSerializer
  -> Api::V1::ZapierIntegrations::QuestionResponseSerializer
```

---

## 1. EVENT TYPE REGISTRY

There is **no separate registry, constant table, or event-name file.** The set of outbound webhook event types is the `kind` **enum on the `RegisteredWebhook` model itself**. There are exactly TWO today.

`app/models/registered_webhook.rb` (entire file):
```ruby
# frozen_string_literal: true

class RegisteredWebhook < ApplicationRecord
  belongs_to :owner, polymorphic: true

  enum kind: {
    new_job_application: 0,
    new_published_job: 1
  }, _prefix: true

  validates :kind, presence: true
  # validates :kind, uniqueness: { scope: [:owner_id, :owner_type] }
  validates :url, presence: true

end
```

Key facts:
- `kind` is an integer enum stored in column `kind` (NOT NULL). Values: `new_job_application: 0`, `new_published_job: 1`.
- `_prefix: true` → predicate methods are `kind_new_job_application?` / `kind_new_published_job?`.
- The uniqueness validation is **commented out**, but in practice the application code treats it as one-webhook-per-kind-per-org (`find_by(kind:)`, `find_or_initialize_by(kind:)`).
- The `event_type` string that the SUBSCRIBER sees is a **second, independent source of truth** hardcoded in each delivery serializer's `event_type` method (`'new_published_job'`, `'new_job_application'`). It happens to match the enum key but is NOT derived from it.

> **For the 3 new hiring-stage-move webhooks:** add 3 new enum values here (e.g. `:hiring_stage_moved` etc., next integers `2, 3, 4`) AND a matching `event_type` string in each new delivery serializer. Adding an enum value is the registration step — there is nothing else to register.

---

## 2. THE SUBSCRIPTION MODEL — `registered_webhooks` table

**Table:** `registered_webhooks`. **Model:** `RegisteredWebhook`.

`db/migrate/20230615000906_create_registered_webhooks.rb`:
```ruby
class CreateRegisteredWebhooks < ActiveRecord::Migration[6.0]
  def change
    create_table :registered_webhooks do |t|
      t.integer :kind, null: false
      t.string  :url, null: false
      t.bigint  :owner_id, null: false
      t.string  :owner_type, null: false
      t.timestamps
    end

    add_index :registered_webhooks, [:owner_type, :owner_id]
  end
end
```

`db/schema.rb:1138`:
```ruby
create_table "registered_webhooks", force: :cascade do |t|
  t.integer "kind", null: false
  t.string "url", null: false
  t.bigint "owner_id", null: false
  t.string "owner_type", null: false
  t.datetime "created_at", precision: 6, null: false
  t.datetime "updated_at", precision: 6, null: false
  t.index ["owner_type", "owner_id"], name: "index_registered_webhooks_on_owner_type_and_owner_id"
end
```

**Columns (this is the COMPLETE list — nothing else exists):**
| column | type | notes |
|---|---|---|
| `id` | bigint | PK |
| `kind` | integer | NOT NULL, enum |
| `url` | string | NOT NULL, the subscriber endpoint |
| `owner_id` | bigint | NOT NULL, polymorphic FK |
| `owner_type` | string | NOT NULL, always `'Organization'` in practice |
| `created_at` / `updated_at` | datetime | |

**COLUMNS THAT DO NOT EXIST (important for matching expectations):**
- ❌ NO `secret` / signing key column
- ❌ NO `active` / `enabled` boolean
- ❌ NO `event_types` array (each row is ONE kind)
- ❌ NO `description` / `name` / label
- ❌ NO delivery-tracking columns (last_delivered_at, failure_count, etc.)

**Owner association:** polymorphic `belongs_to :owner`. The reverse side, `app/models/organization.rb:23`:
```ruby
has_many :registered_webhooks, as: :owner
```
So in practice `owner` is always an `Organization`. The trigger code reads `organization.registered_webhooks`.

### Subscription lifecycle (create/update/destroy) — controller layer

`app/controllers/api/v1/registered_webhooks_controller.rb` (full file). Inherits `Api::V1::BaseController`. Uses Pundit `authorize`.

```ruby
class Api::V1::RegisteredWebhooksController < Api::V1::BaseController

  def index
    @page = params[:page] || 1
    webhooks = current_organization.registered_webhooks
    authorize webhooks
    render_paginated(webhooks, @page, Api::V1::RegisteredWebhookSerializer)
  end

  def create
    webhook = current_organization.registered_webhooks.build(registered_webhook_params)
    authorize webhook
    render_if_save(webhook, Api::V1::RegisteredWebhookSerializer)
  end

  def update
    exists(current_organization.registered_webhooks.where(id: params[:id]), 'no webhook found') do |webhook|
      authorize webhook
      render_if_update(webhook, registered_webhook_params, Api::V1::RegisteredWebhookSerializer)
    end
  end

  def destroy
    exists(current_organization.registered_webhooks.where(id: params[:id]), 'no webhook found') do |webhook|
      authorize webhook
      render_if_destroy(webhook, nil)
    end
  end

  def all
    webhooks_data = params[:webhooks] || []
    authorize(RegisteredWebhook, :update?)
    processed_webhooks = []

    webhooks_data.each do |webhook_data|
      webhook = current_organization.registered_webhooks
                                    .find_or_initialize_by(kind: webhook_data[:kind])
      webhook.url = webhook_data[:url]

      if webhook.url.blank? && webhook.id.present?
        webhook.destroy!
      elsif webhook.url.present?
        if webhook.save
          processed_webhooks << webhook
        else
          Rails.logger.error "Failed to save webhook #{webhook_data[:kind]}: #{webhook.errors.full_messages.join(', ')}"
        end
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Failed to save webhook #{webhook_data[:kind]}: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Unexpected error saving webhook #{webhook_data[:kind]}: #{e.message}"
    end

    render_each(processed_webhooks, Api::V1::RegisteredWebhookSerializer)
  rescue StandardError => e
    Rails.logger.error e
    render_general_errors(['Failed to save webhooks'])
  end

  private

  def registered_webhook_params
    params.permit(:url, :kind)
  end

  def batch_webhook_params
    params.permit(webhooks: [:kind, :url])
  end
end
```

Notes:
- `current_organization.registered_webhooks.build/where` scopes everything to the current org — no cross-org leakage.
- The **`all` collection action** is the primary UI path: it accepts an array `webhooks: [{kind, url}]` and does an upsert-or-delete per kind (`find_or_initialize_by(kind:)`; blank url + existing id → destroy; present url → save). This is how the settings page saves all webhook URLs at once.
- `batch_webhook_params` is defined but unused (`all` reads `params[:webhooks]` directly).
- Uses `render_if_save` / `render_if_update` / `render_if_destroy` / `render_paginated` / `render_each` / `exists` helpers (from `BaseController`) — these check save/update return values per critical rule 12.

**Routes** (`config/routes.rb:328`):
```ruby
resources :registered_webhooks, only: [:create, :update, :index, :destroy] do
  collection do
    put :all
  end
end
```

**Policy** (`app/policies/registered_webhook_policy.rb`, full):
```ruby
class RegisteredWebhookPolicy < ApplicationPolicy
  def index?;   is_org_admin?; end
  def create?;  is_org_admin;  end   # NOTE: no `?` — calls the bang/raising variant
  def update?;  is_org_admin?; end
  def destroy?; is_org_admin?; end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
```
(`create?` calls `is_org_admin` without the `?` — a pre-existing quirk; all webhook management is org-admin-gated.)

**Management serializer** (`app/serializers/api/v1/registered_webhook_serializer.rb`, full) — distinct from the DELIVERY serializers below:
```ruby
class Api::V1::RegisteredWebhookSerializer < ActiveModel::Serializer
  attributes :id, :url, :kind
end
```

**Frontend:**
- Type `app/javascript/shared/types/registeredWebhooks.ts`:
```ts
export interface RegisteredWebhook {
  url?: string;
  id?: number;
  kind?: string;
}
```
- Hook `app/javascript/shared/queryHooks/useRegisteredWebhooks.ts`, settings UI `AccountIntegrationsPolymerWebhooks.tsx` (not quoted here; the `all` endpoint is the save path).

---

## 3. WHERE THE PUBLISH-JOB EVENT FIRES

**Trigger location: a Job model callback chain, NOT an interactor/service/job.** It is fired synchronously (in-process) from within the `before_update` callback path, but the actual HTTP delivery is deferred to a Sidekiq job.

Callback registration (`app/models/job.rb:60`):
```ruby
before_update  :handle_before_update
```

`handle_before_update` (line 476) calls `handle_status_change` (line 514) when `status_changed?`. The status enum (`app/models/job.rb:96`):
```ruby
enum status: {
  draft: 0,
  in_review: 4,
  published: 1,
  closed_filled: 2,
  closed_unfilled: 3,
  status_archived: 5,
  published_but_subscription_cancelled: 6
}
```

`handle_status_change` dispatches on the new status; for `published?` it calls `handle_status_changed_to_published` (line 545):
```ruby
def handle_status_changed_to_published
  ap '***PUBLISHED***'
  touch(:published_at)

  # Set originally_published_at only if it's nil (first time publishing)
  update_column(:originally_published_at, published_at) if originally_published_at.nil?

  Notification::JobStatusChangeJob.perform_later(id, status)
  JobPingGoogleIndexJob.perform_later(id) # Pings Google Indexing API
  UpdateStripeSubscriptionJob.perform_later(organization.id)
  # WebflowSyncOneJob.perform_later(id) if !draft? && organization.has_webflow_mapping?
  CareersPageSubscriptionsNotifierJob.perform_later(id)

  new_published_job_webhook = organization.registered_webhooks.find_by(kind: :new_published_job)
  RegisteredWebhooks::NewJobPublishedJob.perform_later(id, new_published_job_webhook.id) if new_published_job_webhook.present?
end
```

**The exact firing pattern (memorize this — it is the template):**
```ruby
new_published_job_webhook = organization.registered_webhooks.find_by(kind: :new_published_job)
RegisteredWebhooks::NewJobPublishedJob.perform_later(id, new_published_job_webhook.id) if new_published_job_webhook.present?
```
1. Look up the org's single subscription for this kind via `find_by(kind:)`.
2. **Guard:** only enqueue `if ... .present?` — no subscription, no delivery (silent no-op).
3. `perform_later(record_id, registered_webhook.id)` — passes IDs, not objects.

**The applicant analog fires the identical shape** (`app/models/job_application.rb:230`, inside `send_notifications`):
```ruby
new_job_application_webhook = job.organization.registered_webhooks.find_by(kind: :new_job_application)
RegisteredWebhooks::NewJobApplicationJob.perform_later(id, new_job_application_webhook.id) if new_job_application_webhook.present?
```

> **For hiring-stage-move:** the analogous trigger point is in `JobApplication`. Note `job_application.rb` already has `track_movement` (line 183) which detects `saved_change_to_hiring_stage_id?` and `saved_change_to_job_id?` — that is the existing hook where stage-move logic lives. The new webhook fires would follow the `find_by(kind:) ... perform_later(id, webhook.id) if present?` pattern. (Trigger placement is a design decision for the spec — this doc maps the infra, not the new trigger.)

---

## 4. DELIVERY MECHANISM

**Job: `RegisteredWebhooks::NewJobPublishedJob`** (`app/jobs/registered_webhooks/new_job_published_job.rb`, full):
```ruby
class RegisteredWebhooks::NewJobPublishedJob < ApplicationJob
  queue_as :default

  def perform(job_id, registered_webhook_id)
    job = Job.find(job_id)
    registered_webhook = RegisteredWebhook.find(registered_webhook_id)
    return unless job.organization_id == registered_webhook.owner_id

    job.reload

    Faraday.post(
      registered_webhook.url,
      Api::V1::RegisteredWebhooks::PublishedJobSerializer.new(job)
    )
  rescue ActiveRecord::RecordNotFound
    ap 'RegisteredWebhooks::NewJobPublished FAILED, could not find record'
    ap job_id
    ap registered_webhook_id
  rescue StandardError => e
    ap 'RegisteredWebhooks::NewJobPublished exception'
    ap e
  end
end
```

**Applicant analog** (`app/jobs/registered_webhooks/new_job_application_job.rb`, full):
```ruby
class RegisteredWebhooks::NewJobApplicationJob < ApplicationJob
  queue_as :default

  def perform(job_application_id, registered_webhook_id)
    job_application = JobApplication.find(job_application_id)
    registered_webhook = RegisteredWebhook.find(registered_webhook_id)
    return unless job_application.job.organization_id == registered_webhook.owner_id

    Faraday.post(
      registered_webhook.url,
      Api::V1::RegisteredWebhooks::JobApplicationSerializer.new(job_application)
    )
  rescue ActiveRecord::RecordNotFound
    ap 'RegisteredWebhooks::NewJobApplication FAILED, could not find record'
    ap job_application_id
    ap registered_webhook_id
  rescue StandardError => e
    ap 'RegisteredWebhooks::NewJobApplication exception'
    ap e
  end
end
```

**Structural traits of the delivery job (shared by both — THIS is the skeleton):**
- Namespace: `RegisteredWebhooks::` module, file under `app/jobs/registered_webhooks/`.
- `< ApplicationJob` (which is a bare `ActiveJob::Base` — see below).
- `queue_as :default`.
- `perform(record_id, registered_webhook_id)` — two positional ID args.
- Load both records via `.find` (NOT bang-guarded — relies on `rescue ActiveRecord::RecordNotFound`).
- **Ownership guard:** `return unless record.organization_id == registered_webhook.owner_id` (bare return per critical rule 8). Re-verifies the subscription still belongs to the record's org before POSTing.
- Publish job ALSO calls `job.reload` before serializing (to get fresh `published_at` etc. set by `touch`/`update_column` in the trigger). The applicant job does not reload.
- **Delivery = `Faraday.post(url, serializer_instance)`.** The second arg is the ActiveModel::Serializer **instance** (not `.to_json`, not `.as_json`). Faraday serializes the object's body. There is no explicit `Content-Type`, no request block, no headers configured.
- **Two-tier rescue:** `ActiveRecord::RecordNotFound` (logs record IDs) then `StandardError` (logs the exception). All logging via `ap` (awesome_print, per critical rule 3) — printed to stdout/logs only.

**WHAT THE DELIVERY MECHANISM DOES NOT HAVE (critical — set expectations for the new webhooks):**
- ❌ **NO payload signing.** No HMAC, no signature header, no secret. Confirmed by grep across the job, model, and serializers — zero matches for `hmac|signature|secret|sign`.
- ❌ **NO retry / exhaustion.** `ApplicationJob` is bare:
  ```ruby
  class ApplicationJob < ActiveJob::Base
  end
  ```
  No `retry_on`, no `discard_on`, no `sidekiq_options`, no exhaustion block. A failed POST is swallowed by `rescue StandardError` and never retried. (Note: this DIVERGES from the analog-retry convention in inflow-ats Known Failure Pattern #14 — these two existing webhook jobs predate that and have no exhaustion blocks.)
- ❌ **NO timeout configured** (Faraday default).
- ❌ **NO response status checking.** The return of `Faraday.post` is discarded; a 4xx/5xx from the subscriber is treated as success.
- ❌ **NO Slack notifications** on failure (unlike `Integrations::Slack*`/`Notification::*` jobs). Failures only `ap`-log.
- ❌ **NO delivery record / audit table.** Fire-and-forget; nothing is persisted about a delivery (no create/update/destroy of any delivery row). The only DB writes in the whole flow are the subscription CRUD in the controller.
- ❌ **NO custom headers** (no event-id header, no delivery-id header, no timestamp header).

**Delivery record lifecycle:** there is none. A "delivery" is a single in-memory `Faraday.post` call inside one Sidekiq job execution. Nothing is created, updated, or destroyed to represent it.

---

## 5. THE PAYLOAD — delivery serializers

The HTTP body is whatever `ActiveModel::Serializer.new(record)` renders. The event-type metadata is an `event_type` **attribute method** on the serializer (hardcoded string). There is NO envelope/wrapper (no `{ event:, id:, timestamp:, data: {...} }` structure) — the event fields are flattened at the top level alongside the record's attributes.

**Publish-job payload** (`app/serializers/api/v1/registered_webhooks/published_job_serializer.rb`, full):
```ruby
class Api::V1::RegisteredWebhooks::PublishedJobSerializer < ActiveModel::Serializer
  attributes :event_type, :id, :title, :url, :description, :description_without_html, :social_share_image_url,
             :salary_min, :salary_max, :salary_unit, :salary_currency, :salary_type,
             :remoteness, :published_at, :kind, :display_location, :job_category_name

  def event_type
    'new_published_job'
  end

  def description
    object.html_safe_description
  end

  def url
    object.job_application_description_url
  end

  def salary_type
    if object.salary_min.present? && object.salary_max.blank?
      'fixed'
    elsif object.salary_min.present? && object.salary_max.present?
      'range'
    end
  end

  def kind
    object.kind_pretty
  end

  def remoteness
    object.remoteness_pretty
  end
end
```

**Applicant payload** (`app/serializers/api/v1/registered_webhooks/job_application_serializer.rb`, full):
```ruby
class Api::V1::RegisteredWebhooks::JobApplicationSerializer < ActiveModel::Serializer
  attributes :event_type, :id, :url, :job_title, :source, :created_via, :resume_url

  has_one :candidate, serializer: Api::V1::ZapierIntegrations::CandidateSerializer
  has_many :question_responses, serializer: Api::V1::ZapierIntegrations::QuestionResponseSerializer

  def event_type
    'new_job_application'
  end

  def question_responses
    object.public_question_responses
  end

  def url
    object.permalink_url
  end

  def job_title
    object.job.title
  end
end
```

**Payload envelope/metadata structure:**
- `event_type` — the ONLY event metadata. A flat string attribute, first in the list. Hardcoded per serializer.
- ❌ NO `timestamp`, NO `id`-of-event (the `id` attribute is the RECORD's id, not a delivery/event id), NO `delivery_id`, NO `webhook_id`. The event is NOT wrapped in an envelope; record attributes sit at the top level next to `event_type`.

**Structural traits of a delivery serializer (the skeleton for the 3 new ones):**
- Namespace `Api::V1::RegisteredWebhooks::`, file under `app/serializers/api/v1/registered_webhooks/`.
- `< ActiveModel::Serializer`.
- First attribute is `:event_type`, defined by a method returning a hardcoded snake_case string matching the enum kind.
- Remaining attributes are the record fields the subscriber needs; computed/aliased fields get override methods reading `object.<...>`.
- Nested records use `has_one` / `has_many` with `serializer:` pointing at `Api::V1::ZapierIntegrations::*` serializers for reuse.

---

## 6. ZAPIER / THIRD-PARTY CONVENTIONS

- The applicant payload reuses **`Api::V1::ZapierIntegrations::*`** serializers — this is the established Zapier-facing convention. These are the canonical "external integration" candidate/question shapes.

`app/serializers/api/v1/zapier_integrations/candidate_serializer.rb` (full):
```ruby
class Api::V1::ZapierIntegrations::CandidateSerializer < ActiveModel::Serializer
  attributes :first_name, :last_name, :full_name,
             :email, :phone, :location,
             :linkedin_url, :twitter_url, :github_url, :dribbble_url, :website_url

  def linkedin_url; object.linkedin_url_pretty if object.linkedin_url.present?; end
  def twitter_url;  object.twitter_url_pretty  if object.twitter_url.present?;  end
  def github_url;   object.github_url_pretty   if object.github_url.present?;   end
  def dribbble_url; object.dribbble_url_pretty if object.dribbble_url.present?; end
  def website_url;  object.website_url_pretty  if object.website_url.present?;  end
end
```

`app/serializers/api/v1/zapier_integrations/question_response_serializer.rb` (full):
```ruby
class Api::V1::ZapierIntegrations::QuestionResponseSerializer < ActiveModel::Serializer
  attributes :body, :question_text

  def question_text
    object.question.question_text
  end
end
```

- Convention: external/outbound payloads use `*_pretty` accessor methods and only include a field when present (`if object.x.present?`). Frontend rule 7's snake_case-vs-camelCase note: these outbound payloads are snake_case (they go to third parties, not the React app).
- The `Api::V1::Public::WebhooksController` (`config/routes.rb:353`) is for INBOUND webhooks (stripe/mailgun/webflow/slack/discord) — unrelated to this outbound system; do not confuse the two.

---

## 7. COMPLETE FILE INVENTORY — what EXISTS vs what the new webhooks must CREATE

**EXISTS (reuse / extend, do not recreate):**
- `app/models/registered_webhook.rb` — **EXTEND**: add new `kind` enum values.
- `db/schema.rb` / `registered_webhooks` table — **NO migration needed** unless new columns are required (today none are; one row per kind, no secret/active).
- `app/controllers/api/v1/registered_webhooks_controller.rb` — generic; handles any kind via the `all` upsert. No change unless new params needed.
- `app/policies/registered_webhook_policy.rb` — generic, no change.
- `app/serializers/api/v1/registered_webhook_serializer.rb` — management serializer, no change.
- `config/routes.rb:328` — generic, no change.
- `app/javascript/shared/types/registeredWebhooks.ts`, `useRegisteredWebhooks.ts`, `AccountIntegrationsPolymerWebhooks.tsx` — frontend; the kind dropdown/list would need the new kinds added.
- `Api::V1::ZapierIntegrations::*` serializers — reuse for nested candidate/question data if the new payload needs them.
- `ApplicationJob` (`app/jobs/application_job.rb`) — bare base, no retry.

**MUST CREATE per new hiring-stage-move webhook (× the number of new kinds):**
1. A new **delivery job** `app/jobs/registered_webhooks/<event>_job.rb` (`< ApplicationJob`, `queue_as :default`, `perform(record_id, registered_webhook_id)`, ownership guard, `Faraday.post(url, serializer)`, two-tier rescue with `ap`).
2. A new **delivery serializer** `app/serializers/api/v1/registered_webhooks/<event>_serializer.rb` (`< ActiveModel::Serializer`, `:event_type` first, hardcoded string).
3. A **new enum value** in `RegisteredWebhook#kind` (shared file — add value, do not recreate).
4. A **trigger call** at the appropriate model callback / lifecycle point: `webhook = org.registered_webhooks.find_by(kind: :<event>); SomeJob.perform_later(id, webhook.id) if webhook.present?`.

**DOES NOT EXIST anywhere (do not assume; if the new webhooks need these it is NET-NEW design, flag it):**
- No HMAC/signing helper, no secret column, no signature header.
- No retry/exhaustion config, no Slack failure alerting, no delivery audit table, no response-status handling, no custom headers, no event envelope/`delivery_id`/`timestamp`.
