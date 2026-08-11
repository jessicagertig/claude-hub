# 05 — HiringStageVisit model + Payload Data Models

Reference inventory for the hiring-stage-move webhook spec. Covers (A) the exact
`HiringStageVisit` structure and how "previous stage" vs "current stage" is
determined, and (B) the payload data models (Candidate, JobApplication,
Organization, Job) with their serializers, plus the EXISTING webhook delivery
infrastructure that the new webhook should mirror.

Worktree: `/Users/jessica/wrk/wrk-corp/inflow-ats.hiring-stage-move-webhooks`

## FILE CHAIN TRACED

```
db/schema.rb (hiring_stage_visits block)
app/models/hiring_stage_visit.rb
  -> app/models/hiring_stage.rb (active_message_automation, has_many hiring_stage_visits FK current_hiring_stage_id)
  -> app/models/hiring_stage_automation_event.rb (belongs_to hiring_stage_visit)
  -> app/jobs/hiring_stage_message_automation_job.rb (enqueued by after_commit)
app/interactors/create_hiring_stage_visit.rb
db/migrate/20240227021500_create_hiring_stage_visits.rb
db/migrate/20240305032714_create_hiring_stage_automation_events.rb
app/models/job_application.rb
  - after_commit :enqueue_new_job_application, on: [:create]   (L45)
  - after_commit :track_movement,             on: [:update]   (L46)
  - track_movement (L183) -> create_hiring_stage_visit (L382) -> CreateHiringStageVisit.call
  - date_moved_to_current_stage (L386) = hiring_stage_visits.order(created_at: :desc).first&.created_at
  - enqueue_new_job_application (L168) -> NewJobApplicationJob + RegisteredWebhooks::NewJobApplicationJob (L230-231)

Payload models / serializers:
app/models/candidate.rb (enum privacy_status, has_many job_applications)
app/serializers/api/v1/candidate_serializer.rb
app/serializers/api/v1/job_application_serializer.rb
app/serializers/api/v1/organization_serializer.rb
app/serializers/api/v1/job_serializer.rb

EXISTING WEBHOOK INFRA (the analog to copy):
app/models/registered_webhook.rb
db/schema.rb (registered_webhooks block)
app/serializers/api/v1/registered_webhooks/job_application_serializer.rb
  -> app/serializers/api/v1/zapier_integrations/candidate_serializer.rb
app/jobs/registered_webhooks/new_job_application_job.rb
app/models/organization.rb (has_many :registered_webhooks, as: :owner — L23)
```

---

# PART A — HiringStageVisit

## A1. Exact current schema (verbatim from `db/schema.rb` lines 623-634)

```ruby
create_table "hiring_stage_visits", force: :cascade do |t|
  t.bigint "job_application_id", null: false
  t.bigint "current_hiring_stage_id", null: false
  t.bigint "source_hiring_stage_id"
  t.string "current_stage_name_at_move", null: false
  t.bigint "moved_by_organization_user_id"
  t.datetime "created_at", precision: 6, null: false
  t.datetime "updated_at", precision: 6, null: false
  t.index ["current_hiring_stage_id"], name: "index_hiring_stage_visits_on_current_hiring_stage_id"
  t.index ["job_application_id"], name: "index_hiring_stage_visits_on_job_application_id"
  t.index ["source_hiring_stage_id"], name: "index_hiring_stage_visits_on_source_hiring_stage_id"
end
```

Column inventory:

| Column | Type | Null | Default | Index | FK |
|---|---|---|---|---|---|
| `id` | bigint (PK) | no | — | PK | — |
| `job_application_id` | bigint | **no** | — | yes | `job_applications` |
| `current_hiring_stage_id` | bigint | **no** | — | yes | `hiring_stages` |
| `source_hiring_stage_id` | bigint | yes | — | yes | `hiring_stages` |
| `current_stage_name_at_move` | string | **no** | — | — | — |
| `moved_by_organization_user_id` | bigint | yes | — | no | (no FK constraint — plain bigint) |
| `created_at` | datetime(6) | no | — | — | — |
| `updated_at` | datetime(6) | no | — | — | — |

