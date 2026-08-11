# Angle: CSS Animations and Accessibility

## Files checked
- `PlatoTab.tsx` -- keyframes definitions lines 375-383, shimmer bars, dots, `prefers-reduced-motion`
- `PlatoOverviewCallout.tsx` -- card as `<button>` element
- `PlatoMark.tsx` -- SVG `aria-hidden`

## Findings

No findings.

## Verification

### Keyframes
- `shimmer` (lines 375-378): sweeps `background-position` from -600px to 600px. Matches spec.
- `dotPulse` (lines 380-383): opacity 0.25 -> 1 -> 0.25 with Y translation. Animation: 1.1s ease-in-out infinite. Matches spec.

### Shimmer bars
`Styled.ShimmerBar` (lines 841-859): `background-image: linear-gradient(90deg, ...)`, `background-size: 600px 100%`, `animation: ${shimmer} 1.4s ease-in-out infinite`. Dark mode uses `gray[800]`/`gray[700]` instead of `gray[100]`/`gray[200]`. Correct.

Layout matches prototype:
- 92% / 22px / mb 10 -- correct (line 250)
- 70% / 22px / mb 20 -- correct (line 251)
- 100%, 97%, 99%, 58% / 13px / mb 9 -- correct (lines 252-255)
- Block: 100% / 84px / radius 8 / margin 16 0 22 -- correct (line 256, Styled.ShimmerBlock)
- Chip row: 6 chips with widths [64, 52, 78, 46, 70, 58] / 26px height / radius 4 -- correct (lines 258-260)

### Dots
Three `Styled.Dot` elements with staggered delays: 0s, 0.16s, 0.32s (lines 243-245). Dots: 5px circles, `gray[500]` background. Correct.

### prefers-reduced-motion
Present on all 4 animated styled components:
- `Styled.Dot` line 826: `@media (prefers-reduced-motion: reduce) { animation: none; }`
- `Styled.ShimmerBar` line 855: same
- `Styled.ShimmerBlock` line 878: same
- `Styled.ShimmerChip` line 906: same

### Callout keyboard accessibility
`Styled.Card` is `styled.button` (line 76) with full button reset CSS (lines 80-87: `appearance: none; background: none; border: none; padding: 0; text-align: left; width: 100%; cursor: pointer; font: inherit;`). Native `<button>` provides Enter/Space activation and keyboard focus for free. Correct per spec.

### aria-hidden on SVG
`PlatoMark.tsx` line 64: `<svg {...base} aria-hidden="true">`. Correct per spec.

### PlatoNavItem accessibility
`PlatoNavItem` is `styled(NavLink)` which renders an `<a>` element -- proper keyboard navigation and `aria-current` support. Correct.
