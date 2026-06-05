# Weekly Engagement Digest — Design

Date: 2026-05-14
Branch: `weekly-engagement-digest`
Related notes: `docs/superpowers/notes/2026-05-14-weekly-engagement-digest-brainstorm.md`

---

## Overview

A weekly per-organization digest email that surfaces the previous 7 days of hiring activity to organization_users. Primary goal is **retention** — keeping orgs engaged with Polymer, with particular value for orgs that are receiving applications but not engaging with them. Automated, data-driven, no editorial content.

There are three bucket templates based on what the data shows (all-counts-zero, passive-flow-only, active-team), so weeks where all activity counts are zero still send a useful email rather than being skipped.

---

## Scope

### In MVP

The digest body surfaces these seven counts and one highlight, computed over the previous 7-day window, scoped per organization_user:

1. Job applications received
2. Stage moves
3. Jobs published
4. Comments and reviews (rendered as one combined sentence: "X comments and Y reviews")
5. Messages sent to candidates — `messages_sent_total`, the sum of `messages_sent_by_user` + `messages_sent_by_organization` (everything in `ChannelMessage.sent_by` that is *not* `sent_by_candidate`). The user/organization split is computed for the bucket classifier (see below) but the digest body displays only the total.
6. Messages received from candidates (`sent_by: :sent_by_candidate`)
7. Top job by application volume (single per-job highlight). On a tie, picks one arbitrarily (e.g., by lowest `job.id`).

---

## User-Facing Behavior

### Sender

- **From display name:** `Jessica from Polymer`
- **From address:** `hello@mail.polymer.co` (`Variables::EMAIL_HELLO_ADDRESS`)

### Subject

`Your week at [Organization Name]` — single pattern. No numeric variants in the subject because counts may be zero.

### Send schedule

**00:00 UTC every Monday.** Jessica configures this in Heroku Scheduler at go-live; nothing scheduling-related is implemented in the app (see Rake task section).

### Recipients

Every active organization_user in an eligible organization. Default subscribed. An organization_user who belongs to multiple eligible orgs receives one digest per org (each with its own content scoping and its own preference checkbox).

Per-organization_user content scoping:
- **Admin organization_users** receive org-wide content (all jobs, all candidates, all applications)
- **Non-admin organization_users** receive content scoped to their `HiringTeamMembership` assignments only

### Body content modes (buckets)

There are **three Mailgun stored templates, one per bucket**. The app classifies the recipient into a bucket and sends the matching template, passing the same data values as variables. Buckets:

1. **All counts zero** — every one of the 7 metrics is zero for the week. Minimal recap with gentle "we're here" framing.
2. **Passive flow only** — applications received and/or `messages_sent_by_organization` are non-zero, but the human-activity signal (stage moves + comments + reviews + `messages_sent_by_user`) is zero. Surfaces a "you have applications waiting" prompt; this is the retention-critical mode.
3. **Active team** — at least one of {stage moves, comments, reviews, `messages_sent_by_user`} is non-zero. Recap-style summary.

**The template copy and layout are authored by Jessica directly in Mailgun.** The app's only responsibility is to (a) pick the right bucket, and (b) provide the data values the templates need as variables. The spec does not describe what the templates render — only what the app provides (see Mailer / Job).

### Unsubscribe

The email carries a `List-Unsubscribe` header and a visible unsubscribe link in the body. **The unsubscribe destination is not built in this pass.** The mailer uses a placeholder for the unsubscribe URL; the correct unsubscribe link and its endpoint will be added later. Nothing else in this spec depends on that destination existing.

---

## Architecture

All work is in the **Hire** app (the main app: `app/controllers/...`, `app/jobs/...`, `app/services/...`, `app/javascript/ats/...`). Plus three Mailgun stored templates authored in the Mailgun control panel (outside the codebase).

### Components added

