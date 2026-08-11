# Angle 3: Succeeded Layout Data Consumption

## Findings

### No HIGH findings

**Field access paths -- all correct:**
- `structuredData?.assessment?.primaryDomain?.name` (line 112) -- correct camelCase
- `structuredData?.assessment?.secondaryDomain?.name` (line 113) -- correct camelCase
- `structuredData?.assessment?.standoutAccomplishments` (line 114) -- correct camelCase
- `structuredData?.assessment?.keySkills` (line 115) -- correct camelCase
- `structuredData?.skills` (line 116) -- correct
- `structuredData?.roleAnalysis` (line 168, 176) -- correct camelCase
- `structuredData?.applicableExperience` (line 197, 200) -- correct camelCase
- `structuredData?.gaps` (line 204, 206) -- correct
- `aiSummary.headline` (line 154) -- correct
- `aiSummary.createdAt` (line 134) -- correct
- `aiSummary.stale` (line 137) -- correct
- `aiSummary.summaryText` (line 168, 176) -- correct

**Null handling -- correct:**
- All `structuredData` access uses optional chaining (`?.`)
- `standoutAccomplishments` defaults to `[]` (line 114): `assessment?.standoutAccomplishments || []`
- `keySkills` defaults to `[]` (line 115): `assessment?.keySkills || []`
- `skills` defaults to `[]` (line 116): `structuredData?.skills || []`
- Sections are omitted when data is absent:
  - Domain label: guarded by `(primaryDomain || secondaryDomain)` (line 156)
  - Fit card: guarded by `(structuredData?.roleAnalysis || aiSummary.summaryText)` (line 168)
  - Notable achievements: guarded by `standoutAccomplishments.length > 0` (line 181)
  - Relevant experience: guarded by `structuredData?.applicableExperience` (line 197)
  - Gaps: guarded by `structuredData?.gaps` (line 204)
  - Skills: guarded by `sortedSkills.length > 0` (line 211)

**roleAnalysis fallback -- correct:**
Line 176: `{structuredData?.roleAnalysis || aiSummary.summaryText}` -- falls back to summaryText as specified.

**Timestamp -- correct:**
Line 134: `distanceInWords(aiSummary.createdAt)` -- uses the correct function (not `timeAgoInWordsShort`). Import at line 16 is from `@shared/lib/time`.

**Key skills sorting -- correct:**
Lines 120-127 implement the same sorting as the design handoff prototype (ai-tab.jsx line 246-247): case-insensitive prefix match, sort key skills to front.

**`useAiJobApplicationSummary` with id=0:** Line 40 passes `aiSummary?.id || 0` when no summary exists. This produces a 404 API call when no summary exists, but the plan acknowledges this as acceptable (React Query won't retry a 404 by default, and the UI guards on `structuredData` being null). Consistent with the plan's documented risk.
