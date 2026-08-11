# inflow-ats — Pipeline Scratchpad

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Stack:** Ruby 3.1+ / Rails 6.1+ / PostgreSQL / Pundit / Sidekiq · TypeScript 4+ / React 18+ / React Query / Emotion
**Status:** Focus pipeline.
**Conventions sources:**
- This file (`~/claude-hub/inflow-ats/CLAUDE.md`) — pipeline-level rules and known failure patterns
- The source repo's `CLAUDE.md` — core development rules, critical "AI keeps getting these wrong" rules
- `cursor_rules/` directory in the source repo — 45 rules files organized by area (backend, frontend, cypress). Read `core_critical_rules.md` plus the area-specific `_base.md` for each area you touch. Do NOT read all 45 upfront.
- Existing codebase patterns — the codebase itself is a conventions source. Find analogs for whatever you're building.

## What lives in the source repo (authoritative — do not duplicate here)

- `CLAUDE.md` (~500 lines) — core development rules, critical "AI keeps getting these wrong" rules
- `cursor_rules/` — full conventions per area (backend, frontend, cypress, etc.)
- `.claude/agents/` — existing agent definitions (under review; Jessica plans to evaluate which to keep)
- `.claude/commands/cci.md` — existing slash command

The source repo is authoritative for code conventions. **Sessions launched into this scratchpad must read the source repo's `CLAUDE.md` and the relevant `cursor_rules/` area files.** The agent prompts in `_templates/` enforce this.

## What lives here (in this scratchpad)

Cross-session artifacts that should NOT be written into the source repo:

- `features/<slug-YYYY-MM-DD>/` — multi-session feature design, plans, in-progress notes
- `investigations/<slug-YYYY-MM-DD>/` — bug traces, flaky test diagnosis, perf investigations
- `pr-reviews/<PR-number>/` — adversarial PR reviews and notes
- (other workflow subdirs as we add them)

## In-progress working artifacts

Pipeline-specific working artifacts that need durable file storage during a session — draft agents specific to inflow-ats, in-flight investigation notes, feature design drafts that may or may not graduate to a permanent location — live in `~/claude-hub/inflow-ats/_in-progress/<artifact-name>/`, with each work item getting its own per-item subdirectory.

These artifacts do NOT live in the hub-root `~/claude-hub/_in-progress/`. That location is reserved for hub-level and cross-pipeline working artifacts (see the hub root `CLAUDE.md` for the full convention).

The user retains complete control over `_in-progress/` contents: graduate artifacts to their permanent location by moving them, or delete entire `_in-progress/` subdirectories without affecting anything outside.

## Hard rules inherited from global `~/.claude/CLAUDE.md`

These apply to every inflow-ats session and override anything else:

- **Database safety hard rules** — no DROP DATABASE, no `rails db:reset`/`db:setup`/`db:schema:load`, no direct `psql` writes or reads, no setting `DATABASE_URL`, no editing `.env`. Read/write the DB only via running app, `rails console`, or `rails runner`.
- **Pre-commit tests are non-negotiable** — never `--no-verify`, never rewrite tests to pass. Commit via `nvm use && git commit ...` outside the sandbox.
- **Never work directly on `master`** — always a branch.

## Feature Development Harness

This pipeline has pipeline-specific prompt overrides at `~/claude-hub/inflow-ats/features/`. These override the generic prompts at `~/claude-hub/features/` for inflow-ats work (they add `cursor_rules/` integration and Rails/React-specific guidance). Read `~/claude-hub/features/LIFECYCLE.md` for the orchestrated flow — it will find the inflow-ats overrides automatically.

## Pipeline-specific rules

### Source repo path: check REPO-PATH first

Workflow subdirs (e.g., `ai-billing-overhaul-2026-06-23/`) contain a `REPO-PATH` file that points to the correct source repo or worktree for that workflow. **Read `REPO-PATH` before any source file reads, greps, or agent dispatches.** The path in `REPO-PATH` overrides the default source repo path at the top of this file — the default points to the main checkout, which may be on a different branch.

## Known Failure Patterns

Rules extracted from adversarial review findings. Each cites its motivating failure.

### 1. Emotion theme utilities are complete CSS declarations, not raw values

`t.text.sm`, `t.text.xs`, etc. are `css` template literals that already include the `font-size:` property declaration. Use them standalone, not inside a `font-size:` property.

```tsx
// WRONG -- produces "font-size: font-size: 0.875rem;" (invalid CSS)
font-size: ${t.text.sm};

// CORRECT -- standalone usage
${t.text.sm};
```

