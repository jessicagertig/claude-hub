# Pass 2 -- Angle 6: CSS Animations and Accessibility

## Pass 1 Verification

No findings from Pass 1.

## Fresh Scrutiny

### Callout card as button -- focus styling

The plan (Task 3.3) creates the card as `styled.button` with reset CSS and card styling on top. The plan specifies `transition: border-color 0.2s ease` for hover. But there is no `:focus` or `:focus-visible` style mentioned. A `<button>` element will receive the browser's default focus outline, but the button reset CSS (`appearance: none; border: none;`) may interfere with the default focus indicator on some browsers.

The spec mentions "A native `<button>` gets keyboard handling for free (Enter and Space activation) without needing manual `onKeyDown` handling." But does not specify focus styling. The codebase has no existing card-as-button pattern to follow. The browser default focus ring is acceptable for v1. Not a finding (adding a `:focus-visible` style would be an improvement, not a spec requirement).

### Shimmer bar layout from prototype

Plan Task 4B.3 specifies exact widths for shimmer bars (92%, 70%, 100%, 97%, 99%, 58%) and heights (22px, 22px, 13px, 84px block, chip row). These come from "the prototype at `ai-tab.jsx`" which is not a spec requirement but a reasonable implementation detail. The spec says "shimmer bars using a CSS `@keyframes` animation" without specifying exact layout. The plan's detail here is helpful for implementers. ACCEPTABLE.

### dot animation keyframe

Plan Task 4B.1:
```
const dotPulse = keyframes`
  0%, 60%, 100% { opacity: 0.25; transform: translateY(0); }
  30% { opacity: 1; transform: translateY(-2px); }
`;
```

Spec says: "pulsing opacity + slight Y translation over 1.1s." The plan's keyframes implement opacity pulsing (0.25 -> 1 -> 0.25) with slight Y translation (-2px). MATCHES spec intent.

### prefers-reduced-motion placement

Plan specifies `@media (prefers-reduced-motion: reduce) { animation: none; }` inside both the dot styled component (Task 4B.2) and shimmer styled component (Task 4B.3). This is the correct Emotion pattern (nested inside the styled component's css block, co-located with the animation). CORRECT.

## Findings

No HIGH or MED findings.
