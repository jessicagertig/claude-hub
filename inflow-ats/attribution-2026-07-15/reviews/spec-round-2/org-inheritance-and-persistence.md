# org-inheritance-and-persistence — Round 2

Round-2 sweep. No new findings.

- `organization_params` re-read (lines 114+): `params.require(:organization).permit(...)` includes `google_click_id`/`heard_about_us_from` but nothing attribution-shaped; §4.4's "organization_params is NOT modified" keeps request-supplied attribution unreachable — an attacker-controlled `utm_source` in the org-create body is never read (`Organization.new(organization_params)` sees only the permit list).
- Copy placement: the four assignments sit with `created_via` (line 31), before `authorize @organization` (line 33) and `save` — analog-identical.
- Migrations re-checked against `cursor_rules/backend/migrations.md`: no booleans, single purpose, no data migration; the no-index choice is D6-bound (round-1 LOW stands, not re-opened).
- Schema facts re-confirmed: no pre-existing `utm_*`/`internal_ref` on `users`/`organizations`; the four names collide with nothing (repo's only utm columns are on `ahoy_visits`).
- `user.rb` is the only model touched (for `from_omniauth` only); `organization.rb` untouched per repo rule.

## Findings

- None.

## Amendments Applied

- None.
