# params-threading-contract — Round 4

Fresh-eyes probes on the wire contract; all clean.

- `permit(utm_data: {})` accepts nesting from crafted input (`utm_data[a][b]`) — stored raw-as-sent to jsonb; approved semantics (D3), no crash path.
- Conflicting-shape crafted input (`utm_data=x&utm_data[y]=z`) is rejected by Rack/Rails parameter parsing before controller code — pre-existing platform behavior, not introduced by this diff.
- `magicLink`/`register` do not use `skipKeysToSnake`; the new camelCase fields ride `allKeysToSnake` as analyzed in rounds 1–2.
- No model attribute/method collisions for the four new column names (`git grep` across `app/models/` — only a URL string literal in `board_wwr_listing.rb` mentions `utm_source`).
- §4.2's branch-inertness claim re-verified including the unconfirmed branch (`accept_invite` reads `params[:invite_token]`, not `user_params`).

## Findings

- None.

## Amendments Applied

- None.