*Motivated by: email-subjects-phase-1 impl-round-2 frontend-contract F1 -- `ChannelMessageTemplateSelectionModal.tsx` line 207 produced invalid CSS.*

### 2. Parallel-field features: trace every pipeline end-to-end before implementing

When adding a new field that parallels an existing field through multiple pipelines (e.g., `subject` paralleling `body`), enumerate every code path the original field flows through BEFORE writing code. For each path, verify the new field is threaded through: controller permit, controller sanitize, interactor/job processing, model validation, mailer consumption, serializer exposure, anonymization, and frontend form/validation/mutation/display. A missed path means the field silently drops and the fallback fires without the user knowing.

*Motivated by: email-subjects-phase-1 review structure -- the spec and impl reviews verified subject flowed through all 7 channel_message creation paths and 4 distinct pipelines (single-send, bulk, automation, apply-response). The implementation got this right, but only because the spec and plan explicitly enumerated every path. Without that enumeration, paths get missed.*

### 3. Specs and plans must include test requirements

Every spec and implementation plan must state which existing tests need updating and what new test coverage is required. "No tests" is acceptable only when explicitly documented with reasoning (e.g., test infrastructure unavailable), never by omission.

*Motivated by: email-subjects-phase-1 spec-round-1 always-on-checks F2 -- the spec had no test plan section. No tests were created during implementation. The absence was caught by review but should have been caught at spec time.*

### 5. Full-stack feature specs must list all modified files, not just new files

When specifying a feature that touches existing files (controllers, serializers, TypeScript interfaces, UI components), the spec must explicitly list every modified file and what changes. New files are obvious; modifications to existing files are where things get missed. If a feature adds a new preference/field/column, trace it through every layer that already handles the analogous existing fields and list each one.

### 6. Rename cascades: grep for ALL references, including spec files

When renaming an identifier (enum value, settings key, method name, class name), grep the entire codebase (`app/`, `spec/`, `config/`, `lib/`, `db/`, `app/javascript/`) for every reference to the old name. Do not rely on the plan's file list -- plans routinely omit spec files from rename ripple sites. When fixing a stale reference found by review, grep again after fixing to confirm zero remaining references. Do not fix only the files named in the failure report.

*Motivated by: ai-summaries-phase-1 impl-round-1 H3 + impl-round-2 H1 -- the plan listed 9 app files for the `default_auto_generate_ai_summaries_enabled` rename but omitted 3 spec files. Round 1 found 2 stale spec files; the fix agent updated only those 2. Round 2 found a third (`organization_ai_credits_lifecycle_spec.rb`). The defect recurred because the fix agent did not grep for additional stale references.*

### 7. Test stubs must not mask type mismatches at API boundaries

When a test stubs an external API call (e.g., `Stripe::Checkout::Session.list_line_items`), the stub's arguments must match what production code actually passes. If production passes an invoice ID but the stub accepts it without complaint, the test masks a `Stripe::InvalidRequestError` that will fire in production. Review stubs to confirm the object type flowing through production matches what the API expects.

*Motivated by: ai-summaries-phase-1 impl-round-1 H1 -- the `invoice.paid` top-up handler passed a Stripe invoice to `ApplyAiCreditPurchase`, which called `Stripe::Checkout::Session.list_line_items(session.id)` with an invoice ID (`in_xxx`). The spec stubbed `list_line_items` to accept the invoice ID, masking the type mismatch. In production, Stripe would reject the call and the customer would pay but receive no credits.*

### 8. Webhook handlers: trace guard ordering before adding new branches

When adding a new branch to a webhook handler (or any method with early guards/raises), trace the full control flow from method entry to the new branch. Verify that no guard between the entry point and the new branch will reject the request for the new branch's use case. Guards that protect existing branches may not apply to the new one.

*Motivated by: ai-summaries-phase-1 spec-round-1 BLOCKER -- the `invoice.paid` handler had `raise CustomStripeSubscriptionMissingError if organization.stripe_subscription_id.nil?` before all metadata branches. The new `ai_credit_pack_top_up` branch (for orgs without a subscription) was placed after this guard, meaning it would never be reached. Also plan-review pass-1 HIGH -- listing branches moved above the guard without adding `return`, allowing fall-through to the guard.*


### 10. Fix agents must not add code beyond the defect scope

