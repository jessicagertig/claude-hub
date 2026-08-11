# Angle: Succeeded Layout Data Consumption

## Files checked
- `PlatoTab.tsx` -- `renderSucceeded()` lines 111-235
- `shared/types/aiJobApplicationSummary.ts` -- `AiAssessment` interface lines 15-23
- Design handoff `ai-tab.jsx` -- data access patterns

## Findings

No findings.

## Verification

### Field access paths (all camelCase, matching API auto-transform)

1. **Provenance:** `aiSummary.createdAt` (line 135) -- ISO string passed to `distanceInWords()`. Correct function (NOT `timeAgoInWordsShort`).
2. **Stale:** `aiSummary.stale === true` (line 138) -- boolean check, correct.
3. **Headline:** `aiSummary.headline` (line 155) -- from shallow serializer, correct.
4. **Domains:** `assessment?.primaryDomain?.name` and `assessment?.secondaryDomain?.name` (lines 113-114) -- camelCase, matches `AiAssessment` interface.
5. **Key skills:** `assessment?.keySkills` (line 116) -- camelCase, matches interface.
6. **Standout accomplishments:** `assessment?.standoutAccomplishments` (line 115) -- camelCase, matches interface.
7. **Role analysis:** `structuredData?.roleAnalysis` (line 169, 177) -- camelCase, with fallback to `aiSummary.summaryText`. Correct per spec.
8. **Applicable experience:** `structuredData?.applicableExperience` (line 198, 201) -- camelCase.
9. **Gaps:** `structuredData?.gaps` (line 205, 208) -- camelCase.
10. **Skills:** `structuredData?.skills` (line 117) -- camelCase.

### Null/empty guards

- Domains: entire section omitted if neither domain present (line 157: `primaryDomain || secondaryDomain`).
- Fit card: omitted if neither `roleAnalysis` nor `summaryText` present (line 169).
- Achievements: omitted if empty array (line 182: `standoutAccomplishments.length > 0`).
- Experience: omitted if falsy (line 198: `structuredData?.applicableExperience`).
- Gaps: omitted if falsy (line 205: `structuredData?.gaps`).
- Skills: omitted if empty (line 212: `sortedSkills.length > 0`).

All section guards are correct. No crash risk from null/undefined data.

### Key skills sorting

`isKeySkill` function (line 121-124) matches the design handoff exactly: `keys.some((k) => skill === k || skill.toLowerCase().startsWith(k.toLowerCase()))`. Sort at line 126-128 pushes key skills to front. Correct.

### Capitalize function

`capitalize` (line 119) uppercases first letter, used for domain names. Matches design handoff `cap` function.
