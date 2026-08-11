# Angle 13: Operational Concerns

## Verdict: PASS

## Network requests

1. **`useAiJobApplicationSummary` called with id=0 when no summary exists.** The hook is called unconditionally (hooks can't be conditional). When `aiSummary` is null, `aiSummary?.id || 0` passes 0 as the ID. This causes a 404 API call. React Query will retry up to 3 times by default, producing console noise. This is documented in the plan's Risks section and acknowledged as acceptable. The data will be `undefined`, and the UI guards on `structuredData` being null.

   This is not a new operational issue -- it's a known trade-off documented before implementation.

2. **No new API endpoints.** All queries and mutations use existing hooks. No new network surface area.

## Performance

1. **PlatoTab's 53 styled components** are all defined at module scope (outside the component function). They are created once at import time. No performance concern.

2. **Shimmer animations** use CSS-only keyframes (no JS animation loops). GPU-compositable (`transform`, `background-position`). No performance concern.

3. **Full summary fetch** is lazy -- only fires when the component mounts, not on every render. React Query caches the result.

## Error handling

1. **Generate mutation error** is caught and displayed via toast (lines 54-59). Error message extraction path matches the analog.

2. **Credit balance error** (`creditError`) is handled at line 44: `totalRemaining` falls to 0, which triggers the "Buy more credits" UI. No crash path.

3. **Null/undefined structured data** is handled throughout with optional chaining and section omission for falsy values.

## Bundle size

Three new component files. PlatoTab is ~1010 lines but contains no new dependencies -- all imports (`@emotion`, `react-query`, existing hooks/components) are already in the bundle. The `keyframes` import from `@emotion/react` is already used by `Button/index.js`. No bundle impact beyond the component code itself.

## Backward compatibility

Old `AiJobApplicationSummaryFeedItem` and `AiSummaryState` files remain in the codebase, just unused. Safe to revert by restoring the original imports in `JobApplicationActivity.tsx`.

## Findings

None.
