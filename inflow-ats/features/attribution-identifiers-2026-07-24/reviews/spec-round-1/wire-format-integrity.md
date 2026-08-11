# spec-round-1 — wire-format-integrity

Reviewed SPEC.md §§5.5, 5.6, 6.1, 6.5, 14.5 and code-task-list.md T7/T8/T10/T14 against live source, branch `attribution-work-qa` tip `b4cb4463a`.

No issues found.

## Verification evidence

**1. All eight lodash `snakeCase` transforms, run empirically against the repo's installed lodash** (`node -e "require('lodash').snakeCase(...)"` from the repo root):

```
gaClientId             -> ga_client_id
gaSessionId            -> ga_session_id
fbclid                 -> fbclid
fbp                    -> fbp
fbc                    -> fbc
liFatId                -> li_fat_id
googleClickId          -> google_click_id
adrollFirstPartyCookie -> adroll_first_party_cookie
```

All eight equal the spec's wire names exactly; the three single-word names pass through unchanged as §14.5 claims.

**2. `allKeysToSnake` mechanism** (`app/javascript/ats/src/lib/utils/structure.js:94-108`): `newObject[snakeCase(key)] = allKeysToSnake(object[key], modifyValues)` — every key through lodash `snakeCase`, recursion into nested plain objects, values untouched (a value is transformed only when the caller passes a `modifyValues` entry for its key; `apiMutate` passes none). `api.ts` `apiMutate` line 52: `data: skipKeysToSnake ? variables : allKeysToSnake(variables)` — `useSession.ts` `register` and `magicLink` do not set `skipKeysToSnake` (only `login` does), so the transform applies to both payloads.

**3. RESOLVED-decision rationale spot-check (§5.2 / §12.5):** `_.snakeCase('_ga_ABC123XYZ') -> 'ga_abc_123_xyz'` — the spec's claim that a jsonb keyed by GA cookie names would be mangled in transit is mechanically correct (leading underscore dropped, container ID split on case/digit boundaries; the measurement ID is destroyed). The raw-string ruling's stated rationale holds.

**4. Four-way name equality chain** for each of the eight: hidden-input name (§5.5) = `allowed_keys` entry (§6.5) = `sign_up_params` permit symbol (§6.1) = column name (§3) = `snakeCase(<camelCase payload field>)`. Verified pairwise; no mismatches.

**5. Edit points exist as described:**
- `registrations_controller.rb:312` — current permit ends `..., :internal_ref, :adroll_click_id, utm_data: {})`; adding eight plain symbols before the trailing `utm_data: {}` hash permit is implementable exactly as §6.1 states.
- `config/initializers/omniauth.rb:14` — live line is `allowed_keys = %w[partner referral utm_source utm_campaign utm_data internal_ref adroll_click_id]`; §6.5's proposed replacement is this list plus the eight, no drops.
- `useSession.ts` — `register` (destructured params + `variables`, no inline type) and `magicLink` (destructured params + inline TS type + `variables`); §5.6 correctly names the inline TS type as magicLink-only and `?: string | null` matches the existing tracking fields' style.
- `GoogleSSOButton.tsx:61-78` — existing guard is exactly `typeof x === "string" && x.length > 0` per hidden input; all existing tracking inputs are plain single-value except the `utm_data[<key>]` nested family, which the eight correctly avoid (§5.5).
- Column names: organizations already carry `google_click_id` (schema.rb:1078) and `adroll_first_party_cookie` (schema.rb:1094); users carry the analog `adroll_click_id` (schema.rb:1291).

## Amendments Applied

None — orchestrator applies amendments. None recommended from this angle.
