# Angle: Emotion Styling Fidelity

## Files checked
- `PlatoMark.tsx` -- gradient chip, gray[900] glyph color
- `PlatoTab.tsx` -- all 53 styled components
- `PlatoOverviewCallout.tsx` -- all 6 styled components
- `JobApplicationSidebar.tsx` -- `platoNavLinkStyles`, `PlatoNavLabel`
- `NavItem.tsx` -- `linkStyles` (analog)
- `AiJobApplicationSummaryFeedItem.tsx` -- `SectionTitle` eyebrow (analog)

## Findings

No findings.

## Verification

### Accent gradient consistency
- `PlatoMark.tsx` line 98: `linear-gradient(120deg, #fbd7ff 10%, #ffdec1 90%)` -- correct, no dark mode variant (brand element).
- `PlatoTab.tsx` line 632: `FitBar` same gradient -- correct.
- `PlatoOverviewCallout.tsx` line 124: `Bar` same gradient -- correct.

### Glyph color
- `PlatoMark.tsx` line 80: `PlatoChip` passes `color={colors.gray[900]}` to `PlatoMark`. Always `#171717` regardless of mode. Correct per spec.

### Poly DS token usage
Verified throughout all styled components:
- `t.poly.color.loudText` for prominent text
- `t.poly.color.primaryText` for body text
- `t.poly.color.secondaryText` for muted text
- `t.poly.color.placeholderText` for hints/disclaimers
- `t.poly.color.border` / `t.poly.color.borderHover` for borders
- `t.poly.color.wellCanvas` for well backgrounds
- `t.poly.color.cardCanvas` for card backgrounds
- `t.poly.color.chipBorder` for skill chip borders
- `t.poly.color.subtleHover` / `t.poly.color.loudHover` for hover states
- `t.poly.radii.sm` / `t.poly.radii.md` for border radii

### Dark mode ternaries (used where no Poly token exists)
- `t.dark ? t.color.gray[800] : t.color.gray[200]` for header border (line 403) and connector (line 112) -- matches analog
- `t.dark ? t.color.gray[400] : t.color.gray[700]` for achievement icons (line 705) -- matches spec
- `t.dark ? t.color.gray[700] : t.color.gray[100]` for key skill chip fill (line 754) -- matches spec
- `t.dark ? t.color.gray[800] : t.color.gray[100]` for shimmer and zero-state icons -- sensible dark mode adaptation

### t.text.xs usage (KFP#1)
`Styled.Eyebrow` line 675: `${[t.text.xs]}` -- standalone in array syntax, NOT inside `font-size:`. Correct per Known Failure Pattern #1.

### Label convention
53/53 styled components in PlatoTab have `label: PlatoTab_*`. 6/6 in PlatoOverviewCallout have `label: PlatoOverviewCallout_*`. 1/1 in PlatoMark has `label: PlatoMark_Chip`. `platoNavLinkStyles` lacks a label, matching the analog `linkStyles`. `PlatoNavLabel` has `label: JobApplicationSidebar_PlatoNavLabel`.

### Pixel values match spec
- Headline: 23px / 1.28 lh / 600 weight / -0.02em tracking (line 561-567) -- matches
- Fit label: 13.5px / 600 weight (line 647) -- matches
- Fit body: 15px / 24px lh (line 658-660) -- matches
- Achievement text: 14px / 21px lh (line 717-718) -- matches
- Prose: 14.5px / 23px lh / 66ch max-width (line 726-731) -- matches
- Skill chips: 13px / 450 weight / 20px lh / 4px radius / 3px 10px padding (line 747-752) -- matches
- Footer text: 12px (line 789) -- matches
- Footer icon: 13px via `svg { height: 13px; width: 13px; }` (line 779-780) -- matches