When fixing a defect found by review, the fix must be the minimum change that resolves the specific finding. Do not rewrite the surrounding method from scratch. Do not add new methods, new event handlers, new migrations, or new validation rules that were not in the original spec. Do not "improve" adjacent code while you're in the area. If the fix seems to require substantial new functionality, stop and flag it for a new spec/plan/review cycle instead of writing it inline.

*Motivated by: ai-summaries-phase-1 impl-round-5 -- 9 HIGH findings, all caused by a fix agent. The agent was given a single defect (invoice passed where checkout session expected) and instead of making a minimal fix, it wrote ~200 lines of new code: a 46-line `apply_one_off_from_invoice` duplicate method, 3 new webhook event handlers (`charge.refunded`, `customer.subscription.updated` AI branch, `customer.subscription.deleted` AI branch), a complete 59-line rewrite of `handle_credit_pack_invoice_paid`, a new `subscription_status_for_stripe` helper, a validation relaxation on `stripe_checkout_session_id`, and a new migration. None of this was specified. All had to be removed in Round 6.*

### 11. Analog replication: copy behavioral props, not just layout

When replicating an analog component's behavior, copy ALL behavioral props (`loading`, `disabled`, error state guards), not just the visual layout and event handlers. If the analog passes `loading={x} disabled={x}` to a Button, the new component must too. Audit the analog's JSX for every prop that affects user interaction.

HARD SUB-RULE (added after the third occurrence of this class): the shared `Button` component does NOT block clicks when `loading` is true — only `disabled` prevents `onClick` (`app/javascript/ats/src/components/shared/Button/index.js:33-37`). Every `Button` that passes `loading={x}` MUST also pass `disabled={x}`. `loading` alone on an action button is a defect, regardless of what any analog or design shows. Reviewers: grep every new/modified component for `loading={` and confirm the paired `disabled={`.

*Motivated by: ai-display impl-round-1 M1 + impl-round-2 M1 -- `PlatoTab.tsx` replicated `AiSummaryState.tsx`'s generate handler but omitted the `loading`/`disabled` props the analog passes to its Button. Users could double-click and queue duplicate requests. The fix agent then fixed two Button instances but missed a third raw `styled.button` that also called `handleGenerate`. Took two rounds to catch all callsites. RECURRED (third occurrence): job-criteria-settings impl-round-1 F1 (HIGH) -- `JobCriteriaSection.tsx` passed `loading={isInFlight}` without `disabled={isInFlight}` on the Generate/Regenerate button, letting a user click the spinner, confirm the modal, and enqueue a second paid extraction while one was in flight.*

### 12. Styled components: use separate components for visual variants, not conditional props

Do not pass custom boolean props (e.g., `isKey`, `isActive`) to styled HTML elements. Instead, create separate styled components for each variant and select at the call site. Custom props forwarded to DOM elements produce React console warnings and require workarounds (`$`-prefix, `shouldForwardProp`).

*Motivated by: ai-display impl-round-3 M1 -- `Styled.SkillChip` accepted an `isKey` prop to toggle between key-skill and regular styling. React forwarded the prop to the DOM `<span>`, producing console warnings. User directed: split into `Styled.SkillChip` + `Styled.KeySkillChip`.*

### 13. Never fabricate fallback values for absent data

Do not use `|| 0`, `|| ""`, `|| []`, or any other fallback that substitutes a non-nil value for absent data. The app handles nil/null/undefined/empty throughout. Fabricating a fallback disguises missing data as real data and causes downstream bugs. Only add fallbacks with explicit permission.

*Motivated by: ai-display QA run-1 Layer 1 -- `useAiJobApplicationSummary` was called with `aiSummary?.id || 0`, firing a GET request to `/ai_job_application_summaries/0` (guaranteed 404) on every render when no summary existed. The `|| 0` fallback created a real-looking ID from nothing. Also added as core_critical_rules.md rule 10.*

### 14. Analog structural matching: compare signatures, not just layers

When the codebase has an analog for the feature being built, the review must compare at the STRUCTURAL level — parameter interfaces, retry/exhaustion patterns, callback patterns, error handling shapes — not just verify that layers exist. "The feature has a controller, serializer, and job" is layer completeness. "The feature's controller accepts the same parameter shape as the analog's controller" is structural matching. Layer completeness without structural matching lets deviations through.

