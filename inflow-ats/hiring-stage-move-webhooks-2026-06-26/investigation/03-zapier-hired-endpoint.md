# Zapier Pull Endpoint — "added to hiring stage = hired" (job_applications poll)

## File chain traced

```
config/routes.rb (lines 425-461: namespace :integrations -> resources :zapier_integrations)
  -> app/controllers/api/v1/integrations/zapier_integrations_controller.rb
       -> app/models/organization.rb (zapier_api_key column; jobs / job_applications assoc)
       -> app/models/job_application.rb (hiring_stage assoc, created_via enum,
                                         created_via_manual_enum_values, permalink_url,
                                         resume_url, source column, public_question_responses)
       -> app/models/hiring_stage.rb (enum kind: { ... kind_hired: 3 })
       -> app/serializers/api/v1/zapier_integrations/job_application_serializer.rb
            -> app/serializers/api/v1/zapier_integrations/candidate_serializer.rb
            -> app/serializers/api/v1/zapier_integrations/question_response_serializer.rb
       (published_jobs path -> .../published_job_serializer.rb, app/models/job.rb)
db/schema.rb (hiring_stages.kind integer default 0; job_applications.source string,
              created_via integer default 0, hiring_stage_id bigint)
```

---

## IMPORTANT: this is NOT the public `api.polymer.co` API

The Zapier endpoint is **not** in the `ApiPublic::V1::Hire::` namespace that `cursor_rules/backend/public_api_controllers.md` governs. It is an **internal-tree integration controller** under `Api::V1::Integrations::` that serves Zapier directly. It does **not** inherit from `ApiPublic::V1::Hire::BaseController`, does **not** use `api_policy_scope`, does **not** use the public-API error helpers / pagination meta, and authenticates with a **plain per-organization API key header** (`X-API-KEY`), not a Bearer token. Read the "How this relates to public_api_controllers.md" section at the bottom before assuming the public-API conventions apply here.

---

## 1. Route + auth

### Route (config/routes.rb)

The endpoints live inside `namespace :api -> namespace :v1 -> namespace :integrations` (line 69, 70, 434), so the URL prefix is `/api/v1/integrations`:

```ruby
resources :zapier_integrations, only: [] do
  collection do
    get :published_jobs, to: 'zapier_integrations#published_jobs'
    get :job_applications, to: 'zapier_integrations#job_applications'
    get :verify_auth, to: 'zapier_integrations#verify_auth'
  end
end
```

Final paths:
- `GET /api/v1/integrations/zapier_integrations/job_applications`  ← the candidate poll
- `GET /api/v1/integrations/zapier_integrations/published_jobs`
- `GET /api/v1/integrations/zapier_integrations/verify_auth`

### Controller class + auth (app/controllers/api/v1/integrations/zapier_integrations_controller.rb)

It inherits from **`ActionController::Base`** (not from any app `BaseController`, not from `ApiPublic` base):

```ruby
class Api::V1::Integrations::ZapierIntegrationsController < ActionController::Base
  before_action :authenticate
  ...
  private

  def authenticate
    api_key = request.headers['X-API-KEY']
    @organization = Organization.find_by(zapier_api_key: api_key)
    render json: {}, status: 401 if @organization.nil?
  end
```

Auth model: a single opaque `zapier_api_key` string per `Organization`, passed in the `X-API-KEY` request header. `find_by` resolves the owning org; nil org -> `401 {}`. There is **no Pundit, no Devise, no policy scope** — the org is the scope, and every query is rooted on `@organization`.

`verify_auth` exists purely so Zapier's "Connect account" test can confirm the key:

```ruby
def verify_auth
  render json: { organization_name: @organization.name }, status: 200
end
```

### Pagination

Custom, **not** Kaminari-paginated meta. `current_page` is offset by 1 because Zapier pages are 0-indexed:

```ruby
def current_page
  return 1 unless params[:page]
  params[:page].to_i + 1
end
```

`job_applications` caps page size at 100 via `.page(current_page).per(100)`. No `total_pages` / `is_last` meta is emitted — it is a bare serialized array (Zapier polls until it sees no new IDs).

---

## 2. THE HIRED QUERY — how "is hired / was added to hired" is determined

### The action (full method)

```ruby
def job_applications
  job_applications = @organization.job_applications.order(created_at: :desc)
                                  .includes([
                                              :job,
                                              :candidate,
                                              { resume_attachment: :blob },
                                              { public_question_responses: [:question, { custom_file_attachment: :blob }] }
                                            ])

  if params[:stage_kind]
    job_applications = job_applications.joins(:hiring_stage).where(hiring_stages: { kind: params[:stage_kind] })
  end

  if params[:created_via]
    job_applications = job_applications.where(created_via: created_via_filter)
  end

  job_applications = job_applications.page(current_page).per(100)

  render json: job_applications, each_serializer: Api::V1::ZapierIntegrations::JobApplicationSerializer
end
```

### How "hired" is identified — the exact mechanism

