# AI Display — Session Handoff

## What happened

Built and placed Plato UI components from claude.ai/design exports into the inflow-ats worktree. Each component was audited against codebase conventions and fixed before placement.

## Worktree & branches

- **Worktree**: `/Users/jessica/wrk/wrk-corp/inflow-ats.ai-display`
- **Branch**: `ai-display` (based on `spike/scoring-display-prompt`)
- **Main worktree**: `/Users/jessica/wrk/wrk-corp/inflow-ats` on `feature-ai-summaries-integrating-scoring-v3` (backend work)
- **Working tree is clean** — everything committed

## Cherry-pick plan

Create v4 branch from scoring-v3, cherry-pick all ai-display frontend commits:

```bash
cd /Users/jessica/wrk/wrk-corp/inflow-ats
git checkout -b feature-ai-summaries-integrating-scoring-v4
git cherry-pick 9150765c2^..c02e88f18
```

11 commits to cherry-pick (in order):
```
9150765c2 Add Plato AI review tab with sidebar navigation and overview callout
5966ce409 Fix QA Layer 1 findings: conditional route, lazy fetch, remove capitalize, Emotion wrapper, label
20353afcc Fix lazy fetch: only call useAiJobApplicationSummary when status is succeeded
4ce718fe6 Fix zero-credits guard on Regenerate and redirect loop on flag toggle
4b2446956 Revert route gating to static possiblePaths, fix stale banner navigation
9aef60e21 Fix connector tick visibility on PlatoOverviewCallout
451169723 Fix dark mode: use theme-aware color for PlatoMark icon in Fit card header
add603e76 Fix credit loading race: show generate button while credits load
35a461232 Remove fabricated || 0 fallback from useAiJobApplicationSummary call
2db3b5d9e Add Plato UI components, refactor empty states, replace overview callout
c02e88f18 Add rule 10: never fabricate fallback values for absent data
```

Expect conflicts in `config/routes.rb` and possibly `PlatoTab.tsx` / `JobApplicationActivity.tsx` if scoring-v3 touched those files.

## Components created/modified

### New files (in worktree)

| File | Location | Purpose |
|------|----------|---------|
| `Accordion.tsx` | `components/shared/` | Generic 3-level collapsible (Accordion → AccordionSection → AccordionRow). Uses `react-spring`, `ResizeObserver`, `<Icon name="chevron-down">` with CSS rotation |
| `ScoringDetail.tsx` | `views/jobApplications/Plato/` | Domain component composing Accordion for scoring criteria display. Types: `CriterionScore`, `CriterionTier`, `CriterionResult` |
| `FitIndicator.tsx` | `views/jobApplications/Plato/` | `FitStars` (5 gradient sparkles) + `FitHarvey` (3-tier Harvey ball). Band model: `FIT_BANDS`, `fitBand()`, `fitTier()`. Uses module counter for SVG IDs (React 16, no `useId`) |
| `JobApplicationTabEmptyState.tsx` | `views/jobApplications/Plato/` | Purely presentational empty state. Props: `icon`, `title`, `message`, `buttonLabel`, `buttonIcon`, `onClick`, `footnote`. No status resolution — caller passes everything |
| `PlatoTabEmptyState.tsx` | `views/jobApplications/Plato/` | Plato-specific wrapper. Owns status configs (ready/processing/failed/noCredits). Routes `noResume` → `DragAndDropResumeUploader`. Resolves `{link}` and `{creditsRemaining}` tokens |
| `PlatoOverviewCallout.tsx` | `views/jobApplications/Plato/` | Overview tab entry point. Props: `summaryStatus`, `hasResume` (not the whole jobApplication). Derives `PlatoCalloutStatus` internally. Returns null for `succeeded` (separate component handles that). Bar variant + small variant |

### Modified files

| File | Changes |
|------|---------|
| `PlatoTab.tsx` | All 32 `t.poly.*` → `t.dark` ternaries. Header aligned to sibling tabs (`t.text.h2`). Removed `Styled.BodyInner` |
| `PlatoMark.tsx` | Merged new Emotion styled structure with existing API. Kept `color` prop on PlatoMark, `radius` prop on PlatoChip |
| `DragAndDropResumeUploader.tsx` | Styles updated to match `JobApplicationTabEmptyState` (h2→h5, text sizes, dark mode border/bg, icon wrapper) |
| `JobApplicationActivity.tsx` | Import updated to `Plato/PlatoOverviewCallout`. Callout moved inside `Styled.Activities` after `jobApplicationReceivedEvent()`. Props changed to `summaryStatus`/`hasResume` |
| `PlatoOverviewCallout.tsx` (old, parent level) | **Blanked** — replaced by `Plato/PlatoOverviewCallout.tsx` |
| `config/routes.rb` | Added `get 'jobs/:job_id/stages/:stage_id/applicants/:job_application_id/ai', to: 'pages#root'` |
| `cursor_rules/core_critical_rules.md` | Added rule 10: never fabricate fallback values. Renumbered 10→11, 11→12 |

## Codebase conventions enforced

These were all issues from claude.ai/design that were fixed:

- `const t: any = props.theme` (not `const t = props.theme`)
- `||` instead of `??` (build config doesn't support nullish coalescing)
- Optional chaining `?.` IS supported (React 16.14 + Babel)
- `React.useId()` NOT available (React 16.14) — replaced with module counter
- No `t.poly.*` tokens in ATS app — use `t.dark ? lightValue : darkValue`
- `t.text.sm`, `t.rounded.md` etc are complete CSS declarations, not raw values
- Separate styled components for visual variants, not conditional props
- Never fabricate fallback values (`|| 0`, `|| ""`) for absent data
- `react-spring` (not `@react-spring/web`) — old package name, v9.2.1
- `const t: any = useTheme()` (not `useTheme() as any`)
- `let Styled: any; Styled = {};` pattern (not `const Styled: any = {}`)

## Pending / not yet done

- **PlatoTab hardcoded pixel font sizes** (17px, 23px etc) — Jessica will handle, may allow 13px/15px but wants even numbers otherwise
- **KebabButton in PlatoTab** — dead element with no click handler, not addressed
- **PlatoOverviewCallout for succeeded state** — separate component, not built yet. Current callout returns null for succeeded
- **DragAndDropResumeUploader `isDragActive` prop** — custom prop forwarded to DOM, will produce React console warning. Should use `data-drag-active` instead
- **`InlineLink` components** — native `<a>` tags, noted for future swap to router `<Link>`
- **`noCredits` inline link** — `href: "#"` placeholder, needs real AI billing route
- **Integration with scoring data** — UI needs updated statuses and scoring results from backend (scoring-v3 branch) to display properly

## Key failure patterns discovered (added to pipeline CLAUDE.md)

- #11: Analog replication must copy behavioral props (loading/disabled), not just layout
- #12: Styled components — use separate components for visual variants, not conditional props
- #13: Never fabricate fallback values for absent data
- #14: Analog structural matching — compare signatures, not just layers
