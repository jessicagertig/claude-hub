# Angle 6: CSS Animations and Accessibility

## Findings

### No HIGH findings

**Shimmer keyframes -- correct:**
- Defined at PlatoTab.tsx lines 374-377 using Emotion `keyframes`
- `background-position` sweep from -600px to 600px -- matches spec
- Applied to `Styled.ShimmerBar` (lines 836-854): gradient with `gray[100]`/`gray[200]`, `background-size: 600px 100%`, `animation: ${shimmer} 1.4s ease-in-out infinite` -- matches spec
- Dark mode adaptation: shimmer bars use `t.dark` ternaries for `gray[800]`/`gray[700]` -- good
- `Styled.ShimmerBlock` (lines 856-877) and `Styled.ShimmerChip` (lines 886-905) also use the shimmer animation with the same dark mode adaptation

**Dot pulse keyframes -- correct:**
- Defined at lines 379-382: `0%, 60%, 100% { opacity: 0.25; transform: translateY(0); } 30% { opacity: 1; transform: translateY(-2px); }`
- Three dots at lines 241-244: staggered delays 0s, 0.16s, 0.32s via `style={{ animationDelay: "..." }}`
- Dots are 5px circles, `colors.gray[500]` -- matches spec

**prefers-reduced-motion -- correct:**
Each animated styled component includes the media query:
- `Styled.Dot` line 821: `@media (prefers-reduced-motion: reduce) { animation: none; }`
- `Styled.ShimmerBar` line 850: same
- `Styled.ShimmerBlock` line 872: same
- `Styled.ShimmerChip` line 900: same

This is the pattern the spec establishes as the codebase convention (first usage).

**Callout card button semantics -- correct:**
`Styled.Card` at PlatoOverviewCallout.tsx line 76 is `styled.button(...)`. It includes the full button reset CSS (lines 80-87): `appearance: none; background: none; border: none; padding: 0; text-align: left; width: 100%; cursor: pointer; font: inherit;`. Card styling is applied on top. This provides keyboard navigation (Enter/Space) for free, matching the spec's accessibility requirement.

**aria-hidden on PlatoMark SVG -- correct:**
PlatoMark.tsx line 65: `<svg {...base} aria-hidden="true">`. This is explicitly present as the spec requires (the `Icon` component does NOT add this automatically).

**Feather icons via `<Icon>` -- consistent with codebase:**
Icons rendered via `<Icon name="...">` in the new components inherit the existing behavior (no explicit `aria-hidden`). The spec notes this is a pre-existing gap and fixing the `Icon` component is out of scope.

**NavLink for Plato nav item -- correct:**
`PlatoNavItem` is `styled(NavLink, ...)` (JobApplicationSidebar.tsx line 470), providing proper screen reader and keyboard support with `aria-current` on the active route.

**Shimmer skeleton layout -- matches prototype:**
- Two title bars (92%/22px, 70%/22px)
- Four body bars (100%/97%/99%/58%, 13px each)
- One block (100%/84px/8px radius)
- Six chip placeholders ([64,52,78,46,70,58]px, 26px height)
All match the spec (Task 4B.3) and the design handoff prototype.
