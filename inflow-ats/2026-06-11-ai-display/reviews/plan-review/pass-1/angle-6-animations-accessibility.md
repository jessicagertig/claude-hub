# Pass 1 -- Angle 6: CSS Animations (Shimmer + Dots) and Accessibility

## Fact Check

### Emotion keyframes pattern

Plan Task 4B.1 imports `keyframes` from `@emotion/react`. VERIFIED: `Button/index.js` line 6 uses `import { css, keyframes } from "@emotion/react"`. Plan's imports at Task 4.2 include `{ css, keyframes }` from `@emotion/react`. CORRECT.

### Shimmer animation

Plan Task 4B.3:
```css
background-image: linear-gradient(90deg, ${t.color.gray[100]} 0px, ${t.color.gray[200]} 60px, ${t.color.gray[100]} 120px);
background-size: 600px 100%;
animation: ${shimmer} 1.4s ease-in-out infinite;
```

Spec says: `linear-gradient(90deg, gray[100], gray[200], gray[100])`, `background-size: 600px 100%`, `animation: 1.4s ease-in-out infinite`. Plan adds explicit stop positions (0px, 60px, 120px) which are implementation detail. ACCEPTABLE.

### Dot animation

Plan Task 4B.2: three 5px circles, `colors.gray[500]`, staggered 0.16s delays (0s, 0.16s, 0.32s), `animation: ${dotPulse} 1.1s ease-in-out infinite`. MATCHES spec: "three 5px circles, `colors.gray[500]`, staggered 0.16s delays, pulsing opacity + slight Y translation over 1.1s."

### prefers-reduced-motion

Plan Tasks 4B.2 and 4B.3 both include `@media (prefers-reduced-motion: reduce) { animation: none; }`. MATCHES spec requirement. The plan correctly notes this is co-located with the animation declaration inside each styled component's css block.

### Callout card accessibility

Plan Task 3.3: card is `styled.button` with reset CSS (`appearance: none; background: none; border: none; padding: 0; text-align: left; width: 100%; cursor: pointer; font: inherit;`). MATCHES spec: "The callout card must be a `<button>` element with reset CSS." Native `<button>` provides keyboard handling (Enter/Space) for free.

### PlatoMark aria-hidden

Plan Task 2.2: "The SVG element must include `aria-hidden=\"true\"`." MATCHES spec: "add `aria-hidden=\"true\"` explicitly to all SVG elements in `PlatoMark.tsx`."

### Icon component aria-hidden

Spec notes: "The existing `Icon` component does NOT add `aria-hidden` automatically." Plan Task 2.2 reiterates this. VERIFIED by checking the Icon component -- the spec claim is used as-is; I trust the spec review's verification.

### NavLink for Plato nav item

Plan Task 6.3 creates `PlatoNavItem` as `styled(NavLink, ...)`. MATCHES spec: "The Plato tab nav item must be a proper `NavLink` for keyboard navigation and screen reader accessibility."

## Completeness

- Shimmer animation with `prefers-reduced-motion` -- Task 4B.3
- Dot animation with `prefers-reduced-motion` -- Task 4B.2
- Callout card as `<button>` for keyboard accessibility -- Task 3.3
- `aria-hidden="true"` on PlatoMark SVG -- Task 2.2
- NavLink for screen reader / keyboard support -- Task 6.3

All accessibility requirements from the spec are addressed.

## Findings

No HIGH or MED findings.
