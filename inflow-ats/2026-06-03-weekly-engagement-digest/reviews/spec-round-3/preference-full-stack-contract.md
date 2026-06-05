# Preference Full-Stack Contract — Round 3

## Findings

No new issues found. The full-stack preference chain is complete and accurately documented:
1. Data migration writes `email_weekly_digest: true` to existing org_users
2. `default_settings` ensures new org_users get the key
3. `settings_params` permits the key (now in Components table, line 87)
4. `SessionSerializer` surfaces settings (consumed, no code change needed)
5. `UserSettings` interface adds `emailWeeklyDigest` (now in Components table, line 88)
6. `AccountPreferences.tsx` adds the checkbox
7. Rake task uses `with_preference_for(:email_weekly_digest)` to enumerate
8. Deploy-order constraint documented (lines 240-242)

Verified the `Settingsable` concern interaction: `delete_unused_settings` (settingsable.rb:32-42) iterates `settings.keys` and deletes any not in `settingsable_settings` (which calls `default_settings`). Since `email_weekly_digest` will be in `default_settings`, it won't be deleted. This is safe.

## Amendments Applied

None.
