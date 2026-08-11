# conventions-compliance — Round 1 (single-angle pass)

Per the orchestrator directive this round runs conventions as ONE angle with the checklist from `cursor_rules/core_critical_rules.md` + `cursor_rules/backend/_base.md` + `cursor_rules/frontend/_base.md` (all three read in full). The dedicated per-rules-file fan-out (pipeline rule 27) runs separately after loop convergence.

## core_critical_rules.md against the diff

- Rule 1 (no begin blocks): no new begin blocks. ✓
- Rule 5 (one params method): `sign_up_params` remains the controller's single params method; new params appended to it. ✓
- Rule 7 (snake_case/camelCase): frontend payload fields camelCase; wire snake_case via `allKeysToSnake`; `utm_data` inner keys stay raw URL param names — APPROVED deviation #4 (like the Ruby-enum exception), not a violation. ✓
- Rule 8 (bare-return guards): the only new guard is JS (`if (!emailConfirmed) return;` — bare). No new Ruby guards. ✓
- Rule 9 (never deliberately set undefined): no `x ? y : undefined` anywhere; payload fields are direct property reads passed as-is ("pass values directly" pattern). The helper's conditional field omission is the spec-mandated D3/D6 absence semantics (REVIEW-ANGLES angle 1 endorses it explicitly). ✓
- Rule 10 (never fabricate fallbacks): zero `|| ""`/`|| {}`/`|| 0` in the diff. ✓
- Rule 11 (bang methods): `create!` only in `spec/` — the stated exception. ✓
- Rule 12 (check save return values): no new `save`/`update` calls added; the org copy uses direct setters ahead of the existing checked save flow. ✓
- Rule 13 (strict comparisons; loose only vs undefined): `utmData != undefined`, `id != undefined && email != undefined` — house loose-absent guards ✓; all other comparisons strict ✓. The helper's `parsedParams.<key> !== undefined` is the spec-pinned deliberate strict form (a loose `!=` would misclassify the `?utm_source` null passthrough as absent) — spec §5.1/plan F1.2 explicitly bar "fixing" this to `!=`. ✓
- Rule 2a (window.logger): existing loggers preserved; the committed `posthog.ts` loggers are the feature's own diff — not flaggable. ✓
- Never-edit list: no diff on `api.ts`, context files, or core infrastructure. ✓
- Naming: no new record variables outside specs; spec variables use `user`/`organization` matching their models. ✓

## backend/_base.md against the diff

- §1-6 (rescue rules/ensure): no new rescue/ensure blocks. ✓
- §7 (single quotes unless interpolating): all new Ruby strings single-quoted except the confirmations redirect, which interpolates (double quotes correct). Rubocop Style/StringLiterals reports nothing on any diff line (the `omniauth_callbacks_controller.rb:5` hit is a pre-existing untouched line). ✓
- §8 (no `reload` in app code): `reload` appears only in the new specs — the stated spec exception. ✓
- §9 (record variable naming): satisfied (specs only). ✓
- Rubocop on all 13 changed/new Ruby files: the ONLY offense on a diff line is `Metrics/ParameterLists [7/5]` at `user.rb:379` — inherent to the approved D9 all-keyword signature (7 params fixed by decision), acknowledged as non-actionable. All other offenses are on pre-existing untouched lines (verified line-by-line against the diff hunks). Migrations and all five spec files are rubocop-clean. ✓

## frontend/_base.md against the diff

- §1 (no `??`): none. ✓
- §2 (never deliberately set undefined): as above. ✓
- §3 (trust the API layer; JSONB camelCase): no snake_case fallback reads anywhere; the `utm_data` inner-key rawness is APPROVED deviation #4. ✓
- §4 (pragmatic TS): `Record<string, any>` for `utmData`, interface `Props` extension in `GoogleSSOButton.tsx`, optional fields in the `magicLink` inline type. ✓
- §6 (no useMemo for minor computation): none used. ✓
- File structure: helper in the existing `utils.js` (no new component files). ✓
- eslint on all 10 modified frontend files: **0 errors, 8 warnings** — 7 verified pre-existing at base (`utils.js` `index` unused, `useSession.ts` `queryClient` ×2, `Auth.tsx:21` mount-effect exhaustive-deps, `SignupForm.tsx` `isLoadingInvite`, `OrganizationForm.tsx` `theme`, `posthog.ts` `Window`); the 1 new warning (`Auth.tsx:31` exhaustive-deps missing `props.location.search`) is the spec-bound §5.6 `[emailConfirmed]` deps design — verified to match the spec exactly, not a finding per the orchestrator brief.

## Findings

No issues found.
