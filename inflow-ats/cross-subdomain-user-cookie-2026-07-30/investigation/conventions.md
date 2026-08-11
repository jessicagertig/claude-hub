# Conventions gathering — cross-subdomain user-id cookie (hire app)

Source worktree read: `/Users/jessica/wrk/wrk-corp/inflow-ats.cross-subdomain-user-cookie`
Branch: `cross-subdomain-user-cookie`, clean working tree, HEAD `04a5c2d57`. No work started.

**Headline finding up front:** there is no `CLAUDE.md` at the repo root. It lives at
`/Users/jessica/wrk/wrk-corp/inflow-ats.cross-subdomain-user-cookie/.claude/CLAUDE.md`, and its rule
§0a forbids writing any RSpec spec. That single rule answers most of the "testing requirements"
brief, and is quoted in full below.

---

## 1. Full `cursor_rules/` tree listing

```
cursor_rules/backend/_base.md
cursor_rules/backend/architecture.md
cursor_rules/backend/background_jobs.md
cursor_rules/backend/code_style_and_structure.md
cursor_rules/backend/controllers/controller_error_handling.md
cursor_rules/backend/controllers/controller_patterns_and_crud.md
cursor_rules/backend/controllers/pundit_policies.md
cursor_rules/backend/core_critical_rules.md
cursor_rules/backend/interactors/interactor_patterns_and_structure.md
cursor_rules/backend/interactors/interactor_usage_and_guidelines.md
cursor_rules/backend/job_board_integration/job_board_architecture_and_model.md
cursor_rules/backend/job_board_integration/job_board_controller_and_webhooks.md
cursor_rules/backend/job_board_integration/job_board_frontend_and_checklist.md
cursor_rules/backend/migrations.md
cursor_rules/backend/public_api_controllers.md
cursor_rules/backend/serializers.md
cursor_rules/backend/services.md
cursor_rules/console_commands.md
cursor_rules/core_critical_rules.md
cursor_rules/cypress/core_critical_rules.md
cursor_rules/cypress/cypress_assertions_and_antiflake.md
cursor_rules/cypress/cypress_common_pitfalls.md
cursor_rules/cypress/cypress_selectors_and_interactions.md
cursor_rules/cypress/cypress_test_structure_and_setup.md
cursor_rules/cypress/cypress_troubleshooting.md
cursor_rules/frontend/_base.md
cursor_rules/frontend/boolean_variables_and_naming.md
cursor_rules/frontend/components/component_architecture.md
cursor_rules/frontend/components/component_size_and_extraction.md
cursor_rules/frontend/contexts/context_reference.md
cursor_rules/frontend/contexts/context_usage_and_rules.md
cursor_rules/frontend/core_critical_rules.md
cursor_rules/frontend/forms/form_guards_and_conditional_fields.md
cursor_rules/frontend/forms/form_state_and_change_handlers.md
cursor_rules/frontend/forms/form_submission_and_mutations.md
cursor_rules/frontend/forms/form_validation_and_errors.md
cursor_rules/frontend/lists/list_actions_and_modals.md
cursor_rules/frontend/lists/list_sorting_and_filtering.md
cursor_rules/frontend/lists/list_structure_and_data_fetching.md
cursor_rules/frontend/modals/modal_form_and_confirmation_patterns.md
cursor_rules/frontend/modals/modal_state_errors_and_loading.md
cursor_rules/frontend/react_hooks.md
cursor_rules/frontend/react_query/react_query_mutations_and_cache.md
cursor_rules/frontend/react_query/react_query_queries.md
cursor_rules/frontend/reference_patterns.md
cursor_rules/frontend/ui_styling.md
cursor_rules/public_api_controller_rules.md
```

**Duplicate files (verified by `diff`).** `cursor_rules/backend/core_critical_rules.md`,
`cursor_rules/frontend/core_critical_rules.md` and `cursor_rules/cypress/core_critical_rules.md` are
byte-identical to each other and are an older, shorter copy of `cursor_rules/core_critical_rules.md`.
The root file is the authority: it has four rules the three copies lack — "10. Never Fabricate Fallback
Values", "13. JavaScript: Strict Comparisons Always", "14. Never Add an Enum Column Without a Default",
"15. Presence Validations Are For Form Submissions Only". `cursor_rules/public_api_controller_rules.md`
and `cursor_rules/backend/public_api_controllers.md` are near-duplicates of each other (same content,
different section headings).

Also note `.cursorrules` at the repo root references a rules layout that no longer exists
(`cursor_rules/rules.md`, `cursor_rules/typescript_react.md`, `cursor_rules/controller_rules.md`,
`cursor_rules/interactors.md` …). None of those paths exist. `.cursorrules` is stale.

---

## 2. Files read (complete list)

