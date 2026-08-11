# Spec Review: Mutation & Credit Balance Lifecycle

## Findings

- F1 [LOW] Spec line 292 vs analog `AiSummaryState.tsx` line 104 / Credit hint copy diverges from analog while spec claims to follow the "exact pattern." The analog shows only `1 credit` (line 104, `<Styled.CreditNote>1 credit</Styled.CreditNote>`). The spec introduces three new copy variants: "Uses 1 credit . N remaining" (empty), "Uses 1 credit" (failed), "Regenerate . 1 credit" (stale banner) -- none of which exist in the analog. This is likely an intentional design improvement, but the spec simultaneously says at line 292 "Follow the exact pattern from AiSummaryState.tsx lines 31-47 for the generate action" and at line 296 "Follow the pattern from AiSummaryState.tsx lines 49-108" for credits. An implementer reading those lines will look at the analog and see `1 credit`, not the spec's expanded copy. / Acknowledge in the spec that the credit hint copy is a deliberate divergence from the analog's `1 credit` label, so an implementer knows to follow the spec copy, not the analog copy.

- F2 [MED] Spec line 233-234 / `styleType` prop documentation conflicts with the analog's use of `type` prop for link buttons. The spec says the Button component "uses `styleType` prop (not `variant`)" with values `"primary"`, `"secondary"`, `"white"`, `"text"`. This is correct for styling. But the analog's out-of-credits admin button at `AiSummaryState.tsx` line 66 uses `type="internalLink"` (not `styleType`), which is the `type` prop -- a separate prop from `styleType`. The `type` prop controls the rendered element (`internalLink` renders a `<Link>`, `externalLink` renders an `<a>`, default renders a `<button>`). The spec never mentions `type="internalLink"` in its Button props documentation. An implementer following the spec's Button documentation alone would not know that `type` is a separate prop that controls navigation behavior. / Add to the Button compatibility section that the `type` prop controls element type (`"internalLink"` for React Router `<Link>`, `"externalLink"` for `<a>`, default `"button"` for `<button>`), and that the admin buy-credits button uses `type="internalLink"` with `link="/hire/settings/ai-billing"`.

- F3 [LOW] Spec lines 99-110 / The callout's "Generate" CTA label could mislead implementers into wiring a mutation. The callout table (lines 99-108) shows "Generate" as the CTA text for the "No summary, has resume" row, and line 110 says "Clicking the entire card calls `onOpen()`." So "Generate" is just a label -- the card navigates, it does not trigger the mutation. Meanwhile, PlatoTab's empty state (line 61) has a real "Generate summary" button that DOES trigger the mutation. The distinction is only clear if the implementer reads both sections carefully and notes that line 83's "Generate / Regenerate / Try again actions" refers specifically to "PlatoTab" actions, not callout actions. / Add an explicit note in the callout section (near line 110) that the "Generate" CTA label is navigation-only and does NOT trigger the `useGenerateAiSummary` mutation. The mutation is only triggered from within the PlatoTab itself.

- F4 [LOW] Spec line 36 / Success toast string "Summary generation queued" matches the analog exactly (`AiSummaryState.tsx` line 36: `addToast({ title: "Summary generation queued", kind: "success" })`). No issue.

- F5 [LOW] Spec line 40-43 equivalent / Error toast pattern matches the analog exactly (`AiSummaryState.tsx` lines 38-43: `error?.data?.errors?.general?.[0] || "Failed to queue summary"`, `kind: "warning"`, `delay: 10000`). No issue.

- F6 [LOW] Spec line 296 / `creditData?.totalCreditsRemaining || 0` with `isError` fallback matches the analog exactly (`AiSummaryState.tsx` line 28: `const totalRemaining = creditError ? 0 : creditData?.totalCreditsRemaining || 0`). Uses `||` not `??`. No issue.

- F7 [LOW] Spec line 66 admin link / `type="internalLink"` and `link="/hire/settings/ai-billing"` match the analog exactly (`AiSummaryState.tsx` line 66). The analog also passes `size="small"` which the spec does not mention -- but the spec's PlatoTab has its own layout so this may be intentional. No issue beyond F2's documentation gap.

## Checks passed

- **A (success toast):** Matches analog exactly. "Summary generation queued", kind "success".
- **B (error toast):** Matches analog exactly. `error?.data?.errors?.general?.[0] || "Failed to queue summary"`, kind "warning", delay 10000.
- **C (credit hint copy):** Intentional divergence from analog. Analog says "1 credit"; spec introduces richer copy. See F1.
- **D (admin button props):** `type="internalLink"` and `link="/hire/settings/ai-billing"` match analog. But the spec's Button documentation omits `type` prop explanation. See F2.
- **E (`||` vs `??`):** Analog uses `||`, spec uses `||`. Correct.
- **F (callout Generate CTA):** Navigates only, does not trigger mutation. The spec is technically correct but the distinction is subtle. See F3.
- **G (admin link pattern):** Analog uses `Button` with `type="internalLink"`, `link="/hire/settings/ai-billing"`, `size="small"`. Non-admin uses `Button` with `onClick` that opens `CenterModal` with header "Admin access required" and body "Only admins can purchase more credits. Please contact an admin for your organization." Spec says "follow the existing pattern" which is sufficient. See F2 for the documentation gap.
