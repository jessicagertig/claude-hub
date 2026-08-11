# Spec Compliance — Round 1

## Findings

- F1 [HIGH] Missing controller spec — Spec section "Test requirements > New specs" explicitly requires a controller spec for `all_stages`. None was created. (Same as test-coverage F1.)

All other spec requirements verified:
- Route: `post :all_stages` in collection block — ✓
- Controller action: authorize, find job, pluck all IDs, call interactor, render response — ✓
- Interactor: `rescore_requested` skips `:current` filter, `kind` in payload — ✓
- Job branching: link and mailer dispatch on `kind` — ✓
- New mailer: correct structure, templates, no `hiring_stage_id` — ✓
- Serializer: both attributes added with delegation method — ✓
- Mutation hook: correct params, endpoint, query invalidation — ✓
- All modals: correct per spec (branching, props, routes, patterns) — ✓
- CTA cards: V1 and V2 built, V1 rendered — ✓
- Sidebar: placement, flex column, individual props — ✓
- Variable renames: `rescore`, `candidatesToScoreCount`, `rescoreRequested`, `handleOnClickRunPlato` — ✓
- Route fixes: `/setup/description`, `/hire/settings/plato-ai`, `/jobs/:id/setup/ai` — ✓
- Link component: `styled(Link)` from `react-router-dom` for inline links — ✓
