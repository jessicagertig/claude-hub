# Weekly Engagement Digest — Brainstorm Notes

Date: 2026-05-14
Status: brainstorm complete, ready to draft spec
Output: `docs/superpowers/specs/2026-05-14-weekly-engagement-digest-design.md` (to be written next)

This document is the session-context record of decisions reached during brainstorming. Earlier drafts of this file contained framing errors (false dichotomies, incorrect agent findings) which have been removed; this is the clean current-state record.

---

## Goal

A weekly, automated, per-organization digest email surfacing the previous week's hiring activity inside that org's Polymer/Inflow ATS workspace. Primary purpose: **retention** — catch orgs before they abandon Polymer, including orgs receiving inbound applications but not engaging with them. Counts and data, not editorial content.

Product updates ("what's new") are deliberately separate and not part of this spec — they require manual editorial copy and run on a different cadence.

---

## Codebase facts established during brainstorm

### Engagement analyzer (already exists)

- `app/services/engagement_report/organization_analyzer.rb` — per-org analyzer with a configurable time window (currently a `months:` integer parameter, defaults to 6). Computes nearly every metric the digest needs:
  - Inbound: total / passive / user-added applications, monthly buckets, most recent timestamp (`inbound_metrics`, lines 61-80)
  - Setup: jobs created / published / currently-published / updated; templates; automations (lines 82-142)
  - Candidate management: stage moves via `HiringStageVisit` filtered to user-initiated only, candidate updates, job-application updates, comments and reviews via the `Comment` model with its `kind` enum (lines 144-220)
  - Engagement scoring (lines 222-267) and engagement-level bands — **not relevant to the digest, will be ignored**
- `app/services/engagement_report/hiring_cycle_analyzer.rb` — hiring pipeline status. Not used by digest.
- `app/services/engagement_report/report_generator.rb` — wraps the analyzer for the Google Sheets / churn-monitoring caller. Not changed by the digest.
- `app/jobs/engagement_report/generator_job.rb` — Sidekiq wrapper for the analyzer call.
- The analyzer loads three base ID relations once (`load_base_ids`, lines 47-51): `@job_ids`, `@candidate_ids`, `@job_application_ids`. All are org-wide today; the digest extends this to optionally scope by organization_user.

### Email infrastructure

- **Every email send goes through Mailgun.** Two send paths in code, both terminating at Mailgun:
  - `app/services/emails/send_template_email.rb` → `Mailgun::MessageBuilder` with `template` + `template_version` → `Mailgun::Client#send_message`. Templates are **Mailgun Stored Templates** defined in the Mailgun control panel. Used by `MagicLinkMailer`, `InviteMailer`, `CommentMailer`, `JobApplicationMailer`, `StripeSubscriptionMailer`, `ChannelMessageMailer`, etc.
  - `app/mailers/job_mailer.rb` lines 97-116 (`job_change_email`) — `Mailgun::MessageBuilder` with locally-rendered ERB. Used only by `JobMailer#job_in_review`, which Jessica confirmed is not in active production use.
- SMTP via `smtp.mailgun.org:587` is configured (`config/application.rb:109-127`) but mailers call the Mailgun API directly via `Mailgun::Client`, not SMTP.
- **SendGrid is contact-sync only.** `app/services/send_grid_client.rb` wraps `sg.client.marketing.contacts` for list syncing. **It never sends email from this app.** Any SendGrid Marketing broadcasts are operated manually outside the app.
- **Mailgun open/click tracking is disabled by policy.** Open-tracking pixel = marginal deliverability impact and copy-paste-safe; click-tracking = URL rewriting that breaks copy-paste and routing. The digest will not use either. Per-message header overrides are technically possible but not used.
- **No engagement-data tracking exists.** Only the failure-event handling in `app/interactors/mailgun/webhook_handler.rb` (marks `Candidate#has_valid_email = false` on permanent failure).
- **Mailgun Stored Templates accept arbitrary HTML body content as a template variable.** This is the existing pattern (e.g., `ChannelMessageMailer` passes the entire candidate-message body in as a variable). The digest follows the same pattern: Mailgun template provides shell/branding/header/footer/unsubscribe link; the app renders the dynamic body content on the Ruby side and passes it in.

