# Hiring Stage Move Pipeline — Reference (Trigger Surface for the 3 New Webhooks)

**Worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.hiring-stage-move-webhooks`

## FILE CHAIN TRACED

```
SINGLE MOVE (in-app):
  app/controllers/api/v1/job_applications_controller.rb#update
    -> app/policies/job_application_policy.rb#permitted_attributes   (permits :hiring_stage_id, :skip_hiring_stage_message_automation)
    -> JobApplication#update(hiring_stage_id: ...)
    -> app/models/job_application.rb  after_commit :track_movement, on: [:update]
         -> #track_movement  (saved_change_to_hiring_stage_id? branch)
              -> #track_move_to_hiring_stage -> #create_activity_for_movement -> create_activity (PublicActivity)
              -> #create_hiring_stage_visit(previous_stage_id)
                   -> app/interactors/create_hiring_stage_visit.rb  (builds + saves HiringStageVisit row)
                        -> app/models/hiring_stage_visit.rb  after_commit :enqueue_automation_handler, on: :create
                             -> app/jobs/hiring_stage_message_automation_job.rb
                                  -> app/interactors/channel_messages/create_stage_automation_message.rb
                                  -> app/interactors/create_stage_automation_event.rb

SINGLE MOVE (customer public API):
  app/controllers/api_public/v1/hire/job_applications_controller.rb#move_stage / #archive
    -> sets moved_via='customer_api', last_updated_by_organization_user_id, skip_hiring_stage_message_automation
    -> JobApplication#update(hiring_stage_id: ...)   [same after_commit chain as above]

MOVE TO ANOTHER JOB:
  job_applications_controller.rb#move_to_job
    -> JobApplication#move_to_job_at_hiring_stage  -> update(job_id:, hiring_stage_id:)
    -> track_movement (saved_change_to_job_id? branch) -> track_move_to_job + create_hiring_stage_visit(previous_stage_id)