There is **no `HiringStageVisit` query and no "was-ever-added-to-hired" history check here.** "Hired" means the job application's **current** `hiring_stage` has `kind = kind_hired`. The determination is:

```ruby
job_applications.joins(:hiring_stage).where(hiring_stages: { kind: params[:stage_kind] })
```

- `JobApplication belongs_to :hiring_stage` (its current stage, the `hiring_stage_id` FK column).
- The join goes to the `hiring_stages` table and filters on the **`kind` enum integer column**.
- The Zapier client passes `stage_kind` to select which kind. For the "hired" trigger, Zapier sends **`stage_kind=kind_hired`**.

Important enum-mechanics detail: `HiringStage.kind` is an `enum kind: { kind_inbox: 0, ..., kind_hired: 3 }`. ActiveRecord's `.where(hiring_stages: { kind: params[:stage_kind] })` accepts the **string enum key** (`"kind_hired"`) and translates it to the underlying integer `3` for the SQL. So the wire value is the string `"kind_hired"`, the DB value is integer `3`. (Passing the raw integer string `"3"` would NOT resolve through the enum mapping the same way — the contract is the string key.)

So "added to hiring stage = hired" is detected purely as **"current hiring_stage.kind == kind_hired."** A candidate that was moved to hired and then moved out again would NOT appear; this is a current-state poll, not an event/visit history poll. That is the key semantic difference to be aware of when designing the new webhooks (which presumably want the *transition event*, captured by `HiringStageVisit`, not just current state).

### The `kind` enum (app/models/hiring_stage.rb) — the canonical "hired" identifier in code

```ruby
enum kind: {
  kind_inbox: 0,
  kind_in_process: 1,
  kind_archived: 2,
  kind_hired: 3,
}
```

This is the authoritative definition of how "hired" is named in code: the symbol/string **`kind_hired`** (integer `3`). The codebase consistently references hired stages this way:
- `HiringStage.kind_hired` (enum class scope — returns all hired-kind stages)
- `HiringStage#kind_hired?` (predicate)
- `HiringStage.ordered` orders `kind_inbox -> kind_in_process -> kind_hired -> kind_archived`
- Schema: `t.integer "kind", default: 0` on `hiring_stages` — default is `kind_inbox`.

Note a related but distinct in-process reference style elsewhere in JobApplication (uses the **string** key, not the predicate): `job.hiring_stages.where(kind: 'kind_in_process')`. Both `where(kind: 'kind_hired')` and `.kind_hired` are valid; reuse `where(kind: :kind_hired)` for queries and `.kind_hired?` for record checks.

### Secondary filter — `created_via`

```ruby
if params[:created_via]
  job_applications = job_applications.where(created_via: created_via_filter)
end

def created_via_filter
  case params[:created_via]
  when "all"
    return JobApplication.created_via.values
  when "job_board_only"
    return JobApplication.created_via[:created_via_job_board]
  when "manual_only"
    return JobApplication.created_via_manual_enum_values
  else
    return JobApplication.created_via.values
  end
end
```

Backing enum + helper on JobApplication:

```ruby
enum created_via: {
  created_via_manual_add: 0,
  created_via_job_board: 1,
  created_via_api: 2,
  created_via_referral: 3,
  created_via_bulk_manual_add: 4,
  created_via_clone: 5,
  created_via_customer_api_apply: 6,
  created_via_customer_api_import: 7
}

def self.created_via_manual_enum_values
  [created_via[:created_via_manual_add], created_via[:created_via_bulk_manual_add]]
end
```

This filter is orthogonal to the hired filter and is just an extra knob in the Zapier UI (filter by source of the application). It passes raw integer enum values into `.where`, not string keys.

---

## 3. The response serializer (quoted in full)

### app/serializers/api/v1/zapier_integrations/job_application_serializer.rb

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

Field-by-field, what it exposes and where each comes from:

| API field | Source | Notes |
|---|---|---|
| `id` | `JobApplication#id` | raw PK |
| `url` | `object.permalink_url` | `"#{Variables::AtsRootUrl}/applicants/#{hash_id}"` — applicant page link |
| `job_title` | `object.job.title` | from the `belongs_to :job` |
| `source` | `JobApplication#source` (string column) | free-text source string on the application |
| `created_via` | `JobApplication#created_via` enum | serialized as the **string key** (e.g. `"created_via_job_board"`) |
| `resume_url` | `JobApplication#resume_url` | see below; returns nil when no resume |
| `candidate` | nested `CandidateSerializer` | `has_one` |
| `question_responses` | `object.public_question_responses` | `has_many`, public-visibility responses only |

`permalink_url` (app/models/job_application.rb:466):

```ruby
def permalink_url
  "#{Variables::AtsRootUrl}/applicants/#{hash_id}"
end
```

`resume_url` (app/models/job_application.rb:628):

```ruby
def resume_url
  return unless has_resume

  resume_version = has_resume_docx_to_pdf ? resume_docx_to_pdf : resume
  Variables::AtsRootUrl + Rails.application.routes.url_helpers.rails_blob_path(resume_version, only_path: true)
end
```

