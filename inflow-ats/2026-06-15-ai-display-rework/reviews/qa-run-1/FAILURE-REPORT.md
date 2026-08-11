# QA Run 1 -- Failure Report

## Layer reached: Layer 2 (Code Correctness Review), Round 1

## HIGH findings requiring fix

### PT-1: structuredData is null during regenerating status

**File:** `app/javascript/ats/src/views/jobApplications/PlatoTab.tsx`
**Line:** 49

**Problem:** The `structuredData` variable was gated on `statusValue === "current"` only. When `statusValue === "regenerating"` and `renderSucceeded()` was called, `structuredData` was null. The user would see a degraded summary view during regeneration -- missing skills, domains, gaps, achievements, applicable experience, and other structured data sections.

**Fix applied:** Extended the gate to include `"regenerating"`:
```
const structuredData = (statusValue === "current" || statusValue === "regenerating") ? fullSummary?.structuredData : null;
```

**Committed on branch:** `ai-display-rework-qa`

## MED findings collected (not blocking)

See `qa-run-1/layer-2-code-correctness/round-1/consolidated.json` for full list.
