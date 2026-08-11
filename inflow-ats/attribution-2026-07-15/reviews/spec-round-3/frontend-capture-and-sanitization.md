# frontend-capture-and-sanitization — Round 3

Round-3 sweep with the `redirect_if_authed` discovery in hand: does the server-side bounce affect capture?

- Capture happens on `/auth`, `/auth-register` (`AuthForm`), `/register` (`SignupForm`) — all served by `Hire::PagesController` actions with `redirect_if_authed`. A SIGNED-IN visitor to these pages bounces to the app root — but capture targets signup visitors, who are signed out by definition. A signed-out visitor with utm params renders the page and captures normally. The bounce drops query params only for signed-in users, for whom no capture is wanted (creation-time-only, §7.5). No spec impact.
- The marketing-site round (D17, deferred) will link INTO these pages with utm params — signed-out arrivals, unaffected by the bounce.
- Re-checked §5.1 amended text end-to-end for internal consistency after rounds 1–2: input (raw string), output fields, rules 1–3, absence semantics — coherent, no stale cross-references.

## Findings

- None.

## Amendments Applied

- None.
