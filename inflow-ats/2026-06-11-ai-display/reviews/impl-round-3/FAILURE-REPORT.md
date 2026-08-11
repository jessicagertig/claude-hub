# Failure Report: Implementation Round 3

## M1 (MED): `isKey` prop leaks to DOM `<span>` element on SkillChip

**File:** `PlatoTab.tsx`
**Lines:** 217 (JSX usage), 743 (styled component definition), 753-754 (prop consumption)

### Problem

`Styled.SkillChip` is defined as `styled.span((props: any) => ...)`. The custom `isKey` prop is passed in the JSX:

```tsx
// Line 217
<Styled.SkillChip key={skill} isKey={isKeySkill(skill)}>
```

Emotion's `styled.span` forwards all props to the underlying DOM `<span>` element. `isKey` is not a valid HTML attribute, so React emits a console warning for every skill chip rendered:

> Warning: Received `true` for a non-boolean attribute `isKey`.

The styling logic works correctly -- `props.isKey` is read at lines 753-754 to apply key-skill vs non-key-skill colors and backgrounds. The DOM warning is cosmetic.

### Fix

Rename `isKey` to `$isKey` (Emotion transient prop convention). Emotion automatically strips `$`-prefixed props from DOM forwarding.

**Line 217:** Change `isKey={isKeySkill(skill)}` to `$isKey={isKeySkill(skill)}`

**Lines 753-754:** Change `props.isKey` to `props.$isKey`:
```
color: ${props.$isKey ? t.poly.color.loudText : t.poly.color.primaryText};
background: ${props.$isKey ? (t.dark ? t.color.gray[700] : t.color.gray[100]) : "transparent"};
```

This is a 3-line change with no behavioral impact.
