# Plan review pass 1 — creation-time-only-and-existing-behavior-unchanged

Reviewed: plan.md T11, T15, T12, §5.2 lifecycle, §7 against SPEC §8.3/§8.7 and live code @ `b4cb4463a`.

## Fact checks performed (all verified live)

- `magic_create` conditional spans :88-117; tracking merges at :97-101 (connect branch) and :111-115 (else branch), both ending `adroll_click_id: sign_up_params[:adroll_click_id]` — T11 adds to BOTH branches at the exact anchors.
- Existing-user branches: `User.find_by(email: user_params[:email])` at :119; the confirmed/unconfirmed paths read only `user_params[:email]` — inert to the eight new merge keys, as the plan states. (The connect branch's pre-existing `organization.id`-on-nil landmine is documented in the spec file header :10-13 and is out of scope; T17e's `login_intent: 'hire'` requirement keeps specs off it.)
- Password `#create`: `expanded_params = sign_up_params.merge(...)` :13 → `build_resource(expanded_params)` :20 — nothing beyond the T10 permit needed, per SPEC §6.3.
- `from_omniauth`: assignments only inside the `first_or_create` block (:385-398); post-block `update` touches only names — existing SSO users never receive attribution values. T15 adds assignments inside the block only.
- Org values only via `#create` copy (:31-36 extended by T12); T13 removes the last request-param path. No update path, no backfill anywhere in the plan — consistent with §5.2 lifecycle and manifest rows 23/24 ("any new write moment is an automatic mismatch").
- Existing behavior byte-identical: the defaulted `maxLength` param leaves all five existing `sanitizeTrackingValue` call sites (:60/:63/:66/:69/:85) at 255; `utm_data` occurrence-order logic (:45-56, :72-88) untouched by the insertion point; `adroll_click_id` chain untouched at every layer.
- Serializer absence: plan §4 "Deliberately NOT touched" lists all serializers; no plan task edits any serializer.

## Findings

None. 0 BLOCKER, 0 HIGH, 0 MED, 0 LOW.