BULK MOVE:
  app/controllers/api/v1/bulk_move_job_applications_to_stage_controller.rb#create
    -> ValidatePlanAccess (PlanFeatureGate::BULK_MOVE)
    -> RoleFitFilterable#apply_role_fit_filter (select-all resolution)
    -> current_organization.job_applications.where(id: ids_to_move).update(update_params)   [Relation#update => per-record callbacks => track_movement fires per JA]
    -> @job.reset_counters

EXISTING WEBHOOK ANALOG (new_job_application):
  JobApplication after_create chain -> #enqueue_new_job_application (NOT where webhook fires)
  Webhook actually fires from #handle_new_job_application -> #send_notifications:
    job.organization.registered_webhooks.find_by(kind: :new_job_application)
    -> RegisteredWebhooks::NewJobApplicationJob.perform_later(id, webhook.id)
       -> Faraday.post(webhook.url, Api::V1::RegisteredWebhooks::JobApplicationSerializer.new(ja))
  Model: app/models/registered_webhook.rb (enum kind: new_job_application:0, new_published_job:1)
```

---

## 1. The HiringStage model and the "type" (kind) concept

`app/models/hiring_stage.rb` — the stage *type* is the **`kind`** enum column (NOT `stage`, NOT `status`; those are legacy enums on `JobApplication`).

```ruby
class HiringStage < ApplicationRecord
  include Discard::Model
  belongs_to :job, inverse_of: :hiring_stages
  has_many :job_applications
  has_many :hiring_stage_visits, class_name: 'HiringStageVisit', foreign_key: 'current_hiring_stage_id'
  has_many :hiring_stage_message_automations, inverse_of: :hiring_stage, dependent: :destroy

  acts_as_list scope: [:job_id, :kind, discarded_at: nil]

  enum kind: {
    kind_inbox: 0,
    kind_in_process: 1,
    kind_archived: 2,
    kind_hired: 3,
  }
  # ...
end
```

### EXACT enum (this is authoritative — note the `kind_` prefix on every value)

| Type concept | enum name | integer | Generated predicate / scope |
|---|---|---|---|
| inbox | `kind_inbox` | 0 | `hiring_stage.kind_inbox?`, `HiringStage.kind_inbox` |
| in process | `kind_in_process` | 1 | `kind_in_process?`, `HiringStage.kind_in_process` |
| archived | `kind_archived` | 2 | `kind_archived?`, `HiringStage.kind_archived` |
| hired | `kind_hired` | 3 | `kind_hired?`, `HiringStage.kind_hired` |

There is **no separate "stage type" model**. Type = the `kind` integer column on `hiring_stages`. A Job owns multiple HiringStage rows; the special-purpose ones are resolved by `kind` via helpers on `Job`:

```ruby
# app/models/job.rb (STAGE HELPERS, ~line 1148)
def inbox_hiring_stage
  hiring_stages.find_by(kind: 'kind_inbox')
end

def in_process_hiring_stages
  hiring_stages.kind_in_process.order(position: :asc)
end

def archived_hiring_stage
  hiring_stages.find_by(kind: 'kind_archived')
end
```

NOTE: There is **no `hired_hiring_stage` helper** on Job (only inbox/in_process/archived). A `kind_hired` stage exists and is created (`job.rb:381` builds `name: 'Hired', kind: 'kind_hired'`) but has no single-record finder helper. Ordering across types is hand-rolled in `HiringStage.ordered` (inbox → in_process → hired → archived).

**Stage-type checking pattern in practice:** `stage.kind_inbox?` / `stage.kind_archived?` predicates (e.g., `HiringStageMessageAutomation#validate_hiring_stage_kind` rejects `hiring_stage.kind_inbox?`), or `job.archived_hiring_stage` / `job.inbox_hiring_stage` to fetch the type-specific stage.

### Distinguish from the LEGACY enums on JobApplication (do not confuse)
`app/models/job_application.rb` still defines `enum stage: {inbox,screen,interview,decide,offer}` and `enum status: {status_in_process, status_archived, status_hired}`. The `status` comment says *"THIS is NOT used ANYMORE, now we use 'hiring_stage'"*. The live concept is the **`hiring_stage_id` FK → HiringStage#kind**. `validates_presence_of :status` is still enforced though.

---

## 2. The SINGLE move path (in-app)

There is **no dedicated "move" interactor or service for the single in-app move.** The move is a plain `JobApplication#update` that changes `hiring_stage_id`. The visit + activity are produced by an **`after_commit` callback on JobApplication**, not by the controller.

### Controller: `app/controllers/api/v1/job_applications_controller.rb#update`
```ruby
def update
  exists(current_organization.job_applications.where(id: params[:id]), 'no job application found') do |job_application|
    authorize job_application.job

    temp_params = job_application_params
    temp_params[:last_updated_by_organization_user_id] = current_organization_user.id

    job_application.skip_hiring_stage_message_automation = temp_params[:skip_hiring_stage_message_automation] if temp_params.key?(:skip_hiring_stage_message_automation)

    if job_application.update(temp_params)
      # resume/textract side effects only
      render_one(job_application, Api::V1::JobApplicationSerializer)
    else
      render_errors(job_application)
    end
  end
end
```
- `job_application_params` = `params.require(:job_application).permit(policy(JobApplication).permitted_attributes)`.
- `permitted_attributes` (policy) includes **`:hiring_stage_id`** and **`:skip_hiring_stage_message_automation`** (and `:stage, :status, :archive_reason, :source`, etc.).
- `last_updated_by_organization_user_id` is set to the acting user — this is the user later read into the visit row as `moved_by_organization_user_id`.
- `skip_hiring_stage_message_automation` is set as a **virtual attribute** (`attribute :skip_hiring_stage_message_automation, :boolean, default: false` on the model) BEFORE the update so the callback chain can read it.

### Model callback (where the side-effects live)
`app/models/job_application.rb`:
```ruby
attribute :skip_hiring_stage_message_automation, :boolean, default: false
attribute :moved_via, :string

before_validation :set_initial_hiring_stage
after_commit :enqueue_new_job_application, on: [:create]
after_commit :track_movement, on: [:update]
after_create :complete_cloning
after_create :add_default_settings
```

```ruby
def track_movement
  if saved_change_to_job_id?
    previous_job_id = job_id_before_last_save
    previous_stage_id = hiring_stage_id_before_last_save
    track_move_to_job(hiring_stage_id, previous_job_id)
    create_hiring_stage_visit(previous_stage_id)
  elsif saved_change_to_hiring_stage_id?
    previous_stage_id = hiring_stage_id_before_last_save
    track_move_to_hiring_stage(hiring_stage_id)
    create_hiring_stage_visit(previous_stage_id)
  end
end
```

**KEY for the new webhooks:** `track_movement` is the single funnel for *every* stage change on an existing record — in-app update, public-API move/archive, move-to-job, and bulk move all land here. The `if/elsif` means a **job change takes precedence**: when `job_id` changes, only the `moved_job` branch runs (a simultaneous stage change does NOT separately fire the `moved_stage` branch). The webhook firing point should mirror this funnel — most likely inside `track_movement` (or just after `create_hiring_stage_visit`).

```ruby
def create_hiring_stage_visit(source_stage_id = nil)
  CreateHiringStageVisit.call(job_application: self, current_hiring_stage_id: hiring_stage_id, source_hiring_stage_id: source_stage_id)
end
```

`set_initial_hiring_stage` (before_validation) assigns the inbox stage on create when `hiring_stage_id` is nil — relevant because the *first* stage assignment happens at create (handled by `handle_new_job_application -> create_hiring_stage_visit` with no source), not via `track_movement`.

### Public API (customer) single move path
`app/controllers/api_public/v1/hire/job_applications_controller.rb`:
- `#move_stage` and `#archive` both: set `last_updated_by_organization_user_id = current_api_key_owner.id`, set `@job_application.moved_via = 'customer_api'`, set `skip_hiring_stage_message_automation` (from `params[:skip_message_automations]`), then `@job_application.update(hiring_stage_id: ...)`.
- `#move_stage` guards: rejects if already in that stage (`hiring_stage_id == hiring_stage.id`), requires `skip_message_automations` boolean param.
- `moved_via` flows into the activity key: `track_move_to_hiring_stage` chooses `'job_application.moved_stage.customer_api'` vs `'job_application.moved_stage'`. This is the existing "where did the move originate" signal the new webhook payload may want to carry.

---

## 3. The MOVE-TO-JOB path

`app/models/job_application.rb`:
```ruby
def move_to_job_at_hiring_stage(hiring_stage_id:, current_organization_user_id:)
  target_hiring_stage = job.organization.hiring_stages.find(hiring_stage_id)
  target_job = target_hiring_stage.job
  return unless target_hiring_stage

  if target_job.candidates.where(id: candidate_id).any?
    errors.add(:candidate, :taken, message: 'already exists in that job')
  else
    update(job_id: target_hiring_stage.job_id, hiring_stage_id: target_hiring_stage.id, last_updated_by_organization_user_id: current_organization_user_id)
  end
end
```
Controller `#move_to_job` calls it then renders. The `update` changes both `job_id` and `hiring_stage_id` → `track_movement`'s `saved_change_to_job_id?` branch runs → `track_move_to_job` + `create_hiring_stage_visit(previous_stage_id)`.

---

## 4. The BULK move path

### Route
`config/routes.rb:258` → `resources :bulk_move_job_applications_to_stage, only: [:create]` (under `/api/v1`). PUT/POST to `/api/v1/jobs/:job_id/bulk_move_job_applications_to_stage`.

### Controller — `app/controllers/api/v1/bulk_move_job_applications_to_stage_controller.rb`
```ruby
class Api::V1::BulkMoveJobApplicationsToStageController < Api::V1::BaseController
  include RoleFitFilterable

  def create
    result = ValidatePlanAccess.call(organization: current_organization, feature: PlanFeatureGate::BULK_MOVE)
    if result.success?
      @job = current_organization.jobs.find(params[:job_id])
      authorize(@job, :on_hiring_team?)

      ids_to_move = []
      if bulk_params[:included_job_application_ids].present?
        ids_to_move = bulk_params[:included_job_application_ids]
      elsif bulk_params[:excluded_job_application_ids].present?
        stage = @job.hiring_stages.find(bulk_params[:source_hiring_stage_id])
        all_ids = apply_role_fit_filter(stage.job_applications, bulk_params[:role_fit]).pluck(:id)
        ids_to_move = all_ids - bulk_params[:excluded_job_application_ids]
      else
        stage = @job.hiring_stages.find(bulk_params[:source_hiring_stage_id])
        ids_to_move = apply_role_fit_filter(stage.job_applications, bulk_params[:role_fit]).pluck(:id)
      end

      update_params = {
        hiring_stage_id: bulk_params[:target_hiring_stage_id],
        last_updated_by_organization_user_id: current_organization_user.id,
        skip_hiring_stage_message_automation: bulk_params[:skip_hiring_stage_message_automation]
      }

      if current_organization.job_applications.where(id: ids_to_move).update(update_params)
        @job.reset_counters
        render json: { success: true, moved_count: ids_to_move.size }, status: :ok
      else
        render_general_errors(['Unable to move these candidates'])
      end
    else
      render json: { error: result.message }, status: :unprocessable_entity
    end
  end

  private

  def bulk_params
    params.require(:bulk_move_job_applications_to_stage).permit(:target_hiring_stage_id, :source_hiring_stage_id, :skip_hiring_stage_message_automation, included_job_application_ids: [], excluded_job_application_ids: [], role_fit: [])
  end
end
```

### Bulk param shape (server-side resolution — matches Failure-Pattern #14 analog)
`params.require(:bulk_move_job_applications_to_stage).permit(...)`:
- `:target_hiring_stage_id` — destination stage (note: **target_**, not bare `hiring_stage_id`).
- `:source_hiring_stage_id` — origin stage, used to resolve "select all" against the role-fit-filtered list.
- `:skip_hiring_stage_message_automation`
- `included_job_application_ids: []` — explicit selection
- `excluded_job_application_ids: []` — select-all-minus-exclusions
- `role_fit: []` — passed to `RoleFitFilterable#apply_role_fit_filter` so select-all matches the visible filter.

Resolution precedence: included → (else) excluded against role-fit-filtered source-stage set → (else) entire role-fit-filtered source-stage set.

### CRITICAL: bulk move DOES run per-record callbacks
`current_organization.job_applications.where(id: ids_to_move).update(update_params)` is **`ActiveRecord::Relation#update(attributes)`** (relation form, no id arg). It loads each record and calls `#update` individually → validations + `after_commit :track_movement` fire **once per job application**. It is **NOT** `update_all` (which would skip callbacks). Therefore: every bulk move emits a `HiringStageVisit` per JA, a `moved_stage` activity per JA, and (if not skipped) a `HiringStageMessageAutomationJob` per JA. The new webhook, if placed in `track_movement`, will likewise fire once per JA in a bulk move — confirm that fan-out is desired/throttled.

There is **no background Job** for the bulk move itself — it's synchronous in the request. (Contrast Failure-Pattern #14's bulk AI summaries which uses a Job.) `@job.reset_counters` recomputes `job_applications_count` on each HiringStage afterward.