There are **only TWO migrations** that reference `hiring_stage_visit`:
`20240227021500_create_hiring_stage_visits.rb` (creates the table) and
`20240305032714_create_hiring_stage_automation_events.rb` (creates a *child*
table, does NOT alter `hiring_stage_visits`). The schema has never been altered
since creation.

### Original create migration (verbatim, `20240227021500_create_hiring_stage_visits.rb`)

```ruby
class CreateHiringStageVisits < ActiveRecord::Migration[6.0]
  def change
    create_table :hiring_stage_visits do |t|
      t.references :job_application, null: false, index: true, foreign_key: true
      t.references :current_hiring_stage, foreign_key: { to_table: :hiring_stages }, null: false, index: true
      t.references :source_hiring_stage, foreign_key: { to_table: :hiring_stages }
      t.string :current_stage_name_at_move, null: false
      t.bigint :moved_by_organization_user_id

      t.timestamps
    end
  end
end
```

Note: `source_hiring_stage` and `moved_by_organization_user_id` are nullable
(no `null: false`). `moved_by_organization_user_id` is a plain `bigint` with NO
foreign-key constraint and NO index.

## A2. The model (verbatim, `app/models/hiring_stage_visit.rb`)

```ruby
# frozen_string_literal: true

class HiringStageVisit < ApplicationRecord
  attribute :skip_hiring_stage_message_automation, :boolean, default: false

  belongs_to :job_application
  belongs_to :current_hiring_stage, class_name: 'HiringStage'
  # belongs_to :source_hiring_stage, class_name: 'HiringStage', optional: true

  after_commit :enqueue_automation_handler, on: :create

  def enqueue_automation_handler
    # if skip_hiring_stage_message_automation
    #   ap 'SKIPPING MESSAGE AUTOMATION for job application:'
    #   ap job_application.id
    # end
    return if skip_hiring_stage_message_automation
    return unless message_automation.present?

    HiringStageMessageAutomationJob.perform_later(id, message_automation.id)
  end

  def message_automation
    current_hiring_stage.active_message_automation
  end
end
```

Structural facts:
- **Associations:** `belongs_to :job_application`; `belongs_to :current_hiring_stage`
  (class `HiringStage`). The `source_hiring_stage` `belongs_to` is **commented
  out** — even though the FK column `source_hiring_stage_id` exists, there is NO
  active association for it. Reading the source stage requires
  `HiringStage.find(visit.source_hiring_stage_id)` or adding the association.
- **Validations:** NONE declared in the model (DB-level `null: false` only).
- **Callbacks:** ONE — `after_commit :enqueue_automation_handler, on: :create`.
  Fires the message-automation job when the destination stage has an active
  message automation. There is **no duration/time tracking callback.**
- **Scopes:** NONE.
- **Enums:** NONE.
- **Virtual attribute:** `skip_hiring_stage_message_automation` (boolean,
  default false) — not persisted; gates the automation job.
- **Existing duration/time methods:** NONE on this model. The only time field is
  `created_at`. No `entered_at`, no `left_at`, no `duration` method exists.

### Child table (context): `hiring_stage_automation_events`

```ruby
# app/models/hiring_stage_automation_event.rb
belongs_to :hiring_stage_visit
# columns: hiring_stage_visit_id (null:false, FK), automation_id (bigint null:false),
#          automation_type (string null:false), timestamps
```
`HiringStageMessageAutomation#sent_automations_for_job_application` joins through
`hiring_stage_automation_events -> hiring_stage_visits` filtered by
`job_application_id` (`app/models/hiring_stage_message_automation.rb` L18-19).
Not directly relevant to the webhook payload but shows the visit is the join hub.

## A3. How visits are created (the lifecycle)

### Two entry points, both on `JobApplication`

`app/models/job_application.rb` callback registration (L45-46):

```ruby
after_commit :enqueue_new_job_application, on: [:create]
after_commit :track_movement,             on: [:update]
```

**Entry point 1 — initial visit on application creation.**
`handle_new_job_application` (L205-214) calls `create_hiring_stage_visit` with NO
source (so `source_hiring_stage_id` is nil for the very first visit):

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

**Entry point 2 — visit on every stage move.** `track_movement` (L183-198),
fired by `after_commit ... on: [:update]`:

