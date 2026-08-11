# Pass 2 -- Angle 4: Emotion Styling Fidelity

## Pass 1 Verification

No findings from Pass 1. All tokens verified.

## Fresh Scrutiny

### PlatoNavItem height discrepancy

Plan Task 6.3 copies `linkStyles` which includes `height: 40px` at the root level and `height: 32px` inside `${breakpoint.sm}`. The original `NavItem.tsx` linkStyles (lines 56-95) has the same values. This means at mobile breakpoint, the nav item is 40px tall; at sm+, it's 32px. CORRECT -- matches the existing pattern.

### Connector tick left positioning

Plan Task 3.7 uses `left: 28px`. The analog at `Styled.Event` (JobApplicationActivity.tsx line 675) uses `left: ${t.spacing[6]}` and `Styled.QuestionResponses` (line 527) uses `left: 1.75rem`. The theme `spacing[6]` is `1.5rem` (24px). `1.75rem` is 28px. The plan uses `left: 28px` which matches `1.75rem` from the QuestionResponses pattern. CORRECT.

However, looking more closely at the spec: "a 4px-wide, 24px-tall divider line, matching the feed connector pattern in `Styled.Event` `::after`." The Event pattern uses `left: ${t.spacing[6]}` (24px) while the QuestionResponses pattern uses `left: 1.75rem` (28px). These are different. The plan chose 28px. The spec says "matching the feed connector pattern" but references both Event and QuestionResponses. The callout card is more similar to QuestionResponses (a card component in the feed) than to Event (a text line), so 28px is reasonable. Not a finding.

### darkTheme.wellCanvas value

Plan Task 4A.2 stale banner uses `background: ${t.poly.color.wellCanvas}`. In dark mode, `wellCanvas` is `colors.gray[900]` (#171717) which is the same as the page canvas. This means the stale banner would be invisible against the dark mode background. However, the stale banner also has padding and text content, and `wellCanvas` is the intended token for "well" backgrounds in dark mode. The analog `AiSummaryState.tsx` uses `background-color: ${t.dark ? "rgba(255,255,255,0.07)" : "transparent"}` which is NOT `wellCanvas`. But the spec explicitly says `wellCanvas`, so the plan follows the spec. Not a mismatch.

### font-size raw values vs theme tokens

Plan uses several raw px values: 23px (headline), 13.5px (fit-for-role label), 15px (body text), 14px (item text), 14.5px (experience prose), 12.5px (provenance), 12px (footer). The codebase's `t.text.*` utilities are: `t.text.xs` (0.75rem/12px), `t.text.sm` (0.875rem/14px), `t.text.h2` (larger). None of these map to 23px, 13.5px, 15px, or 14.5px. Using raw px values is correct since no token exists. ACCEPTABLE.

## Findings

No HIGH or MED findings.
