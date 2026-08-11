# Angle: collection-point-move — Round 1

Reviewed against live source at `/Users/jessica/wrk/wrk-corp/inflow-ats`, branch `attribution-work-qa`, tip `b4cb4463a`.

## Verified accurate (no finding)

- `OrganizationForm.tsx` lines 24-36 are exactly the removal block: `_gcl_aw` read/parse with its two comment lines (26-27), `window.logger` at 31, the AdRoll comment at 33, `__adroll_fpc` read at 34, `window.logger` at 36. SPEC §5.7's "Remove lines 24-36" is complete and correctly bounded.
- Payload line 72 is `{ name, googleClickId, heardAboutUsFrom, adrollFirstPartyCookie }` — removal yields `{ name, heardAboutUsFrom }` exactly as §5.7 states.
- `useCookieValue` import (line 14) has no other use in the file after the removal (only uses: lines 24, 34) — the conditional "remove if unused" resolves to remove; conditional phrasing is fine.
- Scope-discipline anchors all exist and are correctly enumerated as stay-untouched: `heardAboutUsFrom` (19, 42-44, 72), `window.__adroll.record_user` (53-63), `trackEvent("organization_created")` (76).
- `organizations_controller.rb`: copy block is lines 31-36 (ending `@organization.adroll_click_id = current_user.adroll_click_id`); `organization_params` permit with `:google_click_id, :adroll_first_party_cookie` is line 120; `#update` uses the same `organization_params` (line 64) so the permit narrowing affects it — §6.4's shared-params statement is accurate. Grep confirms nothing else in `app/`, `spec/`, or `cypress/` sends or reads the two fields outside the org controller + its spec — "Nothing else sends them on update today" is accurate.
- §13.5 transition-window consequence: accepted per ruling, not flagged.

## Findings

- F1 [MED] SPEC §10.4 + code-task-list T20 / spec change makes two existing spec artifacts wrong without instructing their update / `spec/controllers/api/v1/organizations_controller_spec.rb` lines 10-12 header comment: "adroll_first_party_cookie is the exception: like google_click_id it is read in the browser at organization-creation time, so it IS permitted through organization_params and arrives in the request body rather than being copied off current_user" — false after the permit removal. Lines 59-69, example `'stores adroll_first_party_cookie from the request body'`: POSTs `adroll_first_party_cookie: 'fpc-abc123'` in the body and asserts `expect(organization.adroll_first_party_cookie).to eq 'fpc-abc123'` — FAILS after the permit removal (the copy block writes `current_user.adroll_first_party_cookie`, nil for that spec's user). §10.4 asks only for a NEW assertion; an implementer following it literally leaves a failing example and a false header comment. Harness calibration: broken/wrong specs are real findings. / Fix: amend §10.4 (and T20) to explicitly (1) replace/invert the `'stores adroll_first_party_cookie from the request body'` example — the request-body value must NOT land, the organization carries `current_user`'s value (or nil), and (2) rewrite the header-comment exception paragraph to reflect that both columns are now copied from `current_user`.

- F2 [MED] code-task-list T9 / line enumeration inconsistent with §5.7, orphans the comment at line 33 / T9 enumerates "lines 24-31" (the `_gcl_aw` block) + "line 34" (`__adroll_fpc`) + "both window.logger calls" (31, 36) — no clause covers line 33 (`// AdRoll writes its first-party cookie on our own domain, so it reads like _gcl_aw`). An implementer following T9 literally leaves a stranded comment above deleted code. SPEC §5.7 ("lines 24-36") is correct. / Fix: amend T9 to the single range "lines 24-36" matching §5.7 (covers both comments and both logger calls).

## Amendments Applied

None — orchestrator applies amendments. Recommended:

1. **SPEC §10.4** — append after the NEW-assertion sentence: "This inverts the existing example `'stores adroll_first_party_cookie from the request body'` (lines ~59-69) — update that example (request-body value ignored; organization carries `current_user`'s value or nil) and rewrite the file's header comment (lines ~10-12), whose 'adroll_first_party_cookie is the exception' paragraph becomes false after the permit removal."
2. **code-task-list T20** — add: "update the existing `'stores adroll_first_party_cookie from the request body'` example (now inverted) and the header comment's request-body-exception paragraph."
3. **code-task-list T9** — replace the "lines 24-31 ... line 34" enumeration with "lines 24-36" (per §5.7), keeping the identifier list.
