# Navigation Map: Plato AI Review Tab

## Starting point
Login lands on the jobs list (/jobs).

## Path to candidate review
1. Login at http://app.lvh.me:5007/auth with rezu.may@wrkhq.com
2. Wait for dev workaround div with magic link, click it
3. Wait for redirect to jobs list
4. Click the job title "Software Engineer" in the jobs list
5. Wait for candidates view to load (column 1: hiring stages, column 2: candidate list)
6. Click a candidate name in column 2 to open their review

## Plato tab (new feature)
- **Location:** Column 3 sidebar navigation, after "Private notes"
- **How to reach:** From candidate review, look for "Plato" nav item with gradient chip icon in column 3 sidebar
- **Click:** "Plato" nav item to open the Plato tab in column 4

## Overview tab callout (new feature)
- **Location:** Column 4, Overview tab content area, at the top of the activity feed
- **How to reach:** From candidate review, the Overview tab is selected by default. The PlatoOverviewCallout card appears at the top of the feed.
- **Click:** Click the callout card to navigate to the Plato tab

## Feature flag gating
- When AI_APPLICANT_SUMMARY flag is ON: Plato nav item visible, callout visible
- When AI_APPLICANT_SUMMARY flag is OFF: Plato nav item hidden, callout hidden, /ai route still renders (unconditional Route)

## Test scenarios

### Scenario A: Flag ON, candidates with no AI summary
- Seed: paid-user-with-candidates.json
- Expected on Overview: Callout says "Ask Plato to review this candidate"
- Expected on Plato tab: Empty state with "Generate summary" button

### Scenario B: Flag OFF
- Seed: paid-user-no-flag.json
- Expected: No Plato nav item in sidebar, no callout on Overview tab

### Scenario C: Flag ON, AI summary generation
- Seed: paid-user-with-candidates.json
- From Plato tab empty state, click "Generate summary"
- Expected: Toast "Summary generation queued", state changes to generating skeleton
