# Preference Full-Stack Contract — Round 1

## Findings

- F1 [HIGH] Deploy-order data loss risk — The `MeController#update_settings` action (me_controller.rb:50-59) does `current_organization_user.update(settings: temp_params)`, which is a **full replacement** of the JSONB `settings` column with only the keys that pass through `settings_params`. The frontend sends `{ ...settings }` (AccountPreferences.tsx:70), which includes every key from the API response. If the data migration (impl step 1) adds `email_weekly_digest: true` to all org_users, and the backend `settings_params` permit list is updated (adding the key) but the frontend `UserSettings` type and `AccountPreferences.tsx` are NOT yet deployed, then the first time ANY user saves their preferences, the frontend will send only three keys (the ones it knows about), the backend will permit all four but only receive three, and the `update(settings: ...)` will overwrite the column — silently deleting the `email_weekly_digest` key the migration just added. The spec's implementation order (step 1 data migration, step 8 frontend) has this vulnerability. **Fix: the spec must state that `settings_params`, `UserSettings`, and `AccountPreferences.tsx` changes must deploy atomically, OR that the `settings_params` addition deploys WITH the frontend, not ahead of it. The data migration and `default_settings` update are safe to deploy early.**

- F2 [MED] `settings_params` permit list — spec line 87 says the preference key is `email_weekly_digest`. The current `settings_params` at me_controller.rb:128-129 is `params.require(:settings).permit(:email_job_applications_new, :email_comments_new, :email_messages_new)`. The spec correctly identifies this needs updating (review-angles line 57-58) but the spec text itself (section "Components added" table and "Preference storage") does not explicitly call out `settings_params` as a file that needs modification. The REVIEW-ANGLES.md catches this, and the "Modified files" table there lists `me_controller.rb`, but the spec's own Components table omits it.

- F3 [MED] `UserSettings` TypeScript interface — current definition at user.ts:1-5 has three fields, all camelCase (`emailJobApplicationsNew`, `emailCommentsNew`, `emailMessagesNew`). The new key `email_weekly_digest` must become `emailWeeklyDigest` on the frontend per core_critical_rules.md rule 7. The spec mentions the camelCase convention only by reference to rule 7 but does not state the frontend key name. This is implicit but an implementer who reads the spec without reading rule 7 could get it wrong.

- F4 [LOW] `Settingsable#add_default_settings` (settingsable.rb:27-29) calls `update_settings(settingsable_settings) if settings.blank?`. This only fires when `settings` is blank (nil or empty). Adding a new key to `default_settings` will NOT retroactively affect existing org_users whose settings column already has data — which is exactly why the data migration exists. The spec correctly describes this flow. No issue.

- F5 [LOW] `SessionSerializer#settings` (session_serializer.rb:58-60) surfaces `current_organization_user&.settings` — this is the raw JSONB column. The API serialization layer transforms snake_case keys to camelCase automatically. Adding a new key to the JSONB column will be surfaced automatically. No issue.

## Amendments Applied

- F1 requires a spec amendment (HIGH).

**Amendment applied to SPEC.md:** Added deploy-order safety note to the Implementation Order section.
