# SSO / OAuth Session Contract — Pass 2

## Pass 1 correction verification
The F1 amendment (T4.1 devise.mapping) lives in the test angle but protects this angle's test file; verified the amended T4.1 text names the correct mapping key `:api_v1_user` (routes.rb: `devise_for :users` inside `namespace :api/:v1`, `devise_scope :api_v1_user` — the mapping name is `api_v1_user`; `Devise.mappings[:user]` does not exist in this app). ✓ No production-code task in this angle was amended.

## Fresh scrutiny
- B5.1 re-checked: only line 14 changes; the existing loop's `value && !value.empty?` guard was re-traced for the `utm_data` Hash case (Rack parses `utm_data[utm_medium]` inputs into a Hash under `'utm_data'`; `Hash#empty?` exists; a hash with keys passes, an empty hash is dropped — same semantics as the string keys). ✓
- B6.1/B6.2 re-diffed against live `user.rb:379–406`: signature order exactly D9; assignments after `partner_source&.downcase`, before `sign_on_provider`; `ap` debug lines and post-block behavior explicitly preserved. ✓
- B6.3 census discipline: grep-before AND re-grep-after conversion — satisfies pipeline rule 6 (rename cascades). Census re-run again this pass: still exactly `user.rb:379` (definition) + `omniauth_callbacks_controller.rb:22` (sole call site). ✓
- B6.4 keyword call re-diffed against spec §4.7: byte-identical. String-key reads match `merged_tracking` construction (line 15). Posthog job lines 26–28 and redirect line 29 outside the edit. ✓
- F5.2 hidden-input block re-checked: per-key analog guard, Rails-nested naming, `key={key}` on the mapped input, loose `!= undefined` outer guard (house form), snake_case names justified (form POST bypasses `allKeysToSnake`). Degenerate-value divergence (null/"" omitted from SSO path) is the analog's own guard behavior, stated as accepted in the plan. ✓

## Completeness sweep (spec §4.5–4.7, §5.3, D7/D8/D9)
All requirements mapped to B5/B6/F3.5/F5; the accepted cookie-overflow risk (spec Risk 2) is carried in plan Risk 3 as decision-bound. Nothing dropped; no new inconsistencies from Pass 1 amendments.

## Findings
No issues found.

## Amendments Applied
None.
