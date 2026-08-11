# Plan review pass 1 — collection-point-move

Reviewed: plan.md T9, T13, T20, §5.1 rows 20-21 against SPEC §5.7/§6.4/§10.4/§13.5 and live code @ `b4cb4463a`.

## Fact checks performed (all verified live)

- `OrganizationForm.tsx`: `useCookieValue` import at :14; lines 24-36 contain exactly the removal set — `gclAwCookieValue` (:24), `parsedArray` (:25), format comments (:26-27), `googleClickId` (:28-29), first `window.logger` (:31), AdRoll comment (:33), `adrollFirstPartyCookie` (:34), second `window.logger` (:36). Nothing else lives in that range (30/32/35 are blank).
- Payload at :72 is exactly `{ name, googleClickId, heardAboutUsFrom, adrollFirstPartyCookie }` — T9b's target `{ name, heardAboutUsFrom }` is the correct narrowing.
- `git grep -ln "useCookieValue"` → exactly 3 files: `OrganizationForm.tsx`, `useCookieValue.ts`, `useReferrerCookie.ts` — T9c's "no other use remains in this file" claim verified; `useReferrerCookie.ts` untouched per plan.
- Not-removed set present in the file: `heardAboutUsFrom` state/input (:19, :42-44, :138-146), `window.__adroll.record_user` block (:53-63), `trackEvent("organization_created")` (:76) — T9d enumerates all three.
- `organizations_controller.rb` `organization_params` at :119-146; `:google_click_id, :adroll_first_party_cookie` present on :120 — T13's removal is precise. `#update` (:60-88) uses the same `organization_params` — the accepted shared-params consequence is stated in T13, matching core rule 5 (verified: cursor_rules/core_critical_rules.md §5 "One Params Method Per Controller").
- Copy block `#create` :31-36 ends at `@organization.adroll_click_id = current_user.adroll_click_id` (:36), followed by `is_claimed` (:37) and `authorize` (:38) — T12's insertion point is exact.
- `organizations_controller_spec.rb`: header comment :10-12 ("adroll_first_party_cookie is the exception … IS permitted through organization_params"), example `'stores adroll_first_party_cookie from the request body'` at :59-69 — T20b/T20c line refs exact; the inversion direction matches SPEC §10.4.
- Transition-window consequence (§13.5) carried as plan risk 7 with the "do NOT add an org-form fallback" prohibition — decision respected, not worked around.

## Findings

None. 0 BLOCKER, 0 HIGH, 0 MED, 0 LOW.
