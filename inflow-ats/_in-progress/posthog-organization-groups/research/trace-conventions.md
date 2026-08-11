# House conventions for new PostHog-groups code — inflow-ats (branch `ai-credit-posthog-events`)

## 1. File chain traced

**Rules files**
```
/Users/jessica/wrk/wrk-corp/inflow-ats/.claude/CLAUDE.md
  → cursor_rules/core_critical_rules.md
  → cursor_rules/backend/_base.md
  → cursor_rules/frontend/_base.md
  → cursor_rules/backend/background_jobs.md
  → cursor_rules/backend/services.md
  → cursor_rules/backend/interactors/interactor_patterns_and_structure.md
  → cursor_rules/backend/interactors/interactor_usage_and_guidelines.md
  → cursor_rules/frontend/react_hooks.md
```
There is **no `CLAUDE.md` at the repo root** — the file is at `/Users/jessica/wrk/wrk-corp/inflow-ats/.claude/CLAUDE.md` (545 lines, read in full). `cursor_rules/core_critical_rules.md` (430 lines) is a near-duplicate with different numbering; both were read in full.

**Code chain (backend PostHog path)**
```
app/jobs/application_job.rb
  → app/jobs/posthog_track_job.rb → app/services/posthog/track.rb
  → app/jobs/posthog_identify_job.rb → app/services/posthog/identify.rb
      → config/initializers/posthog.rb (POSTHOG_CLIENT)
          → config/initializers/01_variables.rb (Variables::POSTHOG_API_KEY, POSTHOG_HOST)
              → config/application.rb:82 (Rails.configuration.x.RailsCredentialsEnv)
          → gem posthog-ruby 2.11.0 lib/posthog/client.rb + lib/posthog/field_parser.rb  [gem boundary]
app/models/subscription_event.rb → app/jobs/posthog_track_job.rb
app/jobs/track_new_sso_owner_signup_job.rb → app/models/user.rb#attribution_properties
```

**Code chain (non-AI job/interactor convention sources)**
```
app/jobs/notify_user_job.rb
app/jobs/heroku_domain_job.rb → config/initializers/01_variables.rb (Variables::HEROKU_APP_NAME)
app/jobs/webflow_sync_one_job.rb
app/jobs/export_job_resumes_to_zip_job.rb
app/jobs/get_resume_text_from_textract_job.rb → app/errors/custom_error_textract.rb
app/interactors/create_subscription_event.rb
app/interactors/create_hiring_stage_visit.rb
app/interactors/create_comment.rb
```

**Code chain (frontend)**
```
app/views/layouts/application.html.erb:78-79
  → app/javascript/ats/src/views/layouts/App.tsx
      → app/javascript/shared/PostHogContext.tsx
          → app/javascript/shared/lib/posthog.ts
      → app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:44,163-177
  → package.json (posthog-js 1.297.4, @posthog/react 1.0.0)  [npm boundary]
```

**`cursor_rules/` directory listing**
```
cursor_rules/
├── console_commands.md
├── core_critical_rules.md
├── public_api_controller_rules.md
├── backend/
│   ├── _base.md
│   ├── architecture.md
│   ├── background_jobs.md
│   ├── code_style_and_structure.md
│   ├── core_critical_rules.md
│   ├── migrations.md
│   ├── public_api_controllers.md
│   ├── serializers.md
│   ├── services.md
│   ├── controllers/
│   │   ├── controller_error_handling.md
│   │   ├── controller_patterns_and_crud.md
│   │   └── pundit_policies.md
│   ├── interactors/
│   │   ├── interactor_patterns_and_structure.md
│   │   └── interactor_usage_and_guidelines.md
│   └── job_board_integration/
├── cypress/
│   ├── core_critical_rules.md
│   ├── cypress_assertions_and_antiflake.md
│   ├── cypress_common_pitfalls.md
│   ├── cypress_selectors_and_interactions.md
│   ├── cypress_test_structure_and_setup.md
│   └── cypress_troubleshooting.md
└── frontend/
    ├── _base.md
    ├── boolean_variables_and_naming.md
    ├── core_critical_rules.md
    ├── react_hooks.md
    ├── reference_patterns.md
    ├── ui_styling.md
    ├── components/  contexts/  forms/  lists/  modals/  react_query/
```

---