| Component | Path | Purpose |
|---|---|---|
| Rake task | `lib/tasks/recurring_tasks.rake` (new task added to existing file) | Top-level task that enumerates eligible recipients and enqueues per-org_user `WeeklyDigestJob` |
| Sidekiq job | `app/jobs/weekly_digest_job.rb` | Per-org_user: runs analyzer, classifies bucket, triggers mailer |
| Mailer | `app/mailers/weekly_digest_mailer.rb` | One method that receives the bucket, maps it to the matching template, builds `message_params`, sends via `Emails::SendTemplateEmail` |
| Bucket classifier | `app/services/weekly_digest_classifier.rb` | Returns the bucket symbol (1/2/3) from analyzer output |
| Analyzer extension | `app/services/engagement_report/organization_analyzer.rb` | Existing analyzer gets optional `organization_user_id:` parameter, generalized cutoff, and new `ChannelMessage` query |
| Data migration | `db/data/YYYYMMDDHHMMSS_<name>.rb` | Adds `email_weekly_digest: true` to existing org_user `settings` (naming convention discussion below) |
| `default_settings` update | `app/models/organization_user.rb` | Adds `email_weekly_digest` to the default-settings hash so new org_users get the key on create |
| `settings_params` update | `app/controllers/api/v1/me_controller.rb` | Adds `:email_weekly_digest` to the `settings_params` permit list so the preference can be saved from the frontend |
| `UserSettings` type update | `app/javascript/shared/types/user.ts` | Adds `emailWeeklyDigest: boolean` to the `UserSettings` interface |
| In-app preference checkbox section | `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx` | New section for the digest preference checkbox, alongside the existing email-notification checkboxes |
| Mailgun stored templates | (Mailgun control panel) | **Three** new stored templates, one per bucket; authored by Jessica |

### Send pipeline

Heroku Scheduler invokes the rake task. The task enumerates eligible recipients — claimed organizations with an active paid plan, and within each, active organization_users who have the weekly-digest preference enabled — and enqueues one `WeeklyDigestJob` per organization_user, staggered the way `engagement_reports` staggers its jobs.

Each `WeeklyDigestJob` runs the analyzer scoped to its organization_user over the 7-day window, asks the classifier for the bucket, and triggers the mailer with the organization_user, the bucket, and the computed counts.

The mailer maps the bucket to its template name, assembles the message parameters (sender, recipient, subject, template name, template version, tags, the data-value variables, and the placeholder unsubscribe header), and sends through `Emails::SendTemplateEmail`. Specifics of each piece are in the Mailer / Job section below.

---

## Data Model

### Preference storage

`organization_user.settings['email_weekly_digest']` (boolean, default `true`). No new table.

Convention matches existing keys (`email_job_applications_new`, `email_comments_new`, `email_messages_new`) — boolean, default true, naming pattern `email_<thing>_<event_or_descriptor>`.

Add to `OrganizationUser#default_settings` (currently `app/models/organization_user.rb:83-89`) so new org_users get the key on creation.

### Eligibility query

Reuses existing helpers — no hand-rolled subscription-status logic:

- **Organizations:** `Organization.claimed` scope (`organization.rb:130`), then `organization.active_paid_plan?` (`organization.rb:651`) per org. This is the same eligibility gate `recurring_tasks.rake`'s `engagement_reports` task uses. `active_paid_plan?` encapsulates plan-list membership plus subscription good-standing (grace period, status whitelist) via `Stripe::SubscriptionStatusChecker` — it is reused, not reproduced.
- **Organization_users:** the existing `actives` scope plus `with_preference_for(:email_weekly_digest)` (`organization_user.rb:165-169`).

The rake task composes these to enumerate recipients (org loop + org_user loop, matching `engagement_reports`).

### Data migration

Lives in `db/data/`. Inherits `ActiveRecord::Migration[6.0]`. `down` raises `ActiveRecord::IrreversibleMigration`.

**Behavior:** iterates all existing organization_users in batches. For each, if the `settings` JSONB does not already contain the `email_weekly_digest` key, writes the merged settings hash with `email_weekly_digest: true` directly to the column (bypassing model validations and callbacks). Records where the key is already present are skipped — this allows the migration to be re-run safely if it fails partway.

This is required because `with_preference_for` uses Postgres `@>` containment, which matches only when the key is present and true — an org_user missing the key entirely would never be enumerated.

**Class name:** `AddWeeklyDigestEmailPreference` (semantic-content convention, matching `set_email_preferences` precedent).

---

## Computation Service (Analyzer Extensions)

