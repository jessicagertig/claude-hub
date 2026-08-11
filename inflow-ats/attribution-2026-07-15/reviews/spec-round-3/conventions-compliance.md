# conventions-compliance — Round 3

This round's conventions file: `cursor_rules/backend/controllers/controller_patterns_and_crud.md` (read in full).

## controller_patterns_and_crud.md vs the spec

- One params definition per controller: `sign_up_params` extended in place; `organization_params` untouched — compliant. (The registrations controller's pre-existing second params method `sanitized_account_update_params` is existing code the spec does not touch.)
- No new routes; no `patch` anywhere — n/a/compliant.
- Render helpers: no render changes anywhere in the diff (`magic_create` responses byte-identical, `organizations#create` keeps `render_one`/`render_errors`) — compliant.
- "Delegate complex business logic to interactors": the additions are attribute threading/copying, exactly the shape the existing controller code (`created_via` copy, `partner_source` merge) uses inline — analog-faithful, no interactor warranted.
- `exists` helper: n/a (no finds added).
- Always authorize: `organizations#create` keeps `authorize @organization`; the Devise endpoints are unauthenticated by design (§6).

## Findings

- None.

## Amendments Applied

- None.
