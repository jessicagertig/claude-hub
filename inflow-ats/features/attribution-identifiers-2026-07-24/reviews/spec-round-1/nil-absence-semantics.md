# Angle: nil-absence-semantics — Round 1

Reviewed SPEC.md §§4, 5.1, 5.3, 5.4, 6.2, 6.4, 8.1, 8.6 and code-task-list.md T4k against live source on `attribution-work-qa` (tip `b4cb4463a`). Every layer of the absence path traced against real code.

## Verified clean (evidence)

- **Helper omission pattern:** `sanitizeTrackingParams` (utils.js:58-70) sets each output key only inside a `parsedParams.<key> !== undefined` guard — absent source → key never set. The eight new fields following this pattern satisfy §5.1's "absent, never null/'' fabrication".
- **Payload pass-through is safe:** `AuthForm.tsx:81-85` / `SignupForm.tsx:67-71` pass `trackingParams.<field>` unconditionally (`adrollClickId: trackingParams.adrollClickId`). Absent field → property value `undefined` → `allKeysToSnake` (structure.js:94-108) preserves the key with value `undefined` → axios `JSON.stringify` drops undefined-valued keys (verified: `JSON.stringify({a: undefined, b: null})` → `{"b":null}`). Wire param never arrives; `sign_up_params[:<key>]` → nil → nil column. No core-rule-9/10 contradiction — §5.3/§5.4 following the analog is correct as written.
- **SSO absence chain:** `GoogleSSOButton.tsx:61-78` guard `typeof x === "string" && x.length > 0` → no input rendered for absent prop; `omniauth.rb:17-21` loop `tracking_params[key] = value if value && !value.empty?` → key absent from `session[:oauth_tracking]`; `merged_tracking['<key>']` → nil (callback controller:9-16); nil-defaulted keywords confirmed at `user.rb:379`; nil assignment in `first_or_create` block → nil column.
- **Org copy:** `organizations_controller.rb:28-36` plain assignment — nil user column copies as nil. §6.4's extension preserves this trivially.

## Findings

- **F1 [MED]** SPEC §4 (`fbc` row, `li_fat_id` row, `google_click_id` row) + §8.6 / "genuinely present" and "absent" are undefined for the three conditional rules, and the analog's own guard gives the wrong answer / Evidence: installed query-string v6.1.0 parses `?fbclid` → `null` and `?fbclid=` → `""` (verified against `node_modules/query-string`). The analog's per-field guard is `parsedParams.<key> !== undefined` (utils.js:59-70), under which `null`/`""` count as PRESENT. An implementer following the analog would (a) construct `fbc = "fb.1.<Date.now()>.null"` — a fabricated real-looking Meta identifier from a valueless `?fbclid`, exactly what §8.6 prohibits; (b) treat a null/empty `?gclid` or `?li_fat_id` as present and suppress the genuine `_gcl_aw` / `li_fat_id` cookie fallback, silently losing a real value / Fix: amend §4 to define "present" for these three rules as *the URL param parses to a non-empty string* (the house guard form `typeof x === "string" && x.length > 0`, already used at GoogleSSOButton.tsx:61-78): `fbc` is constructed only when `fbclid` passes that test; the `li_fat_id` and `gclid` URL-first rules fall back to the cookie whenever the param fails it. Mirror in code-task-list.md T4f/T4g/T4h.

- **F2 [LOW]** SPEC §5.1 new-output-fields list / whether a cookie present with an EMPTY value (`_fbp=`, `_ga=`) counts as "source absent" is unstated; storing `""` on the JSON path would ride to an empty-string column (the omniauth loop and SSO guard drop it, so the two paths diverge for empties — the same degenerate divergence the prior SPEC §5.3 accepted for URL params) / Fix (optional pin): one line in §5.1 — a cookie present with an empty value is treated as absent for all cookie-sourced fields.

## Amendments Applied

None — orchestrator applies amendments. Recommended:

1. (F1, MED) §4: add after the `fbc` FALLBACK sentence: "'Present' for this construction — and for the `li_fat_id` and `google_click_id` URL-first rules — means the URL param parses to a non-empty string (`typeof x === "string" && x.length > 0`, the existing GoogleSSOButton guard form); query-string v6.1.0 parses a valueless `?fbclid` to `null` and `?fbclid=` to `""`, and neither may trigger construction nor suppress a cookie fallback." Mirror one clause into T4f, T4g, T4h.
2. (F2, LOW) §5.1: append "A cookie present with an empty value is treated as absent."
