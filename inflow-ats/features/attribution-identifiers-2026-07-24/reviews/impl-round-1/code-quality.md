# Impl round 1 — code-quality (cursor_rules adherence)

Rules files read: `core_critical_rules.md`, `backend/_base.md`, `backend/core_critical_rules.md`, `backend/migrations.md`, `frontend/_base.md`, `frontend/core_critical_rules.md`.

## Ruby

- Single quotes throughout the new Ruby (`merged_tracking['ga_client_id']`, `'google'` context untouched) — backend/_base rule 7 ✓.
- No begin blocks, no rescue changes, no `ensure`, no bang methods in `app/` (bangs in the extended specs — `User.create!`, `tap(&:confirm)` — are the sanctioned spec exception) ✓.
- No `reload` in application code ✓. No new guard clauses returning truthy/falsy values ✓.
- One params method per controller preserved in both controllers (rule 5) — permits extended/narrowed in place ✓.
- No `update_columns`, no transactions touched.

## JavaScript/TypeScript

- Double quotes throughout the new JS/TS ✓. No `??` (frontend/_base rule 1) ✓.
- Rule 13 comparisons: strict `===`/`!==` everywhere in the new code; the loose-vs-`undefined` exception not needed since every comparison is `!== undefined` (matching the analog's existing `parsedParams.utm_source !== undefined` form in the same function — analog wins) or `=== 0`/`=== -1` index checks. The one pre-existing `utmData != undefined` in `GoogleSSOButton.tsx` untouched ✓.
- Rule 10 (no fabricated fallbacks): zero `|| ""`/`|| 0`/`|| {}`/`|| []` in the diff ✓.
- Rule 9 (never deliberately set undefined): no object property or call argument is set to `undefined`. `getCookieValue`'s `: undefined` return branch is the plan's verbatim, plan-review-approved code expressing "absent" for an internal helper — consistent with how the codebase treats absent values and not the pattern rule 9 targets.
- `window.logger` removals in `OrganizationForm.tsx` are part of the specced line removal, not a logging-convention change; rule 2a not violated.
- Emotion/theme/Button rules: N/A — no styling or Button changes in the diff.
- Naming: `ATTRIBUTION_IDENTIFIER_MAX_LENGTH` parallels `TRACKING_VALUE_MAX_LENGTH`; cookie-entry variable names are descriptive (`cookieEntry`, `gaSessionCookieEntries`, `fbclidParamValue`) ✓. Component/file naming untouched.

## Findings

None. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