`EngagementReport::OrganizationAnalyzer` gets the changes below. The existing churn-monitoring caller passes nothing new and behaves identically.

### Constructor signature changes

Adds an optional `organization_user_id:` parameter (defaults to `nil`). Adds an optional `since:` parameter (defaults to `nil`) to allow callers to pass an absolute cutoff. The existing `months:` parameter (default 6) is kept; the cutoff is computed as `since` if provided, otherwise `months.ago`.

The digest use case passes `since: 1.week.ago`. The existing churn caller continues to rely on `months: 6` and does not pass `since:`.

### `load_base_ids` branching

The existing method that computes `@job_ids`, `@job_application_ids`, and `@candidate_ids` is updated so that `@job_ids` branches on whether `organization_user_id` was provided:

- If `organization_user_id` is nil → all of the organization's jobs (current behavior).
- If `organization_user_id` is provided → load the organization_user. If `org_user.is_admin` (`organization_user.rb:54`) → all of the organization's jobs. Otherwise → `org_user.jobs`, which is already the hiring-team-scoped set via the existing `has_many :jobs, through: :hiring_team_memberships` (`organization_user.rb:15`).

`@job_application_ids` and `@candidate_ids` are derived from `@job_ids` as today. Note `OrganizationUser` also already exposes `job_applications`, `channel_messages`, and `candidates` through that same chain (`organization_user.rb:16-19`) if the implementer prefers to source the scoped sets directly from the org_user rather than re-derive from `@job_ids`.

### New `ChannelMessage` query

Added to the `candidate_management_metrics` group. Joins `ChannelMessage` through `Channel` to filter by `@job_application_ids`, plus the cutoff timestamp. Produces four counts:

- `messages_sent_by_user` — `sent_by: :sent_by_user`
- `messages_sent_by_organization` — `sent_by: :sent_by_organization`
- `messages_sent_total` — sum of the two above (equivalently: not `sent_by_candidate`)
- `messages_received` — `sent_by: :sent_by_candidate`

`messages_sent_total` and `messages_received` are displayed in the digest body. `messages_sent_by_user` and `messages_sent_by_organization` are consumed only by the bucket classifier.

### Bucket classifier

A separate small service consumes analyzer output and returns one of three bucket symbols. Decision logic:

- **`:active_team`** if any of `stage_moves`, `comments`, `reviews`, `messages_sent_by_user` is > 0
- **`:passive_flow`** else if `applications_received > 0` or `messages_sent_by_organization > 0`
- **`:all_counts_zero`** otherwise

---

## Mailer / Job

### `WeeklyDigestMailer`

Follows the established mailer pattern: an `ApplicationMailer` subclass with a single method that builds a `message_params` hash and calls `Emails::SendTemplateEmail.new(message_params).send` (same shape as `CommentMailer#hiring_team_new_comment` and `JobApplicationMailer#hiring_team_new_job_application`).

**One method, not three.** The method receives the bucket and maps it to the matching template name internally — mirroring `CommentMailer`, which selects its template inside one method (`@comment.review? ? "...review-v2" : "...comment-v2"`). Three separate mailer methods are the pattern only when the emails differ in audience/purpose; here it is the same email to the same recipient, differing only by template.

`message_params` keys (only what the app provides to Mailgun — the template owns everything else):

- `from`: `{ name:` (display name), `email: Variables::EMAIL_HELLO_ADDRESS }` (`hello@mail.polymer.co`)
- `to`: `[{ name:, email: }]` for the recipient org_user's user
- `subject`
- `template`: the bucket's template name (one of three)
- `template_version`: `'initial'` (as every existing mailer uses)
- `tags`: 1–2 tags, e.g. `['hire', 'user-facing']` (`SendTemplateEmail` auto-appends the template name as a third)
- `variables`: the data values the templates need — recipient first name, organization name, the seven metrics, top-job title + count, jobs URL, in-app preferences URL, unsubscribe URL, etc. **Plain data values, not rendered HTML.**
- `list_unsubscribe`: a placeholder URL plus a `mailto:` fallback. The real unsubscribe URL is added later (see Unsubscribe under User-Facing Behavior).

