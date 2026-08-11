# Slice map: FE Account → Plato AI settings, usage, gating

Scope: `views/accountAdmin/AccountContainer.tsx`, the new `accountPlatoAi/` container + cards, `OrganizationAiSettings.tsx`, `OrganizationAiUsage.tsx`. Focus of this note is **settings / auto-generate toggle / usage / plan gating**. The billing/subscription cards (`AiCreditSubscription`, `AiCreditOneOffCard`, `AiSubscription*`, the two confirm modals, `aiSubscriptionHelpers`) are new here but belong to the billing slice — noted only for adjacency.

## What changed

**AccountContainer.tsx (SHARED, modified):** Adds a new "Plato AI" account-settings section.
- New feature-flag read: `aiApplicantSummaryEnabled = useFeatureFlipper()({ feature: Features.AI_APPLICANT_SUMMARY })`.
- Nav label map gains `"/hire/settings/plato-ai": "Plato AI"` ONLY when the flag is on (spread-conditional).
- New `<Route path="/hire/settings/plato-ai" exact={false}>` → renders `AccountPlatoAiContainer`. The route itself is NOT flag-gated (only the nav link is) — direct URL nav to `/hire/settings/plato-ai` still mounts the container even with the flag off. Admin gate inside the container is the real guard.

**AccountPlatoAiContainer.tsx (new):** Sub-section shell with its own left sub-nav (Billing / Usage / Settings) and nested routes.
- **Admin-only:** `useAuthorization()({ adminOnly: true })`; returns `null` if not authorized (non-admins see nothing).
- Waits for `currentOrganization` (from `useCurrentSession`) — shows `LoadingIndicator` until loaded.
- Routes: `/billing` → `OrganizationAiBilling`, `/usage` → `OrganizationAiUsage`, `/settings` → `OrganizationAiSettings`; default `<Redirect>` to `/billing`.
- Wraps content in `UnsavedChangesGuard` driven by `isDirty` (set by child forms via `setIsDirty`).

**OrganizationAiSettings.tsx (new):** The settings form. Reads `currentOrganization.settings`, re-syncs on org change via effect. Fields (all Enabled/Disabled `FormSelect` except threshold):
- `autoGenerateAiSummariesEnabled` — "Auto-generate Plato reviews for new applicants." Copy states each successful review spends one credit and individual jobs can override.
- `hiringTeamAiCreditsControlEnabled` — "Allow hiring team members to spend credits" (else admins only).
- `lowAiCreditNotificationsEnabled` — low-balance email to org admins.
- `lowAiCreditNotificationThreshold` — `FormInput type=number min=1`, rendered inside `FormConditionalFields` ONLY when low notifications enabled.
- `zeroAiCreditNotificationsEnabled` — zero-balance alert.
- Save via `useUpdateOrganization` mutate with `{ id, settings: {...} }`. On submit, threshold is forced to `0` when `lowAiCreditNotificationsEnabled` is false. Success toast "Plato AI settings saved" + clears dirty; error sets `errors` from `response.data.errors` + warning toast "Could not save settings".

**OrganizationAiUsage.tsx (new):** Read-only usage view. `useOrganizationAiCreditBalance()`; shows `LoadingIndicator` until `balance` present. Renders `AiCreditBalance` (source breakdown) + a total row showing `balance.totalCreditsRemaining.toLocaleString()` "credits total" and a **"Buy credits"** button that navigates by string-replacing `/usage$` → `/billing` in the current URL.

**AiCreditBalance.tsx (new):** Stacked segmented bar + three source rows: Monthly plan credits (`monthlyCreditsRemaining`, resets, no rollover), Subscription credits (`addonSubscriptionCreditsRemaining`, resets, rolls over), Top-up credits (`addonCreditsRemaining`, rolls over, spent last). Reset dates from `currentPeriodEndAt` / `subscriptionPeriodEndAt` via `prettyDateSimpleISO`, falling back to "next period". Bar denominator is `max(plan+sub+topup, 1)` to avoid divide-by-zero.

**AiCreditMeter.tsx (new):** Generic single-meter component (label, remaining/total, tone plan|subscription|topup). Present in slice but not imported by Usage/Settings — used by billing cards.

**aiSubscriptionHelpers.ts (new):** Pure helpers for the billing slice (`splitTiers`, `deriveTierButtonText`, `deriveTierButtonType`, `formatCents`, `formatResetDate`). No settings/usage impact.

## User-visible / actions enabled
- Admins get a new **Plato AI** item in account settings nav (only when `AI_APPLICANT_SUMMARY` flag on) with Billing / Usage / Settings sub-tabs.
- Settings: toggle auto-generate reviews for new applicants, allow/deny hiring-team credit spend, configure low/zero-credit email alerts + threshold. Save persists to org settings.
- Usage: view current credit balance broken down by source and jump to Billing to buy credits.

## Conditions / gating / edge cases
- Nav link visible only when `AI_APPLICANT_SUMMARY` flag on; the container/route itself is admin-gated (`adminOnly: true`) not flag-gated → non-admins get `null`, direct-URL visitors with flag off still reach admin gate.
- Threshold input only rendered (and only meaningfully saved) when low-credit notifications enabled; disabling forces threshold to `0` on save.
- Usage total uses `Math.max(..,1)` for bar sizing only; the numeric "credits total" uses raw `totalCreditsRemaining`.
- `OrganizationAiSettings` destructures `settings` unconditionally — relies on `currentOrganization.settings` always being defined (container guards on `currentOrganization` but not on `.settings`).

## SHARED / non-AI surfaces that could regress
- **AccountContainer.tsx** — the shared account-settings router/nav. New conditional nav entry + new `<Route>` are additive; risk is only if the spread-conditional or route ordering interferes with existing sections. Verify all pre-existing account tabs (Users, Templates, API keys, Plan & billing, etc.) still render.
- **Organization settings params (`useUpdateOrganization`)** — five new settings keys are sent in the `settings` hash; backend `settings_params` permit must include them or they silently drop. Cross-check backend serializer/permit slice.
- **`useOrganizationAiCreditBalance` query hook** — shared read used by both Usage and billing cards.

## Pipeline/model/provider
None in this slice (pure FE views). No model calls, prompts, or provider logic here.
