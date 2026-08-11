# posthog-events-and-identity — Round 4

Final unverified claim closed and coherence sweep of all event text; all clean.

- §4.8's "Magic-link logins never reach this URL" — now verified at source: `MagicLinksController#validate` signs in and redirects to `@magic_link.redirect_to || '/jobs?magic=not_found'` (success) or `/auth?error=expired_link` (failure) — never `email_confirmed=true`. The `/auth?email_confirmed=true` producer census stands at exactly one (confirmations_controller.rb:18).
- Post-amendment coherence sweep of §1, §4.8, §5.6, §10, §11: no contradictions between Risk 7 (coverage boundary) and the mechanism text ("fires only on the email_confirmed=true landing" remains true); no stale references from any round's amendments (grep for superseded phrasings came back clean).
- Signed-in `/auth?invite_token` exception to `redirect_if_authed`: reachable only via crafted URLs carrying `email_confirmed=true&id&email&invite_token`; falls in the already-recorded tamper class (Risk 6 / round-2 LOW). No amendment.
- `identifyUser` import source (`@shared/lib/posthog`) matches the dominant convention (30+ `trackEvent` imports from the same module; `PostHogContext` merely re-exports).

## Findings

- None.

## Amendments Applied

- None.
