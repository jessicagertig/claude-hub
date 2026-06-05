# Plan Review: Weekly Engagement Digest

**Date:** 2026-06-03
**Reviewer:** Plan Review Agent (2-pass)
**Plan file:** `plan.md`
**Source worktree:** `/Users/jessica/wrk/wrk-corp/inflow-ats.weekly-engagement-digest/`

---

## Pass 1: Fact Check + Completeness + Safety

### 1. File Path Verification

All file paths in the plan verified against the live source tree:

| Path | Exists | Correct |
|---|---|---|
| `app/models/organization_user.rb` | Yes | Yes |
| `app/services/engagement_report/organization_analyzer.rb` | Yes | Yes |
| `app/services/engagement_report/report_generator.rb` | Yes | Yes |
| `app/controllers/api/v1/me_controller.rb` | Yes | Yes |
| `app/javascript/shared/types/user.ts` | Yes | Yes |
| `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx` | Yes | Yes |
| `app/javascript/shared/queryHooks/useMe.ts` | Yes | Yes |
| `lib/tasks/recurring_tasks.rake` | Yes | Yes |
| `app/mailers/comment_mailer.rb` | Yes | Yes |
| `app/mailers/job_application_mailer.rb` | Yes | Yes |
| `app/models/channel_message.rb` | Yes | Yes |
| `app/models/channel.rb` | Yes | Yes |
| `app/models/concerns/settingsable.rb` | Yes | Yes |
| `app/services/emails/send_template_email.rb` | Yes | Yes |
| `app/jobs/engagement_report/generator_job.rb` | Yes | Yes |
| `app/jobs/export_job_candidates_to_csv_job.rb` | Yes | Yes |
| `app/services/spam_detector.rb` | Yes | Yes |
| `app/services/corporate_email_validator.rb` | Yes | Yes |
| `config/initializers/01_variables.rb` | Yes | Yes |
| `app/serializers/api/v1/session_serializer.rb` | Yes | Yes |
| `db/data/20240922221458_add_compensation_to_job_applications_settings.rb` | Yes | Yes |
| `db/data/20220302005956_set_email_preferences.rb` | Yes | Yes |
| `db/data/20251025011948_set_default_modal_display_settings.rb` | Yes | Yes |

All new file paths (to be created) follow codebase conventions.

### 2. Line Number Verification

