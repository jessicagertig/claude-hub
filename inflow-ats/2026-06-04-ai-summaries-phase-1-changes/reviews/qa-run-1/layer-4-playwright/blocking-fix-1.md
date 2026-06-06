# Blocking Fix 1: OrganizationAiUsage crashes with RangeError

## What broke

The Usage tab inside the Plato AI container (`/hire/settings/plato-ai/usage`) crashes with:

```
RangeError: Invalid time value
    at format (...)
    at prettyDate (...)
    at OrganizationAiUsage (...)
```

The React error boundary catches it, showing "Something didn't work."

## Root cause

`OrganizationAiUsage.tsx` line 19:
```tsx
const resetAt = data?.currentPeriodEndAt ? prettyDate(data.currentPeriodEndAt) : null;
```

`prettyDate` (from `@shared/lib/time`) expects a Unix timestamp (seconds) and multiplies by 1000. But `currentPeriodEndAt` from the API is an ISO string (`"2026-07-05T13:44:10.298Z"`). Multiplying an ISO string by 1000 produces `NaN`, which causes `format()` to throw.

## Evidence

- API response: `{"current_period_end_at":"2026-07-05T13:44:10.298Z"}`
- Console error: `RangeError: Invalid time value` in `OrganizationAiUsage`
- Page shows error boundary: "Something didn't work."

## Fix

Change the import and usage to use `prettyDateSimpleISO` (which calls `parseISO()` before `format()`):

```tsx
// Before:
import { prettyDate } from "@shared/lib/time";
const resetAt = data?.currentPeriodEndAt ? prettyDate(data.currentPeriodEndAt) : null;

// After:
import { prettyDateSimpleISO } from "@shared/lib/time";
const resetAt = data?.currentPeriodEndAt ? prettyDateSimpleISO(data.currentPeriodEndAt) : null;
```

## Severity: HIGH (BLOCKING)

This file was created entirely by this feature. The Usage page is completely broken -- cannot be used at all.
