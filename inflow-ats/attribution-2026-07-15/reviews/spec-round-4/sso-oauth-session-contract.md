# sso-oauth-session-contract — Round 4

Fresh-eyes probes; all clean.

- Weird captured key names (bracket characters) in `utm_data` hidden-input names: Rack's nested parsing tolerates or 400s crafted forms — tampered-input-only, no session/data damage, same class as any nested-param endpoint. No amendment.
- Callback-phase lambda re-run, `:json` cookie round-trip, string-key recovery, keyword signature, block-only assignment: unchanged from rounds 1–3 verification; re-read of §4.5–4.7 after all amendments shows no drift from source.
- `git grep -ln from_omniauth` re-run: still exactly 2 files.

## Findings

- None.

## Amendments Applied

- None.