`List-Unsubscribe-Post: List-Unsubscribe=One-Click` is the additional header that makes a compliant email client's native unsubscribe button POST immediately to the unsubscribe URL. `Emails::SendTemplateEmail#add_list_unsubscribe` currently sets only `List-Unsubscribe`; whether to add the one-click POST header now or alongside the real unsubscribe endpoint later is in Open Items.

Invocation follows the codebase norm `WeeklyDigestMailer.<method>(...).deliver_later` — except it is triggered from inside `WeeklyDigestJob`, which is already a background job, so `deliver_now` from there is also acceptable (implementation detail).

### `WeeklyDigestJob`

Sidekiq job, modeled on `EngagementReport::GeneratorJob`. Receives `organization_user_id`. Loads the org_user with `find_by` + guard clause, runs `EngagementReport::OrganizationAnalyzer` scoped to the org_user, runs the bucket classifier, and triggers `WeeklyDigestMailer`. Errors handled with method-level `rescue StandardError` (both `ap` and `Rails.logger.error`), no re-raise — matching `background_jobs.md`.

The job exists to move the **analyzer work** (DB-heavy) off the rake process — not the email send, which `deliver_later` already backgrounds. This mirrors why `EngagementReport::GeneratorJob` exists.

### Rake task

A new **top-level** task added to the existing `lib/tasks/recurring_tasks.rake` (codebase norm — all recurring tasks live there; there is no `polymer:` namespace and no per-feature rake file). Named in the descriptive style of its neighbors (`daily_summary`, `engagement_reports`) — e.g. `weekly_engagement_digest`.

Behavior (mirrors `engagement_reports`): iterate `Organization.claimed`, skip unless `organization.active_paid_plan?`, then iterate that org's `organization_users.actives.with_preference_for(:email_weekly_digest)` and enqueue one `WeeklyDigestJob` per org_user, staggered with a delay to avoid thundering-herd (as `engagement_reports` staggers its jobs).

**Scheduling is handled in production via Heroku Scheduler.** Jessica configures the scheduled entry (`rake <task name>` at **00:00 UTC Monday**) in the Heroku dashboard at go-live. The implementer does **not** add any cron-style gem (`whenever`, `sidekiq-cron`), `clockwork` process, or other in-app scheduler. The rake task is the only piece shipped; Heroku Scheduler invokes it externally.

---

## In-App Preference UI

A new section in `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx`, separate from the existing job-notification preferences section. Section heading along the lines of "Weekly digest" (exact copy is the visual design pass).

The checkbox reads/writes `organization_user.settings['email_weekly_digest']` via the existing endpoint that backs the AccountPreferences page (located at code time). Match the existing email-preference checkboxes in this view exactly — same styled-checkbox component, same row layout, same label-and-description structure as the existing `email_job_applications_new` / `email_comments_new` / `email_messages_new` rows. The implementer must read the current `AccountPreferences.tsx` and replicate the pattern, not invent a new toggle/switch component.

---

## Mailgun Stored Templates

Three stored templates (one per bucket) authored by Jessica in the Mailgun control panel — outside the codebase, but required for sending. Each renders the digest layout from the variables the app passes (counts, names, URLs); the app does **not** send rendered HTML, only data values. The template names are settled at creation time and feed the bucket → template-name mapping in `WeeklyDigestMailer`. App code references each via the `template:` parameter to `Mailgun::MessageBuilder#template`.

---

## Implementation Order

(Suggested order; final ordering settled in the writing-plans phase.)

1. **Data migration** — adds `email_weekly_digest: true` to all existing org_user settings; skips records where the key is already present, so safe to re-run. Safe to deploy ahead of other changes.
2. **`default_settings` update** in `OrganizationUser` — new org_users get the key on create.
3. **Analyzer extensions** — `organization_user_id:` parameter, generalized cutoff, `ChannelMessage` query.
4. **Bucket classifier service** — returns the bucket symbol from analyzer output.
5. **`WeeklyDigestMailer`** — one method; bucket → template name; builds `message_params`; sends via `Emails::SendTemplateEmail`. Placeholder unsubscribe URL.
6. **`WeeklyDigestJob`** — per-org_user orchestrator (analyzer → classifier → mailer).
7. **Rake task** in `recurring_tasks.rake` — enumerates eligible recipients and enqueues jobs. Heroku Scheduler configuration is Jessica's production work, done at go-live.
8. **In-app `AccountPreferences.tsx`** — new section.
9. **Three Mailgun stored templates** — created in Mailgun control panel by Jessica (parallel work).

