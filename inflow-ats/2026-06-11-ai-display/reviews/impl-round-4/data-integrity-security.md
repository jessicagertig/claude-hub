# Angle: Data Integrity and Security (Always-On)

## Files checked
- All 7 implementation files

## Findings

No findings.

## Verification

### No backend changes
This is a frontend-only feature. No controllers, serializers, models, routes, or migrations are modified. No new API endpoints. No authorization changes.

### Feature flag gating
All 3 new UI surfaces are gated behind `AI_APPLICANT_SUMMARY`:
1. Sidebar nav item: wrapped in `<FeatureFlipper feature="AI_APPLICANT_SUMMARY">`
2. Overview callout: wrapped in `<FeatureFlipper feature="AI_APPLICANT_SUMMARY">`
3. Tab route: conditional `possiblePaths` prevents access when flag is off; `redirector()` redirects to `/overview`

### No mutation from callout
The callout card navigates only (`onClick={onOpen}`). The "Generate" CTA label is display-only. No credit-consuming mutation can be triggered from the Overview tab.

### Generate mutation authorization
All generate actions use `useGenerateAiSummary` which calls the existing backend endpoint. The backend `ValidateAiSummaryGeneration` interactor handles credit checking and authorization. No new authorization surface.

### No sensitive data exposure
The feature displays data already accessible via the existing `AiJobApplicationSummarySerializer`. No new data paths. The `assessment` type narrowing is cosmetic (TypeScript-only, no runtime effect).

### WebSocket handling
No new WebSocket handlers. The existing `AI_SUMMARY_COMPLETE` handler at `WebsocketGlobalChannelHandler.tsx` invalidates the relevant queries. The new components consume these queries and re-render automatically.
