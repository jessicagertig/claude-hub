# Plain English Summary

## What the feature does

Moves the AI candidate summary ("Plato") out of the Overview tab's activity feed and into its own dedicated sidebar tab. Currently, the AI summary is an inline card in the activity feed (via `AiJobApplicationSummaryFeedItem` and `AiSummaryState`). After this change:

1. A new "Plato" item appears in the candidate sidebar navigation (with a custom gradient chip icon instead of a Feather icon)
2. Clicking it opens a full-page Plato tab with a rich layout showing the AI assessment: headline, domain expertise, role-fit analysis, notable achievements, relevant experience, gaps, and skills
3. The Overview tab gets a compact callout card that links into the Plato tab
4. The old inline display components are no longer rendered (but not deleted, for safe revert)

The Plato tab has 6 states: succeeded (rich layout), generating (skeleton + dots), textract processing (waiting), failed (retry), empty with resume (generate button), empty without resume (no action). The callout card mirrors these 6 states with compact copy + CTA labels.

## What changes

- **3 new files:** PlatoMark (SVG icon + gradient chip), PlatoTab (the full tab page), PlatoOverviewCallout (the compact card)
- **4 modified files:** JobApplicationContainer (add /ai route), JobApplicationSidebar (add Plato nav item), JobApplicationActivity (swap inline display for callout), aiJobApplicationSummary.ts (narrow assessment type from `any` to `AiAssessment`)

## What does NOT change

- No backend/API/model changes. All data already flows through existing serializers.
- No new hooks, queries, or mutations. Reuses `useGenerateAiSummary`, `useAiJobApplicationSummary`, `useOrganizationAiCreditBalance`.
- No new WebSocket handling. Existing `AI_SUMMARY_COMPLETE` handler already invalidates the right queries.
- The old components (`AiJobApplicationSummaryFeedItem`, `AiSummaryState`) are not deleted.

# Blast Radius Analysis

## Direct impact

| Area | Risk | Notes |
|---|---|---|
| Candidate review sidebar nav | Medium | Custom nav item must match existing NavItem styling exactly |
| Candidate review Overview tab | Medium | Activity feed loses inline AI display, gains callout card |
| Candidate review new /ai route | Low | New route, no existing behavior disrupted |
| TypeScript types | Low | Narrowing `any` to `AiAssessment` is non-breaking |
| Feature flag gating | Low | Same flag (`AI_APPLICANT_SUMMARY`), same gates |

## Indirect impact

| Area | Risk | Notes |
|---|---|---|
| URL routing / possiblePaths | Low | Adding "ai" to possiblePaths affects candidate-switch behavior |
| Deep links / bookmarks | Low | `/ai` is a new path; existing paths unchanged |
| Dark mode | Medium | New components need full dark mode coverage |
| Accessibility | Low | Callout card needs semantic button; nav item needs NavLink |
| Real-time updates | Low | No changes to WebSocket handling |

## What could go wrong

1. Custom PlatoNavItem doesn't match NavItem styling -- visual inconsistency
2. State machine condition ordering causes wrong state to render
3. Structured data field access uses wrong camelCase key -- runtime crash or missing data
4. Timestamp formatting -- `timeAgoInWordsShort` expects Unix seconds, `createdAt` is an ISO string
5. Dark mode coverage gaps in new styled components
6. Feature-flag-off redirect for /ai route not handled (blank pane)