Specifically:
- **Controller parameter interfaces:** if existing bulk operations accept `job_id` + `hiring_stage_id` + `included/excluded_ids` with server-side resolution, the new bulk operation must too. Do not accept raw ID arrays resolved client-side when the analog resolves server-side.
- **Job retry/exhaustion patterns:** if other jobs in the same domain use exhaustion blocks on `retry_on`, the new job must too. Do not skip the exhaustion block when analogs have one.
- **Callback patterns:** if analogous models use `after_commit` callbacks to trigger downstream work, the new model should follow the same pattern unless there's an explicit reason not to.

The review agent must grep for analog files, read their signatures and patterns, and diff against the new code. A structural mismatch is BLOCKER.

### 15. Implementation reviews must review committed code, not the working tree

Review agents must verify they are reviewing the code that will be merged -- the committed diff on the branch -- not the files on disk. Run `git diff HEAD` before starting. If uncommitted changes exist, the review must either require a commit first or explicitly note that the working tree (not the branch) is being reviewed. A PASS verdict on working-tree code is meaningless if that code was never committed.

*Motivated by: ai-scoring-v3 impl-round-3 BLOCKER -- 12 files had uncommitted changes containing the actual implementation. Rounds 1 and 2 both reviewed working-tree files on disk and issued verdicts (FAIL then PASS) without noticing the branch was materially incomplete. The committed code had stale enum references (`in_progress`, `extracted`, `succeeded`) that would throw `ArgumentError` on every invocation. Round 3 caught it by comparing committed code to working tree.*

### 16. Companion records: create via the unconditional owner, not via the conditional association

When a model has a companion record (status record, read model, denormalized summary), create it from the model that unconditionally owns it — not from the model that is conditionally associated with it. `AiJobApplicationSummaryStatus` belongs to `JobApplication` (unconditional, one-to-one). It does NOT belong to `AiJobApplicationSummary` (conditional — summaries come and go, status record persists). Create it via an interactor called from the unconditional owner's setup callback and from the shared pipeline entry point. Do not scatter `find_or_create_by` calls across individual interactors — that misses code paths.

*Motivated by: ai-scoring-v3 impl-round-1 F5 (HIGH) -- `AiJobApplicationSummaryStatus` was only created in `CreateAiSummaryGeneration`. Auto-triggered evaluations never had a status record. Subsequently refactored: `create_status_record` callback removed from `AiJobApplicationSummary`, `find_or_create_by` calls removed from `CreateAiSummaryGeneration`, replaced by `FindOrCreateAiJobApplicationSummaryStatus` interactor called from `JobApplication#enqueue_new_job_application` and `TextractResult#generate_ai_summary_with_credit_flow`.*

### 17. Schema rollbacks destroy data migration records — roll back and re-run data migrations

After rolling back schema migrations with `db:rollback STEP=N`, any data migrations (`db/data/`) with timestamps between the rollback point and HEAD had their data wiped — but their status in `data_migrations` still shows "up." `rails data:migrate` skips them because it thinks they already ran. Check `db/data/` for data migrations in the affected range, roll each back with `rails data:migrate:down VERSION=<timestamp>`, then re-run with `rails data:migrate`. This applies to both dev and test databases.


### 20. Fixing a gap must not change shared infrastructure (enum values, columns, display-state semantics) without explicit owner approval

A gap fix is the MINIMUM change that closes the gap. It must NOT add a value to a shared enum, repurpose a status, or transition an existing display state in a way that destroys data the owner relies on — even when a finding/spec says a state is "missing." First ask what the enum/state is FOR. `AiJobApplicationSummaryStatus` exists only to check for a SUCCEEDED review; it deliberately has no `failed` value. Failures live on the `AiJobApplicationSummary` (its enum has `failed`), and the UI shows failure from the summary, not the status row. The correct failure behavior on the status row is: `initial_summary_pending` → `none`; `current`/`regenerating` → untouched (so a prior succeeded review stays accessible). When a fix seems to require a new enum value or a new state transition, STOP and confirm with the owner — that is an infrastructure change, not a gap fix.

*Motivated by: ai-summary-creation-gaps W5 (issue 3a). A reviewer-blessed spec said the status row "has no failed state" and the fix added `failed: 4` to the `AiJobApplicationSummaryStatus` enum and routed all terminal failures through a `record_failure` choke-point that transitioned the row `current → failed`, clearing the denormalized score/headline/analysis. This DESTROYED a user's prior succeeded review whenever a later regeneration failed. Jessica caught it ("Why would we ever change it from current to failed? Failed isn't even a status."). Fully reverted: no enum change; failure → `initial_summary_pending`→`none`, `current`/`regenerating` untouched. The whole spec + 8-round spec review never questioned whether the status enum SHOULD gain a failed value — they verified the implementation matched the spec, not whether the spec respected the existing infrastructure's purpose.*