| Claim | Actual | Verdict |
|---|---|---|
| `default_settings` at `organization_user.rb:83-89` | Lines 83-89 | CORRECT |
| `with_preference_for` at `organization_user.rb:165-169` | Lines 165-169 | CORRECT |
| `is_admin` at `organization_user.rb:54` | Line 54 | CORRECT |
| `Organization.claimed` scope at `organization.rb:130` | Line 130 | CORRECT |
| `Organization#active_paid_plan?` at `organization.rb:651` | Line 651 | CORRECT |
| `ChannelMessage sent_by` enum at `channel_message.rb:27-32` | Lines 27-32 | CORRECT |
| `Channel belongs_to :job_application` at `channel.rb:6` | Line 6 | CORRECT |
| `engagement_reports` task at `recurring_tasks.rake:134-159` | Lines 134-159 | CORRECT |
| `settings_params` at `me_controller.rb:128-129` | Lines 128-129 | CORRECT |
| `SessionSerializer#settings` at `session_serializer.rb:58-60` | Lines 58-60 | CORRECT |
| `CommentMailer#hiring_team_new_comment` at lines 10-75 | Lines 10-75 | CORRECT |
| `JobApplicationMailer#hiring_team_new_job_application` at lines 10-77 | Lines 10-77 | CORRECT |
| `load_base_ids` at `organization_analyzer.rb:47-51` | Lines 47-51 | CORRECT |
| `ReportGenerator` calls analyzer at line 17 | Line 17 | CORRECT |
| `build_payload` at `report_generator.rb:29-69` | Lines 29-69 | CORRECT |
| `AccountPreferences.tsx` destructuring at line 27 | Line 27 | CORRECT |
| `FormSection` closing `</FormSection>` at line 155 | Line 155 | CORRECT |
| `handleEmailPreferenceChange` at lines 82-88 | Lines 82-88 | CORRECT |
| `handleSubmitForm` at lines 65-80 | Lines 65-80 | CORRECT |
| `actives` scope at `organization_user.rb:48` | Line 48 | CORRECT |
| `has_many :jobs, through: :hiring_team_memberships` at line 15 | Line 15 | CORRECT |
| `receives_*` scopes at lines 35-37 | Lines 35-37 | CORRECT |
| `send_template_email.rb:90` auto-appends template tag | Line 90 | CORRECT |
| Max 2 tags at `send_template_email.rb:86` | Line 86 | CORRECT |
| `add_list_unsubscribe` at `send_template_email.rb:105-106` | Lines 105-106 | CORRECT |
| `Settingsable#add_default_settings` at `settingsable.rb:27-29` | Lines 27-29 | CORRECT |
| `Variables::EMAIL_HELLO_ADDRESS` at line 11 | Line 11 | CORRECT |
| `Variables::ATS_PREFERENCES_URL` at line 21 | Line 21 | CORRECT |
| `channel_message.rb:9` for `belongs_to :channel` | Line 9 | CORRECT |
| `stage_move_metrics` filters by `@job_application_ids` and `@cutoff` | Lines 154-166 (plan says 155-166) | MINOR: off-by-one, not actionable |
| `MeController#update_settings` "line 54 does update(settings: temp_params)" | Line 55 has the `update` call (line 54 is `ap temp_params`) | MINOR: off-by-one, not actionable |

### 3. Behavior Claim Verification

| Claim | Verified | Verdict |
|---|---|---|
| `is_admin` returns `org_admin? \|\| is_owner` | Line 54-56: `org_admin? \|\| is_owner` (where `is_owner` = `org_owner? \|\| god_admin?`) | CORRECT |
| `with_preference_for` uses `@>` JSON containment | Line 168: `where('settings @> ?', preferences.to_json)` | CORRECT |
| `Settingsable#add_default_settings` calls `update_settings(settingsable_settings) if settings.blank?` | Line 28: exactly that | CORRECT |
| `add_new_default_settings` uses `save` (triggers callbacks) | Line 23: `save` | CORRECT |
| `MeController#update_settings` does full JSONB replacement | Line 55: `current_organization_user.update(settings: temp_params)` -- Yes, replaces entire column with only permitted keys | CORRECT |
| `CommentMailer` selects template based on `@comment.review?` | Line 47: `@comment.review? ? "...review-v2" : "...comment-v2"` | CORRECT |
| `SendTemplateEmail` auto-appends template name as tag | Line 90: `message_builder.add_tag(template)` | CORRECT |
| `ReportGenerator` passes only `organization:` to analyzer | Line 17: `OrganizationAnalyzer.new(organization: @organization).analyze` | CORRECT |
| `build_payload` accesses `candidate_mgmt[:stage_moves]`, `[:comments]`, `[:reviews]`, `[:candidate_updates]`, `[:job_application_updates]` but NOT `[:channel_messages]` | Lines 52-56: confirmed -- no `channel_messages` access | CORRECT |
| `sent_by` enum values: system=0, user=1, candidate=2, organization=3 | Lines 27-32: confirmed | CORRECT |
| `Organization.claimed` -> `where(is_claimed: true)` | Line 130: confirmed | CORRECT |
| `Variables::EMAIL_HELLO_ADDRESS` -> `hello@mail.polymer.co` | Line 11: defaults to `'hello@mail.polymer.co'` | CORRECT |
| `Variables::ATS_PREFERENCES_URL` -> `"#{AtsRootUrl}/hire/settings/preferences"` | Line 21: confirmed | CORRECT |
| Existing mailers use `EMAIL_NOTIFICATIONS_ADDRESS`, NOT `EMAIL_HELLO_ADDRESS` | CommentMailer line 50: `Variables::EMAIL_NOTIFICATIONS_ADDRESS`; JobApplicationMailer line 35: same | CORRECT (the digest intentionally uses a different from address) |
| `ApplicationMailer` at `app/mailers/application_mailer.rb` | Line 3: `class ApplicationMailer < ActionMailer::Base` | CORRECT |
| `ApplicationJob` at `app/jobs/application_job.rb` | Line 3: `class ApplicationJob < ActiveJob::Base` | CORRECT |
| Spec directory has only `fixtures/`, `interactors/`, `requests/`, `support/` | Confirmed: no `spec/services/`, `spec/jobs/`, `spec/mailers/`, `spec/data_migrations/` | CORRECT |
| `spec/support/api_factories.rb` exists | Confirmed | CORRECT |
| `AddCompensationToJobApplicationsSettings` uses `update_columns` | Line 9: confirmed | CORRECT |
| `SetDefaultModalDisplaySettings` uses `save(validate: false)` | Line 12: confirmed | CORRECT |
| `SetEmailPreferences` class name at `db/data/20220302005956_set_email_preferences.rb` | Line 3: `SetEmailPreferences` | CORRECT |