### Deploy-order constraint

**The `settings_params` permit-list change (adding `:email_weekly_digest` to `MeController`), the `UserSettings` TypeScript interface update, and the `AccountPreferences.tsx` UI change MUST deploy together.** `MeController#update_settings` does a full replacement of the `settings` JSONB column with only the keys the frontend sends. If the backend permits the new key before the frontend sends it, any user who saves their existing preferences will silently overwrite the column with only the old keys — deleting the `email_weekly_digest` value the data migration set. The data migration (step 1) and `default_settings` update (step 2) are safe to deploy early because they write directly to the column without going through the permit list. Steps 3-7 (analyzer, classifier, mailer, job, rake task) do not interact with the settings save flow and can deploy independently. Step 8 (frontend) must deploy atomically with the `settings_params` addition.

---

## Test Requirements

The existing analog code (`EngagementReport::OrganizationAnalyzer`, `EngagementReport::GeneratorJob`, `CommentMailer`, `JobApplicationMailer`) has no RSpec specs or Cypress tests. This feature adds tests for the new and modified components:

### New RSpec specs required

1. **`WeeklyDigestClassifier`** — unit spec. Test all three bucket paths: `:all_counts_zero`, `:passive_flow`, `:active_team`. Verify boundary conditions (e.g., only `messages_sent_by_organization` > 0 yields `:passive_flow`; only `messages_sent_by_user` > 0 yields `:active_team`).
2. **`EngagementReport::OrganizationAnalyzer` extensions** — unit spec for the new constructor params and `ChannelMessage` query. Test: (a) existing caller behavior unchanged when no new params passed, (b) `organization_user_id:` scoping for admin vs non-admin org_user, (c) `since:` parameter overrides `months:`, (d) message count correctness by `sent_by` type.
3. **`WeeklyDigestJob`** — unit spec. Test: (a) runs analyzer with correct org_user scoping, (b) passes analyzer output to classifier, (c) triggers mailer with correct bucket and data, (d) handles missing org_user gracefully (guard clause), (e) handles analyzer errors (rescue StandardError).
4. **`WeeklyDigestMailer`** — unit spec. Test: (a) `message_params` shape matches `Emails::SendTemplateEmail` requirements, (b) bucket-to-template-name mapping for all three buckets, (c) correct `from` address (`EMAIL_HELLO_ADDRESS`), (d) correct `to` recipient construction.
5. **Data migration** — unit spec. Test: (a) adds key to org_users missing it, (b) skips org_users that already have the key, (c) `down` raises `IrreversibleMigration`.

### Existing tests to update

None identified — the existing analog code has no tests, and the modified `OrganizationUser#default_settings` is not directly tested. The new key addition is covered by the data migration spec above.

### Frontend tests

No frontend unit tests required for the `AccountPreferences.tsx` change — the existing preference checkboxes have no component tests. The new checkbox follows the identical pattern. Manual QA should verify the checkbox appears, saves, and round-trips correctly.

---

## Open Items (to be settled at implementation time, not blocking design)

- **Template copy and layout** for the three buckets — authored by Jessica directly in Mailgun
- **`Settingsable` concern** — referenced in `organization_user.rb:82` but not yet read. Inspect at code-writing time to see if there are existing accessors to use
- **Three Mailgun template names** — created in Mailgun control panel, names decided at template creation time; the bucket → template-name mapping in the mailer uses them
- **Data migration class name** — resolved: `AddWeeklyDigestEmailPreference`
- **Placeholder unsubscribe URL** — how the mailer represents the unsubscribe URL until the real endpoint is built (constant, app config, or stub URL)
- **`List-Unsubscribe-Post` header** — `Emails::SendTemplateEmail#add_list_unsubscribe` currently sets only `List-Unsubscribe`. Decide whether to add the one-click POST header now or with the real unsubscribe endpoint later
- **Job stagger delay** — `engagement_reports` staggers with `count * delay` (30s prod / 5s dev). The digest enqueues per org_user (more jobs than per-org); pick an appropriate stagger