---

## 5. WHERE HiringStageVisit rows are CREATED (the new webhook's neighbor)

### Interactor — `app/interactors/create_hiring_stage_visit.rb`
```ruby
class CreateHiringStageVisit
  include Interactor

  def call
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

**Called from exactly two places** (`grep CreateHiringStageVisit app/` → only `job_application.rb`):
1. `JobApplication#handle_new_job_application` → `create_hiring_stage_visit` (no source) — the **initial** visit when an application is first created/lands in inbox.
2. `JobApplication#track_movement` → `create_hiring_stage_visit(previous_stage_id)` — **every subsequent move**.

### HiringStageVisit columns (db/schema.rb ~line 623)
```
job_application_id          bigint  NOT NULL
current_hiring_stage_id     bigint  NOT NULL
source_hiring_stage_id      bigint  (nullable)
current_stage_name_at_move  string  NOT NULL   # denormalized stage name snapshot
moved_by_organization_user_id bigint (nullable)
created_at / updated_at
```
Note `skip_hiring_stage_message_automation` is passed to `.build` but is a **virtual attribute** (`attribute :skip_hiring_stage_message_automation, :boolean, default: false` on the model) — it is NOT a column; it only gates the after_commit handler. `current_stage_name_at_move` is a denormalized snapshot of the stage name at move time. The model carries a commented-out `source_hiring_stage` association (only `current_hiring_stage` is active).