### 21. Stay in the LIFECYCLE phase loop — do not hand-fix review findings in the main thread

LIFECYCLE Phase 6 is an orchestrated loop: a FRESH review sub-agent per round writes findings, a Phase 5 fix sub-agent applies them, repeat to two clean passes. When the orchestrator drops out of that loop and hand-patches findings itself, it (a) loses the fresh-agent adversarial scrutiny on the fixes, and (b) drifts toward unscoped changes. If a background review agent dies mid-run (e.g., a transient API 500), read its written angle files for the partial findings, then RE-DISPATCH a fresh round — do not silently take over the fixing.

*Motivated by: ai-summary-creation-gaps Phase 6. The orchestrator began hand-writing test coverage and hand-fixing review-flagged gaps in the main thread instead of running the Phase 5↔6 sub-agent loop; Jessica had to redirect: "don't get out of the lifecycle."*

### 22. ModalContext props are frozen at `openModal()` time — do not rely on state-derived props updating

When a React element is passed to `openModal()`, `ModalContext` stores it as frozen state via `setModal(element)`. Any prop value captured in the element — including state-derived values like `isLoading`, `disabled`, error messages — is captured at call time and never updates, even when the underlying state changes. This means `loading={isCommittingChange}` will always be `false` if the modal was opened before the mutation started.

Two correct patterns:
1. **Dismiss before action:** Call `removeModal()` before firing the async operation. The modal is gone before loading state matters. Use when feedback is handled via toast/redirect.
2. **Read state inside the modal:** Pass a callback or context consumer so the modal reads current state at render time, not at open time.

Do NOT rely on a frozen loading/disabled prop to prevent double-clicks on confirm buttons inside modals.

### 23. Fix agents must not remove, delete, or rewrite existing code beyond defect scope

Rule 10 prohibits ADDING code beyond defect scope. This rule covers the opposite: fix agents must not REMOVE validations, DELETE entire files/components, or REWRITE existing methods that were not part of any finding. "Cleaning up while I'm here" is out of scope. A rewrite that changes data sources, drops API parameters, or alters query logic is a behavioral change that requires its own spec, plan, and review cycle.

Specifically prohibited without explicit spec coverage:
- Removing model validations (even conditional ones)
- Deleting components, files, or modules not named in any finding
- Rewriting an existing action's data source (e.g., switching from local DB lookup to Stripe API list)
- Dropping Stripe API `expand` parameters
- Changing toast delay values or other UI behavior constants

If the fix agent believes existing code is wrong or could be improved, it must flag it as a separate concern — not silently "fix" it alongside the assigned defect.

### 25. Do not use `update_columns` inside a transaction

`update_columns` bypasses transaction rollback. If the transaction fails, `update_columns` changes persist. Use `update` inside transactions instead. Outside transactions, `update_columns` is correct when you need to skip callbacks and have already verified prior steps succeeded via if-else guards.

`update_columns` is necessary when a record has callbacks you need to skip (many models in this codebase do). Always verify prerequisite steps have succeeded via if-else guards before calling it. The issue is when it's inside a transaction block where rollback guarantees matter and you have not verified that prerequisite steps succeeded.

*Motivated by: ai-billing-overhaul -- `finalize_stripe_payment` used `update_columns` inside transaction blocks, leaving `stripe_invoice_paid: true` on rollback.*

### 26. Test assertions must be falsifiable by removing the feature under test

A test is a ghost test if its assertions pass regardless of whether the feature it claims to test exists. Before writing a test for declarative configuration (`retry_on`, `validates`, `has_many`, `enum`, `scope`, `after_commit`), mentally delete the declaration from the class and ask: would this assertion still pass? If yes, the assertion is tautological and tests nothing.

Common tautological patterns:
- **Reflection that confirms method existence:** `expect(described_class.instance_method(:perform)).to be_a(UnboundMethod)` is true for ANY class with a `perform` method, regardless of `retry_on` configuration.
- **Assigned-but-never-asserted variables:** `retry_config = described_class.rescue_handlers` followed by assertions on something else. The variable exists to look like coverage.
- **Type checks on return values that are always that type:** `expect(result).to be_a(Hash)` when the method always returns a hash regardless of the configuration being tested.