```ruby
def track_movement
  if saved_change_to_job_id?
    ap 'Job Id changed - Job Application moved to job'
    ap job_id
    previous_job_id = job_id_before_last_save
    previous_stage_id = hiring_stage_id_before_last_save
    track_move_to_job(hiring_stage_id, previous_job_id)
    create_hiring_stage_visit(previous_stage_id)
  elsif saved_change_to_hiring_stage_id?
    ap 'Hiring Stage Id changed'
    ap hiring_stage_id
    previous_stage_id = hiring_stage_id_before_last_save
    track_move_to_hiring_stage(hiring_stage_id)
    create_hiring_stage_visit(previous_stage_id)
  end
end
```

So `source_hiring_stage_id` = `hiring_stage_id_before_last_save` (the stage the
application was in BEFORE this update). `current_hiring_stage_id` = the new
`hiring_stage_id`.

**The shared creation method** (L382-384):

```ruby
def create_hiring_stage_visit(source_stage_id = nil)
  CreateHiringStageVisit.call(job_application: self, current_hiring_stage_id: hiring_stage_id, source_hiring_stage_id: source_stage_id)
end
```

### The interactor (verbatim, `app/interactors/create_hiring_stage_visit.rb`)

```ruby
class CreateHiringStageVisit
  include Interactor

  def call
    ap 'Create Hiring Stage Visit'
    # context: job_application, current_hiring_stage_id, source_hiring_stage_id
    job_application = context.job_application
    current_hiring_stage = job_application.job.hiring_stages.find_by_id(context.current_hiring_stage_id)
    raise ActionController::RoutingError, 'HiringStage Not Found' unless current_hiring_stage

    stage_name = current_hiring_stage.name
    org_user_id = job_application.last_updated_by_organization_user_id
    visit_params = {
      current_hiring_stage_id: context.current_hiring_stage_id,
      source_hiring_stage_id: context.source_hiring_stage_id,
      current_stage_name_at_move: stage_name,
      moved_by_organization_user_id: org_user_id,
      skip_hiring_stage_message_automation: context.job_application.skip_hiring_stage_message_automation
    }
    visit = job_application.hiring_stage_visits.build(visit_params)

    if visit.save
      context.visit = visit
    else
      context.visit = visit
      context.fail!(message: "Could not create HiringStageVisit for job application with id #{job_application.id}.")
    end
  end
end
```

Record create lifecycle / order on a stage move:
1. Something calls `job_application.update(hiring_stage_id: X)`.
2. `after_commit :track_movement` fires.
3. `track_movement` reads `hiring_stage_id_before_last_save` (= previous stage).
4. `create_hiring_stage_visit(previous_stage_id)` -> `CreateHiringStageVisit.call`.
5. Interactor resolves the dest stage's name, captures
   `last_updated_by_organization_user_id`, builds + saves a `HiringStageVisit`.
6. The new visit's own `after_commit :enqueue_automation_handler` may enqueue a
   message-automation job.

`current_stage_name_at_move` snapshots the DESTINATION stage's name at move time
(immune to later stage renames). It is the NEW stage's name, not the source's.

## A4. Determining "last stage" vs "new stage" for a given JobApplication

The only ordering signal is `created_at` (no sequence/position column). Two
proven query shapes already in the codebase:

`app/models/job_application.rb` L386-387:

```ruby
def date_moved_to_current_stage
  hiring_stage_visits.order(created_at: :desc).first&.created_at
end
```

So the **current/newest visit** for a job application is:

```ruby
current_visit = job_application.hiring_stage_visits.order(created_at: :desc).first
# current stage id   => current_visit.current_hiring_stage_id
# previous stage id  => current_visit.source_hiring_stage_id   (nil for the first-ever visit)
# moved at           => current_visit.created_at
# moved by org user  => current_visit.moved_by_organization_user_id
# dest stage name    => current_visit.current_stage_name_at_move
```

The **previous-stage visit** (the visit during which the application sat in the
stage it just left) is the visit whose `current_hiring_stage_id` equals the new
visit's `source_hiring_stage_id`, i.e. the second-newest visit:

