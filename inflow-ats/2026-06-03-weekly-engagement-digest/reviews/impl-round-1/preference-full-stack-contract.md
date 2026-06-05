# Preference Full-Stack Contract -- Round 1

## Findings

### Key name tracing through every layer

1. **Data migration** (`db/data/20260604031833_add_weekly_digest_email_preference.rb`): Uses string key `'email_weekly_digest'`. CORRECT (JSONB stores string keys).

2. **Model defaults** (`organization_user.rb:89`): `email_weekly_digest: true` in `default_settings`. The `Settingsable#add_default_settings` callback converts symbol keys to string keys via `settings[setting[0].to_s] = setting[1]`. CORRECT.

3. **Scope** (`organization_user.rb:38`): `scope :receives_weekly_digest_emails, -> { with_preference_for(:email_weekly_digest) }`. The `with_preference_for` method at line 167-171 converts the symbol to a hash key and uses `@>` JSON containment. CORRECT.

4. **Rake task** (`recurring_tasks.rake:171`): `with_preference_for(:email_weekly_digest)`. Matches the scope. CORRECT.

5. **Backend permit list** (`me_controller.rb:129`): `:email_weekly_digest` added to `settings_params`. CORRECT.

6. **Serializer** (`session_serializer.rb:58-60`): `object&.current_organization_user&.settings` -- returns the full settings hash. The API transformation layer handles `snake_case` -> `camelCase` conversion. CORRECT (no change needed here).

7. **TypeScript type** (`user.ts:5`): `emailWeeklyDigest: boolean`. camelCase. CORRECT.

8. **Frontend destructuring** (`AccountPreferences.tsx:27`): `emailWeeklyDigest` destructured from `settings`. CORRECT.

9. **Frontend checkbox** (`AccountPreferences.tsx:161-166`): `name="emailWeeklyDigest"`, `checked={emailWeeklyDigest}`, `onChange={handleEmailPreferenceChange}`. The `handleEmailPreferenceChange` handler at line 82-88 uses `Object.assign({}, settings, { [name]: value })`. CORRECT.

10. **Save flow** (`AccountPreferences.tsx:69-70`): `updateSettings({ ...settings })` sends the full settings object to `PUT /me/update_settings`. With `emailWeeklyDigest` now in the settings state, it is included. CORRECT.

### Deploy-order constraint

The `settings_params` change (me_controller.rb), `UserSettings` type (user.ts), and `AccountPreferences.tsx` are all in the same commit (9a87ff98c). They WILL deploy atomically. VERIFIED.

### Settingsable concern interaction

The `add_default_settings` callback at `settingsable.rb:27-28` calls `update_settings(settingsable_settings) if settings.blank?`. It only fires when `settings.blank?` (new org_users with no settings). The new key in `default_settings` is included. For existing org_users whose `settings` is already non-blank, the data migration handles backfill. CORRECT.

The `add_new_default_settings` method at `settingsable.rb:16-24` is NOT used by this feature (the data migration is used instead). No conflict. VERIFIED.

No BLOCKER, HIGH, or MED findings.
