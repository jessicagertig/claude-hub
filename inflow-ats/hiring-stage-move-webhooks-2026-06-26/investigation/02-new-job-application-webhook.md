# Webhook Analog #2 — NEW JOB APPLICATION (outbound `new_job_application`)

Reference doc for the second outbound registered-webhook analog. This is the webhook that fires when a candidate applies (a `JobApplication` is created). Per Jessica: the "inbox" hiring-stage case is ALREADY covered by this webhook — see the **Inbox linkage** section for exactly how.

Source repo (feature worktree): `/Users/jessica/wrk/wrk-corp/inflow-ats.hiring-stage-move-webhooks`

---

## FILE CHAIN TRACED

Trigger → delivery:

```
app/models/job_application.rb
  (after_commit :enqueue_new_job_application, on: [:create]  — line 45)
   → JobApplication#enqueue_new_job_application            (line 168)
     → NewJobApplicationJob.perform_later(id)              (line 169)
app/jobs/new_job_application_job.rb
   → NewJobApplicationJob#perform                          → @job_application.handle_new_job_application
app/models/job_application.rb
   → JobApplication#handle_new_job_application             (line 205)
     → JobApplication#send_notifications                   (line 216)
       → job.organization.registered_webhooks.find_by(kind: :new_job_application)   (line 230)
       → RegisteredWebhooks::NewJobApplicationJob.perform_later(id, webhook.id)     (line 231)
app/jobs/registered_webhooks/new_job_application_job.rb
   → RegisteredWebhooks::NewJobApplicationJob#perform
     → Faraday.post(registered_webhook.url, Api::V1::RegisteredWebhooks::JobApplicationSerializer.new(job_application))
app/serializers/api/v1/registered_webhooks/job_application_serializer.rb
   → has_one :candidate  → app/serializers/api/v1/zapier_integrations/candidate_serializer.rb
   → has_many :question_responses → app/serializers/api/v1/zapier_integrations/question_response_serializer.rb
```

Registry model: `app/models/registered_webhook.rb`
Inbox linkage: `app/models/job_application.rb#set_initial_hiring_stage` (line 201) → `app/models/job.rb#inbox_hiring_stage` (line 1151)

