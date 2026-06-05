# Investigation — Note #5: auto_generate_ai_summaries_setting enum rename

## Ground truth
- Job enum `auto_generate_ai_summaries_setting: { inherit:0, on:1, off:2 }, _prefix: true` (`job.rb:158`). Integers unchanged by rename → no data migration for values.
- `Job#effective_auto_generate_ai_summaries_enabled?` (`job.rb:878-886`): cascade — job enum on→true / off→false / else org default. Called only at `textract_result.rb:119` (+ def). Renamed to `should_auto_generate_ai_summaries?` (matches existing `should_*?` convention: should_display_public_logo?, should_attach_external_resume_url?, should_display_banner?, should_trigger?).
- Org setting: key `default_auto_generate_ai_summaries_enabled` in settings JSONB; method `Organization#default_auto_generate_ai_summaries_enabled?` (`organization.rb:947`, `settings&.dig(...)`); default at `organization.rb:1179`; param at `organizations_controller.rb:128`.
- Social-share precedent (`careers_page.rb`, `job.rb:749`): cascade method named for its result (`social_share_image_url`, falls back to `organization.default_careers_page...` when type `'default'`), NO `effective_` prefix. "default" used only as a VALUE on `social_share_image_type`, never in a key/method name. Confirmed dropping `default_` from the org key matches precedent.

## Migration order (from 20260408040701 onward)
1. db/migrate/20260408040701_add_auto_generate_ai_summaries_setting_to_jobs.rb ← column
2. db/data/20260408040801_create_organization_ai_credit_balances_for_existing_organizations.rb
3. db/data/20260408040802_add_ai_settings_to_existing_organizations.rb (seeds the org key)
4. db/migrate/20260415152006_create_bulk_ai_summary_job_applications.rb

## Decision: see approved-decisions.md Note #5 (full renames + in-place migration handling + grouped ripple sites).