## 2. Rules that bear on PostHog-groups work

Citations are `cursor_rules/core_critical_rules.md` (**CCR**) and `.claude/CLAUDE.md` (**CM**), plus `cursor_rules/backend/_base.md` (**BB**), `background_jobs.md` (**BJ**), `services.md` (**SVC**).

### Adding a new ActiveJob
- **BJ §0a** naming `{action}_{resource}_job.rb`, action verb first: "`❌ WRONG naming` … `slack_notify_job.rb  # Action should be first`". Existing PostHog jobs violate this (`PosthogTrackJob`, `PosthogIdentifyJob`) — the established *local* family prefix is `Posthog…Job`, and `TrackNewSsoOwnerSignupJob` follows the verb-first rule.
- **BJ §0b** "Always Use Background Jobs For: 1. **External API calls** - Any sync operation with 3rd party services."
- **BJ §1** "Jobs accept IDs as parameters and load fresh records from the database… `❌ WRONG - Don't pass objects`."
- **BJ §2** "Use `find_by(id:)` instead of `find`" + guard clause.
- **BJ §3** "Jobs Orchestrate — Don't Contain Business Logic. Delegate actual work to models or services."
- **BJ §4** "Use `rescue StandardError` at the end of the `perform` method."
- **BJ Logging** "Use `ap` for general logging (works in production). In rescue blocks: use BOTH `ap` and `Rails.logger.error`. Don't re-raise (job completes, doesn't retry)."
- **CCR 1 / CM 1 / BB 1** no `begin` blocks — method-level rescue.
- **BB 2** rescue the most specific class; `StandardError` only as fallback; never `Exception`.
- **BB 3 / CM 15** never rescue at class or module level.
- **BB 4** never leave a rescue empty.
- **BB 5 / CM 16** `=> e` or `=> exc` only — never `=> error` / `=> exception`.
- **BB 6** avoid `ensure`.
- **CM 0a** "**Never write a new RSpec spec file. Never add examples to an existing one.**"

