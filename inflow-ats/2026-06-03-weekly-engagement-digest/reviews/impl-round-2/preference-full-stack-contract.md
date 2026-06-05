# Preference Full-Stack Contract -- Round 2

## Findings

Re-examined the full-stack contract with focus on the JSONB full-replacement hazard.

### The JSONB full-replacement scenario

The `MeController#update_settings` at line 50-60 does:
```ruby
temp_params = settings_params  # Only permitted keys
current_organization_user.update(settings: temp_params)
```

This replaces the ENTIRE `settings` column with only the keys that `settings_params` permits. The permit list is:
```ruby
params.require(:settings).permit(:email_job_applications_new, :email_comments_new, :email_messages_new, :email_weekly_digest)
```

The frontend sends ALL four keys because:
1. `useState<UserSettings>({ ...meResponse.settings })` initializes state with all keys from the API response
2. `handleSubmitForm` sends `{ ...settings }` which includes all keys in the state
3. The `UserSettings` type includes `emailWeeklyDigest: boolean`

If a user's settings already has `email_weekly_digest: true` from the data migration, and the frontend loads it, the state will include `emailWeeklyDigest: true`. When the user saves, all four keys are sent. The backend permits all four. The column is replaced with all four. No data loss. VERIFIED.

### Edge case: settings with extra keys

If an org_user's settings JSONB contains keys beyond the four permitted ones (e.g., from a future feature or legacy data), those extra keys WILL be silently dropped when the user saves preferences. This is a pre-existing architectural risk mentioned in the plan, not introduced by this feature. NOT a new finding.

### Edge case: org_user switches organizations

The `SessionSerializer#settings` at line 58-60 returns `object&.current_organization_user&.settings`. The settings are per-organization_user, not per-user. If a user switches organizations, the AccountPreferences page loads the new org_user's settings. The data migration backfills all org_users, so the `email_weekly_digest` key is present for all. CORRECT.

### camelCase/snake_case transformation

The API response goes through serialization. The `settings` column stores string keys in snake_case (`email_weekly_digest`). The serializer returns the raw hash. The API transformation layer (likely `olive_branch` gem or similar) converts snake_case to camelCase for the frontend. The frontend sees `emailWeeklyDigest`. When the frontend sends it back, the transformation converts it back to `email_weekly_digest`. The backend `settings_params` permits the snake_case key. CORRECT.

No new findings. No BLOCKER or HIGH.