```ruby
visits = job_application.hiring_stage_visits.order(created_at: :desc).to_a
current_visit  = visits[0]
previous_visit = visits[1]   # the visit that put the app into the stage it just left
```

`previous_visit.current_hiring_stage_id == current_visit.source_hiring_stage_id`
in the normal sequential case (a single linear move history).

## A5. Existing timestamps and whether a NEW "time in previous stage" column is needed

(Findings only — NOT a design.)

- The table has `created_at` and `updated_at`. There is **no `entered_at`,
  `left_at`, `duration`, or `time_in_stage` column.** No model method computes
  duration today.
- **Time in previous stage IS already derivable** from existing data, because
  every move writes a new row with `created_at`:
  - The application ENTERED a stage at the `created_at` of the visit whose
    `current_hiring_stage_id` is that stage.
  - It LEFT that stage at the `created_at` of the NEXT visit (the move off it).
  - Therefore: `time_in_previous_stage = current_visit.created_at - previous_visit.created_at`
    where `current_visit` is the move-off event and `previous_visit` is the
    move-into-the-previous-stage event (see A4).
- Edge cases that affect derivation (report, not solve):
  - The **first-ever visit** has `source_hiring_stage_id = nil` and no prior
    visit, so there is no "previous stage" duration for the initial placement.
  - A **cross-job move** (`saved_change_to_job_id?` branch) also creates a visit
    with `source_hiring_stage_id` = the previous job's stage; `created_at`
    arithmetic still works but the source stage belongs to a different job.
  - Ordering relies solely on `created_at`; two visits created in the same
    transaction/second would tie (sub-second `precision: 6` mitigates this).
- A persisted column would only be needed if the spec wants the value frozen at
  move time (immune to later visit deletions / `dependent: :destroy`) or wants to
  index/query by it. Derivation requires reading two rows per move.

---

# PART B — Payload data models

The webhook payload could carry: the candidate who moved, the job application,
the candidate's OWN other applications, the organization, and the job. Below is
each model's serializer attribute list (the menu of fields available) plus how to
reach the related records, plus PII/anonymization notes.

## B0. EXISTING WEBHOOK INFRASTRUCTURE (the analog to mirror)

This feature already has a sibling: the **new_job_application** webhook. The new
hiring-stage-move webhook should structurally match it.

`app/models/registered_webhook.rb` (verbatim):

```ruby
class RegisteredWebhook < ApplicationRecord
  belongs_to :owner, polymorphic: true

  enum kind: {
    new_job_application: 0,
    new_published_job: 1
  }, _prefix: true

  validates :kind, presence: true
  validates :url, presence: true
end
```

`registered_webhooks` schema (verbatim, `db/schema.rb` L1138-1146):

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

`Organization` owns them: `has_many :registered_webhooks, as: :owner`
(`app/models/organization.rb` L23).

**Enqueue site** for the new-application webhook, inside
`JobApplication#send_notifications` (`app/models/job_application.rb` L230-231):

```ruby
new_job_application_webhook = job.organization.registered_webhooks.find_by(kind: :new_job_application)
RegisteredWebhooks::NewJobApplicationJob.perform_later(id, new_job_application_webhook.id) if new_job_application_webhook.present?
```

**Delivery job** (verbatim, `app/jobs/registered_webhooks/new_job_application_job.rb`):

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

**Webhook payload serializer** (verbatim,
`app/serializers/api/v1/registered_webhooks/job_application_serializer.rb`):

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

Key structural takeaways for the spec:
- Webhook payloads use a **dedicated, intentionally-slim serializer** under
  `Api::V1::RegisteredWebhooks::` — NOT the heavy internal `Api::V1::*Serializer`.
- They reuse the slim `Api::V1::ZapierIntegrations::CandidateSerializer` for the
  candidate (only URL-pretty public contact fields — see B1).
- The payload deliberately carries a hardcoded `event_type` string.
- Delivery is `Faraday.post(url, Serializer.new(object))`, guarded by an
  owner-org match, wrapped in `RecordNotFound` + `StandardError` rescues.

## B1. Candidate

Model: `app/models/candidate.rb`.
- `has_many :job_applications, dependent: :destroy, inverse_of: :candidate` (L10)
- `has_many :jobs, through: :job_applications` (L11)
- `belongs_to :organization, inverse_of: :candidates` (L17)

