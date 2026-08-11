# conventions-compliance — Round 1

Per the orchestrator override, spec-stage conventions review checks the spec's claims against cursor_rules files (per-file fan-out happens at impl review). This round: `cursor_rules/core_critical_rules.md` (read in full) and `cursor_rules/backend/migrations.md` (read in full).

## core_critical_rules.md vs the spec

- Rule 1 (no begin blocks): no rescue changes specced — n/a.
- Rule 2a (window.logger encouraged): the §5.9 posthog.ts diff is logger-only — compliant, not flagged (rule explicitly forbids flagging it).
- Rule 5 (one params method): `sign_up_params` extended in place; no new params method. Compliant.
- Rule 7 (snake/camel + exceptions): §5 case-convention note handles both directions; `utm_data` inner-key rawness is an approved deviation (REVIEW-ANGLES Priority rule 4), analogous to the Ruby-enum exception. Compliant.
- Rule 8 (bare-return guards): the amended §5.6 effect "bare-returns unless emailConfirmed" — compliant phrasing.
- Rule 9 (never deliberately set undefined): §5.1 absence semantics pass values through rather than conditionally setting `undefined`. Compliant.
- Rule 10 (never fabricate fallbacks): §7.2 restates it verbatim; nil-for-absent enforced at every layer. Compliant.
- Rule 11 (no bang methods; specs exempt): §9 relies on the spec exemption only. Compliant.
- Rule 12 (check save returns): no new save/update calls introduced; `organizations#create` keeps its existing if/else. Compliant.
- Rule 13 (strict comparisons; loose only vs undefined): §5.3 guards use `typeof x === "string"`; §5.6 uses `=== "true"`. The "both params present" guard should use the house `x != undefined` form at impl time — noted, spec-level wording is fine.
- Files-never-edit list: spec §7.10 respects it (`api.ts`, contexts untouched). `PostHogContext.tsx` is NOT edited (the §5.6 amendment deliberately avoided touching provider init).
- `organization.rb` special rule (line 340): spec §3 explicitly requires no edit. Compliant.

## backend/migrations.md vs the spec

- Rule 1 (boolean verb prefix): no booleans — n/a.
- Rule 2 (no new migrations during active development): new feature → new migrations — the allowed case.
- Rule 3 (single purpose; indices for commonly queried fields): one table per migration; no index is D6-mandated and the columns are not app-queried (recorded as LOW under org-inheritance F1, not a conflict).
- Data-migrations section: no backfill (D6) — n/a.

## Findings

- F1 [LOW] Impl-time reminder recorded: the §5.6 both-params guard should be written with the house `!= undefined` guard (rule 13), and the per-key `utm_data` input guard already specifies the analog's `typeof`/length form. No spec text change needed — the spec doesn't prescribe a non-house form anywhere.

## Amendments Applied

- None.
