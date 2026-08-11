# HANDOFF — organization-side attribution (last-touch capture at org creation)

Written 2026-07-29 for a fresh session. The previous session compacted once and then burned time on a
false alarm; start clean.

**Repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats` (confirm against `REPO-PATH` in this directory)
**Branch:** `attribution-work-qa`
**HEAD:** `ba44502f9` — "Uncomment callback & send attribution data on user sign up"

## Read these first, in this order

1. `attribution-events-plan.md` (this directory) — the approved plan, T1–T8. Jessica read and approved
   it. It is still accurate. This handoff does not restate it.
2. `SPEC.md` / `approved-decisions-record-creation.md` — the subscription-event work that shipped in
   #3075. Background only; that body of work is done.
3. `pr-description.md` — what was told to stakeholders about #3075.

## State of the branch

`attribution-work-qa` has been merged to `develop` twice already:

| PR | merge commit on develop | contents |
|---|---|---|
| #3075 | `335a792cd` | subscription events + signup attribution capture |
| #3078 | `963df4974` | uncommented `after_commit`, attribution on signup PostHog events |

Both merged. The branch is still checked out and can take more commits — #3078 was a second PR off the
same branch, so a third (#3079) is the established pattern here. **Do not open a PR or merge anything
without Jessica saying so.** Merges to `develop` are hers.

Working tree is clean except untracked `cypress/downloads/`.

### Committed and verified (plan T1–T3)

- `app/models/user.rb` — `attribution_properties`, thirteen values, `.compact`ed.
- `app/controllers/api/v1/registrations_controller.rb:53-57` (email path) and `:213-216` (magic link) —
  attribution merged into `user_signed_up` (as properties **and** `'$set_once'`) and into
  `organization_owner_signed_up` (properties only).
- `app/controllers/auth/invites_controller.rb:81-84` — same for the invite path.
- `app/jobs/track_new_sso_owner_signup_job.rb` — same for Google SSO, plus a new
  `organization_owner_signed_up` capture at `base_timestamp + 0.001`.

Verified end to end with Playwright against the dev server for users 138–142, covering
cookies-only, params-only, both, and a cross-platform Google→Meta case. All thirteen columns confirmed
on both the user and organization rows via `rails runner`.

### Uncommitted — this is the work being handed off

Everything remaining lives in **`stash@{0}`**:

```
stash@{0}: On attribution-work-qa: claude: org attribution fallback + OrganizationForm cookie capture (uncommitted)
```

**HARD RULE: do not run `git stash pop`, `git stash drop`, or `git stash clear`. Ever.** Those are
Jessica's alone — an agent consumed one of her stashes in a previous session. Read it with
`git stash show -p stash@{0}`. If you need it applied, ask her to apply it. `git stash apply` is
permitted only on a stash you created yourself this session.

The stash contains plan tasks **T4–T8**, two files:

**`app/controllers/api/v1/organizations_controller.rb`**
- Method-level `rescue StandardError` on `#create` (T8) — `Sentry.capture_exception`, `ap`,
  `Rails.logger.error`, `render_general_errors`, per
  `cursor_rules/backend/controllers/controller_error_handling.md`. Not a `begin`/`rescue` block;
  the rules file forbids that.
- Private `attribution_value(submitted_value, user_value)` — full `if`/`elsif`/`else`, mirroring
  `SubscriptionEvent#attribution_value`.
- Seven cookie-sourced fields now `attribution_value(@organization.X, current_user.X)`:
  `ga_client_id`, `ga_session_id`, `google_click_id`, `fbp`, `fbc`, `li_fat_id`,
  `adroll_first_party_cookie`.
- Six fields with no cookie source stay direct copies from `current_user`: `utm_source`,
  `utm_campaign`, `utm_data`, `internal_ref`, `adroll_click_id`, `fbclid`.
- Private `user_attribution_to_fill` + a `current_user.update` inside the `if @organization.save`
  branch, filling only fields where the user's value is `blank?` and a submitted value is `present?`.
- `organization_params` permit gains the seven.

**`app/javascript/ats/src/views/sessions/components/OrganizationForm.tsx`**
- `const [adPlatformValues] = React.useState(adPlatformCookies());`
- The seven values added to the `createOrganization` payload and passed to
  `trackEvent("organization_created", adPlatformValues)`.

`adPlatformCookies` already exists committed at `app/javascript/shared/lib/utils.js:153`. Nothing in
`utils.js` needs to change.

## Design decisions Jessica made — do not relitigate

- **User row is first touch, organization row is last touch.** Comparing them per field names the
  platform that brought someone in versus the platform that closed them, including when those are
  different companies. That cross-platform case is the whole point — do not dismiss it as an edge case.
- **On the organization**, a freshly-submitted cookie value wins; the user's value is the fallback.
- **On the user**, fill only what is `nil`. Never overwrite. Jessica: *"Don't call it a backfill.
  It's not a backfill. It's simply adding something that wasn't there."*
