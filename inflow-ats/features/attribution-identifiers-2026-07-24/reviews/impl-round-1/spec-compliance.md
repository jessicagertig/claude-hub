# Impl round 1 — spec-compliance

Checked every SPEC requirement section-by-section against the committed diff.

- **§3 data model:** 8 users columns + 6 organizations columns, all nullable strings, no defaults/indexes/constraints, no model changes, no backfill; spec-proposed file/class names used verbatim. ✓ Schema commit rule honored (see migrations-and-schema-hygiene).
- **§4 capture rules:** all eight sources and parse rules implemented exactly, including the `_ga` <4-segment raw fallback, the `_gcl_aw` no-raw-fallback rule, first-occurrence repeated-param handling, and the "present = non-empty string" definition for the three conditional rules (see per-identifier-capture-contract). ✓
- **§5.1 helper contract:** signature/contract preserved; first-`=` cookie split; exact-equality name matching; empty-value cookie = absent; 1024 cap on final values; existing fields at 255. ✓
- **§5.2:** `gaSessionId` single raw `"; "`-joined string. ✓
- **§5.3–§5.6:** AuthForm payload + props, SignupForm payload, GoogleSSOButton Props/destructure/hidden inputs (guard form and snake_case names exact), useSession five insertion points. ✓
- **§5.7:** OrganizationForm removal exact and minimal; the three explicitly-protected items (`heardAboutUsFrom`, `window.__adroll.record_user`, `trackEvent("organization_created")`) untouched. ✓
- **§6.1–§6.3:** eight permits before the trailing `utm_data: {}`; eight merge keys in BOTH `magic_create` branches; password path permit-only. ✓
- **§6.4:** eight copy lines in the specced form; two permits removed. ✓
- **§6.5:** `allowed_keys` matches the spec's snippet verbatim. ✓
- **§6.6–§6.7:** 16-keyword signature matching the spec's snippet; eight assignments in the `first_or_create` block; callback extended with the eight string-key reads; mandatory call-site grep satisfied (4 files, all extended). ✓
- **§7 authorization:** no new endpoints, no policy changes; permit narrowing only. ✓
- **§8 constraints:** 1 nil-for-absent ✓ (no fabricated fallbacks anywhere in the diff); 2 raw storage ✓ (no hashing/mapping/downcasing; server stores what it receives — pinned by the >255 test value); 3 creation-time only ✓; 4 single collection point ✓; 5 no serializer exposure ✓ (grep clean); 6 fbc never fabricated ✓; 7 existing capture behavior byte-identical ✓.
- **§10 tests:** all four files extended as directed, including the inversion and both header-comment rewrites; no Jest; no new Cypress. ✓
- **§11 out of scope:** nothing out-of-scope was implemented (no sends, no Insight Tag, no marketing-site code, no backfill, no PostHog change, no serializer change). ✓
- **§13 rulings:** all five RESOLVED decisions honored — gclid URL-first/cookie-fallback (1), 1024 cap (2), raw-string `ga_session_id` (3), per-keyword `from_omniauth` (4), no org-form fallback for the transition window (5). No code contradicts any ruling.
- **§12/§14:** corrections respected; no unrequested mitigation added for the accepted risks.

## Findings

None. 0 BLOCKER / 0 HIGH / 0 MED / 0 LOW.
