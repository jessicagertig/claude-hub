# params-threading-contract — Round 1

Verified against live source: `AuthForm.tsx` `handleAuth` (payload lines 70–98, sends `loginIntent: "hire"` always), `SignupForm.tsx` `handleSignup` (lines 56–77), `useSession.ts` (`magicLink` lines 41–82 destructure + inline type + variables; `register` lines 27–39 destructure + variables, no inline type — spec 5.4 matches this asymmetry), `api.ts` `apiMutate` (`data: skipKeysToSnake ? variables : allKeysToSnake(variables)`), `structure.js` `allKeysToSnake` (line 94, recurses into plain objects, lodash `snakeCase` per key), `registrations_controller.rb` (`sign_up_params` lines 300–303, `magic_create` lines 73–207, `create` lines 10–71), `questions_controller.rb` line 50 (`options: {}` trailing hash-permit into jsonb), routes (`post '/sign_up' → registrations#create`, `post '/magic_login' → registrations#magic_create` — config/routes.rb 81–82), actionpack 6.1.7.7 `strong_parameters.rb` line 247 (`:as_json` delegated to `@parameters` — permitted nested `Parameters` serialize to the plain inner hash on jsonb write, so the questions-analog assignment shape is safe for `utm_data`).

## Findings

- F1 [MED → filed under test-coverage-and-ghost-tests as its F2] `magic_create`'s `user_params` conditional first branch (`login_intent == 'connect' && organization.nil?`, lines 88–97) evaluates `connect_login_intent_organization_id: organization.id` — `organization` is nil in exactly that branch, so any POST without `login_intent` (defaults `'connect'`) and without `organization_slug` raises `NoMethodError`. Production is unaffected (AuthForm always sends `loginIntent: "hire"`; connect flows send a slug), but the spec's §9 tests as previously written would 500. Pre-existing latent defect — NOT in scope to fix (spec §4.2 correctly leaves `magic_create` response/control flow untouched); the spec's test instructions must route around it. Amendment applied in §9 (see test-coverage angle file).
- F2 [LOW] `magic_create` merges the four keys into `user_params` in both branches of the conditional; in the connect branch the added keys sit alongside `connect_login_intent_organization_id`. No behavioral interaction — nil-safe merge keys. No amendment.

## Verified-clean

- Wire contract: camelCase payload fields → `allKeysToSnake` → exactly `utm_source`/`utm_campaign`/`utm_data`/`internal_ref`; canonical inner `utm_*` keys are fixed points of lodash `snakeCase` (spec's `utm_content2 → utm_content_2` transit note is accurate as a fact statement).
- Absent field → `undefined` in variables → dropped by JSON serialization (axios) → param never arrives → `sign_up_params[<key>]` nil → column nil. jsonb stays SQL NULL (no default — §3 table).
- `permit(..., utm_data: {})` trailing-argument form matches the questions analog exactly; scalar-vs-hash mismatches from hostile clients are dropped by strong params (nil column), consistent with raw-storage semantics.
- `create` path needs no action-body change: `expanded_params = sign_up_params.merge(created_via:, partner_source:)` (lines 13–16) mass-assigns the four once permitted — spec §4.3 accurate.
- Existing-user branches of `magic_create` read only `user_params[:email]` (branch 1: `MagicLink.generate(email: user_params[:email], ...)`; branch 2: operates on the found `user`) — adding keys is inert; JSON responses byte-identical. Spec §4.2 accurate.
- No new params method (core_critical_rules rule 5); values stored raw (D3 — approved deviation from the `partner_source&.downcase`/`get_created_via` analog, not flagged).

## Amendments Applied

- None in this file (the `login_intent: 'hire'` test amendment is recorded under test-coverage-and-ghost-tests).
