# angle-4: enum-rename-cascade — Round 1

Verified all ripple sites against the source code:

- `app/models/job.rb` line 158: `enum auto_generate_ai_summaries_setting:` — confirmed, needs rename to `auto_generate_ai_summaries`
- `app/models/job.rb` line 878-884: `effective_auto_generate_ai_summaries_enabled?` — confirmed, needs rename to `should_auto_generate_ai_summaries?`
- `app/serializers/api/v1/job_serializer.rb` line 5: `:auto_generate_ai_summaries_setting` — confirmed
- `app/controllers/api/v1/jobs_controller.rb` lines 163/218: `:auto_generate_ai_summaries_setting` — confirmed
- `app/models/organization.rb` lines 947-948: `default_auto_generate_ai_summaries_enabled?` — confirmed
- `app/controllers/api/v1/organizations_controller.rb` line 128: `:default_auto_generate_ai_summaries_enabled` — confirmed
- `app/models/textract_result.rb` line 119: `effective_auto_generate_ai_summaries_enabled?` — confirmed
- `app/javascript/ats/src/lib/newLookups.ts` line 39: `"inherit" | "on" | "off"` — confirmed
- `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx` lines 21/33/72: `autoGenerateAiSummariesSetting` — confirmed
- `app/javascript/shared/types/organization.ts` line 3: `defaultAutoGenerateAiSummariesEnabled` — confirmed
- `app/javascript/ats/src/views/accountAdmin/OrganizationAiSettings.tsx` lines 23/111/113: `defaultAutoGenerateAiSummariesEnabled` — confirmed

## Finding 1

**[MED]** Missing ripple site: `newLookups.ts` type name not addressed

**Where:** `app/javascript/ats/src/lib/newLookups.ts` line 39

**What:** The spec mentions renaming the enum values (`"inherit"` → `"default"`, `"on"` → `"enabled"`, `"off"` → `"disabled"`) but the TypeScript type name is `AutoGenerateAiSummariesSetting`. If the backend enum field name changes from `auto_generate_ai_summaries_setting` to `auto_generate_ai_summaries`, the type name should also be updated to `AutoGenerateAiSummaries` (without `Setting`), and its comment updated from `Job#auto_generate_ai_summaries_setting` to `Job#auto_generate_ai_summaries`.

**Evidence:** `newLookups.ts` line 38-39:
```ts
// Job - Auto-generate AI Summary Setting (Job#auto_generate_ai_summaries_setting)
export type AutoGenerateAiSummariesSetting = "inherit" | "on" | "off";
```

**Fix:** Add to Note #5's `newLookups.ts` section: rename the type from `AutoGenerateAiSummariesSetting` to `AutoGenerateAiSummaries`, and update the comment to reference `Job#auto_generate_ai_summaries`.

## Finding 2

**[MED]** Missing ripple site: `JobSetupAiSettings.tsx` enum values in option labels

**Where:** `app/javascript/ats/src/views/jobApplications/jobSetup/JobSetupAiSettings.tsx`

**What:** The spec mentions updating the field name and enum values, but the component likely has UI label strings referencing the old values (e.g., "Inherit", "On", "Off"). The implementation agent needs to update the option labels to match the new value names ("Default", "Enabled", "Disabled"). This may not need explicit spec mention since the enum values themselves change.

No action needed — the implementing agent will naturally update the option values alongside their labels.

All ripple sites confirmed present. No BLOCKER or HIGH findings for this angle.
