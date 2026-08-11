# Angle: Succeeded Layout Data Consumption and Structured Data Access

## Verdict: PASS

### Data fetching

PlatoTab.tsx lines 38-41: `useAiJobApplicationSummary` is called with `{ jobApplicationId, aiJobApplicationSummaryId: aiSummary?.id || 0 }`. When no summary exists, this fires with id=0, producing a silent 404. This is acknowledged in the plan's Risks section and matches the analog's unconditional fetch pattern. The data is only used in the succeeded state (line 43: `structuredData = status === "succeeded" ? fullSummary?.structuredData : null`).

### Field access paths (all camelCase, all with optional chaining)

- `aiSummary.createdAt` (line 135) -- shallow summary, provenance timestamp
- `aiSummary.headline` (line 155) -- shallow summary, headline
- `aiSummary.stale` (line 138) -- shallow summary, stale flag
- `structuredData?.assessment?.primaryDomain?.name` (line 113) -- domain label
- `structuredData?.assessment?.secondaryDomain?.name` (line 114) -- domain label
- `structuredData?.assessment?.standoutAccomplishments` (line 115) -- notable achievements
- `structuredData?.assessment?.keySkills` (line 116) -- skill emphasis
- `structuredData?.skills` (line 117) -- skill cloud
- `structuredData?.roleAnalysis` (line 169, 177) -- fit-for-role card, with fallback
- `structuredData?.applicableExperience` (line 198) -- relevant experience section
- `structuredData?.gaps` (line 205) -- gaps section

All field names are camelCase (the API layer auto-transforms from backend snake_case). All use optional chaining for null safety.

### Fallback behavior

`roleAnalysis` falls back to `aiSummary.summaryText` (line 169: `structuredData?.roleAnalysis || aiSummary.summaryText`, and line 177: `structuredData?.roleAnalysis || aiSummary.summaryText`). Matches spec: "sourced from `structuredData.roleAnalysis` falls back to `aiSummary.summaryText` if absent."

### Section omission when data absent

- Notable achievements: `standoutAccomplishments.length > 0` (line 182) -- omits if empty
- Relevant experience: `structuredData?.applicableExperience` (line 198) -- omits if falsy
- Gaps: `structuredData?.gaps` (line 205) -- omits if falsy
- Skills: `sortedSkills.length > 0` (line 212) -- omits if empty
- Domain label: `primaryDomain || secondaryDomain` (line 157) -- omits if neither present

All match spec requirements for conditional omission.

### distanceInWords usage

Line 16: `import { distanceInWords } from "@shared/lib/time"`. Line 135: `distanceInWords(aiSummary.createdAt)`. This is the correct function -- accepts ISO strings, includes `{ addSuffix: true }` by default. Not `timeAgoInWordsShort` (which expects Unix seconds).

### Timestamp formatting

`distanceInWords` returns "about 3 hours ago" etc. The spec explicitly notes "about" prefix is acceptable UX (plan Open Question 1).

### No findings.
