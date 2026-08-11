# Impl round 1 — collection-point-move

Reviewed: committed diff + `OrganizationForm.tsx` and `organizations_controller.rb` read whole in committed state.

## Removal scope (SPEC §5.7, pipeline rules 10/23)

- `OrganizationForm.tsx`: the `useCookieValue` import, the `_gcl_aw` read/parse (`gclAwCookieValue`/`parsedArray`/`googleClickId` + both comment lines), the `__adroll_fpc` read (`adrollFirstPartyCookie` + the AdRoll comment), and both `window.logger` cookie-read calls are ALL gone. Payload is now exactly `{ name, heardAboutUsFrom }` (`OrganizationForm.tsx:56`).
- Scope discipline verified line-by-line against the committed file: `heardAboutUsFrom` state/handler/input untouched; the `window.__adroll.record_user` block untouched (`OrganizationForm.tsx:37-54`); `trackEvent("organization_created")` untouched (`:60`); nothing else in the file changed. Grep confirms zero `_gcl_aw`/`__adroll_fpc` references remain under `app/javascript/ats/`.

## Server side (SPEC §6.4)

- `organization_params` (`organizations_controller.rb:128`): `:google_click_id` and `:adroll_first_party_cookie` removed; `:heard_about_us_from` retained; nothing else in the permit changed. Shared-params consequence (`#update` also stops accepting them) is the accepted stated fact — no workaround was added ✓.
- `#create` copy block (`organizations_controller.rb:37-44`): the eight copy lines added in analog-identical form after `adroll_click_id`, before `@organization.is_claimed = true` / `authorize @organization`. Values never come from the request.
- No org-form fallback for the §13.5 transition window was added ✓ (flagging such a fallback was this angle's trap — none exists).

## Spec inversion (SPEC §10.4)

- `'stores adroll_first_party_cookie from the request body'` correctly inverted to `'ignores google_click_id and adroll_first_party_cookie sent in the request body'` (`organizations_controller_spec.rb:75-90`): POSTs `'from-body'` for both, asserts `current_user`'s values (`'gclid-abc123'`/`'fpc-abc123'`) land instead. Distinguishable values ✓.
- Header comment (`:5-12`) rewritten — the "adroll_first_party_cookie is the exception … IS permitted through organization_params" paragraph is gone, replaced by an accurate description of the move.
- The four spec files ran green (20 examples, 0 failures).

## Findings

**LOW-1** — The inverted example pins the feature but cannot isolate the permit removal alone. In `#create`, the explicit copy lines (`organizations_controller.rb:43-44`) overwrite whatever `Organization.new(organization_params)` mass-assigned, so this example would still pass if the two permits were restored while the copy lines stayed. It is NOT a ghost test — against the pre-feature code (permits present, no copy lines) it fails, so it does pin the feature's behavior change. But plan.md §8's falsifiability claim ("the T20b inversion fails if T13's permit removal is reverted") is inaccurate as stated: the only surface where the permit removal alone is observable is `#update`, which has no test (missing coverage — never HIGH/MED per harness-profile.md). Note-only; no change required.

0 BLOCKER / 0 HIGH / 0 MED / 1 LOW.
