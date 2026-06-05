# Preference Full-Stack Contract -- Round 3

## Findings

### Key name trace: `email_weekly_digest` (backend) / `emailWeeklyDigest` (frontend)

| Layer | File | Key | Verified |
|---|---|---|---|
| Data migration | `db/data/20260604031833_add_weekly_digest_email_preference.rb:7` | `'email_weekly_digest'` (string) | YES |
| Model defaults | `organization_user.rb:89` | `email_weekly_digest: true` (symbol, stored as string by JSONB) | YES |
| Model scope | `organization_user.rb:38` | `with_preference_for(:email_weekly_digest)` | YES |
| Settingsable concern | `settingsable.rb:28` | `add_default_settings` writes all keys from `default_settings` when `settings.blank?` | YES |
| API permit | `me_controller.rb:129` | `:email_weekly_digest` | YES |
| Serializer | `session_serializer.rb:58-60` | `object.current_organization_user.settings` (passes all keys through) | YES |
| TypeScript type | `user.ts:5` | `emailWeeklyDigest: boolean` | YES |
| UI destructure | `AccountPreferences.tsx:27` | `emailWeeklyDigest` | YES |
| UI checkbox | `AccountPreferences.tsx:162` | `name="emailWeeklyDigest"` | YES |
| Rake task | `recurring_tasks.rake:171` | `with_preference_for(:email_weekly_digest)` | YES |

### snake_case/camelCase boundary

Backend uses `email_weekly_digest` (snake_case). Frontend uses `emailWeeklyDigest` (camelCase). The serializer surfaces settings as-is (JSONB column). The API response uses snake_case keys which the frontend's React Query layer camelizes. This matches the existing keys (`email_comments_new` -> `emailCommentsNew`, etc.). CORRECT per `core_critical_rules.md` rule 7.

### Settings save flow

`handleEmailPreferenceChange` at `AccountPreferences.tsx:82-88` uses `Object.assign({}, settings, { [name]: value })` where `name` is the camelCase `emailWeeklyDigest`. `handleSubmitForm` sends `{ ...settings }` via `updateSettings`. The backend `MeController#update_settings` at the controller calls `current_organization_user.update_settings(settings_params.to_h)`. `Settingsable#update_settings` at line 45-56 iterates the hash and writes each key as `setting[0].to_s`. The full round-trip is verified.

### Deploy-order constraint

The spec notes that `settings_params` + `UserSettings` + `AccountPreferences.tsx` must deploy together because `MeController#update_settings` does a full replacement via `Settingsable#update_settings`. Looking at `update_settings` at `settingsable.rb:45-56`: it iterates `new_settings` and writes each key to `settings[key] = value`, then saves. This is additive -- it does NOT delete keys not present in `new_settings`. However, `handleSubmitForm` sends the entire `settings` object from React state, which starts from `meResponse.settings`. If the frontend doesn't know about `emailWeeklyDigest` (pre-deploy), it won't include that key in the save payload, and `update_settings` won't touch it -- it only writes keys present in `new_settings`. So actually the deploy-order constraint is about the permit list: if `:email_weekly_digest` is in the permit list but the frontend doesn't send it, the key is simply absent from `settings_params` and never written. The data migration's value is preserved. The spec's caution is valid but the actual risk is lower than stated. NOT a finding -- the implementation is correct.

No issues found.
