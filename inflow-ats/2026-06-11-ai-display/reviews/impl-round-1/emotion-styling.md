# Angle 4: Emotion Styling Fidelity

## Findings

### No HIGH findings

**Known Failure Pattern #1 (t.text.xs standalone):** Grep for `font-size:.*t\.text\.` across all changed files returns zero matches. The `Styled.Eyebrow` at PlatoTab.tsx line 670 uses `${[t.text.xs]}` standalone -- correct. This matches the spec and avoids the double `font-size:` bug.

**label: convention:** Every `Styled.*` definition in all three new files has a `label:` property. Verified counts:
- PlatoMark.tsx: 1 styled component, 1 label (`PlatoMark_Chip`)
- PlatoOverviewCallout.tsx: 6 styled components, 6 labels (all `PlatoOverviewCallout_*`)
- PlatoTab.tsx: 53 label occurrences across all styled components (all `PlatoTab_*`)

**Poly DS tokens used correctly:**
- `t.poly.color.loudText`, `t.poly.color.primaryText`, `t.poly.color.secondaryText`, `t.poly.color.placeholderText` -- used throughout
- `t.poly.color.border`, `t.poly.color.borderHover` -- used for borders
- `t.poly.color.wellCanvas`, `t.poly.color.cardCanvas`, `t.poly.color.chipBorder` -- used correctly
- `t.poly.color.subtleHover`, `t.poly.color.loudHover` -- used in nav item styles
- `t.poly.radii.sm`, `t.poly.radii.md` -- used correctly

**Dark mode -- correct:**
- Accent gradient `linear-gradient(120deg, #FBD7FF 10%, #FFDEC1 90%)` is mode-invariant (PlatoMark.tsx line 99, PlatoOverviewCallout.tsx line 124, PlatoTab.tsx lines 627, 840-844)
- Glyph color inside PlatoChip: `colors.gray[900]` always (PlatoMark.tsx line 81)
- Shimmer bars use `t.dark` ternaries for gray scale (lines 842-844) -- correct dark mode adaptation
- Skill chips use `t.dark` ternary for key-skill fill (line 749): `t.dark ? t.color.gray[700] : t.color.gray[100]` -- matches spec
- Icon colors use `t.dark` ternary where Poly DS tokens don't cover: achievement icons (line 700), connector tick (line 112)

**Styled component namespace pattern:** All files use `let Styled: any; Styled = {};` followed by `Styled.Name = styled.element(...)` -- correct.

**Pixel values match spec:**
- Headline: 23px/1.28/600/-0.02em (line 556-559) -- matches
- Fit label: 13.5px/600 (line 642-643) -- matches
- Fit body: 15px/24px (line 653-654) -- matches
- Achievement text: 14px/21px (line 712-713) -- matches
- Prose: 14.5px/23px/66ch (line 720-726) -- matches
- Skill chip: 13px/450/20px/4px radius/3px 10px padding (lines 742-747) -- matches
- Footer: 12px/placeholderText (line 784-785) -- matches

**Header bar structure:** Follows `Styled.Title` from JobApplicationActivity.tsx -- `pt(4), pb(4), px(4)`, border-bottom, flex row, space-between (lines 397-407). Correct.

**Connector tick on callout card:** `::after` pseudo-element (PlatoOverviewCallout.tsx lines 104-113) -- 4px width, `t.spacing[6]` height, `t.dark` gray ternary. Matches the `Styled.Event` analog pattern.