**Query all applications for a candidate:** `candidate.job_applications`
(optionally `.order(created_at: :desc)` as the internal serializer does).

### Internal serializer (verbatim, `app/serializers/api/v1/candidate_serializer.rb`)

```ruby
class Api::V1::CandidateSerializer < ActiveModel::Serializer
  attributes :id, :organization_id,
             :first_name, :last_name, :full_name, :initials,
             :email, :phone, :location,
             :has_valid_email,
             :cover_letter,
             :linkedin_url,
             :twitter_url,
             :github_url,
             :dribbble_url,
             :website_url,
             :job_applications_count,
             :private_note,
             :privacy_status,
             :created_via

  has_many :job_applications, serializer: Api::V1::JobApplicationSerializer do
    object.job_applications.order(created_at: :desc)
  end

  has_many :jobs, serializer: Api::V1::JobSerializer # Needed to display the name of the current Job on a Candidate View

  # filter is a method provided by AMS to remove keys that should not be included
  def filter(keys)
    if scope&.is_admin
      keys
    else
      keys - [:private_note]
    end
  end
end
```

### Webhook/Zapier serializer (verbatim, `app/serializers/api/v1/zapier_integrations/candidate_serializer.rb`)

This is what the EXISTING webhook actually sends for a candidate:

```ruby
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
  # ...twitter_url / github_url / dribbble_url / website_url all use *_pretty
end
```

**PII / anonymization:**
- `Candidate` has `enum privacy_status: { public: 0, needs_anonymization: 1,
  anonymized: 2 }, _prefix: true` (`app/models/candidate.rb` L109-113). This is
  the PII state machine. `privacy_status` IS exposed by the internal
  `CandidateSerializer`.
- The internal serializer's `filter(keys)` removes `:private_note` unless
  `scope&.is_admin`. **The webhook delivery job has NO `scope`** (it calls
  `Serializer.new(object)` with no scope), so any scope-gated attribute would be
  treated as non-admin. The slim Zapier serializer sidesteps this by never
  exposing `private_note`/`privacy_status` at all.
- A hiring-stage-move webhook that includes candidate contact fields must decide
  how to treat `needs_anonymization`/`anonymized` candidates — the existing
  webhook serializer does NOT check `privacy_status` before emitting name/email.

## B2. JobApplication

Model: `app/models/job_application.rb`.
- `belongs_to :job` (L13), `belongs_to :candidate` (L14),
  `belongs_to :hiring_stage` (L15).
- Reach the organization via `job_application.job.organization` (there is no
  direct `belongs_to :organization` on JobApplication; the org-ownership check in
  the delivery job uses `job_application.job.organization_id`).
- `has_many :hiring_stage_visits` (L26) — the move history (Part A).

### Internal serializer (verbatim, `app/serializers/api/v1/job_application_serializer.rb`)

```ruby
class Api::V1::JobApplicationSerializer < ActiveModel::Serializer
  include Pundit
  attributes :id, :hash_id, :job_id, :candidate_id, :hiring_stage_id,
             :stage,
             :status, :possible_future_candidate,
             :archive_reason,
             :created_at,
             :created_at_timestamp,
             :updated_at_timestamp,
             :created_at_time_ago_short,
             :shared_document,
             :source,
             :has_resume,
             :resume_url,
             :resume_original_url,
             :resume_encoded_s3_url,
             :resume_content_type,
             :should_use_microsoft_docx_viewer,
             :created_via,
             :urls,
             :last_updated_by_organization_user_id,
             :settings,
             :external_resume_url,
             :external_resume_status,
             :relative_url,
             :bulk_ai_summary_processing

  attribute :desired_compensation, if: :show_desired_compensation?

  has_many :channels, serializer: Api::V1::ShallowChannelSerializer
  has_many :question_responses, serializer: Api::V1::QuestionResponseSerializer

  has_one :candidate, serializer: Api::V1::ShallowCandidateSerializer
  has_one :job, serializer: Api::V1::JobSerializer
  has_one :ahoy_visit, serializer: Api::V1::AhoyVisitSerializer
  has_one :ai_job_application_summary_status,
          serializer: Api::V1::AiJobApplicationSummaryStatusSerializer
  # ... methods: shared_document, question_responses, show_question_response?,
  #     bulk_ai_summary_processing, show_desired_compensation? (Pundit-gated)
end
```

