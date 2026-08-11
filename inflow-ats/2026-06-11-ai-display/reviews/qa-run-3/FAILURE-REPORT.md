# QA Run 3 -- Layer 2 Failure Report

**Layer:** code-correctness
**Round:** 1
**Agents dispatched:** 5
**Findings:** 2 HIGH, 5 MED

## HIGH findings requiring fixes

### l2-001 -- Header Regenerate and stale banner action missing zero-credits guard
**File:** app/javascript/ats/src/views/jobApplications/PlatoTab.tsx
**Lines:** 349 (header), 144 (stale banner)
When totalRemaining is 0, clicking Regenerate calls handleGenerate directly. Backend rejects. User sees generic error with no path to buy credits.
**Fix:** Add credit check. When totalRemaining is 0, show buy-credits pattern instead of Regenerate.

### l2-002 -- Infinite redirect loop on flag toggle
**File:** app/javascript/ats/src/views/jobApplications/JobApplicationContainer.tsx
**Lines:** 154-162
currentViewPath stays stale at "ai" when flag toggles off. redirector sends to /ai, which doesn't match, loops.
**Fix:** Add else branch in useEffect to reset currentViewPath to "overview" when currentView is not in possiblePaths.
