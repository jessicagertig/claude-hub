# SPEC REVIEW — COMPLETE

**Date:** 2026-07-16 02:30
**Spec:** `/Users/jessica/claude-hub/inflow-ats/attribution-2026-07-15/SPEC.md`
**Repo state reviewed:** branch `attribution-work` at 62dd55867, working tree clean except the intentional uncommitted `app/javascript/shared/lib/posthog.ts` diff (part of the feature; untouched by review).

## Final verdict: READY FOR PLANNING

Two consecutive full passes (rounds 4 and 5) with zero MED+ findings and zero amendments, within the 5-round cap. One open question for Jessica is recorded below — it does not change any implementable line of the spec (the diff to build is identical with or without her ruling), so planning can proceed; her ruling would scope a possible follow-up increment.

## Round outcomes

| Round | Verdict | Findings | Amendments |
|---|---|---|---|
| 1 | FAIL | 1 BLOCKER (D12 event placement vs posthog init timing — see round-2 correction), 1 HIGH (query-string v6.1.0 parse sorts keys alphabetically → §5.1 input contract could not satisfy D4's occurrence-order rule), 4 MED (email_verified guard scope; Devise::Test::ControllerHelpers/warden; login_intent 'hire' needed to dodge a pre-existing `organization.id`-on-nil crash branch; utm_data per-key input guard), 6 LOW | 8 |
| 2 | FAIL | 1 HIGH (round-1 amendment rationale corrected: the ungated `useOrganization` query means Auth.tsx currently mounts after posthog.init — round-1 BLOCKER was overclaimed; two-effect mechanism retained as strictly more robust), 2 MED (existing-unconfirmed-branch not-modified test; §9 preamble coherence), 3 LOW | 3 |
| 3 | FAIL | 1 HIGH (email_verified fires only for signed-out confirmations — `Hire::PagesController#redirect_if_authed` + `active_for_authentication?` override; disclosed as Risk 7, mechanism unchanged) | 2 |
| 4 | PASS | 0 | 0 |
| 5 | PASS | 0 | 0 |

## Plain English Summary

When someone arrives at the app's signup or login pages from an ad or a marketing link, the address bar often carries little tags describing where they came from. Today those tags are thrown away. This change catches them at the door, cleans them up (trims absurd lengths, caps how many extras are kept), and writes them onto the person's account at the moment it is created — and later copies them onto the company workspace the person creates. Nothing is guessed or backfilled: tag-less arrivals get blank fields, and existing accounts stay untouched.

Separately, the browser itself will now announce the key funnel moments to the analytics tool — "submitted their email," "verified their email," "entered their name," "created a company workspace" — and will tell the analytics tool who the person is when they land from the email-verification link. All existing server-side announcements stay untouched as a backup layer.

## Blast Radius (post-review)

- **Behavior changes:** confirmation redirect URL gains `id` + URL-encoded `email` params (same path, failure branch untouched); `User.from_omniauth` goes keyword-only (single call site, converted in-PR, repo-wide re-search mandated); omniauth setup lambda whitelists four more keys; signup payloads carry up to four new fields (unknown-param tolerant in both directions).
- **Modified files:** 7 backend surfaces + 8 frontend files + 2 new migrations + 6 new test files; nothing else (serializers, policies, jobs, api.ts, contexts, Cypress all zero-diff).
- **If wrong, what breaks:** worst case is a missed positional `from_omniauth` caller (ArgumentError on every SSO login — mitigated by census + specs) and the confirmation redirect (critical signup path — trivial change, spec'd tests + Cypress traverse it). Everything else degrades to today's behavior (nil columns, skipped events).

## Spec amendments applied during review (13 total)

Round 1:
1. §5.6 rewritten — identify+track moved out of the mount effect into a `useEffect` keyed on the existing `emailConfirmed` state; single both-params-present guard covers BOTH `identifyUser` and `trackEvent("email_verified")`.
2. §5.1 input contract — helper takes the raw `location.search` string; key order derived from the raw string (query-string v6.1.0 parse sorts keys alphabetically, no opt-out), values from `queryString.parse`.
3. §5.2 + §5.5 capture bullets — pass `location.search` (not the parsed object) into the helper.
4. §9.6 Jest — occurrence-order test must use non-alphabetical param order (anti-ghost).
5. §9.1 — `include Devise::Test::ControllerHelpers` (warden; precedent `bulk_ai_job_application_summaries_controller_spec.rb:7`) + mandatory `login_intent: 'hire'` on every `magic_create` POST (routes around the pre-existing `organization.id`-on-nil connect branch, lines 88–97 — explicitly NOT fixed in this PR).
6. §9.3 — `include Devise::Test::ControllerHelpers` for the omniauth callback spec.
7. §5.3 — `utm_data` hidden inputs rendered per-key behind the analog guard `typeof value === "string" && value.length > 0`.
8. §8 — analog line ref `NewJobCenterModal.tsx:47` → `:46`.

Round 2:
9. §5.6 timing paragraph corrected (round-1 rationale was wrong: the ungated `useOrganization` query currently delays Auth.tsx past `posthog.init`; mechanism retained because it is robust to that gate being removed).
10. §9.1 — existing-UNCONFIRMED-user branch not-modified bullet added.
11. §9 preamble — Devise-controller specs opt into the helpers per-file (coherence).

Round 3:
12. §11 Risk 7 added — `email_verified` coverage boundary (see Open Questions).
13. §10 — coverage-fix mechanisms scoped as a new decision outside this PR.

## Open questions for Jessica (recorded, not blocking planning)

1. **HEADLINE — `email_verified` fires only for confirmations clicked while signed out (Risk 7 in the spec).** Verified chain: signups are signed in while unconfirmed (`User#active_for_authentication?` is `super || organization.nil?`, user.rb:136–138), and `Hire::PagesController#redirect_if_authed` (routes.rb:591 → pages_controller.rb:24–31) 302s any signed-in `/auth` request to `app_root_path`, dropping all query params — so the typical same-browser confirmation click never renders `Auth.tsx`. The event captures cross-device / logged-out / browser-restarted confirmations only, and funnel step 3 has no server backup. The D12 mechanism is built exactly as decided; the decision was made without this fact on the table (neither funnel-audit.md nor identify-findings.md mentions `redirect_if_authed`). Options if the boundary is unacceptable: (a) fire the event at the post-bounce app-root landing (new decision — needs a signal that the arrival came from confirmation), (b) server-side `PosthogTrackJob`/`PosthogIdentifyJob` at `confirmations#show` success (the never-approved D11 topic; deviates from browser-first), (c) accept the undercount until the marketing-site round. The existing "Email address confirmed. Log in to continue." banner has had this same property all along.
2. Round 1's BLOCKER was corrected in round 2: the original mount-effect placement would currently work (the ungated `useOrganization` query delays Auth.tsx's mount past `posthog.init`). The spec keeps the state-keyed effect because it survives the plausible `enabled:` cleanup on `useOrganization`. If Jessica prefers the simpler mount-effect placement anyway, that is a one-line spec change — but the robust form costs nothing extra.
3. LOW items left as recorded facts (no spec change): case-sensitive `utm_` prefix matching; a literal `?utm_data=x` param nests inside `utmData`; `utmData` key LENGTH is uncapped (D4 caps count and value length only); hand-tampered `id`/`email` params can fire a polluted identify (same class as accepted Risk 6); percent-encoded key names must be decoded before order-matching (plan-level).

## Handoff notes for the planning phase

- The pre-existing `magic_create` connect-branch crash (`organization.id` on nil, registrations_controller.rb:88–97) is OUT of scope — tests route around it via `login_intent: 'hire'`; do not fix it in this PR.
- The `posthog.ts` working-tree diff is part of this feature — commit as-is, no further edits to that file.
- Every §9 test file is new; none exist today (re-verified each round).