### Models and schema

- `organization_users.settings` is `jsonb default {} null: false`. Existing default keys (`organization_user.rb` lines 83-89):
  ```ruby
  { email_job_applications_new: true, email_comments_new: true, email_messages_new: true }
  ```
  Naming convention: `email_<thing>_<event_or_descriptor>`, all booleans, all default `true`.
- `organization_user.rb` has an existing scope `with_preference_for(preference)` on lines 165-169 using Postgres JSONB containment (`settings @> ?`). Will be reused for filtering digest recipients.
- A `Settingsable` concern is referenced on line 82 ("See Settingsable for the rest"). Not yet read; will be inspected at code-writing time.
- `organizations.stripe_subscription_status` exists (string column). Used for the digest's eligibility gate.
- `Candidate`, `JobApplication`, `Job` are all org-scoped.
- `HiringStageVisit` records stage moves; analyzer's `stage_move_metrics` filters `where.not(source_hiring_stage_id: nil)` to exclude initial-creation transitions.
- `Comment` model carries both comments and reviews via a `kind` enum.
- `ChannelMessage` belongs to `Channel`, `Channel` belongs to `JobApplication`. `ChannelMessage` has a `sent_by` enum: `sent_by_system` (0), `sent_by_user` (1), `sent_by_candidate` (2), `sent_by_organization` (3). **The analyzer does not currently query `ChannelMessage`** — the digest adds a new query.

### Existing app architecture

- Frontend apps in `app/javascript/`: `ats`, `account`, `connect`, `job_board`, `shared`. No `individual_app` in `app/javascript/` — the individual app is purely ERB.
- `individual_app` lives in `app/controllers/individual_app/` and `app/views/individual_app/`. Server-rendered ERB. Scoped to candidate/job-board-visitor flows on the `individual.polymer.co` subdomain (routes.rb line 642).
- `job_board` app: org-scoped careers-page subdomain. Has both ERB (`app/views/job_board/privacy/show.html.erb`) and React (`app/javascript/job_board/src/views/ApplicationForm.tsx`, `ApplyApp.tsx`).
- **Data deletion / privacy precedent:** `app/controllers/job_board/privacy_controller.rb` + `app/views/job_board/privacy/show.html.erb` + `app/javascript/job_board/styles/_privacy.scss`. ERB form, hidden token field, signed-token validation, success-redirect pattern. Conceptually candidate-facing, so the digest doesn't piggyback on it — but the form pattern is reference material.
- `MagicLinksController` (`app/controllers/magic_links_controller.rb`) is the template for unauthenticated token-validating controllers. No global `authenticate_user!` filter exists in `ApplicationController`; authentication is opt-in per controller.

### Data migrations pattern

- `db/data/` directory holds data migrations (separate from `db/migrate/` schema migrations; uses the `data_migrate` gem pattern).
- Templates relevant for the digest's preference data migration:
  - `db/data/20220226023038_add_default_org_user_settings.rb` — iterates `OrganizationUser.find_each` and calls `add_default_settings`
  - `db/data/20220302005956_set_email_preferences.rb` — handles per-org_user `settings` JSONB updates
- Migration file naming: `YYYYMMDDHHMMSS_descriptive_name.rb`

### Scheduling infrastructure

- **Heroku Scheduler** handles cron-style task scheduling. No `sidekiq-cron` or `whenever` gem in use for this purpose.
- The digest will run as a rake task triggered by Heroku Scheduler. The rake task enumerates eligible orgs and enqueues per-org Sidekiq jobs.
- **Rake task documentation is currently weak** — Jessica wants a `lib/tasks/README.md` listing rake tasks with name / desired time / explanation. This is **spec item #1** for the implementation.

### Existing in-app notification preferences UI