### HiringStageVisit model + its own after_commit
```ruby
class HiringStageVisit < ApplicationRecord
  attribute :skip_hiring_stage_message_automation, :boolean, default: false

  belongs_to :job_application
  belongs_to :current_hiring_stage, class_name: 'HiringStage'

  after_commit :enqueue_automation_handler, on: :create

  def enqueue_automation_handler
    return if skip_hiring_stage_message_automation
    return unless message_automation.present?

    HiringStageMessageAutomationJob.perform_later(id, message_automation.id)
  end

  def message_automation
    current_hiring_stage.active_message_automation
  end
end
```

So there are **two layered `after_commit` hooks** in a move:
- `JobApplication after_commit :track_movement, on: :update` → creates the visit row.
- `HiringStageVisit after_commit :enqueue_automation_handler, on: :create` → enqueues the message automation job.

This `HiringStageVisit after_commit` is the **closest structural analog** for "fire a side effect when a move is committed." A move-stage webhook could be enqueued here (visit row is the canonical record of a move and carries source + destination + actor + timestamp), OR in `track_movement` alongside `create_hiring_stage_visit`.

---

## 6. Existing after_commit callbacks & downstream side-effects on a move

Full enumeration of what currently happens on a committed stage move:

| # | Side-effect | Where | Notes |
|---|---|---|---|
| 1 | **Activity feed entry** (PublicActivity) | `track_move_to_hiring_stage` / `track_move_to_job` → `create_activity_for_movement` → `create_activity` | key = `job_application.moved_stage` (or `.customer_api` variant) / `job_application.moved_job`. Params include job_title, job_id, hiring_stage_id, hiring_stage_name, candidate_full_name, navigation_url, user{...}, `moved_via` (default `'user_in_app'`). |
| 2 | **HiringStageVisit row** | `create_hiring_stage_visit` → `CreateHiringStageVisit` interactor | source + destination + actor + name snapshot. |
| 3 | **Message automation** (auto-send templated channel message) | `HiringStageVisit#enqueue_automation_handler` → `HiringStageMessageAutomationJob` | gated by `skip_hiring_stage_message_automation` and `current_hiring_stage.active_message_automation`. |

