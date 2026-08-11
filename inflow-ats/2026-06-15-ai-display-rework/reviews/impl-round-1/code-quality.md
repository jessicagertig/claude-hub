# code-quality

## Rule compliance

### Rule 2 (Theme colors) -- PASS
All theme colors in PlatoLoadingState verified against theme.ts and existing codebase usage. `t.color.gray[100-600]`, `t.color.black`, `t.text.h5`, `t.text.sm`, `t.text.xs`, `t.text.medium`, `t.spacing[1-3]`, `t.px(6)`, `t.py(10)`, `t.rounded.md`, `t.mt()`, `t.mb()` -- all exist.

### Rule 7 (snake_case/camelCase) -- PASS
`AiJobApplicationSummaryStatus` fields: `id`, `aiJobApplicationSummaryId`, `status`, `scorePercentage`, `headline`, `integratedRoleAnalysis`, `updatedAt` -- all camelCase. Status enum values (`none`, `current`, `regenerating`) have no underscores so the exception doesn't apply, but they match correctly.

### Rule 9 (never set undefined) -- PASS
No new `|| undefined` patterns introduced. Pre-existing `|| undefined` at PlatoTabEmptyState lines 82-83 not touched by this diff.

### Rule 10 (no fabricated fallbacks) -- LOW (pre-existing)
`JobApplicationActivity.tsx` lines 401-403 use `|| ""` and `|| 0` fallbacks. These are documented as pre-existing known issues in the review instructions. Not counting.

### Rule 11 (no nullish coalescing) -- PASS
No `??` usage in new code. PlatoLoadingState uses `!= null` ternary instead.

### Rule 12 (check update return values) -- LOW
See update-columns-to-update-migration.md. Happy-path `update` calls don't check return values. Pre-existing pattern from `update_columns`; validation always passes. Not blocking.

### Rule 13 (no useMemo for minor computation) -- PASS
No `useMemo` usage in new code.

### Styling convention -- PASS (with LOW note)
All styled components use `const t: any = props.theme;` pattern. Labels present on most styled components.

## Findings

### LOW: Missing labels on two styled components in PlatoLoadingState

`Styled.Circle` (line 162) and `Styled.Spinner` (line 173) in `PlatoLoadingState.tsx` do not have `label:` properties in their CSS. The cursor rules convention says "Always include a label for debugging." These are minor visual elements (empty circle and spinner animation) but should have labels for consistency.

Files: `app/javascript/ats/src/views/jobApplications/Plato/PlatoLoadingState.tsx` lines 162, 173