### 4. Substantive Issues Found

#### Finding P1-1: INCOMPLETE SCOPING — `inbound_metrics` and `job_metrics` bypass `@job_ids` [HIGH]

The plan's Step 3b correctly modifies `load_base_ids` to scope `@job_ids`, `@job_application_ids`, and `@candidate_ids` based on org_user. However, several analyzer methods do NOT use these instance variables:

- `inbound_metrics` (line 62) uses `@organization.job_applications` directly
- `job_metrics` (line 91) uses `@organization.jobs` directly
- `candidate_update_metrics` (line 169) uses `@organization.candidates` directly
- `job_application_update_metrics` (line 180) uses `@organization.job_applications` directly

The digest job's `extract_metrics` pulls `applications_received` from `inbound[:total_applications]` and `jobs_published` from `setup[:jobs][:published]`. For non-admin org_users, these will be org-wide counts, NOT scoped to their hiring-team jobs.

The plan correctly notes the issue exists for `top_job_by_applications` (Step 6 note), but does NOT flag the same issue for `applications_received` and `jobs_published`.

**Impact:** Non-admin org_users will see org-wide counts for applications received and jobs published, but scoped counts for stage moves, comments, reviews, and messages. This is inconsistent with the spec's "Non-admin organization_users receive content scoped to their HiringTeamMembership assignments only."

**Resolution options (for implementation agent to address, not redesign here):**
1. Modify `inbound_metrics` and `job_metrics` to use `@job_ids`/`@job_application_ids` when `@organization_user_id` is present
2. Have the digest job bypass the unscoped analyzer methods and compute `applications_received` and `jobs_published` directly from the org_user's scoped associations
3. Accept the inconsistency as intentional (admins and non-admins both see org-wide inbound/published counts, but scoped management activity)

This is flagged for the implementation agent to resolve. The plan should note this explicitly.

#### Finding P1-2: Data migration inherits `ActiveRecord::Migration[6.0]` — correct but note precedent divergence [INFO]

The plan says to inherit `ActiveRecord::Migration[6.0]`, matching "all existing data migrations." However, `AddCompensationToJobApplicationsSettings` (2024) inherits `[6.1]`. Most others use `[6.0]`. The plan's choice of `[6.0]` is acceptable since the majority of data migrations use it, but the implementation agent should use whatever the `data_migrate` generator produces (likely `[6.0]` or `[6.1]` depending on config). Not actionable.

#### Finding P1-3: Plan Step 8 numbering jumps to Steps 13/14 [MINOR — corrected]

