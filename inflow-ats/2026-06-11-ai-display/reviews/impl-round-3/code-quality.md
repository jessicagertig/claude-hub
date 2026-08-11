# Angle: Code Quality

## Verdict: MED finding

### M1 (MED): `isKey` prop leaks to DOM `<span>` element on SkillChip

**File:** `PlatoTab.tsx` line 217, 743
**Severity:** MED

`Styled.SkillChip` is `styled.span((props: any) => ...)` (line 743). The `isKey` prop is passed at line 217: `<Styled.SkillChip key={skill} isKey={isKeySkill(skill)}>`. Because `styled.span` forwards all props to the underlying DOM element, and `isKey` is not a standard HTML attribute, React will emit a console warning: "Warning: Received `true` for a non-boolean attribute `isKey`."

The component works correctly -- the styling logic at lines 753-754 reads `props.isKey` and applies the correct colors/background. The issue is a noisy console warning in development, not a crash or visual bug.

**Fix options (any one):**
1. Use a transient prop prefix: rename `isKey` to `$isKey` in both the styled component definition and the JSX. Emotion's `styled` automatically filters props starting with `$` from the DOM.
2. Add `shouldForwardProp` to the styled component: `styled('span', { shouldForwardProp: prop => prop !== 'isKey' })((props: any) => ...)`.
3. Use a CSS class instead: apply a className like `"key"` and target it with `&.key { ... }` in the styled component.

### No other code quality issues found.

All imports are clean (no unused imports). All variables are consumed. The `buttonLoading` variable is used across 3 surfaces. The `renderCreditsAction` helper correctly DRYs up the credit display logic across Empty and Failed states. The `renderBody` function is clean and readable.