### Webhook/Zapier serializer (verbatim, `app/serializers/api/v1/zapier_integrations/job_application_serializer.rb`)

```ruby
class Api::V1::ZapierIntegrations::JobApplicationSerializer < ActiveModel::Serializer
  attributes :id, :url, :job_title, :source, :created_via, :resume_url

  has_one :candidate, serializer: Api::V1::ZapierIntegrations::CandidateSerializer
  has_many :question_responses, serializer: Api::V1::ZapierIntegrations::QuestionResponseSerializer

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

Note: the `RegisteredWebhooks::JobApplicationSerializer` (B0) is nearly identical
to this Zapier one but adds `event_type`. For a hiring-stage-move webhook the
move-relevant fields available include `hiring_stage_id`, `stage`, `status`,
`last_updated_by_organization_user_id`, plus the `hiring_stage_visits` history.

**PII:** `desired_compensation` is Pundit-gated (`show_desired_compensation?` ->
`policy.view_desired_compensation?`). With no scope in the webhook job, a
Pundit-gated attribute would error or be excluded — the slim webhook serializers
avoid all Pundit-gated and scope-gated attributes for this reason.

## B3. Organization

Model: `app/models/organization.rb`. `has_many :registered_webhooks, as: :owner`
(L23). It is the webhook OWNER. There is **no slim
`RegisteredWebhooks::` or `ZapierIntegrations::` organization serializer** — the
existing webhook payloads do not embed the organization; they only use it to
look up the registered webhook and to verify ownership in the delivery job.

### Internal serializer (verbatim, `app/serializers/api/v1/organization_serializer.rb`)

```ruby
class Api::V1::OrganizationSerializer < ActiveModel::Serializer
  attributes :id, :organization_id, :owner_id, :name, :description,
             :website_url,
             :has_logo,
             :logo_medium,
             :settings,
             :twitter_handle,
             :plan,
             :is_scrapable,
             :is_claimed,
             :remoteness,
             :created_at,
             :stripe_customer_id,
             :stripe_checkout_session_id,
             :stripe_subscription_id,
             :stripe_current_period_end_at,
             :stripe_current_period_end_at_timestamp,
             :stripe_default_payment_method_on_file,
             :stripe_subscription_status,
             :stripe_promo_code,
             :stripe_subscription_in_good_standing,
             :active_paid_plan?,
             :active_plan?,
             :wwr_company_statement,
             :wwr_company_bio,
             :has_webflow_authentication?,
             :has_webflow_mapping?,
             :has_slack_authentication?,
             :has_discord_authentication?,
             :published_jobs_count,
             :has_ever_published_job,
             :flipper_id,
             :flipper_group,
             :careers_page_url,
             :careers_page_slug,
             :careers_page_subscribers_count,
             :enabled_linkedin_basic_jobs,
             :linkedin_company_id,
             :can_enable_linkedin,
             :enable_x_hiring,
             :white_label_job_board_enabled,
             :hud_display_visibility,
             :webflow_authenticated_via_api_v2,
             :careers_page_subscribers_count,
             :hidden_jobs_count,
             :archived_jobs_count,
             :draft_jobs_count,
             :owner_email_is_corporate,
             :eligible_for_linkedin,
             :created_via,
             :whatjobs_company_description,
             :eligible_for_free_trial
  # has_many :users, :organization_users, :careers_pages; has_one slack/discord/webflow