Publish-job analog (#1), for the structural diff:
```
app/models/job.rb
  (before_update :handle_before_update — line 60)
   → Job#handle_before_update (476) → Job#handle_status_change (514)
     → published? → Job#handle_status_changed_to_published (545)
       → organization.registered_webhooks.find_by(kind: :new_published_job)         (line 558)
       → RegisteredWebhooks::NewJobPublishedJob.perform_later(id, webhook.id)        (line 559)
app/jobs/registered_webhooks/new_job_published_job.rb
   → Faraday.post(url, Api::V1::RegisteredWebhooks::PublishedJobSerializer.new(job))
app/serializers/api/v1/registered_webhooks/published_job_serializer.rb
```

---

## 1. The registry model — `RegisteredWebhook`

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
- ONE table (`registered_webhooks`) backs BOTH outbound webhooks. The two events are distinguished by the `kind` enum (`new_job_application: 0`, `new_published_job: 1`), NOT by separate tables/models.
- `belongs_to :owner, polymorphic: true`. In practice the owner is always an `Organization` — `app/models/organization.rb:23` declares `has_many :registered_webhooks, as: :owner`. The trigger code resolves a webhook via `organization.registered_webhooks` / `job.organization.registered_webhooks`.
- Columns used: `kind`, `url`, `owner_id`, `owner_type`. No secret/signing column, no per-event payload config column.
- The uniqueness validation on `kind` is COMMENTED OUT. Nothing in the model enforces one webhook per kind per org — but the find/registration paths use `find_by` / `find_or_initialize_by(kind:)`, so effectively one row per kind per org is assumed.
- `_prefix: true` means helper methods are `kind_new_job_application?` etc.

**Registration controller** `app/controllers/api/v1/registered_webhooks_controller.rb`: standard CRUD plus a bulk `all` action that does `registered_webhooks.find_or_initialize_by(kind: webhook_data[:kind])`, sets `url`, destroys when url blank, saves otherwise. Permitted params: `params.permit(:url, :kind)`. Serialized via `Api::V1::RegisteredWebhookSerializer` which exposes only `:id, :url, :kind`.

> NOTE: `app/controllers/api/v1/public/webhooks_controller.rb` is INBOUND webhooks (Stripe/Webflow/Slack/Discord/Mailgun receivers). It is unrelated to these OUTBOUND registered webhooks. Do not confuse the two.

---

## 2. Trigger — how it FIRES on job application creation

### 2a. The model callback (the real entry point)

`app/models/job_application.rb:45`:

```ruby
after_commit :enqueue_new_job_application, on: [:create]
```

`app/models/job_application.rb:168-181`:

```ruby
def enqueue_new_job_application
  NewJobApplicationJob.perform_later(id)
  DocxToPdfJob.perform_later(id)
  # Non-docx resumes submit to Textract here; docx resumes submit after PDF conversion in DocxToPdfJob.
  if !resume_is_docx && Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)
    SubmitResumeToTextractJob.perform_later(id)
  end
  # Auto-generate AI summary for new applicants when enabled on the job.
  if job.should_auto_generate_ai_summaries?
    validation_result = ValidateAutoAiSummaryGeneration.call(job_application: self)
    CreateAiSummaryGeneration.call(job_application: self, validation_result: validation_result) if validation_result.success?
  end
  find_or_create_ai_job_application_summary_status
end
```

So the webhook is NOT fired directly from the callback. The callback enqueues the generic `NewJobApplicationJob` (note: this is `app/jobs/new_job_application_job.rb`, NOT the `RegisteredWebhooks::` one). That job is the orchestrator for ALL "new application" side effects.

### 2b. The orchestrator job

`app/jobs/new_job_application_job.rb` (entire relevant body):

```ruby
class NewJobApplicationJob < ApplicationJob
  queue_as :default

  def perform(job_application_id)
    if JobApplication.where(id: job_application_id).any?
      @job_application = JobApplication.find(job_application_id)
      @job_application.handle_new_job_application
    end
  end
end
```

### 2c. `handle_new_job_application` → `send_notifications`

`app/models/job_application.rb:205-214`:

```ruby
def handle_new_job_application
  add_shared_document_template
  add_hiring_process
  create_channels
  send_emails
  clean_candidate_social_links
  track_new_job_application_activity
  send_notifications
  create_hiring_stage_visit
end
```

`app/models/job_application.rb:216-232` — the webhook fire lives at the END of `send_notifications`, alongside Slack/Discord integrations:

```ruby
def send_notifications
  return if created_via_bulk_manual_add?

  feature_access = PlanFeatureGate.new(job.organization)

  if feature_access.allow?(PlanFeatureGate::SLACK_INTEGRATION)
    Slack::NotifyJobApplicationJob.perform_later(id) if Flipper.enabled?(:CONFIG_NOTIFICATIONS_FOR_NEW_JOB_APPLICATIONS, job.organization)

    Integrations::SlackNewJobApplicationJob.perform_later(id) if candidate.organization.has_slack_authentication? && job.organization.settings['slack_new_job_applications']
  end
  if feature_access.allow?(PlanFeatureGate::DISCORD_INTEGRATION)

    Integrations::DiscordNewJobApplicationJob.perform_later(id) if candidate.organization.has_discord_authentication?
  end
  new_job_application_webhook = job.organization.registered_webhooks.find_by(kind: :new_job_application)
  RegisteredWebhooks::NewJobApplicationJob.perform_later(id, new_job_application_webhook.id) if new_job_application_webhook.present?
end
```

Key facts about the trigger:
- Guard `return if created_via_bulk_manual_add?` at the top means **bulk-manual-added** applications do NOT fire ANY of these notifications, including the webhook.
- The webhook lookup is `find_by(kind: :new_job_application)` on the org's `registered_webhooks`. If the org has registered no such webhook, `new_job_application_webhook` is nil and nothing is enqueued (`if ... .present?`).
- The delivery job receives TWO args: the `job_application.id` and the `registered_webhook.id`. It does NOT receive a serialized payload — the payload is built inside the delivery job.

### 2d. Trigger lives in the MODEL, not in an interactor or service

The decision of "which webhook to look up and whether to enqueue" lives in `JobApplication#send_notifications` (a model instance method), reached via the `after_commit` → `NewJobApplicationJob` → `handle_new_job_application` chain. There is NO interactor or service for this. (Contrast: publish webhook lookup lives in `Job#handle_status_changed_to_published`, also a model method.)

---

## 3. Event type — definition & relation to the registry

The event type string is defined IN THE SERIALIZER as a method, not on the model:

`app/serializers/api/v1/registered_webhooks/job_application_serializer.rb`:

```ruby
def event_type
  'new_job_application'
end
```

It is hard-coded and emitted as the `event_type` attribute in the payload. The string `'new_job_application'` matches the `RegisteredWebhook.kind` enum key (`new_job_application: 0`), but there is NO programmatic link — the serializer literally returns a string literal. The registry's enum is what the org's webhook row stores; the serializer's `event_type` is what the receiver sees. They are kept in sync by convention only.

---

## 4. Payload — the serializer (FULL CODE)

### 4a. Top-level — `Api::V1::RegisteredWebhooks::JobApplicationSerializer`

`app/serializers/api/v1/registered_webhooks/job_application_serializer.rb` (entire file):

```ruby
# frozen_string_literal: true

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

Attribute-by-attribute, what the candidate/application data the payload carries (THIS directly informs the hiring-stage-move payload):

- `event_type` → literal `'new_job_application'` (serializer method).
- `id` → `JobApplication#id` (DB column, auto).
- `url` → `object.permalink_url` → `"#{Variables::AtsRootUrl}/applicants/#{hash_id}"` (job_application.rb:466). The ATS deep-link to the applicant.
- `job_title` → `object.job.title` (the Job's title).
- `source` → `JobApplication#source` — a plain `t.string "source"` column (schema line 20). Free-text application source.
- `created_via` → `JobApplication#created_via` — emitted via the `created_via` enum (integer column `created_via` default 0). Serializer emits the enum STRING (e.g. `created_via_job_board`). Enum values: `created_via_manual_add: 0, created_via_job_board: 1, created_via_api: 2, created_via_referral: 3, created_via_bulk_manual_add: 4, created_via_clone: 5, created_via_customer_api_apply: 6, created_via_customer_api_import: 7`.
- `resume_url` → `JobApplication#resume_url` (job_application.rb:628-633):
  ```ruby
  def resume_url
    return unless has_resume

    resume_version = has_resume_docx_to_pdf ? resume_docx_to_pdf : resume
    Variables::AtsRootUrl + Rails.application.routes.url_helpers.rails_blob_path(resume_version, only_path: true)
  end
  ```
  Returns nil when no resume; otherwise an ATS-hosted blob URL (PDF-converted version preferred).

Nested:
- `candidate` (`has_one`, `CandidateSerializer`) — full candidate contact info (see 4b).
- `question_responses` (`has_many`, `QuestionResponseSerializer`) — but the method overrides it to `object.public_question_responses` (job_application.rb:20: `has_many :public_question_responses, -> { with_public_visibility }, class_name: 'QuestionResponse'`). Only PUBLIC-visibility responses are included; private responses are excluded.

NOTE: there is no top-level `job_id`, `organization`, `hiring_stage`, `created_at`, or `candidate_id` in this payload. Job is represented ONLY by `job_title`. There is NO organization data in the payload at all (the org is implied by which URL the webhook was registered on).

### 4b. Nested — `Api::V1::ZapierIntegrations::CandidateSerializer`

`app/serializers/api/v1/zapier_integrations/candidate_serializer.rb` (entire file):

```ruby
# frozen_string_literal: true

class Api::V1::ZapierIntegrations::CandidateSerializer < ActiveModel::Serializer
  attributes :first_name, :last_name, :full_name,
             :email, :phone, :location,
             :linkedin_url,
             :twitter_url,
             :github_url,
             :dribbble_url,
             :website_url

  def linkedin_url
    object.linkedin_url_pretty if object.linkedin_url.present?
  end

  def twitter_url
    object.twitter_url_pretty if object.twitter_url.present?
  end

  def github_url
    object.github_url_pretty if object.github_url.present?
  end

  def dribbble_url
    object.dribbble_url_pretty if object.dribbble_url.present?
  end

  def website_url
    object.website_url_pretty if object.website_url.present?
  end
end
```

Candidate fields carried: `first_name, last_name, full_name, email, phone, location`, and "pretty" normalized social URLs (`linkedin_url, twitter_url, github_url, dribbble_url, website_url`), each emitted only when present. This is reused from the Zapier integration namespace — NOT a webhook-specific candidate serializer.

### 4c. Nested — `Api::V1::ZapierIntegrations::QuestionResponseSerializer`

`app/serializers/api/v1/zapier_integrations/question_response_serializer.rb` (entire file):

```ruby
# frozen_string_literal: true

class Api::V1::ZapierIntegrations::QuestionResponseSerializer < ActiveModel::Serializer
  attributes :body, :question_text

  def question_text
    object.question.question_text
  end
end
```

Each public question response carries `body` (the answer) and `question_text` (the question prompt, via `object.question.question_text`).

---

## 5. Delivery path — the delivery job

`app/jobs/registered_webhooks/new_job_application_job.rb` (entire file):

```ruby
# frozen_string_literal: true

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

Delivery facts:
- Each event KIND has its OWN delivery job. `new_job_application` uses `RegisteredWebhooks::NewJobApplicationJob`; publish uses `RegisteredWebhooks::NewJobPublishedJob`. They are NOT a shared delivery job. The shared piece is only the convention (Faraday.post, ownership guard, rescue shape).
- `queue_as :default`.
- Ownership re-check: `return unless job_application.job.organization_id == registered_webhook.owner_id`. Bare `return` (compliant with core rule 8). This re-verifies the webhook still belongs to the same org at delivery time.
- Delivery is `Faraday.post(url, serializer_instance)`. The serializer instance is passed as the POST body directly. There is NO signing/secret header, NO retry/exhaustion block, NO `Content-Type` set explicitly, NO response-status check, NO logging of the HTTP response. Fire-and-forget.
- Error handling: rescues `ActiveRecord::RecordNotFound` (logs ids via `ap`) and `StandardError` (logs the exception via `ap`). No re-raise, so Sidekiq will NOT retry on these.

---

## 6. STRUCTURAL DIFF — `new_job_application` (#2) vs `new_published_job` (#1)

This diff tells us which parts of the skeleton are PER-EVENT vs SHARED.

| Aspect | #2 new_job_application | #1 new_published_job | Shared or per-event? |
|---|---|---|---|
| Registry model | `RegisteredWebhook`, `kind: :new_job_application` (enum 0) | `RegisteredWebhook`, `kind: :new_published_job` (enum 1) | **SHARED model+table**, per-event enum VALUE |
| Owner association | `Organization has_many :registered_webhooks, as: :owner` | same | SHARED |
| Trigger model | `JobApplication` | `Job` | per-event |
| Trigger callback | `after_commit :enqueue_new_job_application, on: [:create]` | `before_update :handle_before_update` (status change path) | **per-event — different callback TYPE and timing** (after_commit-on-create vs before_update) |
| Trigger lifecycle | record CREATE | record UPDATE (status → published) | per-event |
| Intermediate orchestrator | YES — generic `NewJobApplicationJob` → `handle_new_job_application` → `send_notifications` | NO — fired inline in `Job#handle_status_changed_to_published` | **per-event — different depth** |
| Method where webhook lookup lives | `JobApplication#send_notifications` (model) | `Job#handle_status_changed_to_published` (model) | both in MODEL, per-event method |
| Lookup code | `job.organization.registered_webhooks.find_by(kind: :new_job_application)` | `organization.registered_webhooks.find_by(kind: :new_published_job)` | SAME shape, per-event kind |
| Enqueue guard | `... .perform_later(id, webhook.id) if webhook.present?` | `... .perform_later(id, webhook.id) if webhook.present?` | SHARED shape |
| Extra trigger guard | `return if created_via_bulk_manual_add?` at top of `send_notifications` | none (just status==published) | per-event |
| Delivery job | `RegisteredWebhooks::NewJobApplicationJob` | `RegisteredWebhooks::NewJobPublishedJob` | **per-event — separate job classes** |
| Delivery job args | `(job_application_id, registered_webhook_id)` | `(job_id, registered_webhook_id)` | SAME shape, per-event record id |
| Delivery ownership guard | `job_application.job.organization_id == registered_webhook.owner_id` | `job.organization_id == registered_webhook.owner_id` | SAME shape |
| `reload` before post | NO | **YES — `job.reload`** (new_job_published_job.rb:11) | per-event difference |
| HTTP call | `Faraday.post(url, JobApplicationSerializer.new(...))` | `Faraday.post(url, PublishedJobSerializer.new(...))` | SAME mechanism, per-event serializer |
| Rescue shape | `ActiveRecord::RecordNotFound` + `StandardError`, log via `ap` | identical | SHARED shape |
| Payload serializer | `Api::V1::RegisteredWebhooks::JobApplicationSerializer` | `Api::V1::RegisteredWebhooks::PublishedJobSerializer` | **per-event file** |
| `event_type` value | `'new_job_application'` (hard-coded method) | `'new_published_job'` (hard-coded method) | per-event string |
| Payload shape | candidate-centric: `event_type, id, url, job_title, source, created_via, resume_url` + nested `candidate` + `question_responses` | job-centric: `event_type, id, title, url, description, description_without_html, social_share_image_url, salary_*, remoteness, published_at, kind, display_location, job_category_name` | **completely different per-event** |
| Nested serializers | reuses `ZapierIntegrations::CandidateSerializer` + `ZapierIntegrations::QuestionResponseSerializer` | none (flat) | per-event |

### Per-event skeleton (what a NEW webhook event — e.g. hiring-stage-move — needs its OWN of):
1. A new `kind` enum value on `RegisteredWebhook`.
2. A trigger point (callback/method) in the relevant model.
3. A delivery job `RegisteredWebhooks::<Event>Job` taking `(record_id, registered_webhook_id)`, with the ownership guard + `Faraday.post` + the two-rescue block.
4. A payload serializer `Api::V1::RegisteredWebhooks::<Event>Serializer` with a hard-coded `event_type` method.

### Shared skeleton (reused as-is):
- The `RegisteredWebhook` model + `registered_webhooks` table + polymorphic owner.
- The registration controller + `RegisteredWebhookSerializer`.
- The lookup idiom `org.registered_webhooks.find_by(kind: ...)` + `.perform_later(id, webhook.id) if webhook.present?`.
- The delivery idiom: ownership guard → `Faraday.post(url, Serializer.new(record))` → rescue `RecordNotFound` + `StandardError` with `ap` logging. No signing, no retry, no response check in EITHER analog.

---

## 7. Inbox linkage — HOW "inbox" is already covered

The new-application webhook is NOT scoped to a hiring stage. It fires for EVERY non-bulk-manual application creation. The reason inbox arrivals are inherently covered:

`app/models/job_application.rb:44, 201-203`:

```ruby
before_validation :set_initial_hiring_stage
...
def set_initial_hiring_stage
  self.hiring_stage_id = job.inbox_hiring_stage.id if hiring_stage_id.nil? && job.inbox_hiring_stage
end
```

`app/models/job.rb:1151-1153`:

```ruby
def inbox_hiring_stage
  hiring_stages.find_by(kind: 'kind_inbox')
end
```

Linkage: a brand-new `JobApplication` with no `hiring_stage_id` is assigned the job's INBOX hiring stage by `set_initial_hiring_stage` (a `before_validation` callback) before it is saved. The CREATE then triggers `after_commit :enqueue_new_job_application` → ... → the `new_job_application` webhook. So a candidate "landing in the inbox stage" IS a new-application create, and the existing `new_job_application` webhook already fires for it.

Implication for a hiring-stage-MOVE webhook: the move-into-inbox-on-creation case is already emitted as `new_job_application`. A hiring-stage-move webhook should fire on STAGE TRANSITIONS of EXISTING applications. The relevant transition hook already exists: `app/models/job_application.rb:46` `after_commit :track_movement, on: [:update]` → `track_movement` (line 183) handles `saved_change_to_hiring_stage_id?` (and `saved_change_to_job_id?`). That `track_movement` method (NOT the create path) is the natural trigger site for a move webhook, mirroring how `send_notifications` is the site for the create webhook.

---

## 8. Cursor-rule compliance notes (for building the move analog)

- Background jobs: naming `{action}_{resource}_job.rb`; external HTTP must be in a job (cursor_rules/backend/background_jobs.md). Both analogs comply.
- Serializers: don't define methods for plain columns (cursor_rules/backend/serializers.md rule 1). The `JobApplicationSerializer` correctly leaves `id`, `source`, `created_via` as bare attributes and only writes methods for derived values (`url`, `job_title`, `event_type`, `question_responses`).
- Core rule 8 (guard clauses, bare return): both delivery jobs use bare `return unless ...` — comply.
- Core rule 11/12 (no bang, check return values): delivery jobs do read-only `find` + `Faraday.post`; the `find` raises `RecordNotFound`, which is explicitly rescued. Note `RegisteredWebhook.find` (non-bang-equivalent raising) is used and the raise is handled — acceptable here.
