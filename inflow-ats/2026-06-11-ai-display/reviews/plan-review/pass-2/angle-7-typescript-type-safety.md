# Pass 2 -- Angle 7: TypeScript Type Safety

## Pass 1 Verification

No findings from Pass 1. All field names and types verified.

## Fresh Scrutiny

### AiAssessment domain types: `| null` vs optional

The interface uses `primaryDomain: { name: string; reasoning: string } | null` (required but nullable) vs `careerNarrative?: string` (optional). This means `primaryDomain` must exist in the JSON but can be `null`, while `careerNarrative` may be absent entirely. This distinction matters for the UI:
- `structuredData?.assessment?.primaryDomain?.name` -- the `?.` after `primaryDomain` handles the null case. CORRECT.
- `structuredData?.assessment?.careerNarrative` -- the `?.` after `assessment` handles the optional case. CORRECT.

The plan's usage at Task 4A.4 (`structuredData?.assessment?.primaryDomain?.name`) uses optional chaining throughout, which handles both null and undefined. SAFE.

### experienceClassifications typed as any[]

The interface uses `experienceClassifications?: any[]`. This is typed as `any[]` because the structure of experience classifications is complex and not consumed by the Plato tab UI. The spec says "experienceClassifications is not consumed by the Plato tab UI." Using `any[]` follows cursor_rules/frontend/_base.md rule 4 ("use `any` pragmatically for legacy objects"). ACCEPTABLE.

### Non-breaking type refinement claim

Plan Task 1.3 claims the change from `any` to `AiAssessment` is non-breaking because `AiJobApplicationSummaryFeedItem` does not access `assessment`. VERIFIED in Pass 1: grep found no `assessment` references in that file. The change from `any` to a specific interface is always safe for consumers that don't access the field. For consumers that DO access it as `any`, TypeScript will still allow most operations because the interface is more specific than `any` -- but no existing consumers access it. CONFIRMED non-breaking.

## Findings

No HIGH or MED findings.