end
```

**PII / sensitive:** this internal serializer exposes Stripe customer/subscription
IDs and billing status. Those must NOT leak into an external webhook payload.
Identification-only fields a move webhook might carry: `id`, `name`,
`website_url`, `careers_page_url`, `plan`. (There is `mini_organization_serializer.rb`
and `shallow_organization_serializer.rb` if a slimmer org is wanted — not read
here, flagged for the spec.)

## B4. Job

Model: `app/models/job.rb`. `belongs_to :organization`. Reach from a job
application via `job_application.job`. Job is the OWNER lookup path for the
new_published_job webhook (`app/models/job.rb` L558). There is a public-API job
serializer at `app/serializers/api_public/v1/hire/job_serializer.rb` and a
`mini`/`shallow` set if a slim job is wanted (not read here).

### Internal serializer (verbatim, `app/serializers/api/v1/job_serializer.rb`)

```ruby
class Api::V1::JobSerializer < ActiveModel::Serializer
  attributes :id, :hash_id, :organization_id, :process_template_id,
             :auto_generate_ai_summaries,
             :title,
             :description,
             :description_html,
             :description_without_html,
             :video_url,
             :department, :country, :state_region, :city, :map_location,
             :organization_name,
             :kind, :kind_pretty,
             :status, :visible, :user_id,
             :job_applications_count,
             :created_at,
             :published_at,
             :archived_at,
             :archived_at_timestamp,
             :archived_at_time_ago_short,
             :unarchived_count, :inbox_count,
             :display_location,
             :settings,
             :apply_through,
             :is_allowed_remote,
             :remoteness, :remoteness_pretty,
             :application_thirdparty_url,
             # remote restriction fields...
             :shared_document_template,
             :active_wwr_listing,
             :webflow_item_id,
             :job_category_name, :job_category_id,
             :user_ids, :organization_user_ids,
             :social_share_image_url, :has_social_share_image, :social_share_image_filename,
             :banner_image_url, :has_banner_image, :banner_image_filename, :banner_media_type,
             :job_post_url,
             :salary_min, :salary_max, :salary_unit, :salary_currency,
             :use_apply_response_template, :apply_response_template,
             :external_listings_enabled, :external_listings_settings,
             :originally_archived_at,
             :ai_job_application_summaries_count,
             :should_auto_generate_ai_summaries

  has_many :questions, serializer: Api::V1::QuestionSerializer
  has_many :hiring_stages, serializer: Api::V1::HiringStageSerializer
  # methods: description, description_html, shared_document_template, questions,
  #          hiring_stages (kept, ordered by position), active_wwr_listing,
  #          banner_image_*, should_auto_generate_ai_summaries
end
```

Move-relevant job fields a webhook might carry: `id`, `title`, `status`,
`organization_id`, `organization_name`, `job_post_url`. The `hiring_stages`
association (kept, ordered by `position`) is where stage names/positions live if
the payload needs the full pipeline shape (each `HiringStage` has `name`, `kind`,
`position`, `job_id`, `discarded_at` per the `hiring_stages` schema block).

---

## Summary for the spec phase

- `hiring_stage_visits` columns: `job_application_id`, `current_hiring_stage_id`,
  `source_hiring_stage_id`, `current_stage_name_at_move`,
  `moved_by_organization_user_id`, `created_at`, `updated_at`. No
  entered/left/duration column; ordering is by `created_at` only.
- "Current stage" of a move = newest visit's `current_hiring_stage_id`;
  "previous stage" = same visit's `source_hiring_stage_id` (= second-newest
  visit's `current_hiring_stage_id`). Time-in-previous-stage IS derivable as
  `current_visit.created_at - previous_visit.created_at` — a persisted column is
  only needed for freezing/indexing, not for availability.
- An EXISTING webhook system (`RegisteredWebhook` enum `new_job_application`/
  `new_published_job`, org-owned, slim `Api::V1::RegisteredWebhooks::` serializer,
  `Faraday.post` delivery job enqueued from a model callback) is the exact analog
  to mirror for a `hiring_stage_move` webhook.
- Payload data is reachable from the job application: candidate
  (`job_application.candidate`, all apps via `candidate.job_applications`), job
  (`job_application.job`), organization (`job_application.job.organization`).
- PII guards: `Candidate#privacy_status` enum (public/needs_anonymization/
  anonymized) is NOT respected by the existing webhook serializer; internal
  serializers gate `private_note` (scope) and `desired_compensation` (Pundit) and
  expose Stripe IDs on Organization — none of which the slim webhook serializers
  emit. A new move-webhook serializer should follow the slim
  `RegisteredWebhooks::`/`ZapierIntegrations::` precedent and avoid scope/Pundit-
  gated and billing fields.