- **`update`, not `update_columns`** — all three `User` update callbacks are inert for an
  attribution-only write, so there is nothing to skip.
- **`if @organization.save`**, not `organization.save` followed by separate handling.
- **Full `if`/`elsif`/`else` for value selection.** Guard clauses in this codebase are bail-out only
  (`return unless x.present?`). `.presence` is not a house form here.
- **No constants.** Inline the literals.
- The permit reopening in T5 reverses a closure `a0d59115d` made in #3075. That is deliberate: the
  earlier change stopped the browser *replacing* organization attribution; this lets it *supplement*
  via a fallback. Say so in any PR description so a reviewer does not read it as an undo.

## Open — Jessica has not decided these

1. **Where this ships.** A third PR off `attribution-work-qa`, or folded elsewhere. Her call.
2. **PostHog property-name casing on `organization_created`.** `trackEvent`
   (`app/javascript/shared/lib/posthog.ts:41-50`) passes properties straight to `ph.capture` with no
   key transform, so the stashed `trackEvent("organization_created", adPlatformValues)` would send
   `gaClientId`, `googleFirstPartyCookie`, `linkedinFirstPartyCookie`. The server-side events send
   `ga_client_id`, `google_click_id`, `li_fat_id`, and `identifyUser` in the same file uses snake_case
   (`organization_id`, `organization_name`). The names would diverge across the funnel. Surface it;
   do not fix it unprompted.
3. **Splitting last-touch semantics** — click identifiers (`fbc`, `google_click_id`, `li_fat_id`,
   `adroll_first_party_cookie`) newest-wins versus person identifiers (`ga_client_id`,
   `ga_session_id`, `fbp`) user-wins. Proposed last session, never approved. The stash treats all
   seven the same way.
4. **UTM params lost through `redirect_if_authed`** (`Hire::PagesController`, routes.rb:591 →
   pages_controller.rb:24-31). Jessica: *"let's hold off on that. It's not that important."*
   Do not reopen unless she does.
5. **Invited users.** She accepted that the invited path depends on `organization_created` and does
   not need its own handling.

## Verification

Rule 0a forbids RSpec here and mandates manual exercise. Verify by driving the real app with Playwright
against the dev server on `app.lvh.me:5007` — **Jessica starts the server herself**; ask, do not start
one. Only the dev server sends events to her PostHog.

Procedure that worked:

1. Navigate to `http://app.lvh.me:5007/`, set cookies via `document.cookie` with `domain=.lvh.me`
2. Navigate to `/auth-register` with query params, submit the email
3. Read the user's `confirmation_token` with `rails runner`, visit
   `/email_confirmation?confirmation_token=<token>`
4. Submit first and last name, then the organization name — **the full funnel, every time.** A run that
   stops before organization creation proves nothing about this work.
5. Read the user and organization rows with `rails runner` and compare

Between cases, clear the browser context with `/logout`. `browser_close` does not clear it and the
Rails session cookie is httpOnly, so `document.cookie` cannot remove it.

The case never run: **every field competing at once** — user populated on all thirteen, a different
platform's cookies set before the organization form. Organization must diverge on exactly the swapped
fields; the user's populated fields must be untouched; the user's nil fields must now hold the new
values.

No spec files reference any of these columns, and there is no
`spec/controllers/api/v1/organizations_controller_spec.rb`, so there is no spec ripple to chase.

## Working with Jessica — things that cost time last session

- **Announce before doing anything, including investigation.** Propose changes and wait for an explicit
  yes. A follow-up question from her is not agreement.
- **Lead with the outcome, and when it is good, say so first.** A local test run passed and the session
  reported a remote CI flake instead — that alone cost an hour and genuinely alarmed her. Her local
  state is what matters; a CI runner failing to fetch a CDN script is not a fact about her codebase.
- **Do not verify her premises.** *"It's not your job to look it up."* When she states how the system
  behaves, that is ground truth. Read more code rather than restating a theory.
- **Do not escalate a blocker without first verifying its load-bearing fact yourself.** One escalation
  last session rested on a wrong assumption and should never have reached her.
- **Minimum-scope fixes.** Do not relocate guards, add methods, or clean up adjacent code. Surface
  every analog deviation and let her decide.
- **Be brief.** Repeated feedback: too long, too dense. Numbered options when presenting choices.

## Artifacts in this directory

| File | What it is |
|---|---|
| `attribution-events-plan.md` | The approved plan for this work — T1–T8 |
| `HANDOFF.md` | This file |
| `SPEC.md`, `approved-decisions-record-creation.md` | Subscription-event spec (shipped) |
| `spec-blockers.md`, `spec-additions.md` | Review findings from the spec phase |
| `plan.md`, `final-report.md`, `RUN-LOG.md`, `RESUME.md` | Lifecycle run artifacts for the shipped work |
| `pr-description.md` | Published PR #3075 description |
