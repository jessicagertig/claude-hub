# code-quality (always-on impl) — Round 1

Checked against `cursor_rules/core_critical_rules.md`.

- Rule 1 (no begin blocks): controller `create` has none. ✓
- Rule 5 (one params method): `ai_job_application_summary_params` is the sole params method. ✓
- Rule 7 (snake_case/camelCase boundary): frontend `rescoreRequested` ↔ backend `rescore_requested` via API layer. ✓
- Rule 8 (bare guard returns): mailer `return unless recipients.any?` (bare) both methods; interactor bare `return`. ✓
- Rule 9 (never set `undefined`): none introduced. ✓
- Rule 10 / #13 (no fabricated fallbacks): `rescoreRequested` always sent (`true`/`false` literals), required in `GenerateParams`, never defaulted. ✓
- Rule 11 (no bang methods outside spec): mailer/interactor/controller use no bang methods; `create!`/`update!` appear only in specs (allowed). ✓
- Rule 12 (styled component per variant, no custom boolean DOM props): new `Styled.Info`/`Statement`/`RescoreCheckbox` are plain `styled.div`, no custom props. ✓
- Rule 13 (no className styling): new markup uses styled components. Pre-existing `className="submit-button"` on the Button is untouched (not new markup — out of scope). ✓
- Known-failure #1 (theme utilities are complete declarations): `${t.text.sm}` / `${[t.text.xs, ...]}` used standalone, never inside `font-size:`. ✓
- Known-failure #11 (Button `loading`+`disabled` pairing): both modals' submit buttons and PlatoTab Regenerate button keep the pairing. ✓
- Ruby variable naming (rule 9 / global): mailer block var `organization_user` (full model name). ✓
- Ruby single quotes / TS double quotes respected in new code.

## Findings
No issues found.
