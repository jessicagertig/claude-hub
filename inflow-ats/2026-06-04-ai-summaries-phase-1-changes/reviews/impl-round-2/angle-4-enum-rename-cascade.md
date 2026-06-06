# Angle 4: Enum Rename Cascade -- Round 2

## Scope

`auto_generate_ai_summaries_setting` -> `auto_generate_ai_summaries`, value renames, org settings key rename, cascade method rename. Round 1 H3 found two stale spec files. Verifying those are fixed and checking for any additional stale references.

## Findings

### F1 (CLEAR) -- Round 1 H3 fix: `job_ai_settings_spec.rb` updated

All references updated: `auto_generate_ai_summaries_setting` -> `auto_generate_ai_summaries`, `:inherit` -> `:default`, `:on` -> `:enabled`, `:off` -> `:disabled`, `effective_auto_generate_ai_summaries_enabled?` -> `should_auto_generate_ai_summaries?`, `default_auto_generate_ai_summaries_enabled` -> `auto_generate_ai_summaries_enabled`.

### F2 (CLEAR) -- Round 1 H3 fix: `textract_result_ai_trigger_spec.rb` updated

All 9 stale references updated to new names.

### F3 (HIGH) -- Stale settings key in `organization_ai_credits_lifecycle_spec.rb`

**File:** `spec/models/organization_ai_credits_lifecycle_spec.rb:44`

```ruby
expect(organization.settings['default_auto_generate_ai_summaries_enabled']).to be false
```

The settings key was renamed to `auto_generate_ai_summaries_enabled` (in `organization.rb` `add_default_settings` and the data migration). This spec now checks a key that is never set, so `organization.settings['default_auto_generate_ai_summaries_enabled']` returns `nil`, and `expect(nil).to be false` will fail.

This is the same class of defect as Round 1 H3 -- a stale enum/settings reference in a spec file not listed in the plan's "Files to Modify" table.

**Fix:** Change line 44 to:
```ruby
expect(organization.settings['auto_generate_ai_summaries_enabled']).to be false
```

### F4 (CLEAR) -- No other stale references found

`grep` for `default_auto_generate_ai_summaries_enabled` and `defaultAutoGenerateAiSummariesEnabled` across `app/`, `config/`, `lib/`, `spec/` returns only the lifecycle spec (F3 above).

### F5 (CLEAR) -- Rename migration created

`db/migrate/20260605035312_rename_auto_generate_ai_summaries_setting_to_auto_generate_ai_summaries.rb` is an additive rename migration with conditional guards. The original `20260408040701` migration was also edited in-place per spec.

## Verdict: 1 HIGH (F3). FAIL for this angle.