There is currently **NO webhook fired on a hiring-stage move.** The only registered-webhook fires are `new_job_application` (on JobApplication create) and `new_published_job` (on Job publish). The three new webhooks are net-new at this trigger surface.

### The message-automation chain (full structural analog for "side effect on move")
`app/jobs/hiring_stage_message_automation_job.rb#perform(hiring_stage_visit_id, automation_id)`:
- Loads `HiringStageVisit`, its `job_application`, and the acting `@org_user` (`last_updated_by_organization_user_id`).
- Guards: `return unless hiring_stage_visit.current_hiring_stage_id == automation.hiring_stage_id`; `return unless automation.should_trigger?(...)`.
- `ChannelMessages::CreateStageAutomationMessage.call(...)` to send; on success `CreateStageAutomationEvent.call(automation:, hiring_stage_visit_id:)` records a `HiringStageAutomationEvent`.
- Errors broadcast a growl to the user via `GlobalChannel.broadcast_to`.

`HiringStageMessageAutomation` (`app/models/hiring_stage_message_automation.rb`): `belongs_to :hiring_stage, :job, :channel_message_template`; `enum frequency: {once, every_time}`; `scope :enabled`; `should_trigger?` = enabled AND (`every_time` OR `once`-with-zero-prior-events). `HiringStage#active_message_automation = hiring_stage_message_automations.kept.enabled.first`. Validation forbids automations on `kind_inbox` stages.

`HiringStageAutomationEvent` (`app/models/hiring_stage_automation_event.rb`): `belongs_to :hiring_stage_visit, :automation (polymorphic)` — dedup ledger so `frequency_once` fires only once per JA (joined through visits).

---

## 7. The EXISTING webhook system (the structural analog to copy for the 3 new webhooks)

### Model — `app/models/registered_webhook.rb`
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
Schema (`registered_webhooks`): `kind:int NOT NULL`, `url:string NOT NULL`, `owner_id:bigint NOT NULL`, `owner_type:string NOT NULL`, timestamps. `Organization has_many :registered_webhooks, as: :owner` (owner is always the Organization in practice). **NOTE:** uniqueness validation on `kind` is commented out — multiple rows of the same kind are technically allowed at the model level, though the `all`/`find_or_initialize_by` controller flow treats one-per-kind. The three new webhook kinds would be added to this enum (next integers 2,3,4).

### Fire site pattern (the exact shape the new webhooks must follow)
`new_published_job` (`app/models/job.rb#handle_status_changed_to_published`, ~558):
```ruby
new_published_job_webhook = organization.registered_webhooks.find_by(kind: :new_published_job)
RegisteredWebhooks::NewJobPublishedJob.perform_later(id, new_published_job_webhook.id) if new_published_job_webhook.present?
```
`new_job_application` (`app/models/job_application.rb#send_notifications`, ~230):
```ruby
new_job_application_webhook = job.organization.registered_webhooks.find_by(kind: :new_job_application)
RegisteredWebhooks::NewJobApplicationJob.perform_later(id, new_job_application_webhook.id) if new_job_application_webhook.present?
```
Structural rule: `find_by(kind:)` on the org's registered_webhooks, then `perform_later(record_id, webhook.id)` **only if a webhook of that kind is registered** (no-op otherwise).

