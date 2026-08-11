# Pass 1 -- Angle 7: TypeScript Type Safety -- AiAssessment Interface

## Fact Check

### Current type

VERIFIED: `aiJobApplicationSummary.ts` line 31: `assessment?: any;` in `AiResumeStructuredData`.

### Proposed AiAssessment interface

Plan Task 1.1:
```typescript
export interface AiAssessment {
  primaryDomain: { name: string; reasoning: string } | null;
  secondaryDomain: { name: string; reasoning: string } | null;
  tertiaryDomain: { name: string | null; reasoning: string } | null;
  keySkills: string[];
  standoutAccomplishments: string[];
  careerNarrative?: string;
  experienceClassifications?: any[];
}
```

Spec proposes the same interface. MATCHES.

### Backend serializer

The `AiJobApplicationSummarySerializer` just passes through `structured_data` as a raw JSONB attribute. The structured data is populated by the AI pipeline (from `~/claude-hub/inflow-ats/2026-06-08-ai-scoring/`). The field names in the JSONB are stored in snake_case and the API layer auto-transforms to camelCase.

The serializer does not filter or reshape the `structured_data` -- it's a direct pass-through. So the TypeScript interface must match whatever the AI pipeline stores. The plan states `tertiaryDomain` is "not consumed by the Plato tab UI but is always present in the backend response" and includes it for completeness. This is a safe defensive addition.

### Field name verification

Backend snake_case -> Frontend camelCase:
- `primary_domain` -> `primaryDomain` CORRECT
- `secondary_domain` -> `secondaryDomain` CORRECT
- `tertiary_domain` -> `tertiaryDomain` CORRECT
- `key_skills` -> `keySkills` CORRECT
- `standout_accomplishments` -> `standoutAccomplishments` CORRECT
- `career_narrative` -> `careerNarrative` CORRECT
- `experience_classifications` -> `experienceClassifications` CORRECT

### Existing code compatibility

Plan Task 1.3: "existing code that accesses `assessment` as `any` (in `AiJobApplicationSummaryFeedItem.tsx`) still compiles -- it does not access `assessment` at all, so no breakage."

VERIFIED: `grep -rn "assessment" AiJobApplicationSummaryFeedItem.tsx` returned no results. The existing feed item component does not access the `assessment` field. Changing from `any` to `AiAssessment` is non-breaking.

### Type change

Plan Task 1.2: Change `assessment?: any` to `assessment?: AiAssessment`. The `?` (optional) is preserved, meaning `assessment` can still be undefined. This is correct since it's a JSONB sub-field that may not be present in older records.

## Completeness

- AiAssessment interface defined -- Task 1.1
- AiResumeStructuredData updated -- Task 1.2
- Backward compatibility verified -- Task 1.3
- All fields consumed by PlatoTab are in the interface -- COMPLETE

## Findings

No HIGH or MED findings.