For `retry_on` specifically: test behavioral outcomes (job re-enqueued, exhaustion block executed) not reflective properties of the class. A correct retry_on test raises the target error and asserts `have_enqueued_job` or verifies the exhaustion block's side effects (logging, status update).


### 27. Conventions review must be scoped one reviewer per rules file, not one broad "compliance" angle

A single broad cursor-rules-compliance angle that "checks ~30 rules files" finds almost nothing; a fan-out with one reviewer per cursor_rules file, each holding only that file's rules as its checklist against the diff, finds real defects. When conventions compliance is a review goal, dispatch per-rules-file reviewers — a combined angle reads the rules it already remembers and skims the rest.

*Motivated by: job-criteria-settings Phase 6.5. Impl rounds 1-3 each ran a cursor-rules-compliance angle spanning ~30 rules files and produced 0 MED conventions findings. The dedicated conventions pass (25 reviewers, one per cursor_rules file) then found 10 MED + ~20 LOW on the same diff — including a functional gap (the missing query error state, rule 28) and a backend/_base.md §8 `reload` violation. See reviews/conventions-pass/CONVENTIONS-FAILURE-REPORT.md.*

### 28. query-string v6.1.0 `parse` sorts keys alphabetically — occurrence-order logic must read the raw string

The installed `query-string` (v6.1.0) `parse` ends in `Object.keys(ret).sort().reduce(...)` (`node_modules/query-string/index.js:157`) — returned keys are alphabetized unconditionally, with no opt-out in this version. Any logic that depends on query-param occurrence order (first-N caps, first-occurrence-wins) must derive key order from the raw `location.search` string and use `parse` only for values. Repeated-param arrays are built in occurrence order and survive the final sort (the `!Array.isArray(value)` guard). Tests for order-sensitive behavior must use a non-alphabetical param order — with alphabetical input, a sorted-parse implementation passes anyway.

*Motivated by: attribution spec-round-1 frontend-capture-and-sanitization F1 (HIGH) — SPEC.md §5.1 defined the sanitizer's input as the object returned by `queryString.parse(location.search)`, making D4's "first 10 by occurrence order" rule unimplementable from the stated input; an implementer following the spec literally would ship an alphabetical-order cap, and the Jest test as previously written would pass anyway. Fixed by amending the input contract to the raw `location.search` string.*

### 29. `/auth` landings: signed-in users are bounced server-side before React runs — trace the landing route for every session state

`Hire::PagesController#redirect_if_authed` (`before_action` on `pages#auth`; routes.rb:591 → pages_controller.rb:24–31) 302s any signed-in `/auth` request to `app_root_path`, dropping all query params (only `invite_token` exempts). Fresh signups ARE signed in while unconfirmed: `User#active_for_authentication?` is `super || organization.nil?` (user.rb:136–138), so the typical same-browser email-confirmation click never renders `Auth.tsx`. Any feature that reads `/auth` query params or fires browser-side events on an `/auth` landing must state which session states actually reach the page — trace the server chain (route → before_actions → redirect) for signed-in, signed-in-unconfirmed, and signed-out arrivals before deciding event/capture placement.

*Motivated by: attribution spec-round-3 posthog-events-and-identity F1 (HIGH) — the approved D12 `email_verified` browser event on the `/auth?email_confirmed=true` landing fires only for confirmations clicked while signed out; the decision was made without `redirect_if_authed` on the table. Funnel step 3 undercounts with no server backup; disclosed as SPEC.md Risk 7 for Jessica's ruling.*

### 30. Devise controller specs need BOTH `Devise::Test::ControllerHelpers` and an explicit `devise.mapping`

Controller specs for any controller inheriting `DeviseController` require two lines, and the second is the one that gets missed: `include Devise::Test::ControllerHelpers` (warden setup — not wired globally in rails_helper) AND `before { @request.env['devise.mapping'] = Devise.mappings[:api_v1_user] }`. Devise 4.8.1's `DeviseController` runs `prepend_before_action :assert_is_devise_resource!`, which raises `AbstractController::ActionNotFound` whenever `request.env["devise.mapping"]` is unset — `Devise::Test::ControllerHelpers` does NOT set the mapping, and an in-action assignment runs after the prepend_before_action, so it cannot save the spec. The mapping name in this app is `:api_v1_user` (`devise_for` under `namespace :api/:v1`); `Devise.mappings[:user]` does not exist.

