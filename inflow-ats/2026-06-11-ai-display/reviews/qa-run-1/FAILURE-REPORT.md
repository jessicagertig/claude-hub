# QA Run 1 -- Layer 1 Failure Report

**Layer:** diff-to-spec
**Round:** 1
**Agents dispatched:** 8
**Findings:** 5 HIGH

## Findings requiring fixes

### l1-001 -- Route for /ai renders unconditionally when flag is off
**File:** app/javascript/ats/src/views/jobApplications/JobApplicationContainer.tsx
**Lines:** 278-287
The /ai Route is unconditional inside the Switch. When AI_APPLICANT_SUMMARY is off, direct navigation to /ai still renders PlatoTab. The plan review removed the FeatureFlipper wrapper (React Router v5 constraint), but the conditional possiblePaths only prevents the redirector fallthrough -- it does not prevent the Route from matching.
**Fix:** Wrap the Route in a conditional: {isAiEnabled && <Route path={match.path}/ai ... />}

### l1-002 -- useAiJobApplicationSummary fires 404 on non-succeeded states
**File:** app/javascript/ats/src/views/jobApplications/PlatoTab.tsx
**Lines:** 38-40
useAiJobApplicationSummary is called unconditionally with aiSummary?.id || 0. In 5 of 6 states, this sends GET /ai_job_application_summaries/0 (404). The spec requires fetching only when status === "succeeded".
**Fix:** Extract the succeeded-state rendering into a child component that owns the hook call, OR add an enabled guard to the useQuery call.

### l1-003 -- capitalize() applied to domain names (not in spec)
**File:** app/javascript/ats/src/views/jobApplications/PlatoTab.tsx
**Lines:** 613, 654, 658
The spec says display primaryDomain.name and secondaryDomain.name as received. The implementation adds a capitalize() transform not specified in the spec.
**Fix:** Remove the capitalize() helper and its calls.

### l1-004 -- PlatoMark wrapper uses inline style instead of Emotion
**File:** app/javascript/ats/src/components/shared/PlatoMark.tsx
**Line:** 69
The spec requires Emotion styled components. The outer span uses inline style attribute.
**Fix:** Create a Styled.Wrapper Emotion styled component.

### l1-005 -- PlatoNavItem missing styled component label
**File:** app/javascript/ats/src/views/jobApplications/JobApplicationSidebar.tsx
**Lines:** 429-468
The spec requires every styled component to have a label: property. platoNavLinkStyles does not include one.
**Fix:** Add label: JobApplicationSidebar_PlatoNavItem; to the function.
