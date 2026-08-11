# Angle 3: Succeeded Layout Data Consumption

## Verdict: PASS

## Data access paths

### Shallow data (from jobApplication.aiJobApplicationSummary)
- `aiSummary.headline` at line 155 -- CORRECT (shallow field)
- `aiSummary.createdAt` at line 135 -- CORRECT (shallow field)
- `aiSummary.stale` at line 138 -- CORRECT (shallow field)
- `aiSummary.status` at line 36 -- CORRECT (shallow field)
- `aiSummary.summaryText` at line 177 -- CORRECT (shallow field, used as fallback)

### Full data (from useAiJobApplicationSummary)
- `structuredData?.assessment?.primaryDomain?.name` at line 113 -- CORRECT (camelCase)
- `structuredData?.assessment?.secondaryDomain?.name` at line 114 -- CORRECT (camelCase)
- `structuredData?.assessment?.standoutAccomplishments` at line 115 -- CORRECT (camelCase)
- `structuredData?.assessment?.keySkills` at line 116 -- CORRECT (camelCase)
- `structuredData?.skills` at line 117 -- CORRECT (top-level field)
- `structuredData?.roleAnalysis` at line 169 -- CORRECT (camelCase)
- `structuredData?.applicableExperience` at line 198 -- CORRECT (camelCase)
- `structuredData?.gaps` at line 205 -- CORRECT (camelCase)

### Fallback behavior
- `roleAnalysis` falls back to `aiSummary.summaryText` at line 177: `structuredData?.roleAnalysis || aiSummary.summaryText` -- MATCHES spec requirement at SPEC.md line 72.

### Section omission for missing data
- `standoutAccomplishments.length > 0` at line 182 -- CORRECT (omits if empty array)
- `structuredData?.applicableExperience &&` at line 198 -- CORRECT (omits if falsy)
- `structuredData?.gaps &&` at line 205 -- CORRECT (omits if falsy)
- `sortedSkills.length > 0` at line 212 -- CORRECT (omits if empty)
- `(primaryDomain || secondaryDomain) &&` at line 157 -- CORRECT (omits if both absent)
- `(structuredData?.roleAnalysis || aiSummary.summaryText) &&` at line 169 -- CORRECT (omits if both absent)

### Query fetching pattern
- Full summary fetched via `useAiJobApplicationSummary` at lines 38-41 with `aiSummary?.id || 0` -- MATCHES the plan's documented approach (silent 404 when no summary).
- `structuredData` only populated when `status === "succeeded"` at line 43 -- CORRECT.

### Key-skills sorting
- Line 121-124: `isKeySkill` uses `keySkills.some((k) => skill === k || skill.toLowerCase().startsWith(k.toLowerCase()))` -- MATCHES the prototype at ai-tab.jsx line 246.
- Line 126-128: `sortedSkills` sorts key skills to front -- CORRECT.

### Domain name capitalization
- Line 119: `capitalize` function applied at lines 160 and 164 -- MATCHES spec requirement for capitalized first letter.

### Timestamp
- Line 135: `distanceInWords(aiSummary.createdAt)` -- CORRECT. Uses the ISO-string-compatible function, NOT `timeAgoInWordsShort`.

## Findings

None.