The plan labels backend steps 1-8, then jumps to "Step 13" and "Step 14" for frontend changes. This is confusing. The plan has 8 backend steps (1-8) and should logically continue with Steps 9-10 for frontend. The numbering appears to be a remnant of an earlier draft with more steps.

**Correction applied to plan:** No change applied — the numbering is unconventional but unambiguous because each step references its content clearly, and the plan's Files to Create or Modify table uses sequential 1-15 numbering. The implementation agent can follow the step titles regardless of numbers.

### 5. Completeness Check (Spec vs Plan)

| Spec Requirement | Plan Step | Covered |
|---|---|---|
| Seven metrics computed over 7-day window | Steps 3, 6 | Yes |
| Top job by application volume | Step 6 (`top_job_by_applications`) | Yes |
| Three bucket templates (all-counts-zero, passive-flow, active-team) | Step 4 (classifier), Step 5 (TEMPLATE_MAP) | Yes |
| Bucket classifier logic (active_team > passive_flow > all_counts_zero) | Step 4 | Yes |
| Admin org_users see org-wide content | Step 3b (scoped_job_ids) | Partial (see P1-1) |
| Non-admin org_users see hiring-team-scoped content | Step 3b | Partial (see P1-1) |
| `email_weekly_digest` preference in settings JSONB | Steps 1, 2 | Yes |
| Data migration backfills existing org_users | Step 1 | Yes |
| `default_settings` updated for new org_users | Step 2a | Yes |
| `settings_params` adds `:email_weekly_digest` | Step 8 | Yes |
| `UserSettings` TypeScript interface updated | Step 13 | Yes |
| `AccountPreferences.tsx` new section | Step 14 | Yes |
| Separate FormSection (not within existing Notifications section) | Step 14b | Yes |
| Rake task in `recurring_tasks.rake` | Step 7 | Yes |
| Sidekiq job per org_user | Step 6 | Yes |
| Mailer sends via `Emails::SendTemplateEmail` | Step 5 | Yes |
| From address: `Jessica from Polymer` / `EMAIL_HELLO_ADDRESS` | Step 5 | Yes |
| Subject: `Your week at [Organization Name]` | Step 5 | Yes |
| `template_version: 'initial'` | Step 5 | Yes |
| Tags: `['hire', 'user-facing']` | Step 5 | Yes |
| Placeholder unsubscribe URL | Step 5 | Yes |
| `List-Unsubscribe` header | Step 5 | Yes |
| Stagger delay for job enqueue | Step 7 | Yes |
| `find_by` + guard clause pattern | Steps 5, 6 | Yes |
| `rescue StandardError` with `ap` + `Rails.logger.error` | Step 6 | Yes |
| No re-raise | Step 6 | Yes |
| Eligibility: `Organization.claimed` + `active_paid_plan?` | Step 7 | Yes |
| Preference filter: `with_preference_for(:email_weekly_digest)` | Step 7 | Yes |
| Deploy-order: settings_params + UserSettings + AccountPreferences atomic | Deploy Order Phase C | Yes |
| Data migration safe to deploy early | Deploy Order Phase A | Yes |
| Backward compatibility for existing `ReportGenerator` caller | Step 3 backward compat section | Yes |
| Test: WeeklyDigestClassifier spec | Test Plan #1 | Yes |
| Test: OrganizationAnalyzer extensions spec | Test Plan #2 | Yes |
| Test: WeeklyDigestJob spec | Test Plan #3 | Yes |
| Test: WeeklyDigestMailer spec | Test Plan #4 | Yes |
| Test: Data migration spec | Test Plan #5 | Yes |
| No frontend tests required (matches existing pattern) | Test Plan "Frontend Tests" | Yes |

**All spec requirements are covered.** The scoping issue (P1-1) is a gap in the implementation approach rather than a missing requirement.

### 6. Safety Compliance

