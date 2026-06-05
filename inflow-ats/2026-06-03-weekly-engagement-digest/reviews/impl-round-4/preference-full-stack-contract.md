# Preference Full-Stack Contract -- Round 4

## Findings

### Settings save mechanism (adversarial check)

`MeController#update_settings` at `me_controller.rb:50-60` calls `current_organization_user.update(settings: temp_params)`. This is `ActiveRecord#update`, which replaces the entire `settings` JSONB column with the contents of `temp_params`. This is NOT `Settingsable#update_settings` (which is additive/merge-style).

This means the frontend MUST send all settings keys on every save, or missing keys are lost. The frontend does this correctly:
1. `AccountPreferences.tsx:25` initializes `settings` state from `meResponse.settings` (the full settings hash from the API).
2. `handleEmailPreferenceChange` at line 86 uses `Object.assign({}, settings, { [name]: value })` -- creates a new object from ALL existing settings plus the changed key.
3. `handleSubmitForm` at line 69-74 sends `{ ...settings }` -- all keys.
4. `settings_params` permits all 4 keys: `:email_job_applications_new, :email_comments_new, :email_messages_new, :email_weekly_digest`.

All 4 keys are present in both the frontend state and the permit list. The full column is correctly preserved on save. CORRECT.

### Data migration idempotency

`AddWeeklyDigestEmailPreference#up` at `db/data/20260604031833:5-9`:
- `find_each` iterates all org_users.
- `next if existing_settings.key?('email_weekly_digest')` -- skips records that already have the key. Safe for re-runs.
- `org_user.update_columns(settings: existing_settings)` -- writes directly to column, bypassing callbacks and validations. Appropriate for a data migration.

### Settingsable#add_default_settings

Called by the `after_create` callback at `organization_user.rb:26`. `add_default_settings` at `settingsable.rb:27-29`: `update_settings(settingsable_settings) if settings.blank?`. For new org_users, `settings` is blank, so `update_settings` writes all 4 default keys including `email_weekly_digest: true`. For existing org_users who already have settings (from the data migration), `settings.blank?` is false, so `add_default_settings` is a no-op. CORRECT.

### with_preference_for query

`OrganizationUser.with_preference_for(:email_weekly_digest)` at `organization_user.rb:167-171` generates: `WHERE settings @> '{"email_weekly_digest": true}'::jsonb`. The `@>` containment operator requires the key to be present AND true. This works correctly with the data migration (which sets the key to `true`) and the default_settings (which also sets `true`). Users who unsubscribe via the UI will have the key set to `false`, and `@>` will not match. CORRECT.

No issues found.
