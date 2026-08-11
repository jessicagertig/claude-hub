# Pass 1 -- Angle 3: Succeeded Layout Data Consumption and Structured Data Access

## Fact Check

### Field paths (all camelCase)

The plan references these fields from structuredData:

| Field path in plan | Present in AiResumeStructuredData type? | Notes |
|---|---|---|
| `structuredData.roleAnalysis` | YES (line 26: `roleAnalysis?: string`) | Optional string |
| `structuredData.applicableExperience` | YES (line 27: `applicableExperience?: string`) | Optional string |
| `structuredData.gaps` | YES (line 28: `gaps?: string`) | Optional string |
| `structuredData.skills` | YES (line 22: `skills: string[]`) | Non-optional array |
| `structuredData.assessment.primaryDomain.name` | Via `assessment?: any` (line 31) | Relies on AiAssessment interface |
| `structuredData.assessment.secondaryDomain.name` | Via `assessment?: any` (line 31) | Relies on AiAssessment interface |
| `structuredData.assessment.keySkills` | Via `assessment?: any` (line 31) | Relies on AiAssessment interface |
| `structuredData.assessment.standoutAccomplishments` | Via `assessment?: any` (line 31) | Relies on AiAssessment interface |

All field paths use correct camelCase forms as confirmed by the TypeScript interface.

### Backend serializer

The `AiJobApplicationSummarySerializer` (app/serializers/api/v1/ai_job_application_summary_serializer.rb) serializes `structured_data` as a raw attribute. The structured data is a JSONB column -- the API layer's automatic snake-to-camel transform applies to the top-level keys AND nested keys. This means `role_analysis` -> `roleAnalysis`, `applicable_experience` -> `applicableExperience`, `primary_domain` -> `primaryDomain`, `key_skills` -> `keySkills`, `standout_accomplishments` -> `standoutAccomplishments`. All correct.

### Fallback behavior

Plan Task 4A.5: `structuredData?.roleAnalysis` falls back to `aiSummary.summaryText` if absent. MATCHES spec: "The `structuredData.roleAnalysis` text (falls back to `aiSummary.summaryText` if absent)."

### Section omission for empty/falsy data

- Notable achievements: Plan 4A.6 -- "Omit entire section if `structuredData?.assessment?.standoutAccomplishments` is empty or absent" -- MATCHES spec
- Relevant experience: Plan 4A.7 -- "Omit if `structuredData?.applicableExperience` is falsy" -- MATCHES spec
- Gaps: Plan 4A.8 -- "Omit if `structuredData?.gaps` is falsy" -- MATCHES spec
- Skills: Plan 4A.9 -- "Omit if `structuredData?.skills` is empty or absent" -- MATCHES spec
- Domain label: Plan 4A.4 -- "Skip entire section if neither domain is present" -- MATCHES spec

### Key skills sorting logic

Plan 4A.9: `isKeySkill` uses case-insensitive prefix match. References prototype at `ai-tab.jsx` line 246: `keys.some((k) => x === k || x.toLowerCase().startsWith(k.toLowerCase()))`. This sorting logic is not explicitly in the spec but is referenced from the prototype design. Reasonable implementation detail.

### Provenance timestamp

Plan 4A.1 uses `distanceInWords(aiSummary.createdAt)`. VERIFIED: `distanceInWords` at shared/lib/time.ts line 89 accepts ISO strings via `new Date(date)`, includes `{ addSuffix: true }` by default. The plan correctly warns against `timeAgoInWordsShort` (line 14) which expects Unix seconds.

### useAiJobApplicationSummary usage

Plan Task 4.3: hook call with `aiJobApplicationSummaryId: aiSummary?.id || 0` when no summary exists. VERIFIED: `useAiJobApplicationSummary` at shared/queryHooks/useAiJobApplicationSummary.ts lines 34-44 requires `aiJobApplicationSummaryId: number`. When id is 0, the GET request to `/job_applications/{id}/ai_job_application_summaries/0` will 404. The plan documents this and accepts it. The analog (`AiJobApplicationSummaryFeedItem`) always receives a non-null summary (line 16: Props require `aiJobApplicationSummary: AiJobApplicationSummary`), so the analog never hits this case.

## Completeness

All 10 sections of the succeeded layout from the spec are addressed:
1. Provenance line -- Task 4A.1
2. Stale banner -- Task 4A.2
3. Headline -- Task 4A.3
4. Domain label -- Task 4A.4
5. Fit for this role card -- Task 4A.5
6. Notable achievements -- Task 4A.6
7. Relevant experience -- Task 4A.7
8. Gaps to probe -- Task 4A.8
9. Skills -- Task 4A.9
10. Footer disclaimer -- Task 4A.11

Section margin spacing (Task 4A.10): "Each section block: margin-bottom 22px." -- Present in plan.

## Findings

No HIGH or MED findings.

### F1 [LOW] The 404 from useAiJobApplicationSummary with id=0 will produce console noise

**Where:** Plan Task 4.3
**What:** Plan acknowledges this. React Query defaults to 3 retries, so the console will show 3 failed network requests. The plan notes this in Risks section 1.
**Evidence:** useAiJobApplicationSummary.ts does not pass `retry: false` to `useQuery`.
**Fix:** Not required for v1, but implementer could consider adding `{ enabled: aiSummary?.id > 0 }` as a query option if the hook is extended, or pass `retry: 0` for this specific case.