- Lives in `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx`. This is the org-level admin Preferences tab (alongside Team, Billing, Integrations, etc.). Existing copy: "For jobs that you are on the hiring team of, you will receive email notifications for the events selected below." Existing preferences are job-notification scoped, not workspace-wide.
- The digest preference will be a **new section inside this same `AccountPreferences.tsx` file**, separate from the existing job-notification section.

---

## Settled decisions

### MVP scope

The digest body surfaces these seven counts plus one highlight, all over the previous 7-day window:

1. Job applications received
2. Stage moves (count)
3. Jobs published
4. Comments and reviews — collapsed into one sentence at render ("X comments and Y reviews")
5. Messages sent to candidates (everything in `ChannelMessage.sent_by` that is *not* `sent_by_candidate`)
6. Messages received from candidates (`sent_by: :sent_by_candidate`)
7. Top job by application volume highlight (single per-job specific)

Automation-event counts and per-job breakdowns beyond the top job are **out of scope** for MVP.

### Recipients

- Every active organization_user in eligible organizations receives the digest by default (opt-out via the preference described below).
- Content is **scoped per organization_user**:
  - Admin organization_users → org-wide content (all jobs, all candidates, all applications)
  - Non-admin organization_users → scoped to their `HiringTeamMembership` assignments (only jobs they are on the hiring team of)
- The analyzer accepts an optional `organization_user_id` parameter:
  - When **absent (nil)** → existing org-wide behavior (current churn-monitoring caller unchanged)
  - When **present** → analyzer resolves the admin/non-admin question internally:
    - admin → all org jobs (`@organization.jobs.select(:id)`)
    - non-admin → `organization_user.jobs.ids` (via `HiringTeamMembership`)
- The digest mailer always passes `organization_user_id`. The "is this an admin?" decision lives in the analyzer, not the mailer.

### Eligibility (organization level)

```ruby
Organization.where.not(stripe_subscription_status: [nil, 'cancelled'])
```

Orgs with cancelled or nil Stripe status are excluded. (Exact value/enum representation of "cancelled" matched at code time.) This automatically excludes legacy `@workhq`-owner orgs since they have nil Stripe status — no separate workhq filter needed.

### Eligibility (organization_user level)

Filtered via the existing `OrganizationUser.with_preference_for(:email_weekly_digest)` scope, which uses Postgres JSONB containment to find org_users with the key set to `true`.

### Preference data model

- **No new table.** Preference lives at `organization_user.settings['email_weekly_digest']` (boolean).
- **Default value:** `true` (opt-in by default — users start subscribed).
- **Naming:** `email_weekly_digest` follows the existing `email_<thing>_<event>` convention of the three existing keys.
- **`default_settings` method** (line 83 of `organization_user.rb`) gets `email_weekly_digest: true` added so new org_users get it automatically.
- **Data migration** named `AddWeeklyDigestToEmailPreferences` merges the key into existing org_user `settings`:
  ```ruby
  OrganizationUser.find_each do |org_user|
    next if org_user.settings.key?('email_weekly_digest')
    org_user.update_column(:settings, org_user.settings.merge('email_weekly_digest' => true))
  end
  ```
  Lives in `db/data/`. Inherits `ActiveRecord::Migration[6.0]`. `down` raises `IrreversibleMigration`. Uses `update_column` to skip validations/callbacks (matches existing pattern in `db/data/20220226023038_add_default_org_user_settings.rb`).

### Send schedule

- **Rake task** enqueues per-org `WeeklyDigestJob` for every eligible org/org_user pair.
- **Heroku Scheduler** runs the rake task at **00:00 UTC Monday**.
  - = Sunday 7pm ET (EST) / 8pm ET (EDT) — Sunday evening US, prime reading window
  - = Sunday 4pm PT (PST) / 5pm PT (PDT) — Sunday late afternoon US west
  - = Monday 00:00 UK (GMT) / 01:00 UK (BST) — UK wakes Monday morning to it
  - = Monday 01:00 Norway (CET) / 02:00 Norway (CEST) — wakes Monday morning to it
