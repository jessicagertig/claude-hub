# Spec review complete — attribution-identifiers

**Final verdict: READY FOR PLANNING.**

Reviewed on branch `attribution-work-qa` @ `b4cb4463a` (verified at review start and unchanged from spec time — no repo drift). One full round (7 feature angles + always-on checks, one reviewer per angle), per harness-profile.md. Round 1 produced 7 MED + 5 LOW, zero HIGH/BLOCKER — all amended inline; per the profile, no verification round was required. No finding contradicted any §13 ruling; the five RESOLVED decisions stand untouched.

## Plain English summary

The feature captures eight additional ad-platform identifiers (Google Analytics client/session, Meta fbclid/fbp/fbc, LinkedIn li_fat_id, plus Google click ID and the AdRoll first-party cookie) at user signup, stores them on the `users` row, and copies them onto the `organizations` row at organization creation — exactly the pipeline the existing UTM/AdRoll capture already uses. Nothing is sent to any ad platform; this is capture-only, building the dataset for future server-side conversion APIs. The one destructive part: the organization form stops collecting `google_click_id` and `adroll_first_party_cookie` (collection moves to signup), and the server stops accepting them from the organization request body.

The spec is structurally sound: every one of the eight identifiers has every layer of the analog `adroll_click_id` chain (verified 15 layers × 8 identifiers, no gaps), all eight camelCase→snake_case wire transforms were verified empirically against the installed lodash, and the only deviations from the analog are the four Jessica-sanctioned ones. The review's findings were all precision gaps — capture edge rules the spec left implicit (repeated URL params, dotless cookie values, exact cookie-name matching, what "present" means for the fbc-construction and cookie-fallback rules) and two stale/incomplete factual claims (the `from_omniauth` grep count predating `ec9f87232`'s spec files; §10.4 not directing the inversion of an existing test example the permit removal breaks). All are amended into SPEC.md and code-task-list.md.

## Blast radius

- **Signup paths (all three):** magic-link, password, and Google SSO signups all gain eight payload fields/hidden inputs. Riskiest surface: the SSO session ride (`session[:oauth_tracking]`, ~4KB cookie ceiling — accepted risk §14.1, realistic values fit) and the omniauth callback's exhaustive spec expectations (fail loudly if missed; now explicitly directed).
- **Organization creation:** gains eight copy lines from `current_user`; loses two request-body permits. The permit narrowing also affects `#update` (shared params method) — verified nothing else sends those params today.
- **Organization form (user-facing):** stops reading two cookies; payload narrows to `{ name, heardAboutUsFrom }`. Pre-ship signups creating post-ship orgs get nil `google_click_id`/`adroll_first_party_cookie` — accepted by Jessica (§13.5).
- **Shared helper `sanitizeTrackingParams`:** only two consumers (AuthForm, SignupForm), both signup pages; existing fields' behavior byte-identical (255 cap, occurrence-order utm_data untouched).
- **Schema:** 8 new `users` columns, 6 new `organizations` columns, all nullable strings, no backfill. The §3 HARD hunk-level `db/schema.rb` staging rule applies at commit time.
- **Tests:** four existing RSpec files extended; one existing example (`'stores adroll_first_party_cookie from the request body'`) inverts. Cypress `registration.cy.js` (top priority, read-only) verified unbreakable by these changes — it asserts navigation/text only, no payload shapes, and GTM does not load in test env.
- **Not touched:** serializers, policies, jobs, PostHog events, `heard_about_us_from`, the `window.__adroll.record_user` pixel call, `api.ts`, contexts.

## Round outcomes

**Round 1** (`reviews/spec-round-1/`): 7 MED, 5 LOW, 0 HIGH, 0 BLOCKER. Angle files: per-identifier-capture-contract (3 MED/1 LOW), collection-point-move (2 MED), sso-session-ride (1 MED/1 LOW), nil-absence-semantics (1 MED/1 LOW), always-on-checks (2 MED/3 LOW — both MEDs duplicates of other angles'), wire-format-integrity (clean), creation-time-only-and-existing-behavior-unchanged (clean), migrations-and-schema-hygiene (1 LOW note). All three Phase-1 candidate findings confirmed and amended. 18 amendments applied (10 SPEC.md, 8 code-task-list.md — full list in `spec-round-1/verdict.md`); post-amendment stale-reference sweep clean.

**Round 2:** not run — profile requires it only after HIGH+ findings.

## Notable clean verifications

- All eight lodash `snakeCase` transforms verified by executing the repo's installed lodash: `gaClientId→ga_client_id`, `gaSessionId→ga_session_id`, `liFatId→li_fat_id`, `googleClickId→google_click_id`, `adrollFirstPartyCookie→adroll_first_party_cookie`, `fbclid`/`fbp`/`fbc` unchanged. The §5.2 jsonb-rejection rationale is mechanically correct (`_.snakeCase('_ga_ABC123XYZ')` → `ga_abc_123_xyz`).
- The `ga_session_id` value (contains `=`, `;`, spaces) rides the SSO form intact: browsers percent-encode form values, and Rack 2.2.9 parses POST bodies on `'&'` only (`rack/request.rb:454`) — the `;`-separator behavior applies to GET query strings only.
- `organizations` already has `google_click_id` (schema.rb:1078) and `adroll_first_party_cookie` (schema.rb:1094); none of the new columns pre-exist on either table — no duplicate-column migration risk.

## Open questions for Jessica

None requiring a ruling. Two notes, no action needed:

1. Pre-existing oddity, untouched by this feature: `omniauth_callbacks_controller.rb:5` assigns `request.env["devise.mapping"] = Devise.mappings[:user]` — a mapping that does not exist in this app (`:api_v1_user` is the real one); harmless today because nothing downstream reads it.
2. The §3 "schema.rb corruption" is not visible in the current working tree (clean at `b4cb4463a`); it will presumably appear when `db:migrate` regenerates schema.rb from the drifted dev database. The hunk-level staging rule stands regardless.