**Notably absent:** the serializer exposes **NO hiring-stage fields at all** — no stage id, no stage name, no `kind`. The "hired" semantics are entirely encoded in the server-side `stage_kind` query filter; the payload itself does not tell the consumer which stage the application is in. For the new webhooks, if the consumer needs to know the destination stage name/kind, that has to be added — this endpoint does not model it.

### Nested: app/serializers/api/v1/zapier_integrations/candidate_serializer.rb

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

Social URLs are delegated to `*_pretty` helpers and guarded with `.present?` (returns nil if the raw field is blank). `first_name`, `last_name`, `full_name`, `email`, `phone`, `location` are exposed raw from `Candidate`.

### Nested: app/serializers/api/v1/zapier_integrations/question_response_serializer.rb

```ruby
class Api::V1::ZapierIntegrations::QuestionResponseSerializer < ActiveModel::Serializer
  attributes :body, :question_text

  def question_text
    object.question.question_text
  end
end
```

`public_question_responses` is `has_many :public_question_responses, -> { with_public_visibility }, class_name: 'QuestionResponse'` on JobApplication — only publicly-visible responses are serialized.

### (Adjacent, for completeness) published_job_serializer.rb

```ruby
class Api::V1::ZapierIntegrations::PublishedJobSerializer < ActiveModel::Serializer
  attributes :id, :title, :url, :description, :description_without_html, :social_share_image_url

  def description
    object.html_safe_description
  end

  def url
    object.job_application_description_url
  end
end
```

---

## 4. Reusable hiring-stage code patterns (what to copy for the new webhooks)

**Identifying "hired" in code — reuse exactly:**
- Stage kind enum lives on `HiringStage`: `enum kind: { kind_inbox: 0, kind_in_process: 1, kind_archived: 2, kind_hired: 3 }`. The string/symbol token for hired is **`kind_hired`**.
- Query for hired applications: `job_applications.joins(:hiring_stage).where(hiring_stages: { kind: :kind_hired })` (pass the enum **key**, not the integer).
- Record-level check on a stage: `hiring_stage.kind_hired?`.
- Class scope for hired stages: `HiringStage.kind_hired`.

**Current-stage vs. transition-event — the design decision the new webhooks must make:**
- This endpoint uses `JobApplication belongs_to :hiring_stage` (the **current** stage FK `hiring_stage_id`). It is a *current-state* filter.
- The **transition** is recorded separately by `HiringStageVisit` (`app/models/hiring_stage_visit.rb`): `belongs_to :job_application`, `belongs_to :current_hiring_stage, class_name: 'HiringStage'`, with a (commented-out) `source_hiring_stage` and an `after_commit :enqueue_automation_handler, on: :create` callback. Visits are created via `CreateHiringStageVisit.call(...)` from `JobApplication#create_hiring_stage_visit`, fired by the `saved_change_to_hiring_stage_id?` after-callback. If the new webhooks need to fire on the *move into hired* (an event), the `HiringStageVisit` after_commit-on-create path — filtered by `current_hiring_stage.kind_hired?` — is the structural analog, **not** this poll query.

**Org scoping pattern:** root every query on `@organization` resolved from the `X-API-KEY` header (`Organization.find_by(zapier_api_key: ...)`), no Pundit. Eager-load with `.includes([...])` for everything the serializer touches.

---

## 5. How this relates to cursor_rules/backend/public_api_controllers.md

Those rules govern `ApiPublic::V1::Hire::` controllers (Bearer-token, `api_policy_scope`, `render_public_api_error`, `render_paginated` with `total_pages`/`is_last` meta, serializers under `app/serializers/api_public/v1/hire/`). **The Zapier controller follows essentially NONE of them** — it predates / sits outside that convention set:

| public_api rule | Zapier controller |
|---|---|
| Bearer token + `current_api_organization` | `X-API-KEY` header -> `Organization.find_by(zapier_api_key:)` |
| `api_policy_scope(Model)` | direct `@organization.job_applications` |
| `render_public_api_error` codes | bare `render json: {}, status: 401` |
| `render_paginated` w/ meta keys | custom `current_page` (+1 offset), bare array, no meta |
| serializers in `app/serializers/api_public/v1/hire/` | serializers in `app/serializers/api/v1/zapier_integrations/` |
| `validate_params` allowlist | none — reads `params[:stage_kind]`, `params[:created_via]`, `params[:page]` directly |
| inherits `ApiPublic::V1::Hire::BaseController` | inherits raw `ActionController::Base` |

Takeaway for the new work: if the new hiring-stage-move webhooks are meant to extend the **Zapier** integration, match the `Api::V1::Integrations::ZapierIntegrationsController` conventions above (X-API-KEY, org-rooted queries, `zapier_integrations` serializer namespace, custom paging). If they are meant for the **public customer API**, follow `public_api_controllers.md` instead. These are two different surfaces — confirm which one the webhook lives on before copying patterns.