| Check | Result |
|---|---|
| Database safety rules (no DROP, no db:reset, no direct psql) | PASS — data migration uses `update_columns`, which is the approved pattern |
| Migration risk of data loss | PASS — `update_columns` with skip-if-present is safe; `down` raises IrreversibleMigration |
| Authorization/policy changes | PASS — no Pundit policy changes; scoping is done in the analyzer, not at the authorization layer |
| Existing functionality breakage risk | PASS — analyzer changes are backward-compatible (new params default to nil); settings_params addition is deployed atomically with frontend |
| cursor_rules compliance | PASS — no "Service" in class name, keyword arguments, `find_by` not `find`, method-level rescue, `ap` + `Rails.logger.error`, snake_case backend / camelCase frontend, no bang methods outside specs |
| No direct work on master/main | PASS — feature branch `weekly-engagement-digest` |

### 7. Scope and Ordering

| Check | Result |
|---|---|
| Each step traces to a spec requirement | Yes |
| Dependencies sequenced correctly | Yes — data migration before model update, analyzer before classifier, classifier before job, job before rake task |
| Independent steps marked | Yes — Deploy Order phases A/B/C identify independent groups |
| Deploy-order constraint respected | Yes — Phase C identifies the atomic deploy requirement |

---

## Pass 2: Verify Corrections + Fresh Scrutiny

### Re-read of the plan after Pass 1

1. **P1-1 (scoping gap) remains the only substantive issue.** This is not a plan error per se — the analyzer's existing methods (`inbound_metrics`, `job_metrics`) bypass `@job_ids`, and the plan's `load_base_ids` fix does not reach those methods. The plan needs a note acknowledging this gap and directing the implementation agent to address it.

2. **No new inconsistencies introduced by Pass 1.** All line numbers, file paths, and behavior claims remain correct.

3. **Fresh scrutiny items:**

   - **`messages_sent_total` definition:** The spec says it is "the sum of `messages_sent_by_user` + `messages_sent_by_organization` (everything in `ChannelMessage.sent_by` that is not `sent_by_candidate`)." The parenthetical would include `sent_by_system`, but the primary definition (sum of user + org) excludes it. The plan's implementation at Step 3c correctly follows the primary definition (sums user + org only, excludes system). CORRECT.

   - **`build_result` in the analyzer:** The analyzer's `build_result` method (lines 344-428) builds a nested hash. The new `channel_messages` key would be added to `candidate_management_metrics` (line 144-152), and `build_result` accesses `candidate_mgmt[:channel_messages]` — but wait, `build_result` at line 385-407 DOES NOT include a `channel_messages` key in its output. The plan says the new key is "additive and does not break the existing consumer" but the plan's `extract_metrics` in Step 6 accesses `result[:candidate_management][:channel_messages]`. This path does not exist unless `build_result` is updated to include it. HOWEVER: looking again at the analyzer, the `analyze` method at line 19 calls `candidate_mgmt = candidate_management_metrics` and then passes `candidate_mgmt` to `build_result`. The `build_result` method cherry-picks keys from `candidate_mgmt`. For the digest job, it calls `analyzer.analyze` which returns the `build_result` output. The `channel_messages` data is in the raw `candidate_management_metrics` return but is NOT in the `build_result` output.

   **Finding P2-1: `channel_messages` not in `build_result` output [HIGH]**

   The plan's Step 6 `extract_metrics` accesses `result[:candidate_management][:channel_messages]`. But `build_result` (lines 344-428) does NOT pass `channel_messages` through to the final result hash. The existing `build_result` at lines 385-407 explicitly cherry-picks keys from `candidate_mgmt` and does NOT include the new `channel_messages` key.

   The plan's Step 3c says to add `channel_messages: channel_message_metrics` to the `candidate_management_metrics` return hash. This is correct. But `build_result` at line 385-407 would need to ALSO be updated to include `channel_messages` in its output, or the digest job would need to call the analyzer differently (e.g., call `candidate_management_metrics` directly rather than going through `analyze` -> `build_result`).

   **Resolution:** The plan should add an explicit note that `build_result` must be updated to pass through the `channel_messages` key. Specifically, add to the `candidate_management` section of `build_result` (after line 407):
   ```ruby
   channel_messages: candidate_mgmt[:channel_messages]
   ```
   This is a straightforward addition that does not break existing consumers (they do not access `channel_messages`).

   - **`useMe.ts` line 32-35 for `updateSettings`:** Verified at lines 32-35. The function sends `UserSettings` to `PUT /me/update_settings`. CORRECT.

   - **`Variables::AtsRootUrl` is a constant, not `Variables::ATS_ROOT_URL`:** The plan's Step 5 uses `Variables::AtsRootUrl` (PascalCase) for the jobs URL. The actual constant at line 19 is `AtsRootUrl` (PascalCase). CORRECT.

   - **Plan Step 14b says "before `</FormContainer>`":** The actual closing tag at line 156 is `</FormContainer>`. New section would go after line 155 (`</FormSection>`) and before line 156 (`</FormContainer>`). CORRECT.

   - **`AccountPreferences.tsx` `FormContainer` at line 114-156:** The form uses `id="preferences-form"`. The new section inside this container would be submitted along with the rest. Since `handleSubmitForm` spreads `{ ...settings }`, the new key is included automatically. CORRECT.