*Motivated by: attribution plan-review pass-1 test-coverage-and-ghost-tests F1 (HIGH) — plan task T4.1's omniauth-callbacks controller spec skeleton omitted the mapping line (a latent gap inherited from spec §9.3, which mandated only the helpers include); every T4 example would have failed at dispatch. Spec round 1 had already caught the missing helpers include itself (spec-round-1 test-coverage-and-ghost-tests F1, MED).*

### 31. Controller specs run jobs inline — swap the queue adapter or job side effects fire for real

`config/environments/test.rb:64` sets `config.active_job.queue_adapter = :inline`, so a controller spec that hits a job-enqueuing path executes the job inside the example — `NotifyUserJob` pings a real Slack webhook when the user has an organization. Follow the `bulk_ai_job_application_summaries_controller_spec.rb:9–14` precedent: an `around` block that sets `ActiveJob::Base.queue_adapter = :test` for the example and restores the previous adapter after.

*Motivated by: attribution planning — every new controller spec needed the around block added; plan-review pass-1 test-coverage-and-ghost-tests verified it as load-bearing (`:inline` at test.rb:64 + the real `Slack::Notifier` ping in `app/jobs/notify_user_job.rb` confirmed live).*

### 32. git stash: creating is allowed; pop/drop/clear are prohibited; never chain stash commands

Agents may run `git stash push`. Agents must NEVER run `git stash pop`, `git stash drop`, or `git stash clear` — the destructive stack operations are Jessica's only. `git stash apply` is permitted only on a stash the agent itself created in the current session, and only after verifying by message in `git stash list` output that stash@{0} is actually that stash. Never chain stash commands (`git stash push ... && git stash apply && git stash drop`): the failure mode is a silently failed `push` (e.g., an untracked-file pathspec with stderr suppressed) that leaves the chained destructive commands operating on someone else's stash@{0}. If a verification step needs a clean tree, prefer the committed branch state (`git diff` against HEAD, or a separate worktree via `wt`) over a stash round-trip. Recovery reference: a dropped stash commit is recoverable via `git fsck` → `git stash store`.

*Motivated by: INCIDENT-stash-2026-07-16 (attribution Phase 5) — the implementation sub-agent, verifying a pre-existing Jest failure, ran a chained stash round-trip; the push failed silently and the apply+drop consumed Jessica's stash@{0} ("On develop: Credits update and UI usage tweak stash", 5 files). Recovered via fsck with an unresolved stash-entry-count discrepancy.*

### 33. `document.cookie` reads: exact name match, split on the FIRST `=` only, empty value = absent

When reading a cookie by name: the cookie name is the substring before the FIRST `=`, compared by exact equality — a bare `startsWith("_ga")`-style lookup matches `_ga_ABC123XYZ` before `_ga` and corrupts the value; prefix matching is correct only for genuinely dynamic families (`_ga_<CONTAINER>`). The cookie value is everything AFTER the first `=` — GA cookie values legitimately contain `=`. The natural analog `useCookieValue` (`app/javascript/shared/hooks/useCookieValue.ts`) has exactly ONE defect not to inherit: `cookie.split("=")[1]` (line 10) truncates the value at the second `=`. Its name match `` cookie.startsWith(`${cookieKey}=`) `` (line 8) is NOT a shadowing defect — the appended `=` makes it exact; do not re-report it. A cookie present with an empty value (`_fbp=`) is treated as absent — never store `""` (rule 13).

*Motivated by: attribution spec-round-1 per-identifier-capture-contract F3 (MED) — the spec stated the first-`=` value rule but not exact-name matching, leaving the `_ga`/`_ga_*` shadowing open; nil-absence-semantics F2 (LOW) — empty-value cookies unstated, JSON path would store `""` while the SSO path dropped it; plan-review pass-1 per-identifier-capture-contract F1 (MED) — the plan misattributed a "shadowing defect" to `useCookieValue`'s startsWith that does not exist.*

### 34. query-string v6.1.0 presence semantics: `?x` → null, `?x=` → "", repeated → array — "present" guards must test non-empty string

