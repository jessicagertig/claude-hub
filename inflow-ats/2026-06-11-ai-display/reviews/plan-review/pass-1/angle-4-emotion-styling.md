# Pass 1 -- Angle 4: Emotion Styling Fidelity

## Fact Check

### Theme tokens

Verified against `lightTheme.ts` and `darkTheme.ts`:

| Token | Light value | Dark value | Used in plan? |
|---|---|---|---|
| `poly.color.loudText` | `colors.black` (#000000) | `colors.gray[200]` (#E5E5E5) | YES |
| `poly.color.primaryText` | `colors.black` | `colors.gray[300]` (#D4D4D4) | YES |
| `poly.color.secondaryText` | `colors.gray[600]` (#525252) | `colors.gray[400]` (#A3A3A3) | YES |
| `poly.color.placeholderText` | `colors.gray[500]` (#737373) | `colors.gray[500]` | YES |
| `poly.color.border` | `colors.gray[200]` (#E5E5E5) | `colors.gray[800]` (#262626) | YES |
| `poly.color.borderHover` | `colors.gray[400]` (#A3A3A3) | `colors.gray[600]` (#525252) | YES |
| `poly.color.wellCanvas` | `colors.gray[100]` (#F5F5F5) | `colors.gray[900]` (#171717) | YES |
| `poly.color.cardCanvas` | `colors.white` (#FFFFFF) | `colors.gray[800]` (#262626) | YES |
| `poly.color.chipBorder` | `colors.gray[300]` (#D4D4D4) | `colors.gray[700]` (#404040) | YES |
| `poly.color.subtleHover` | `colors.gray[100]` | `colors.gray[800]` | YES (nav item) |
| `poly.color.loudHover` | `colors.gray[200]` | `colors.gray[700]` | YES (nav item) |

All tokens referenced in the plan exist in both themes.

### Radii

Verified against `shared/styles/theme.ts`: `radii: { xs: "4px", sm: "5px", md: "7px", lg: "13px" }`.

Plan references:
- `radii.sm` for nav item border-radius -- CORRECT (5px, matches `NavItem.tsx` line 58)
- `radii.md` for callout card -- CORRECT (7px)
- 9px radius for fit-for-role card -- No token exists for 9px. Plan uses raw value. Acceptable (no token maps to 9px).
- 4px radius for skill chips -- Matches `radii.xs`. Plan uses raw `4px`. Acceptable.

### Gray scale values

Verified against `colors.ts`: 50, 100, 200, 300, 400, 500, 600, 700, 800, 900. Plan claims no 150 exists in the shared colors file -- VERIFIED.

Plan states `ats/styles/theme.ts` has 150 in `baseColors` -- not verified (plan claims this but the shared `colors.ts` is the canonical reference). No plan code uses gray[150].

### Accent gradient

Plan: `linear-gradient(120deg, #FBD7FF 10%, #FFDEC1 90%)` -- same in both light and dark mode. MATCHES spec. Not a theme-derived value.

### Glyph color in PlatoChip

Plan Task 2.3: `colors.gray[900]` (#171717) regardless of dark mode. MATCHES spec and VERIFIED against colors.ts.

### t.text.xs usage (Known Failure Pattern #1)

Plan Task 4A.10: "Spread `${[t.text.xs]}` standalone -- do NOT put it inside `font-size:`." CORRECT handling. The array spread pattern `${[t.text.xs]}` is used in the codebase (e.g., `JobApplicationSidebar.tsx` line 315: `${[t.h(4), t.ml(1), t.mb("px"), t.rounded.xs]}`).

### Eyebrow style

Plan Task 4A.10 specifies: `text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600; color: ${t.poly.color.secondaryText}; margin-bottom: 8px` with `${[t.text.xs]}` standalone.

Spec says: "Implement as a styled component: `text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600; color: ${theme.poly.color.secondaryText}`" with `t.text.xs` standalone.

The plan upgrades from the analog's `t.dark ? t.color.gray[400] : t.color.gray[500]` to `t.poly.color.secondaryText` (gray[600] light / gray[400] dark). MATCHES spec intention.

### Dark mode for skill chips

Plan Task 4A.9: Key skill fill: `${t.dark ? t.color.gray[700] : t.color.gray[100]}`. MATCHES spec: "requires `t.dark` ternary -- no `chipCanvas` poly token exists". VERIFIED: `chipBorder` exists in poly tokens but there is no `chipCanvas` token.

### linkStyles copy

Plan Task 6.3 reproduces linkStyles. Comparing with NavItem.tsx lines 56-95:
- Height 40px -- MATCH (NavItem line 57)
- `radii.sm` -- MATCH (NavItem line 58 uses `props.theme.poly.radii.sm`)
- Margins, padding -- MATCH
- `> svg` opacity transitions -- MATCH
- `.active` state with `subtleHover` -- MATCH
- `${breakpoint.sm}` responsive gate -- MATCH
- Hover with `loudHover` -- MATCH
- `> svg` stroke on hover -- MATCH

The plan's reproduction is accurate.

### label: convention

Plan specifies `label: PlatoTab_*`, `label: PlatoOverviewCallout_*` format. MATCHES codebase convention (e.g., `label: JobApplicationSidebar_CandidateProfile`, `label: AiSummaryState_Component`).

## Completeness

All styled components referenced in the spec have corresponding plan tasks with dark mode variants. The accent gradient is mode-invariant. All poly tokens used exist in both theme files.

## Findings

No HIGH or MED findings.

### F1 [LOW] Plan uses raw `border-radius: 9px` for fit-for-role card when `radii.md` is 7px

**Where:** Plan Task 4A.5
**What:** Spec says "9px radius" for the fit-for-role card. No theme token matches 9px. Plan uses raw value, which is correct -- this is a spec design decision, not a missed token.
**Evidence:** `theme.ts` radii: xs=4px, sm=5px, md=7px, lg=13px.
**Fix:** None needed. Raw value is appropriate when no token exists.
