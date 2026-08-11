# Pass 1 -- Angle 5: Generate/Regenerate Mutation and Credit Balance Lifecycle

## Fact Check

### Generate mutation pattern

Plan Task 4.4 copies the handler from AiSummaryState.tsx lines 31-47. VERIFIED against source:

```typescript
// AiSummaryState.tsx lines 31-46
const handleClick = () => {
  generate(
    { jobApplicationId },
    {
      onSuccess: () => {
        addToast({ title: "Summary generation queued", kind: "success" });
      },
      onError: (error: any) => {
        addToast({
          title: error?.data?.errors?.general?.[0] || "Failed to queue summary",
          kind: "warning",
          delay: 10000,
        });
      },
    },
  );
};
```

Plan's handler matches exactly. CORRECT.

### Toast content
- Success toast: "Summary generation queued" with `kind: "success"` -- MATCHES analog and spec
- Error toast: `error?.data?.errors?.general?.[0] || "Failed to queue summary"` with `kind: "warning"` and `delay: 10000` -- MATCHES analog and spec

### useGenerateAiSummary hook

VERIFIED: `useGenerateAiSummary` at useAiJobApplicationSummary.ts lines 15-23 returns a mutation. On success, it invalidates `["jobApplication", variables.jobApplicationId]` and `["organizationAiCreditBalance"]`. The plan correctly states that the WebSocket handler at `WebsocketGlobalChannelHandler.tsx` lines 212-228 handles the broader invalidation of `["jobApplication"]`, `["aiJobApplicationSummary"]`, and `["organizationAiCreditBalance"]`.

### Credit balance hook

VERIFIED: `useOrganizationAiCreditBalance` at useOrganizationAiCreditBalance.ts lines 9-13 returns `useQuery<OrganizationAiCreditBalance>(...)`.

Plan Task 4.3: `const totalRemaining = creditError ? 0 : creditData?.totalCreditsRemaining || 0;` -- MATCHES the analog pattern at AiSummaryState.tsx line 28: `const totalRemaining = creditError ? 0 : creditData?.totalCreditsRemaining || 0;`

### Buy credits pattern

Plan Task 4.5 copies the modal from AiSummaryState.tsx lines 58-79. VERIFIED:
- Admin: `<Button type="internalLink" link="/hire/settings/ai-billing">` -- MATCHES analog line 66
- Non-admin: `CenterModal` with "Admin access required" header -- MATCHES analog lines 70-79
- Plan Task 4D.1 (Failed) and 4E.1 (Empty) both reference zero-credits handling -- MATCHES spec

### Credit hint copy

Plan specifies:
- Empty state (4E.1): "Uses 1 credit . {totalRemaining} remaining" -- MATCHES spec
- Failed state (4D.1): "Uses 1 credit" -- MATCHES spec
- Stale banner (4A.2): "Regenerate . 1 credit" -- MATCHES spec

### Callout does NOT trigger generate

Plan Task 3.2 and 3.6: "ALL CTA labels are display-only text. The card always navigates via `onOpen()`" -- MATCHES spec

### WebSocket handling

Plan states no additional WebSocket handling is needed. VERIFIED: WebsocketGlobalChannelHandler.tsx lines 212-228 invalidates all three query keys. New components use the same React Query cache, so they will pick up the invalidation automatically.

## Completeness

- Generate action from empty state -- Task 4E.1
- Generate action from failed state (try again) -- Task 4D.1
- Regenerate from header button -- Task 4.6 (header right section)
- Regenerate from stale banner -- Task 4A.2
- Zero credits admin path -- Tasks 4D.1 and 4E.1
- Zero credits non-admin path -- Tasks 4D.1 and 4E.1
- Credit hint below buttons -- Tasks 4D.1 and 4E.1
- Stacked column layout for button + hint -- Tasks 4D.1 and 4E.1 ("flex-direction: column; align-items: center; gap: 8px;")

All spec requirements for the generate/credit lifecycle are covered.

## Findings

No HIGH or MED findings.