### Job — `app/jobs/registered_webhooks/new_job_application_job.rb`
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
Structural traits each webhook job shares (collected from `NewJobApplicationJob` + `NewJobPublishedJob`):
- `< ApplicationJob`, `queue_as :default`.
- `perform(subject_id, registered_webhook_id)` — two positional ids.
- Re-find both records; **ownership guard** `return unless subject.org_id == registered_webhook.owner_id`.
- `Faraday.post(registered_webhook.url, <Serializer>.new(subject))`.
- Two rescues: `ActiveRecord::RecordNotFound` (logs ids via `ap`) then `StandardError` (logs `ap e`). No retry/exhaustion block. (`NewJobPublishedJob` additionally calls `job.reload` before serializing — violates the no-`reload` rule but exists in the analog.)

### Serializer pattern (`ActiveModel::Serializer`)
`Api::V1::RegisteredWebhooks::JobApplicationSerializer`: attributes `:event_type, :id, :url, :job_title, :source, :created_via, :resume_url`; `has_one :candidate` (Zapier candidate serializer); `has_many :question_responses` (public only); `event_type` method returns the literal string `'new_job_application'`; `url` = `object.permalink_url`. `PublishedJobSerializer` similarly defines `event_type => 'new_published_job'`. Each new move webhook needs its own `Api::V1::RegisteredWebhooks::<X>Serializer` with an `event_type` string matching its enum name.

### Config surface — `app/controllers/api/v1/registered_webhooks_controller.rb`
CRUD + an `all` batch action (`find_or_initialize_by(kind:)`, set url, destroy when blank+persisted, else save). `registered_webhook_params = params.permit(:url, :kind)`. Serialized by `Api::V1::RegisteredWebhookSerializer` (attributes `:id, :url, :kind`). Frontend hook: `app/javascript/shared/queryHooks/useRegisteredWebhooks.ts` (`GET/POST/PUT/DELETE /registered_webhooks`, `POST /registered_webhooks/all`). Adding new kinds requires the enum addition + frontend exposing the new kind options; no schema change to `registered_webhooks` (kind is already an int).

---

## 8. Move create/update lifecycle & order of operations (single in-app move)

1. Controller `#update` authorizes the job, sets `last_updated_by_organization_user_id`, sets virtual `skip_hiring_stage_message_automation`.
2. `JobApplication#update(hiring_stage_id: new_id, ...)`:
   a. `before_validation :set_initial_hiring_stage` (no-op when stage already present).
   b. Validations (`validates_presence_of :status`, attachment validations, candidate uniqueness).
   c. DB UPDATE committed.
3. `after_commit :track_movement, on: :update` fires:
   a. `saved_change_to_hiring_stage_id?` true (and `saved_change_to_job_id?` false) → stage branch.
   b. `track_move_to_hiring_stage(hiring_stage_id)` → `create_activity_for_movement` → `create_activity` (PublicActivity row, key `job_application.moved_stage[.customer_api]`).
   c. `create_hiring_stage_visit(previous_stage_id)` → `CreateHiringStageVisit` builds + `visit.save` (INSERT into `hiring_stage_visits` with source, destination, `current_stage_name_at_move`, `moved_by_organization_user_id`).
   d. `HiringStageVisit after_commit :enqueue_automation_handler, on: :create` → unless skipped and an `active_message_automation` exists → `HiringStageMessageAutomationJob.perform_later(visit.id, automation.id)`.
4. Controller renders `Api::V1::JobApplicationSerializer`.

**Ordering implication for the new webhooks:** the JA row is already committed when `track_movement` runs; the visit row is created inside `track_movement` and is itself committed before its own `after_commit` runs. A webhook enqueued in `track_movement` (after `create_hiring_stage_visit`) will have both the updated JA and the new visit persisted. A webhook enqueued from `HiringStageVisit#after_commit` would have access to the visit's source/destination/actor/snapshot directly. The `if/elsif` in `track_movement` means a move that also changes `job_id` won't fire the stage-move branch — decide explicitly whether a move-to-job should also emit a stage-move webhook.