- Bridges "Sunday evening read" framing for Americas and "wake up Monday to it" framing for Europe.

### Three-bucket body content modes

The same email template branches into three content modes based on the data:

1. **Zero everything** — none of the 7 metrics moved this week
2. **Passive flow only** — applications received and/or non-`sent_by_user` messages sent, but the human-activity signal is zero
3. **Active team** — at least one of {stage moves, comments, reviews, messages sent by user} is non-zero

**Human-activity signal for bucket detection:** `stage moves + comments + reviews + messages_sent_by_user_count`. We compute `messages_sent_by_user_count` separately for bucket detection while still **displaying** the combined `total_messages_sent_count` (everything not sent by candidate). Two queries internally, one number shown externally.

Detailed copy/layout for each bucket mode is **deferred to a separate design pass** (Jessica's). Tone direction: bucket 1 = minimal recap with gentle "we're here" framing; bucket 2 = the retention-critical state, surface "you have applications waiting" prompt; bucket 3 = recap-style summary of the week's activity.

### Sender details

- **From display name:** "Jessica from Polymer"
- **From address:** `hello@mail.polymer.co`
- **Subject line:** "Your week at [Organization Name]" (single pattern; no number variants because counts may be zero)

### Unsubscribe flow

Two-surface design:

1. **`List-Unsubscribe` and `List-Unsubscribe-Post: List-Unsubscribe=One-Click` headers** set on every digest send. The header URL points to the app's `unsubscribe` POST endpoint. Gmail/Outlook's native unsubscribe button POSTs to this URL. Honors the user instantly. POST is required by RFC 8058 (link scanners don't POST), safe from accidental scanner-following.
2. **Visible unsubscribe link in the email body** goes to the hosted email preferences page via a signed-token GET URL. User sees a styled checkbox UI, un-checks the digest, clicks Save → POST → confirmation page. Confirm-page UX, not one-click — protects against accidental clicks and link scanners.

Note: per Gmail's 2024 bulk-sender rules, `List-Unsubscribe-Post: One-Click` strongly signals "bulk" to Gmail, which biases toward Updates-tab placement. This is an accepted trade-off; Primary-tab placement is unrealistic for a recurring branded digest. Spam-complaint reputation (the bigger deliverability risk) benefits more from one-click than tab placement is hurt.

### Hosted email preferences page

- Lives in a **new dedicated app: `email_preferences`**. Not in `individual_app` (wrong scope — candidates, not org_users). Not in `job_board` (wrong purpose — candidate-facing). Not in `account` or `ats` (auth-required, doesn't fit no-login email-link entry point).
- Structure:
  - Controllers: `app/controllers/email_preferences/`
  - ERB shell views: `app/views/email_preferences/`
  - React source: `app/javascript/email_preferences/`
  - New pack
  - Routes under an `email_preferences` namespace; subdomain or path-based scoping to be decided at writeup time
- **React used only for the styled checkbox** (reuses the existing styled checkbox component from the component library). Rest of the page is ERB shell, parallel to `job_board/privacy/show.html.erb`'s pattern.
- Token validation, JSONB update, and confirmation-page redirect handled by the controller.

### Controller architecture

Two actions on a new `EmailPreferences::PreferencesController` (or similar):

- **`show`** (GET `/email_preferences?token=...`) — validates the signed token, looks up the org_user, renders the ERB shell with the React checkbox pre-checked or unchecked based on current state.
- **`update`** (POST) — handles both flavors of POST:
  - UI form submission (form-encoded with explicit checkbox state) → updates `organization_user.settings['email_weekly_digest']` to whatever the form sent
  - RFC 8058 one-click POST (body is exactly `List-Unsubscribe=One-Click`) → sets `email_weekly_digest` to `false`
  - Single action branches internally; both write to the same JSONB.

`ApplicationController` does not enforce auth globally, so no auth filter is added to this controller. Only `skip_before_action :verify_authenticity_token, only: [:update]` because the one-click POST cannot carry our CSRF token.

### Computation service architecture

- **Reuse, don't duplicate.** `EngagementReport::OrganizationAnalyzer` gets parameterized extensions:
  - Add optional `organization_user_id:` parameter to the initializer. When passed, `load_base_ids` branches to scope `@job_ids` either to the full org (admin) or to `organization_user.jobs.ids` (non-admin). The existing churn-monitoring caller passes nothing and gets the current org-wide behavior.
  - The cutoff parameter (`months:`) is generalized to accept either a months value or an arbitrary `Time` cutoff for the 7-day digest use case. Implementation detail at code time.
  - Add a `ChannelMessage` count method that joins through `Channel` to filter by `@job_application_ids` — produces both `messages_sent_total` (everything `!sent_by_candidate`) and `messages_sent_by_user_count` (just `sent_by_user`, for bucket detection) and `messages_received_count` (just `sent_by_candidate`).
- The digest mailer/job consumes only the subset of analyzer output it cares about; no presenter layer required.

### In-app preference UI

- New section inside `app/javascript/ats/src/views/accountAdmin/AccountPreferences.tsx`, separate from the existing job-notification section. Section heading: "Weekly digest" (or whatever the design pass decides at the visual level).

### Mailgun template

- **A new Mailgun Stored Template** must be created in the Mailgun control panel for this digest. Different shape from existing notification-style templates (longer body, structured sections, three conditional layouts for the bucket modes).
- App-side Ruby code renders the dynamic body content (the per-org summary) on the server, passes it into the Mailgun template as a body-content variable, along with header variables (org name, recipient name, signed unsubscribe URL, etc.).
- Mailgun template handles the standardized shell: header, footer, branding, body-content slot, visible unsubscribe link, plain-text alternative.

### Naming

- Internal name: `weekly_digest`
- Mailer class: `WeeklyDigestMailer`
- Job class: `WeeklyDigestJob`
- Service module: `WeeklyDigest::` (specific class names settled at code time)
- Rake task namespace: `polymer:weekly_digest:` (final namespace at code time)
- Preference JSONB key: `email_weekly_digest`
- Data migration class: `AddWeeklyDigestToEmailPreferences`
- App directory: `email_preferences`

---

## Spec items / known scope

- **Spec item #1:** create `lib/tasks/README.md` with weekly digest rake task name / desired time / explanation. Establishes the documentation pattern for the rake task surface (which is currently undocumented and a mess).

---

## Open / deferred (to be flagged in spec, not blocking)

- **Detailed copy and visual layout** for each of the three bucket-mode body contents — Jessica's separate design pass
- **Exact URL / subdomain** for the `email_preferences` app — subdomain (`emailpreferences.polymer.co`? hyphenated? `mail.polymer.co/preferences`?) or path-based on an existing domain. Implementation-time decision
- **Token signing mechanism** — HMAC with custom payload, Rails `MessageVerifier`, or `signed_global_id`. Implementation-time decision; the `MagicLink` token pattern is one precedent worth checking
- **React pack/bundle structure** for the `email_preferences` app — dedicated pack vs. extending an existing bundle. Implementation-time
- **`Settingsable` concern** content — referenced in `organization_user.rb:82` but not yet read. Check at code-writing time to see if there are accessors to use
- **Exact "cancelled" value/enum representation** on `stripe_subscription_status` — string vs integer enum, US/UK spelling. Verified at code-writing time

---

## Out of scope for this spec

- Product updates / "what's new" emails — separate future spec; not automatable like the digest
- Retrofitting other mailers with `List-Unsubscribe-Post: One-Click` — broader project for the existing mailer surface, not blocking the digest
- SendGrid Marketing email preferences coordination — future when those emails are actually built
- Automation-event metrics in the digest body — discussed but explicitly deferred
- Per-job breakdowns beyond "top job by applications" — explicitly deferred
- A separate sending subdomain (`digest.polymer.co`) for deliverability isolation — future DNS work
- Renaming `job_board` — Jessica explicitly not renaming
- Stripping the unused `Caffeinate` gem — separate cleanup ticket
