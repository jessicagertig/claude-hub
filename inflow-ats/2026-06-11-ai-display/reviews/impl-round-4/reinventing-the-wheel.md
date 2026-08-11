# Angle: Reinventing the Wheel (Always-On)

## Files checked
- All 3 new files against existing codebase patterns

## Findings

No findings.

## Verification

### Hooks reused (not reinvented)
- `useGenerateAiSummary` -- existing hook, same as analog
- `useAiJobApplicationSummary` -- existing hook, same as analog
- `useOrganizationAiCreditBalance` -- existing hook, same as analog
- `useToastContext` -- existing context hook
- `useModalContext` -- existing context hook
- `useCurrentSession` -- existing context hook
- `useFeatureFlipper` -- existing hook
- `distanceInWords` -- existing utility from `@shared/lib/time`

### Components reused
- `Button` -- existing component with `styleType`, `type`, `loading`, `disabled` props
- `Icon` -- existing Feather icon component
- `CenterModal` -- existing modal component
- `FeatureFlipper` -- existing component wrapper
- `NavLink` -- React Router component (same as NavItem analog)

### Patterns followed (not reinvented)
- Tab container structure matches `JobApplicationActivity.tsx` pattern
- Generate mutation callback matches `AiSummaryState.tsx` pattern
- Credit balance / buy-credits pattern matches `AiSummaryState.tsx` pattern
- NavItem styles copy from `NavItem.tsx` linkStyles verbatim
- Feed connector `::after` pattern matches `Styled.Event` / `Styled.QuestionResponses`
- Styled component organization matches codebase convention
- Dark mode approach matches codebase (Poly DS tokens + t.dark ternaries)

### Justified new patterns
- Card-as-`<button>`: spec explicitly notes "no existing card-as-button analog exists" -- new pattern, justified for accessibility
- `prefers-reduced-motion`: spec notes "no existing pattern exists in this codebase" -- new convention, correctly established
- `PlatoMark` SVG component: more complex than `WandIcon` analog (3 variants, parameterized size), but follows same inline SVG approach