Rules / instruction files:
- `.cursorrules`
- `.claude/CLAUDE.md` (this repo's CLAUDE.md — 545 lines, read in full)
- `cursor_rules/core_critical_rules.md` (full)
- `cursor_rules/backend/_base.md` (full)
- `cursor_rules/backend/core_critical_rules.md` (full)
- `cursor_rules/backend/architecture.md` (full)
- `cursor_rules/backend/code_style_and_structure.md` (full)
- `cursor_rules/backend/controllers/controller_patterns_and_crud.md` (full)
- `cursor_rules/backend/controllers/controller_error_handling.md` (full)
- `cursor_rules/backend/controllers/pundit_policies.md` (full)
- `cursor_rules/backend/services.md` (full)
- `cursor_rules/backend/interactors/interactor_patterns_and_structure.md` (full)
- `cursor_rules/backend/interactors/interactor_usage_and_guidelines.md` (full)
- `cursor_rules/backend/migrations.md` (full)
- `cursor_rules/frontend/_base.md` (full)
- `cursor_rules/frontend/core_critical_rules.md` (full via diff against root)
- `cursor_rules/frontend/boolean_variables_and_naming.md` (full)
- `cursor_rules/cypress/core_critical_rules.md` (full via diff against root)
- `cursor_rules/cypress/cypress_test_structure_and_setup.md` (full)
- `cursor_rules/console_commands.md` (full)
- Scope headers read for every remaining rules file (listed in §7).

Source files:
- `app/controllers/application_controller.rb`
- `app/controllers/hire/base_controller.rb`
- `app/controllers/hire/pages_controller.rb`
- `app/controllers/api/v1/base_controller.rb`
- `app/controllers/admin/base_controller.rb`
- `app/controllers/account/base_controller.rb`
- `app/controllers/connect/base_controller.rb`
- `app/controllers/individual_app/base_controller.rb`
- `app/controllers/account/pages_controller.rb`
- `app/controllers/connect/pages_controller.rb`
- `app/controllers/job_board/base_controller.rb`
- `app/services/subdomain_app_constraints.rb`
- `config/initializers/01_variables.rb`
- `config/initializers/ahoy.rb`
- `config/routes.rb` (lines 110–130, 535–600 plus targeted greps)
- `app/views/layouts/application.html.erb`
- `app/views/hire/pages/root.html.erb`
- `app/javascript/shared/hooks/useCookieValue.ts`
- `app/javascript/shared/lib/utils.js` (lines 1–80)
- `cypress/e2e/auth/logout.cy.js`
- `/Users/jessica/.rvm/gems/ruby-3.1.6/gems/ahoy_matey-4.0.1/lib/ahoy/controller.rb` (line 9, for the
  origin of `track_ahoy_visit`)

Trace chain for the main question (where does the callback go):
`config/routes.rb:568` → `app/controllers/hire/pages_controller.rb` → `app/controllers/hire/base_controller.rb`
→ `app/controllers/application_controller.rb` → `ahoy_matey-4.0.1/lib/ahoy/controller.rb:9`.
Domain-derivation chain: `config/routes.rb:541` → `app/services/subdomain_app_constraints.rb:7`
→ `config/initializers/01_variables.rb:95`.

---

## 3. Applicable rules checklist

### 3a. Stack

> "**Backend:**
> - Ruby 3.1+, Rails 6.1+, PostgreSQL
> - Pundit, ActiveModelSerializers, Sidekiq, AWS S3
>
> **Frontend:**
> - TypeScript 4.0+, React 18+, React Router v5
> - React Query, Emotion for styling"

`cursor_rules/core_critical_rules.md:5-11` (identical at `.claude/CLAUDE.md:5-11`).

Devise is in use but is not listed in the stack block. Confirmed live: `config/routes.rb:123`
`devise_for :users, skip: [:sessions, :omniauth_callbacks]` nested under `namespace :api` / `:v1`, and
`config/routes.rb:127` `devise_scope :api_v1_user`. The session helpers on the hire side are therefore
`api_v1_user_signed_in?` and `current_api_v1_user` (`app/controllers/hire/pages_controller.rb:26`).

### 3b. Naming conventions

**Ruby file naming:**

> "**Backend:**
> - Models: `snake_case.rb` (e.g., `job_application.rb`)
> - Controllers: `snake_case_controller.rb` (e.g., `job_applications_controller.rb`)
> …
> - Services: `snake_case.rb` - **NEVER include 'service' in filename** (e.g., `calculate_daily_summary.rb` NOT `calculate_daily_summary_service.rb`)
> - Interactors: `snake_case.rb` (e.g., `create_job_application.rb`)"

`cursor_rules/core_critical_rules.md:390-398`.

**Service class naming (applies if the domain logic gets extracted to `app/services/`):**

> "### 1. Never Include "Service" in the Class Name
>
> **CRITICAL**: Never include "Service" in the class name."

`cursor_rules/backend/services.md:25-27`.

> "### 2. Use Descriptive Public Method Names — Not `call` or `execute`
> …
> **Note**: Avoid generic names like `call` or `execute` (`call` is okay reserved for interactors). Use descriptive names that indicate what the method does."

`cursor_rules/backend/services.md:37-49`.

**Interactor naming (applies if it gets extracted to `app/interactors/`):**

> "Use verb phrases that describe the action:
> …
> ```ruby
> # ✅ CORRECT
> CreateJobApplication
> …
> # ❌ WRONG
> JobApplicationCreator
> ```"

`cursor_rules/backend/interactors/interactor_patterns_and_structure.md:9-23`.

**Variable naming for records — the strong rule:**

> "### 18. Variable Names Must Identify Their Record Type ⚠️
>
> Name every variable so that a reader can immediately match it to the model/table it refers to, regardless of how deeply nested the code is. Use the full model name in snake_case — `existing`, `record`, `item`, `entry`, `row`, `txn`, `ledger`, `transaction`, `purchase`, `latest` are never acceptable as standalone variable names for database-backed records."

`.claude/CLAUDE.md:394-400`. Same rule at `cursor_rules/core_critical_rules.md:413-419` ("Variable
Naming for Records") and at `cursor_rules/backend/_base.md:151-169`, which adds:

> "Never shorten `JobApplication` to `application` — `application` is ambiguous and could refer to the Rails app itself."

`cursor_rules/backend/_base.md:167`.

*Applies here:* if the callback assigns the signed-in user to a local, it must be `user` — the model is
`User`, so the full model name in snake_case is `user`. `current_api_v1_user` is the Devise helper name
and is not a variable.

**Constant naming for config values.** No rules file covers it. Codebase precedent is
`config/initializers/01_variables.rb`, which is inconsistent by design: it mixes SCREAMING_SNAKE_CASE
(`MARKETING_BASE_URL:6`, `APP_DOMAIN_LIST:95`, `POSTHOG_API_KEY:35`) with CamelCase
(`AtsRootUrl:19`, `CareerRootUrl:23`, `ServerEnv:33`, `StripeSecretApiKey:88`). The newer entries
(2026 AI-credit block, lines 124–147) are all SCREAMING_SNAKE_CASE.

**Cookie key naming.** No rule. Codebase precedent is exactly two cookies, both snake_case symbols
scoped by app area: `cookies[:account_referrer]` (`app/controllers/account/pages_controller.rb:5`) and
`cookies[:connect_referrer]` (`app/controllers/connect/pages_controller.rb:7`).

**Boolean naming (only if a boolean column/flag appears):**

> "### 1. Boolean Columns Must Be Prefixed with a Verb
> Every boolean column name MUST start with a verb like `is_`, `has_`, `can_`, `should_`  OR use the `_enabled` suffix pattern."

`cursor_rules/backend/migrations.md:7-8`.

### 3c. Where logic is allowed to live

The house rule is a line count, not a layer mandate:

> "### 1. Controller Actions Over 15 Lines of Business Logic Must Use an Interactor
> Controllers orchestrate, interactors execute."

`cursor_rules/backend/architecture.md:7-8`.

The "when to use an interactor" list repeats the threshold and enumerates the other triggers:

> "### Create an Interactor When:
> - **Complex CRUD** - Create/update/destroy with business logic beyond just saving params
> - **Complex validation** - CSV imports, external API requirements, business rules spanning multiple checks
> - **Multi-model operations** - Logic spanning multiple models that must succeed or fail together
> - **Controller action >15 lines of logic** - Extract to interactor
> - **Controller + callback overlap** - When controller method and model callback do similar things"

`cursor_rules/backend/interactors/interactor_usage_and_guidelines.md:9-15`.

And the escape hatch downward:

> "### Use Model Method When:
> - **Simple CRUD** - Standard create/update with no computed fields
> - **Simple state checks** - `listing.live?`, `listing.expired?`"

`cursor_rules/backend/interactors/interactor_usage_and_guidelines.md:21-23`.

A private method on a controller is explicitly the sanctioned home for `before_action` targets:

> "### Before Actions
>
> ```ruby
> # Pattern: Set resources or check preconditions
> class Api::V1::HiringStagesController < Api::V1::BaseController
>   before_action :set_job, only: [:index, :show, :create, :update, :destroy]
>
>   private
>
>   def set_job
>     @job = current_organization.jobs.find(params[:job_id])
>   end
> end
> ```"

`cursor_rules/backend/controllers/controller_patterns_and_crud.md:196-208`.

There is one narrow prohibition on extracting to a private method, and it is scoped to rescue only:

> "❌ **Don't extract to private methods just for rescue**"

`cursor_rules/backend/controllers/controller_error_handling.md:30`.

**Reading:** a private method on the controller registered as a `before_action` is the house form for
this size of change, and the >15-line interactor threshold is nowhere near triggered by
"set a cookie to `current_api_v1_user.id.to_s`". Note that `cursor_rules/backend/architecture.md` and
`controller_patterns_and_crud.md` both state their scope as internal API controllers in
`Api::V1::` — see the ambiguity note in §6.

**Services scope, for completeness** (this change matches none of these):

> "### Create a Service When:
> - **External API integration** …
> - **Complex calculations** …
> - **Multi-step workflows** spanning multiple models …
> - **Email/notification routing** …"

`cursor_rules/backend/services.md:7-12`.

**Concerns.** No rule anywhere in `cursor_rules/` about controller concerns. Codebase reality:
`app/controllers/concerns/` contains exactly `role_fit_filterable.rb` and an `api_public/` subdirectory.
The house has NOT extracted shared callbacks into concerns — `set_sentry_context` is copy-pasted
verbatim into both `app/controllers/api/v1/base_controller.rb:33-46` and
`app/controllers/admin/base_controller.rb` rather than shared. A concern for a single new callback would
be a deviation from that precedent.

### 3d. Callback conventions

Registration form, `only:` usage, and the `private` section come from
`cursor_rules/backend/controllers/controller_patterns_and_crud.md:196-219` (quoted in §3c above), which
shows both the `only:`-scoped form and the plain form:

> "```ruby
> # Or for organization-scoped resources
> class Api::V1::OrganizationsController < Api::V1::BaseController
>   before_action :set_organization, only: [:show, :update, :destroy]
>
>   private
>
>   def set_organization
>     @organization = current_user.organization
>   end
> end
> ```"

`cursor_rules/backend/controllers/controller_patterns_and_crud.md:210-219`.

There is no rule about `after_action` anywhere in `cursor_rules/`. Codebase reality: `after_action`
appears exactly once in `app/controllers/`, commented out —
`app/controllers/application_controller.rb:5` `# after_action :set_sentry_context`. Every live callback
in the app is a `before_action` (or one `around_action`, `app/controllers/job_board/base_controller.rb:5`).

**Guard-clause style — confirmed present in the rules files.** The bail-out-only rule is stated three
times:

> "### 8. Guard Clauses: Bare return (No Explicit Falsy Values) ⚠️
>
> Use bare `return` without explicit falsy values like `false`, `nil`, etc.
>
> ```ruby
> # ✅ CORRECT - Bare return
> def process
>   return unless valid?
>   return if cancelled?
>
>   # main logic
> end
> ```"

`.claude/CLAUDE.md:196-215`.

> "### 8. Guard Clauses: No Truthy/Falsy Return Values
>
> Guard clauses should use bare `return` — do not return truthy or falsy values like `false`, `nil`, `true`, `""`, `[]`, `{}`, `0`, etc. Our code is optimized so that early returns are always the default `nil` that Ruby returns implicitly. We don't explicitly state it."

`cursor_rules/core_critical_rules.md:152-154`.

> "## Method Return Patterns
>
> - Use guard clauses only for early exits without values
> - Never use guard clauses to return a value
> - Return meaningful objects for the method's contract
> - Rely on Ruby's implicit return for non-predicate methods"

`cursor_rules/backend/code_style_and_structure.md:49-54`.

And a caution against forcing the shape:

> "### Early Returns with Guard Clauses
> Don't artificially attempt to always apply an early return clause"

`cursor_rules/backend/controllers/controller_patterns_and_crud.md:244-245`.

**The "value selection uses a full if/elsif/else" half of the hub rule is NOT in any cursor_rules file.**
It exists only in `~/claude-hub/inflow-ats/CLAUDE.md` (memory pointer
`feedback_inflow_guard_clauses_bailout_only`). The repo's own rules cover only the bail-out half.
Codebase precedent for the full-expression form:
`app/controllers/hire/pages_controller.rb:26-31` uses `if … else … end` rather than a guard,
and `app/controllers/connect/pages_controller.rb:5` uses the bail-out form
`redirect_to app_root_url and return unless current_organization_user.is_admin`.

**Where guards go in existing per-request callbacks:** `app/controllers/api/v1/base_controller.rb:37`
`return unless current_user` — bare `return`, first line of the method body, before the side effect.
Identical at `app/controllers/admin/base_controller.rb`.

### 3e. Nil / absence idioms

> "### 10. Never Fabricate Fallback Values
>
> Do not use `|| 0`, `|| ""`, `|| []`, or any other fallback that substitutes a non-nil value for absent data. The app handles nil/null/undefined/empty throughout — fabricating a fallback disguises missing data as real data and causes downstream bugs.
> …
> Only add fallbacks with explicit permission or when the consuming code genuinely cannot handle nil (e.g., `useState` initializers where `|| ''` is the established pattern per rule 9)."

`cursor_rules/core_critical_rules.md:225-247`. This rule is present ONLY in the root file — the three
area copies do not have it.

> "**Ruby:**
> - Single quotes unless interpolating
> - Guard clauses for early exits (without return values)
> - Safe navigation (`&.`) for nullable objects"

`cursor_rules/core_critical_rules.md:423-426` and `.claude/CLAUDE.md:460-463`.

**`.present?` vs `.presence`.** No rule in any cursor_rules file. Codebase precedent is `.present?`:
e.g. `app/services/subdomain_app_constraints.rb:5` `request.subdomain.present?`,
`cursor_rules/backend/services.md:241` `return unless @organization.stripe_subscription_id.present?`.
The hub CLAUDE.md records the count as 432 `.present?` vs 10 `.presence`; `.presence` is not a house form.

**The JS-side guard, if any frontend piece is needed:**

> "### 13. JavaScript: Strict Comparisons Always — One Exception: Comparing to undefined
>
> The only exception to using strict comparisons (`===`/`!==`) when writing JavaScript is when comparing to `undefined`. The loose `x != undefined` / `x == undefined` is the house guard for absent values — it intentionally catches both `undefined` and `null` in one check."

`cursor_rules/core_critical_rules.md:297-299`.

> "### 9. Never Deliberately Set undefined ⚠️
>
> **NEVER** explicitly set values to `undefined`."

`.claude/CLAUDE.md:225-227`.

### 3f. Environment-dependent code

**There is no rule anywhere in `cursor_rules/` or `.claude/CLAUDE.md` about `Rails.env.*` branching in
app code versus config.** I grepped every rules file for `Rails.env`; the only hit is
`cursor_rules/cypress/cypress_troubleshooting.md:109` "Tests run against test environment (Rails.env.test)",
which is descriptive, not a rule.

**There is no rule about ENV var usage either.** The only ENV guidance is incidental, inside the services
file's argument-passing examples:

> "```ruby
> # cloudflare_client.rb
> def initialize(api_token: ENV['CLOUDFLARE_API_TOKEN'])
>   @api_token = api_token
> end
> ```"

`cursor_rules/backend/services.md:113-117`.

**Codebase precedent instead — and it is directly load-bearing for this feature.** The house form for
"which registrable domain am I on" is `request.domain`, not a `Rails.env` branch. Every subdomain
constraint derives it from the request and validates against one shared list:

```ruby
class SubdomainAppConstraints
  def self.matches?(request)
    request.subdomain.present? &&
      request.subdomain.start_with?('app') &&
      Variables::APP_DOMAIN_LIST.include?(request.domain)
  end
end
```

`app/services/subdomain_app_constraints.rb:3-9`. The list:

```ruby
APP_DOMAIN_LIST = ['wrkhq.com', 'wrk.xyz', 'polymer.co', 'lvh.me', 'ngrok.io', 'localhost'].freeze
```

`config/initializers/01_variables.rb:95`. Same pattern at `subdomain_hire_constraints.rb:9`,
`subdomain_api_constraints.rb:7`, `subdomain_individual_constraints.rb:7`,
`subdomain_jobs_constraints.rb:7`, `recaptcha/verifier.rb:59`, and
`app/controllers/job_board/base_controller.rb:12,37`.

`request.domain` returns `lvh.me` under `app.lvh.me` and `polymer.co` under `app.polymer.co`, so
`".#{request.domain}"` produces exactly the two required values with zero environment branching. That is
the conventional derivation. Env branching does exist elsewhere in the app
(`app/services/subdomain_hire_constraints.rb:5` `Rails.env.development? && request.domain == 'localhost'`;
`app/views/layouts/application.html.erb` `Rails.env.development?` / `Rails.env.test?` guards), so it is
not forbidden — it is simply not how domain is derived.

### 3g. Testing requirements

**The governing rule — quoted in full because it decides this section:**

> "### 0a. DO NOT WRITE RSPEC SPECS ⛔
>
> **Never write a new RSpec spec file. Never add examples to an existing one.** Not for a feature, not for a bug fix, not because a spec or plan asked for one, not because a review flagged missing coverage. If you believe something needs test coverage: in an autonomous run, put it in the final report. Otherwise, ask in one line.
>
> The only specs in this repo are the customer/public API specs under `spec/requests/api_public/` and the Cypress tests. Both are Jessica's. Do not edit either (see #1 above).
>
> **Why:** AI-written specs are written against an AI-written understanding of the feature, then reviewed against that same understanding. They pass while the design underneath is wrong, they cost hours of review time per feature, and in practice they have caught nothing that manual testing did not. 60 of them were deleted on 2026-07-28 for exactly this reason — every real defect in that feature was found by Jessica in twenty minutes with a live Stripe account, not by the specs or the QA rounds built on them.
>
> **Verification is manual.** Exercise the real path — the running app, a real account, `rails runner` against real data — and report what you actually observed."

`.claude/CLAUDE.md:29-37`.

**Verified against the filesystem.** `spec/` contains exactly 13 spec files, all under
`spec/requests/api_public/v1/hire/`. There are ZERO controller specs, ZERO request specs outside
`api_public`, ZERO cookie assertions (`grep -rn "cookies" spec/` → no matches), and ZERO
`response.headers` assertions (`grep -rn "response\.headers" spec/` → no matches). `spec/support/`
holds four files: `ai_credits_test_helpers.rb`, `api_factories.rb`, `api_request_helpers.rb`,
`api_response_matchers.rb`.

**So the brief's request cannot be satisfied as written, and I am reporting that rather than
substituting something.** There are no existing spec files that are structural analogs for "a spec that
asserts a controller callback set a response header/cookie", because no such spec has ever existed here
and none may be written. Concretely:

- `grep -rn "Devise::Test\|devise.mapping" spec/` → **no matches.** The
  `Devise::Test::ControllerHelpers` + `devise.mapping` requirement (hub CLAUDE.md rule 30) describes a
  spec file that was written and then deleted in the 2026-07-28 purge. There is nothing left to imitate.
- `grep -rn "queue_adapter" spec/` → **no matches.** The queue-adapter `around` block requirement
  (hub CLAUDE.md rule 31) is likewise orphaned. Its cited precedent,
  `bulk_ai_job_application_summaries_controller_spec.rb`, no longer exists.

Those two hub rules remain accurate about the mechanism (`config/environments/test.rb:64` still sets
`config.active_job.queue_adapter = :inline`) but they now have no live exemplar in this repo, and rule 0a
means neither will be exercised by this change.

**The nearest real analog that DOES exist is a Cypress test, not a spec.** `cypress/e2e/auth/logout.cy.js`
is the only test in the repo that asserts on a `Set-Cookie` response header:

```js
cy.wait("@logout").then(({ response }) => {
  expect(response, "logout response present").to.exist;
  const setCookie = response.headers["set-cookie"] || response.headers["Set-Cookie"];
```

`cypress/e2e/auth/logout.cy.js:58-60`, with the expiry assertions at lines 62-72.

**Cypress rules that would apply if an E2E test is written.** Writing a new Cypress file IS permitted:

> "- Existing Cypress tests may only be altered if the initial user instructions or specifications explicitly call for it. Otherwise they are read-only.
> - You may create new Cypress test files."

`.claude/CLAUDE.md:532-533`.

Structure, naming, and setup:

> "- Test files: `feature-name.cy.js` (e.g., `add-candidate.cy.js`, `team-invites.cy.js`)
> - Use kebab-case for all test files
> - Name files descriptively based on the feature being tested
> - Group related tests in subdirectories by domain"

`cursor_rules/cypress/cypress_test_structure_and_setup.md:27-30`.

> "### Database Reset
> **Always** reset the database in `beforeEach()`:
> ```js
> beforeEach(() => {
>   cy.resetDatabase();
>   cy.createDefaultUserAndOrganization({ setActivePaidSubscription: false });
> });
> ```"

`cursor_rules/cypress/cypress_test_structure_and_setup.md:79-86`.

> "### Describe Block Naming
> - Use descriptive names that explain the feature and context
> - Format: `"Feature - Action"` or `"Domain - Specific Test Context"`"

`cursor_rules/cypress/cypress_test_structure_and_setup.md:58-60`.

> "**Test through the real UI and API wherever possible:**
> - This is true end-to-end testing - we avoid mocking as much as possible
> - Real API calls run during tests (we intercept for waiting, not mocking)"

`cursor_rules/cypress/cypress_test_structure_and_setup.md:100-102`.

A Cypress test for this feature would live at `cypress/e2e/auth/` alongside `login.cy.js`,
`logout.cy.js`, `registration.cy.js`, and would assert the cookie after `cy.loginAsDefaultUser()`.
Whether one is *expected* is Jessica's call — nothing in the rules mandates an E2E test per feature.

**And the hard rule that governs committing regardless:**

> "### 0. Pre-Commit Tests: NON-NEGOTIABLE ⛔
>
> **Under NO circumstances** may anything proceed without tests running via the pre-commit hook. If tests cannot run, **stop everything** and surface the problem — do not commit, do not bypass, do not work around."

`.claude/CLAUDE.md:19-21`. The commit mechanics (`nvm use && git commit`, outside the sandbox, never
`--no-verify`) are at `.claude/CLAUDE.md:41-61`.

### 3h. Security rules

**There is no rule in `cursor_rules/` or `.claude/CLAUDE.md` about cookies, sessions, secrets, PII, or
exposing internal IDs to the client.** I grepped every rules file for `cookie`, `session[`, `secret`,
and `PII`; the only structural hits are unrelated (`before_action -> { validate_params(...) }` in the
public-API rules, and the `session[:org_id]` line used as an example of *not* reading globals inside an
interactor, `cursor_rules/backend/interactors/interactor_usage_and_guidelines.md:57`).

The closest thing to a rule is the interactor prohibition:

> "### Pass All Dependencies via Context
> …
> ```ruby
> # ❌ WRONG - Don't access globals or instance variables
> class CreateJobApplication
>   def call
>     @organization = Organization.find(session[:org_id])  # BAD
>   end
> end
> ```"

`cursor_rules/backend/interactors/interactor_usage_and_guidelines.md:45-60`. That governs interactors
reading the session, not controllers writing cookies.

**Codebase posture — surfaced, not adjudicated.** The analytics stack in this repo carries an explicit,
commented GDPR stance:

```ruby
Ahoy.mask_ips = true # for GDPR, no IP tracking
Ahoy.cookies = false # for GDPR, no cookies
```

`config/initializers/ahoy.rb:9-10`. Both existing app-written cookies
(`app/controllers/account/pages_controller.rb:5`, `app/controllers/connect/pages_controller.rb:7`) store
a referrer URL, not an identifier, and neither passes `httponly: false` or any options hash — they take
Rails' defaults. There is no precedent in this codebase for writing a user identifier into a
JS-readable cookie. That is a factual gap, not a verdict.

Two related surfaces exist for exposing values to the browser, both same-origin only and neither a
cookie: `app/views/layouts/application.html.erb` sets `window.*` globals from `Variables::*`
(`window.POSTHOG_API_KEY`, `window.SERVER_ENV`, `window.IS_DEVELOPMENT` …), and
`app/views/hire/pages/root.html.erb` is a bare React mount div with no server-injected data.

### 3i. Ruby style rules that will touch the diff

> "### 7. Single Quotes for String Literals
>
> Use double quotes only for interpolation or special characters."

`cursor_rules/backend/_base.md:171-173`.

> "### 15. Never Rescue at Class or Module Level ⚠️"

`.claude/CLAUDE.md:343` (also `cursor_rules/backend/_base.md:54`).

> "### 1. Controllers: NO BEGIN BLOCKS ⚠️"

`.claude/CLAUDE.md:63` (also `cursor_rules/backend/controllers/controller_error_handling.md:11`).

> "### 10. No Bang Methods (`!`) ⚠️
>
> Don't use bang methods (`update!`, `create!`, `save!`) that raise exceptions on failure."

`.claude/CLAUDE.md:264-266`.

> "### 17. No `reload` in Application Code ⚠️"

`.claude/CLAUDE.md:378` (also `cursor_rules/backend/_base.md:135`).

> "- Fix linter violations ONLY on lines you wrote or modified. Do not fix pre-existing violations in files you touched.
> - Do not run linter auto-fix on entire files."

`.claude/CLAUDE.md:527-528`.

> "- Implement fully, no placeholders or TODOs (UNLESS user specifically asked for placeholder or TODO)"

`cursor_rules/core_critical_rules.md:353`.

### 3j. Frontend rules that would apply IF a frontend piece turns out to be needed

The brief asked for these even though the change looks backend-only. My read: **no frontend change is
implied by the conventions** — nothing in the hire React app needs to read this cookie (the consumer is
`www.polymer.co`, a different repo). If that changes, these apply:

> "### 3. Trust the API Transformation Layer — No snake_case Fallbacks"

`cursor_rules/frontend/_base.md:67`.

> "### 4. Pragmatic TypeScript — Use `any` When Needed
>
> Prioritize working code over perfect types. This codebase wasn't built for strict typing."

`cursor_rules/frontend/_base.md:115-117`.

> "### 1. Do Not Use Nullish Coalescing Operator (`??`)
>
> Not supported in current build config."

`cursor_rules/frontend/_base.md:18-20`.

> "### 6. Do NOT Use `useMemo` for Minor Computation"

`cursor_rules/frontend/_base.md:149`.

> "- Use PascalCase for component filenames (e.g., `JobContainer.tsx`)
> - Use camelCase for hook filenames (e.g., `useCandidate.ts`)"

`cursor_rules/frontend/_base.md:177-178`.

> "**TypeScript/React:**
> - Double quotes for strings
> - Functional components with hooks"

`cursor_rules/core_critical_rules.md:428-430`.

> "### 1. When to Create a Variable vs. Inline a Condition
>
> - **Don't create a variable** for a simple boolean based on one condition"

`cursor_rules/frontend/boolean_variables_and_naming.md:9-11`.

And the house cookie-reading form, which already exists and must be reused rather than reinvented —
`getCookieEntries` / `getCookieValue` in `app/javascript/shared/lib/utils.js:39-55`, which does exact
name matching and splits on the first `=`:

```js
const cookieName = cookieEntry.substring(0, separatorIndex);
const cookieValue = cookieEntry.substring(separatorIndex + 1); // everything after the FIRST "="
if (cookieValue.length === 0) return; // cookie present with empty value = absent
```

`app/javascript/shared/lib/utils.js:44-46`. The older `useCookieValue`
(`app/javascript/shared/hooks/useCookieValue.ts:10`) uses `cookie.split("=")[1]`, which truncates a
value at its second `=` — do not copy that one.

Finally, contexts are off-limits:

> "## Files You Should Never Edit
>
> Unless explicitly asked:
> - Context files (`ModalContext.tsx`, `ToastContext.tsx`, `CurrentSessionContext.tsx`)
> - `api.ts` (API layer)
> - Core infrastructure components
> - `AGENTS.md` — do not create, modify, or write to any AGENTS.md file"

`.claude/CLAUDE.md:537-543`.

---

## 4. Three structural analogs

The brief asked for controller callbacks that perform a per-request side effect on the response or on
external state. **Three qualifying callbacks exist, plus two cookie writes that are NOT callbacks.**
No single place in this codebase does both — there is no existing "callback that writes a cookie."
I am reporting all five rather than pretending the union exists.

AI-related files were excluded as analog sources per the standing disqualification.

### Analog A — `Api::V1::BaseController#set_sentry_context`

`app/controllers/api/v1/base_controller.rb:7, 31-46`

```ruby
class Api::V1::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :track_ahoy_visit
  before_action :authenticate_api_v1_user!
  before_action :set_sentry_context

  alias current_user current_api_v1_user
  ...
  private

  def set_sentry_context
    return unless current_user

    Sentry.set_user(id: current_user.id, email: current_user.email)
  end
end
```

Per-request side effect on external state (Sentry's user context), keyed on the signed-in user's `id`.

### Analog B — `Admin::BaseController#set_sentry_context`

`app/controllers/admin/base_controller.rb`

```ruby
class Admin::BaseController < ApplicationController
  skip_before_action :track_ahoy_visit
  before_action :verify_current_user_is_admin
  before_action :set_sentry_context

  private
  ...
  def set_sentry_context
    return unless current_user

    Sentry.set_user(id: current_user.id, email: current_user.email)
  end
end
```

Byte-for-byte the same method as Analog A, duplicated rather than shared. The same file also holds
`verify_current_user_is_admin`, a private callback whose side effect is on the response
(`redirect_to root_path unless current_user_is_admin?`).

### Analog C — `JobBoard::BaseController#switch_locale`

`app/controllers/job_board/base_controller.rb:5, 36-49`

```ruby
class JobBoard::BaseController < ApplicationController
  layout 'job_board_application'
  around_action :switch_locale
  ...
  def switch_locale(&action)
    @is_custom_domain = !Variables::APP_DOMAIN_LIST.include?(request.domain)
    @careers_page = @is_custom_domain ? CareersPage.find_by(custom_domain: request.host) : CareersPage.friendly.find_by(slug: params[:organization_slug])

    ap 'SWITCH LOCALE'
    ap @careers_page&.language

    locale = @careers_page&.language || I18n.default_locale
    I18n.with_locale(locale, &action)
  end
end
```

The only `around_action` in the app. Note it is NOT private — this file has no `private` keyword at all.
It is also the clearest in-controller example of deriving behavior from `request.domain` against
`Variables::APP_DOMAIN_LIST`.

### The two cookie writes (not callbacks)

`app/controllers/account/pages_controller.rb:3-6`

```ruby
class Account::PagesController < Account::BaseController
    def root
      cookies[:account_referrer] = request.referrer
    end
  end
```

`app/controllers/connect/pages_controller.rb:3-8`

```ruby
class Connect::PagesController < Connect::BaseController
  def root
    redirect_to app_root_url and return unless current_organization_user.is_admin

    cookies[:connect_referrer] = request.referrer
  end
end
```

### Shared structural traits, stated concretely

- **Registration.** All three callbacks are declared at the top of the class body, immediately after the
  class line and any `layout` / `skip_before_action` lines, before any method definitions. `before_action`
  in two cases, `around_action` in one. No `after_action` is live anywhere in the app.
- **Placement of the method.** Two of three are under a `private` keyword at the bottom of the same class
  (`api/v1/base_controller.rb:31`, `admin/base_controller.rb`). The third
  (`job_board/base_controller.rb`) has no `private` at all — its callback targets are public. So "private"
  is the majority form but not universal.
- **Not in a concern.** None of the three is in `app/controllers/concerns/`. The identical
  `set_sentry_context` body is physically duplicated across two base controllers rather than extracted.
  `app/controllers/concerns/` holds only `role_fit_filterable.rb` and an `api_public/` subdirectory.
- **Naming.** Verb-first snake_case describing the effect: `set_sentry_context`, `switch_locale`,
  `verify_current_user_is_admin`, `set_job`, `set_organization`, `redirect_if_authed`. No `_callback`
  suffix, no `handle_` prefix.
- **Guarding.** The two that depend on a signed-in user open with a bare early return —
  `return unless current_user` — as the first statement, before the side effect. This matches the
  bail-out-only guard rule exactly.
- **Where they live in the hierarchy.** Each callback is declared on the *base controller* for its app
  area (`Api::V1::BaseController`, `Admin::BaseController`, `JobBoard::BaseController`), never on
  `ApplicationController`. `ApplicationController` carries no live `before_action` of its own — only the
  gem-injected `track_ahoy_visit` from `ahoy_matey-4.0.1/lib/ahoy/controller.rb:9`, which the area base
  controllers then individually `skip_before_action`.
- **The cookie writes diverge from all of the above.** Both are inline in the `root` action, not in a
  callback, not private, no options hash on the cookie (no `domain:`, no `httponly:`), and no guard on
  the value being written. `Connect::PagesController` puts a bail-out redirect above the cookie write;
  `Account::PagesController` has no guard at all.
- **The hire app has no such callback yet.** `Hire::BaseController`
  (`app/controllers/hire/base_controller.rb`) is two lines: it only skips `track_ahoy_visit`.
  `Hire::PagesController` (`app/controllers/hire/pages_controller.rb`) has one `before_action
  :redirect_if_authed, except: %i[root]` and a private `redirect_if_authed`. Per `config/routes.rb:568`
  and the AUTHED ROUTES block, `pages#root` is the action every signed-in app load lands on, and it is
  precisely the action `redirect_if_authed` excludes.

---

## 5. Rules this change would violate or sit awkwardly against

Surfaced, not resolved.

1. **`Ahoy.cookies = false # for GDPR, no cookies` (`config/initializers/ahoy.rb:10`), paired with
   `Ahoy.mask_ips = true # for GDPR, no IP tracking` (line 9).** The codebase's analytics layer was
   deliberately configured to set no cookies for GDPR reasons. This feature adds a cookie carrying a
   user identifier, readable by JavaScript, for the purpose of retargeting exclusion. It is a different
   subsystem and a different purpose, and there is no rule forbidding it — but it is the one recorded
   privacy stance in the repo and this change runs against its grain. Jessica's call.

2. **`httponly: false` has no precedent and no rule.** Neither existing cookie write passes any options.
   Rails' `ActionDispatch::Cookies` default for a plain `cookies[:x] =` assignment is already
   `httponly: false` (only `cookies.signed`/`encrypted` and the session cookie set HttpOnly here), so
   passing it explicitly is redundant *as behavior* but is the only way to make the intent legible. There
   is no house rule either way. Flagging because "add a param that changes nothing at runtime" is the kind
   of thing a reviewer will challenge without the intent documented.

3. **The `domain:` option would be the first in the codebase.** `grep -rn "cookies\[" app/ lib/ config/`
   returns exactly two writes, neither with options. Whatever form the domain derivation takes will be
   setting precedent, not following it. The nearest precedent for the *derivation itself* is
   `request.domain` + `Variables::APP_DOMAIN_LIST` (§3f), which is well established.

4. **Scope ambiguity in the controller rules.** `cursor_rules/backend/controllers/controller_patterns_and_crud.md:3`
   states "These rules apply to internal API controllers in the `Api::V1::` namespace
   (`app/controllers/api/v1/`)", and `cursor_rules/backend/architecture.md` is written entirely around the
   JSON request cycle (`Controller → Pundit → Interactor → Model → Serializer → JSON Response`). The hire
   page controllers are HTML controllers outside that namespace. **Two readings:** (a) the controller rules
   do not formally bind `Hire::PagesController`, and only `cursor_rules/backend/_base.md` (which claims
   "all Ruby/Rails files in `app/`") applies; (b) the `Api::V1::` scoping is meant to separate internal
   from *public* API conventions (the header's own next line points to `public_api_controllers.md`), not to
   exempt HTML controllers, so the callback/private-method conventions still govern. I lean (b) on the
   header's own framing, but the text supports (a) literally. Worth a line in the spec either way.

5. **`.cursorrules` is stale and points at files that do not exist.** It instructs "ALWAYS read
   `cursor_rules/rules.md`" plus `typescript_react.md`, `controller_rules.md`, `interactors.md`,
   `services.md`, `error_handling.md`, `architecture.md`, `migration_guidelines.md`. Of those, only
   `services.md` and `architecture.md` exist, and both only under `cursor_rules/backend/`. Anyone
   following `.cursorrules` literally reads nothing. Not a conflict with this feature, but it will
   mislead an implementation agent told to "follow `.cursorrules`."

6. **Three area `core_critical_rules.md` files are stale copies.** `backend/`, `frontend/` and `cypress/`
   each carry an outdated duplicate missing four rules that the root file has — including "Never Fabricate
   Fallback Values" and the `x != undefined` guard rule. An agent told to read
   `cursor_rules/backend/core_critical_rules.md` for backend work will not see the fallback rule at all.

7. **Two hub-level rules (30 and 31) now have no live exemplar.** `~/claude-hub/inflow-ats/CLAUDE.md`
   rules 30 (`Devise::Test::ControllerHelpers` + `devise.mapping`) and 31 (queue-adapter `around` block)
   both cite spec files that no longer exist, and rule 0a forbids creating their successors. The
   underlying mechanisms are still real (`config/environments/test.rb:64` still sets
   `queue_adapter = :inline`), but neither rule can bind this change.

---

## 6. Rules I read and determined do not apply — one line each

- `cursor_rules/backend/migrations.md` — no schema change; boolean-prefix and enum-default rules have nothing to bind to. (Read in full anyway; the boolean-verb rule is noted in §3b in case a flag appears.)
- `cursor_rules/backend/serializers.md` — scope is `app/serializers/`; a cookie is not serialized output.
- `cursor_rules/backend/background_jobs.md` — scope is `app/jobs/`; the write is synchronous, in-request.
- `cursor_rules/backend/public_api_controllers.md` — scope is `ApiPublic::V1::Hire::` at `api.polymer.co`; this is a hire HTML controller.
- `cursor_rules/public_api_controller_rules.md` — near-duplicate of the above, same scope, same non-applicability.
- `cursor_rules/backend/controllers/pundit_policies.md` — read in full; authorization is about who may perform an action, and this callback performs no authorizable action (the user is already authenticated by the time it runs). No `authorize` call is implied. Flagging in case the spec wants one anyway.
- `cursor_rules/backend/job_board_integration/job_board_architecture_and_model.md` — scope is `BoardXxxListing` job-board integrations.
- `cursor_rules/backend/job_board_integration/job_board_controller_and_webhooks.md` — same scope, webhooks.
- `cursor_rules/backend/job_board_integration/job_board_frontend_and_checklist.md` — same scope, its frontend checklist.
- `cursor_rules/console_commands.md` — read in full; governs Rails-console and bash ergonomics (`ap`, `JSON.pretty_generate`, methods ending in a print statement). Relevant only if manual verification is done via `rails runner`/console, which rule 0a's "Verification is manual" makes likely.
- `cursor_rules/cypress/cypress_assertions_and_antiflake.md` — applies only if a Cypress test is written.
- `cursor_rules/cypress/cypress_common_pitfalls.md` — same condition.
- `cursor_rules/cypress/cypress_selectors_and_interactions.md` — same condition; selector rules, and this feature has no UI to select.
- `cursor_rules/cypress/cypress_troubleshooting.md` — same condition; diagnostic guidance.
- `cursor_rules/cypress/core_critical_rules.md` — stale duplicate of the root core rules; superseded.
- `cursor_rules/backend/core_critical_rules.md` — stale duplicate; superseded by root.
- `cursor_rules/frontend/core_critical_rules.md` — stale duplicate; superseded by root.
- `cursor_rules/frontend/components/component_architecture.md` — no component is being built.
- `cursor_rules/frontend/components/component_size_and_extraction.md` — no component.
- `cursor_rules/frontend/contexts/context_reference.md` — no context is being touched; contexts are read-only per `.claude/CLAUDE.md:537-543`.
- `cursor_rules/frontend/contexts/context_usage_and_rules.md` — same.
- `cursor_rules/frontend/forms/form_guards_and_conditional_fields.md` — no form.
- `cursor_rules/frontend/forms/form_state_and_change_handlers.md` — no form.
- `cursor_rules/frontend/forms/form_submission_and_mutations.md` — no form, no mutation.
- `cursor_rules/frontend/forms/form_validation_and_errors.md` — no form.
- `cursor_rules/frontend/lists/list_actions_and_modals.md` — no list.
- `cursor_rules/frontend/lists/list_sorting_and_filtering.md` — no list.
- `cursor_rules/frontend/lists/list_structure_and_data_fetching.md` — no list.
- `cursor_rules/frontend/modals/modal_form_and_confirmation_patterns.md` — no modal.
- `cursor_rules/frontend/modals/modal_state_errors_and_loading.md` — no modal.
- `cursor_rules/frontend/react_hooks.md` — no hook, unless a frontend read is added later.
- `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md` — no React Query surface; a cookie is not server state fetched through `api.ts`.
- `cursor_rules/frontend/react_query/react_query_queries.md` — same.
- `cursor_rules/frontend/reference_patterns.md` — self-described as "templates and examples, not enforcement rules" (line 3); no component to template.
- `cursor_rules/frontend/ui_styling.md` — no Emotion styling, no theme colors.
- `cursor_rules/backend/interactors/*` — read in full and quoted in §3c for the >15-line threshold; the interactor form itself is not reached at this size.
- `cursor_rules/backend/services.md` — read in full and quoted in §3b/§3c; none of the four "create a service when" triggers is met.