Companion to rule 28 (same installed library). The installed `query-string` (v6.1.0) parses `?x` to `null`, `?x=` to `""`, and `?x=a&x=b` to `["a","b"]` (all verified against the installed package). The analog per-field guard in `sanitizeTrackingParams` (`parsedParams.<key> !== undefined`, `app/javascript/shared/lib/utils.js:59-70`) tests KEY presence only — `null` and `""` count as present under it. Any conditional logic keyed on a param being "present" (construct an identifier from it, suppress a cookie fallback because of it) must instead use the house non-empty-string guard `typeof x === "string" && x.length > 0` (`GoogleSSOButton.tsx:61-78`); otherwise a valueless `?fbclid` fabricates a real-looking identifier (`fb.1.<Date.now()>.null`) and a null/empty param suppresses a genuine cookie fallback. URL-sourced scalar fields must take the FIRST occurrence of a repeated param — an array passed through diverges by transport: the JSON path's Rails scalar permit silently drops it (nil column) while a form hidden input stringifies it (`"a,b"`).

*Motivated by: attribution spec-round-1 nil-absence-semantics F1 (MED) — the spec's conditional fbc-construction and cookie-fallback rules left "present" undefined, and the analog's own guard gives the wrong answer; per-identifier-capture-contract F1 (MED) — repeated-param handling unstated for the three URL-sourced fields, with the two transport paths diverging.*

### 35. Behavior removals/inversions: the spec must direct updating existing test examples and comments that pin the OLD behavior

When a spec removes or inverts existing behavior (permit removal, guard change, default change), sweep the existing spec files for examples asserting the old behavior and header comments documenting it, and direct their inversion/rewrite explicitly — directing only a NEW assertion is not enough. The stale example self-catches red at test time but then gets "fixed" unreviewed by whoever hits it; the stale comment never self-catches. This extends rule 6 (rename cascades) to behavior changes: spec files are the routinely-forgotten ripple site.

*Motivated by: attribution spec-round-1 collection-point-move F1 / always-on-checks F2 (MED) — SPEC §10.4 directed only a NEW assertion for the `organization_params` permit removal; the existing example `'stores adroll_first_party_cookie from the request body'` (organizations_controller_spec.rb:59-69) inverts and the header comment (lines 10-12, "adroll_first_party_cookie is the exception … it IS permitted through organization_params") becomes false.*

### 36. First-occurrence detection on a new ledger: the pre-existing cohort has no history rows — the spec must address it explicitly

When a feature detects "the first X" (first payment, first conversion, first login) by checking for the absence of a prior row in a NEW table, every entity that already passed X before the feature ships has no row — so its NEXT occurrence satisfies the predicate and records a false "first." The misclassification is silent, spreads over each entity's natural cycle (up to a full year for annual billing), and fans out to every downstream consumer of the row (analytics events, notifications). Any spec keying semantics on "no prior row in the new table" must explicitly address the pre-existing cohort — backfill rows before enabling writers, a created-timestamp cutoff in the predicate, or accept-and-disclose with the blast radius quantified — and the choice is the owner's, surfaced as an open question, never defaulted silently.

*Motivated by: subscription-events-ledger spec-round-1 conversion-predicate-correctness F1 (the run's only HIGH) — the `converted_to_paid`/`trial_converted_to_paid` first-cash semantics rode entirely on "no prior conversion-type row for this `stripe_subscription_id`"; with no backfill, every already-paying subscription's first post-deploy `invoice.paid` recorded a false conversion row + PostHog event, plus a false Discord "Trial Converted to Paid" ping for every trial-era customer (`trial_end` persists on a Stripe subscription for its lifetime). Disclosed as SPEC §11 Risk 6 with mitigation options for Jessica's ruling.*

### 37. "Must still pass" test claims require an executed baseline run — never assert or checkbox green without one

When a spec or plan names existing spec files that "must still pass," run those files at the branch base FIRST and record the exact example/failure counts. A file already red at base makes the requirement unmeetable, contaminates the impl-review signal (feature diff blamed for pre-existing drift), and turns any "all green" plan checkbox into a false verification claim. Never check a tests-green box without an actual executed run whose counts are recorded. If a named file fails at base, report the pre-existing failure as an escalation and scope the green requirement to the files the feature actually owns — fixing the stale shared spec is the owner's call (rules 10/23), not a feature fix agent's.

*Motivated by: subscription-events-ledger impl-round-1 E1/E2 — SPEC §9.5 required `stripe_webhook_handler_ai_credits_spec.rb` to "still pass," but it failed 17/17 at branch base `a0d59115d`: ancestor commit `c2f69130d` renamed `amount_cents_paid` → `stripe_amount` and never updated the spec (a rule 6 violation by that earlier work; the same stale name sits in `organization_ai_credit_purchase_spec.rb` and `cancel_ai_credit_subscription_spec.rb`). Plan Task 9.6's "all green" checkbox was checked despite the file being impossible to run green at that point.*