### Adding an `after_commit` callback
- **BJ §5** "Prefer `after_commit` Over `after_save` for Triggering Jobs… The key rule is: don't enqueue a job inside an uncommitted transaction."
- Interactor rules, *Usage Patterns → From Models*: "Use when logic spans multiple models OR when controller + callback do similar things… `after_update_commit :sync_external_listing, if: :should_sync?`… delegate to interactor."
- **CM 17 / BB 8** "No `reload` in Application Code."
- **CM (User Interaction)** "You may make feature-related changes to `app/models/organization.rb` (adding methods, enum values, callbacks) but do NOT fix formatting, linting, or style issues in that file." (CCR's older wording says "Do not automate edits to `app/models/organization.rb`" — the `.claude/CLAUDE.md` version is the current one.)

### Adding a service / interactor
- **SVC "When to Use Services"**: "**External API integration** - `cloudflare_client.rb`, `webflow_api.rb`, `what_jobs_api.rb`". A PostHog groups call is an external API integration → **service**, not interactor.
- **SVC 1** "**CRITICAL**: Never include 'Service' in the class name." **CCR File Naming**: "Services: `snake_case.rb` - **NEVER include 'service' in filename**".
- **SVC 2** "Use Descriptive Public Method Names — Not `call` or `execute`… (`call` is okay reserved for interactors)."
- **SVC 3** "Pass IDs When Called from Background Jobs, Objects in Request Cycle."
- **SVC 5** "Use Keyword Arguments for Clarity: `def initialize(organization:, previous_plan: nil)`."
- **SVC 6** "Use `find_by` Not `find` When IDs Might Be Invalid."
- **SVC "Namespacing Patterns"** — `app/services/module_name/` directory for complex modules; `Posthog::Track` / `Posthog::Identify` already live at `app/services/posthog/`.
- **SVC final line**: "**IMPORTANT**: If you plan to use these patterns [service calling another service, service queueing a background job], explicitly state this to the user before implementing."
- Interactor rules: `include Interactor`, `def call`, everything through `context`, `context.fail!(error: '…')`, error messages carry the offending values.

### Calling a third-party API
- **BJ §0b** — must go through a background job (exception only when the vendor is already async, e.g. Mailgun `send_later`).
- **SVC "Error Handling → Method-Level Rescue for Silent Failures"**: "When service should not crash calling code" — the PostHog services follow this exactly.
- **SVC "Raising Exceptions for Retry Logic"**: raise to trigger job retry (this is what `CustomErrorTextract` does).

### Adding a credential to `config/initializers/01_variables.rb`
- No cursor_rules file governs this; the convention is the file itself (see §5). Global charter rule: it is a **credential registry**, one entry per secret/per-environment value, never collapsed for DRY.
- The gate pattern in `config/initializers/posthog.rb:5` (`if Variables::POSTHOG_API_KEY.present?`) means every consumer must tolerate `POSTHOG_CLIENT` being `nil`.

### Naming variables for DB records
- **CM 18 / CCR "Variable Naming for Records" / BB 9**: "Use the full model name in snake_case — `existing`, `record`, `item`, `entry`, `row`, `txn`, `ledger`, `transaction`, `purchase`, `latest` are never acceptable as standalone variable names for database-backed records." BB 9 adds: "Never shorten `JobApplication` to `application`."
- For groups work this means `organization`, not `org` or `group`.

### Guard clauses
- **CCR 8 / CM 8 / BB (via SVC "Guard Clauses with Early Returns")**: "Guard clauses should use bare `return` — do not return truthy or falsy values like `false`, `nil`, `true`, `""`, `[]`, `{}`, `0`… `✅ EXCEPTION - Returning error messages is okay`."
- **CCR "Coding Styles → Ruby"**: "Guard clauses for early exits (without return values). Safe navigation (`&.`) for nullable objects."

### Null checks
- Ruby: `&.` (`@user.organization&.id` in `app/services/posthog/track.rb:28`), `.present?`, `.compact` on property hashes.
- TypeScript — **CCR 13**: "The only exception to using strict comparisons (`===`/`!==`) when writing JavaScript is when comparing to `undefined`. The loose `x != undefined` / `x == undefined` is the house guard for absent values — it intentionally catches both `undefined` and `null` in one check."
- **CCR 10 / CM (rule 10 in CCR only)** "Never Fabricate Fallback Values" — no `|| 0`, `|| ""`, `|| []`.
- **CCR 9 / CM 9 / FB 2** "Never Deliberately Set undefined."
- **CM 11 / FB 1** "No Nullish Coalescing Operator (`??`) — Not supported in current build config. Webpack will fail to compile."

### Other rules that will bite this feature
- **CCR 11 / CM 10** no bang methods (`update!`, `create!`, `save!`) outside `spec/` and `app/controllers/cypress/`.
- **CCR 12** always check `save`/`update` return values.
- **CCR 14 / CM 19** enum columns always `default: 0, null: false`; 0 is the *starting* state.
- **CCR 15 / CM 20** presence validations only for required form fields — never for server-set values.
- **CCR 7 / CM 7** backend snake_case, frontend camelCase; Ruby enum values stay snake_case on the frontend.
- **CCR 3 / CM 3** `ap`, never `pp`.
- **CCR "Coding Styles → Ruby"** single quotes unless interpolating; **TypeScript** double quotes.
- **CM "Linter & Formatting Scope"** fix lint only on lines you wrote.

---

## 3. House ActiveJob pattern

`ApplicationJob` is empty — every convention lives in the job class itself:

```ruby
# app/jobs/application_job.rb
# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
end
```

**Queue declaration:** 89 of 92 job files declare `queue_as :default`. The only deviation is `app/jobs/export_job_resumes_to_zip_job.rb:4` (`queue_as :exports`).

**Representative job — the exact analog for a PostHog groups job** (`app/jobs/posthog_track_job.rb`, full file):

```ruby
# frozen_string_literal: true

class PosthogTrackJob < ApplicationJob
  queue_as :default

  def perform(user_id, event, properties = {})
    user = User.find_by(id: user_id)
    return unless user

    Posthog::Track.new(user: user, event: event, properties: properties.deep_symbolize_keys).track
  end
end
```

Note `properties.deep_symbolize_keys` — ActiveJob serializes the hash to JSON with string keys, so the job re-symbolizes before handing it to the service. Any new groups job taking a properties hash must do the same.

**Representative job with in-job third-party calls, private helper and rescue** (`app/jobs/track_new_sso_owner_signup_job.rb`, full file):

```ruby
# frozen_string_literal: true

class TrackNewSsoOwnerSignupJob < ApplicationJob
  queue_as :default

  def perform(user_id, base_timestamp)
    user = User.find_by(id: user_id)
    return unless user
    return unless POSTHOG_CLIENT

    attribution_properties = user.attribution_properties

    capture(user, 'user_signed_up', base_timestamp, attribution_properties.merge(method: 'google_sso', '$set_once' => attribution_properties))
    capture(user, 'organization_owner_signed_up', base_timestamp + 0.001, attribution_properties.merge(method: 'google_sso', '$set_once' => { originally_signed_up_as_owner: true }))
    capture(user, 'organization_owner_email_verified', base_timestamp + 0.002)
    capture(user, 'organization_owner_user_name_submitted', base_timestamp + 0.003)
  rescue StandardError => e
    Rails.logger.error("[PostHog] SSO owner signup funnel track failed: #{e.message}")
  end

  private

  def capture(user, event, timestamp, extra_properties = {})
    POSTHOG_CLIENT.capture({
                             distinct_id: user.id.to_s,
                             event: event,
                             properties: { email: user.email }.merge(extra_properties),
                             timestamp: timestamp
                           })
  end
end
```

**`retry_on` + exhaustion block.** Only four job files in the repo use `retry_on`, and three are AI-feature jobs. The one non-AI-summary example is `app/jobs/get_resume_text_from_textract_job.rb` (full file):

```ruby
# frozen_string_literal: true

class GetResumeTextFromTextractJob < ApplicationJob
  queue_as :default

  retry_on CustomErrorTextract, wait: 5.minutes, attempts: 3 do |job, _error|
    cleanup_orphaned_summary(job.arguments.first)
  end

  def self.cleanup_orphaned_summary(job_application_id)
    job_application = JobApplication.find_by(id: job_application_id)
    return unless job_application

    ai_job_application_summary = job_application.latest_ai_job_application_summary
    return unless ai_job_application_summary&.status_textract_processing? && !ai_job_application_summary.stale?

    requesting_org_user = OrganizationUser.find_by(id: ai_job_application_summary.requested_by_organization_user_id)
    ai_job_application_summary.update(status: :failed, error_message: 'Resume processing failed after multiple attempts.')

    textract_result = job_application.textract_results.order(created_at: :desc).first
    textract_result&.send(:broadcast_ai_summary_failed, requesting_org_user, 'Resume processing failed after multiple attempts.')
  end

  def perform(job_application_id)
    textract_service = GetResumeTextFromTextract.new(job_application_id)
    textract_service.parse_resume_text
  # rescue StandardError => e
  #   ap 'StandardError - GetResumeTextFromTextractJob Error'
  #   ap e
  end
end
```

Pattern: `retry_on <CustomError>, wait:, attempts:` with a block that receives `|job, error|` and calls a **class method** on the job; the class method re-finds the record with `find_by` and guards with bare `return unless`. The custom error is a one-line class in `app/errors/`:

```ruby
# app/errors/custom_error_textract.rb:3
class CustomErrorTextract < StandardError
```

Raised by the service, not the job — `app/services/get_resume_text_from_textract.rb:41`: `raise CustomErrorTextract # This will cause the GetResumeTextFromTextractJob to retry`.

**Note for the groups feature:** neither `PosthogTrackJob` nor `PosthogIdentifyJob` declares `retry_on`. Both swallow failures inside the service's `rescue StandardError` (see §4/`Posthog::Track#track`), so a PostHog outage silently drops the event. That is the current house behavior for PostHog specifically; a new groups job that copies `PosthogTrackJob` inherits it.

**Third representative (external API + credential + `Sentry.capture_exception`)** — `app/jobs/heroku_domain_job.rb` full body shown in the trace; its rescue is `rescue StandardError => e / Sentry.capture_exception(e)`. And the simplest form, `app/jobs/webflow_sync_one_job.rb`:

```ruby
class WebflowSyncOneJob < ApplicationJob
  queue_as :default

  def perform(job_id)
    @job = Job.find_by_id(job_id)
    ap 'WebflowSyncOneJob - status'
    ap @job.status if @job.present?
    @job.create_or_update_on_webflow(true) if @job.present? && !@job.draft?
  end
end
```

---

## 4. House interactor pattern

`app/interactors/create_subscription_event.rb` (full file) — the closest analog, since it is the non-AI interactor in the PostHog/billing area:

```ruby
# frozen_string_literal: true

class CreateSubscriptionEvent
  include Interactor

  def call
    ap 'Create Subscription Event Interactor'
    # ap context

    organization = context.organization
    return unless organization

    no_plan_change = context.previous_plan.present? && context.previous_plan == organization.plan

    context.fail!(message: 'No plan change: previous_plan matches the current plan') if no_plan_change

    ap 'Stripe subscription in good standing?'
    ap organization.stripe_subscription_in_good_standing

    event_params = {
      event_type: context.event_type,
      to_plan: organization.plan
    }

    event_params[:stripe_subscription_id] = organization.stripe_subscription_id if organization.stripe_subscription_id.present?

    # Check for duplicate within last 24 hours. from_plan is deliberately not part of it.
    recent_duplicate = organization.subscription_events
                                   .where(event_params)
                                   .where('created_at >= ?', 24.hours.ago)
                                   .exists?

    context.fail!(message: 'Duplicate SubscriptionEvent created within the last 24 hours') if recent_duplicate

    event_params[:from_plan] = context.previous_plan

    subscription_event = organization.subscription_events.build(event_params)

    if subscription_event.save
      ap 'Successfully created SubscriptionEvent'
      ap subscription_event.event_type
      context.subscription_event = subscription_event
    else
      context.subscription_event = subscription_event
      context.fail!(message: "Could not create SubscriptionEvent for organization with id #{organization.id}")
    end
  rescue StandardError => e
    Rails.logger.error e
    context.fail!(message: 'An error occurred while creating the SubscriptionEvent')
  end
end
```

Second example, `app/interactors/create_hiring_stage_visit.rb` (full file), showing the canonical build/save/`context.fail!` tail without a rescue:

```ruby
# frozen_string_literal: true

class CreateHiringStageVisit
  include Interactor

  def call
    ap 'Create Hiring Stage Visit'
    # ap context
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

Observed house traits: `# frozen_string_literal: true`, `include Interactor`, a single `def call`, an `ap 'Human readable name'` line as the first statement, local variables pulled off `context` (the newer files use bare locals; the rules file shows `@ivar` — both exist, `create_subscription_event.rb` is the newer form), the `if record.save … else … context.fail!` tail with the record assigned to context on **both** branches, and `context.fail!(message: …)` (note: the rules file writes `context.fail!(error: …)`; the two live non-AI interactors both use `message:`).

`CreateComment` adds the Pundit variant: `include Pundit` plus a public `authorize` method that does `raise Pundit::NotAuthorizedError unless authorized`.

---

## 5. Credential registry pattern

**Declaration** — `config/initializers/01_variables.rb:35-36`:

```ruby
  POSTHOG_API_KEY = ENV['POSTHOG_API_KEY'] || Rails.application.credentials.dig(Rails.configuration.x.RailsCredentialsEnv, :posthog, :api_key)
  POSTHOG_HOST = ENV['POSTHOG_HOST'] || 'https://us.i.posthog.com'
```

The whole file is `module Variables` with bare constants (line 3: `module Variables`, line 148: `end`). The dominant form is `ENV['NAME'] || Rails.application.credentials.dig(Rails.configuration.x.RailsCredentialsEnv, :vendor, :key)`; a minority use `Rails.env.to_sym` instead of the `x.RailsCredentialsEnv` accessor (e.g. `WHAT_JOBS_API_TOKEN` line 30, `PostmarkToken` line 38). Naming is mixed — SCREAMING_SNAKE for newer entries (`POSTHOG_API_KEY`, `STREAM_API_KEY`), PascalCase for older ones (`AtsRootUrl`, `StripeSecretApiKey`, `MailSlurpApiKey`). New entries should use SCREAMING_SNAKE.

`Rails.configuration.x.RailsCredentialsEnv` is defined at `config/application.rb:82`:

```ruby
    config.x.RailsCredentialsEnv = Rails.env.test? ? :development : Rails.env.to_sym
```

**Usage — initializer building a shared client** (`config/initializers/posthog.rb`, full file):

```ruby
# frozen_string_literal: true

require 'posthog-ruby'

POSTHOG_CLIENT = if Variables::POSTHOG_API_KEY.present?
  PostHog::Client.new(
    api_key: Variables::POSTHOG_API_KEY,
    host: Variables::POSTHOG_HOST,
    on_error: proc { |_status, msg| Rails.logger.error("[PostHog] #{msg}") }
  )
end
```

**Usage — inside a job** (`app/jobs/heroku_domain_job.rb:11`): `heroku_app_name = Variables::HEROKU_APP_NAME`.

**Usage — exposed to the browser** (`app/views/layouts/application.html.erb:78-79`):

```erb
      window.POSTHOG_API_KEY = "<%= Variables::POSTHOG_API_KEY %>";
      window.POSTHOG_HOST = "<%= Variables::POSTHOG_HOST %>";
```

**Consumer guard** — every server-side PostHog consumer must handle `POSTHOG_CLIENT == nil`, because the constant is only assigned when the key is present. `app/services/posthog/track.rb:11`, `app/services/posthog/identify.rb:9` and `app/jobs/track_new_sso_owner_signup_job.rb:9` all do `return unless POSTHOG_CLIENT`.

---

## 6. Frontend useEffect side effect tied to loaded data

The exact analog, `app/javascript/ats/src/views/layouts/AppAuthRouter.tsx:163-177`:

```tsx
  /* POSTHOG IDENTIFY
  --===================================================-- */
  const currentPlan = currentOrganization?.plan;
  React.useEffect(() => {
    if (currentUser?.id) {
      identifyUser({
        id: currentUser.id,
        email: currentUser.email,
        organizationId: organizationId,
        organizationName: organizationName,
        plan: currentPlan,
        organizationUserRole: currentUser.currentOrganizationUser?.role,
      });
    }
  }, [currentUser, organizationId, currentPlan, organizationName]);
```

Traits: a banner comment in the `/* NAME\n--====-- */` house form; the derived scalar (`currentPlan`) hoisted **out** of the effect so it can be a dependency; `React.useEffect` (namespaced, not a named import); a truthiness guard on the loaded field before firing; every read value listed in the dependency array. The data comes from React Query hooks above (`useGetMe`, `useOrganization`, lines 76-95), never from `useState`.

The adjacent Heap effect (lines 146-161) is the same shape with no guard, and the pageview effect in `app/javascript/shared/PostHogContext.tsx:11-18` shows the ref-guarded variant:

```tsx
  React.useEffect(() => {
    if (location?.pathname && location.pathname !== previousPathnameRef.current) {
      previousPathnameRef.current = location.pathname;
      if (posthog.__loaded) {
        posthog.capture("$pageview");
      }
    }
  }, [location.pathname]);
```

The browser-side call layer is `app/javascript/shared/lib/posthog.ts` — a module of plain functions (`identifyUser`, `trackEvent`, `resetUser`) that each begin with the loaded-check + `window.logger` skip path:

```ts
function getPosthog() {
  return posthog.__loaded ? posthog : null;
}

function trackEvent(event: string, properties?: Record<string, any>): void {
  const ph = getPosthog();
  if (!ph) {
    window.logger("%c[PostHog] trackEvent skipped - not loaded", "background-color: #FF76D2", { event, properties });
    return;
  }

  window.logger("%c[PostHog] trackEvent", "background-color: #FF76D2", { event, properties });
  ph.capture(event, properties);
}
```

Note `identifyUser` sends **snake_case** property keys to PostHog (`organization_id`, `organization_name`, `organization_user_role`) while taking camelCase arguments — the PostHog property namespace is snake_case on both frontend and backend. A groups implementation must keep that.

---

## 7. House null/undefined guard in TypeScript

The guard is the **loose** comparison against `undefined`, per `core_critical_rules.md` rule 13 ("JavaScript: Strict Comparisons Always — One Exception: Comparing to undefined").

Counts over `app/javascript/**/*.{ts,tsx}`:

| form | occurrences |
|---|---|
| `x != undefined` (loose, excludes `!==`) | **167** |
| `x == undefined` (loose, excludes `===`) | **89** |
| `x !== undefined` (strict) | 38 |

Loose forms total **256** vs 38 strict. Commands: `grep -rn "!= undefined" app/javascript --include=*.ts --include=*.tsx | grep -v "!== undefined" | wc -l` and `grep -rnE "[^!=]== undefined" app/javascript --include=*.ts --include=*.tsx | wc -l`.

Live examples in the PostHog path, `AppAuthRouter.tsx`:
- line 81 `const hasUser = currentUser != undefined && currentUser.id !== undefined;`
- line 112 `if (currentOrganization != undefined) {`
- line 128 `if (featureFlagsData != undefined) {`
- line 208 `if (currentUser == undefined) {`
- line 341 `if (organizationId == undefined && location.pathname !== "/organization/new") {`

The 38 strict `!== undefined` uses are the boolean-default carve-out from `.claude/CLAUDE.md` rule 11 / `frontend/_base.md` rule 1: "For booleans: `value !== undefined ? value : defaultValue`". Optional chaining (`currentUser?.id`) is used freely; `??` is forbidden (webpack will not compile it).

---

## 8. CLAUDE.md / rules content on analytics, tracking, and third-party services

`.claude/CLAUDE.md` contains **nothing** naming PostHog, analytics, or tracking. What it does carry that constrains this feature:

- **§0a "DO NOT WRITE RSPEC SPECS ⛔"** — "Never write a new RSpec spec file. Never add examples to an existing one… **Verification is manual.** Exercise the real path — the running app, a real account, `rails runner` against real data — and report what you actually observed." A PostHog-groups feature ships with zero new specs; verification is a real PostHog project.
- **§0 "Pre-Commit Tests: NON-NEGOTIABLE"** and the commit procedure (`nvm use && git commit …`, outside the sandbox, never `--no-verify`).
- **"Files You Should Never Edit"** — `ModalContext.tsx`, `ToastContext.tsx`, `CurrentSessionContext.tsx`, `api.ts`, core infrastructure components, `AGENTS.md`. `PostHogContext.tsx` is **not** on that list, but it is a context file in the same directory family — treat edits to it as needing a stated reason.
- **"Linter & Formatting Scope"** — fix lint only on lines you wrote.

The third-party guidance lives in the rules modules, not CLAUDE.md:
- `cursor_rules/backend/background_jobs.md §0b` — external API calls always go through a background job, with the "already async" exception.
- `cursor_rules/backend/services.md` — external API integration is a **service**; the service rescues `StandardError` and logs rather than crashing the caller; if the service will queue a background job or call another service, **state that to the user before implementing** (final line of services.md).

**Existing PostHog surface a groups feature must integrate with** (not a rules statement, but the de-facto contract):
- Server-side entry points are the two jobs `PosthogIdentifyJob` / `PosthogTrackJob`, enqueued from 8 controllers, 2 models, and 1 service (`app/services/email_processor.rb:83`).
- Event property namespace is snake_case; PostHog magic keys are passed as string keys — `'$set_once' => {…}` in `registrations_controller.rb:55`, `invites_controller.rb:83-84`, `track_new_sso_owner_signup_job.rb:13-14`, and `event_properties['$set'] = { is_paying: true, is_trialing: false }` in `subscription_event.rb:47-54`.
- `distinct_id` is always `user.id.to_s` (`posthog/track.rb:14`, `posthog/identify.rb:12`, `track_new_sso_owner_signup_job.rb:25`), and org-scoped events resolve the user as `organization.owner.id` (`subscription_event.rb:61`).
- Default properties already carry `organization_id`, `organization_name`, `plan` (`posthog/track.rb:24-31`).

**Library support (gem boundary).** `Gemfile:122` `gem 'posthog-ruby', '~> 2.0'`; `Gemfile.lock:371` resolves `posthog-ruby (2.11.0)`. That version supports groups natively: `PostHog::Client#capture` accepts `attrs[:groups]` (`lib/posthog/client.rb:108`) which `FieldParser.parse_for_capture` turns into `properties['$groups'] = groups` after `check_is_hash!(groups, 'groups')` (`lib/posthog/field_parser.rb:20-27`), and `PostHog::Client#group_identify(attrs)` (`lib/posthog/client.rb:136`) takes `:group_type`, `:group_key`, optional `:properties` and `:distinct_id`, defaulting `fields[:distinct_id] ||= "$#{group_type}_#{group_key}"` (`field_parser.rb:66-83`). Frontend: `package.json:70` `"posthog-js": "1.297.4"`, `package.json:31` `"@posthog/react": "1.0.0"`.