### Pass 2 Final Completeness Sweep

All spec requirements remain covered. The two substantive findings (P1-1 scoping gap, P2-1 `build_result` gap) are implementation details that the plan should acknowledge but that do not change the plan's overall approach or structure.

---

## Verdict: APPROVED (with two implementation notes)

Both passes produced clean results on file paths, line numbers, behavior claims, safety compliance, completeness, and ordering. Two substantive findings require notes in the plan but do not constitute fundamental issues:

1. **P1-1 (Analyzer scoping gap):** `inbound_metrics` and `job_metrics` bypass `@job_ids`/`@job_application_ids`, so `applications_received` and `jobs_published` will be org-wide for non-admin org_users. The implementation agent must address this.

2. **P2-1 (`build_result` gap):** The `channel_messages` key added to `candidate_management_metrics` will not appear in the `analyze` output unless `build_result` is also updated. The implementation agent must add the key to `build_result`.

Neither finding changes the plan's structure, approach, or deploy order. Both are straightforward to resolve during implementation.

---

## Reviewed Plan

The plan as written in `plan.md` is approved for implementation with the following notes appended:

### Implementation Notes (from plan review)

**Note 1 — Analyzer scoping gap for `inbound_metrics` and `job_metrics`:**
The plan's Step 3b modifies `load_base_ids` to scope `@job_ids`, `@job_application_ids`, and `@candidate_ids` for org_user-scoped calls. However, `inbound_metrics` (line 62) uses `@organization.job_applications` directly and `job_metrics` (line 91) uses `@organization.jobs` directly — neither uses the scoped instance variables. For non-admin org_users, `applications_received` (from `inbound[:total_applications]`) and `jobs_published` (from `setup[:jobs][:published]`) will be org-wide, not scoped. The implementation agent should either: (a) modify these methods to use `@job_ids`/`@job_application_ids` when `@organization_user_id` is present, (b) have the digest job compute these metrics directly from the org_user's associations instead of using the analyzer's unscoped output, or (c) confirm with Jessica that org-wide counts are acceptable for these two metrics.

**Note 2 — `build_result` must pass through `channel_messages`:**
The plan's Step 3c adds `channel_messages: channel_message_metrics` to the `candidate_management_metrics` return hash. However, `build_result` (lines 344-428) cherry-picks keys from `candidate_mgmt` and does NOT include `channel_messages` in its output. The implementation agent must add `channel_messages: candidate_mgmt[:channel_messages]` to the `candidate_management` section of `build_result` (after line 407) so the digest job's `extract_metrics` can access `result[:candidate_management][:channel_messages]`.
