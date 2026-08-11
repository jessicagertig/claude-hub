# test-coverage-and-ghost-tests — Round 4

Re-audit of §9 after all amendments; all clean.

- The six test files' requirements are internally consistent with the amended mechanism sections (§5.1 raw-string input ↔ Jest occurrence-order case; §9.1 warden/include + login_intent + both existing-user branches; §9.3 warden/include; §9.5 URL pins).
- No FactoryBot in the Gemfile (claim re-verified); `spec/support/api_factories.rb` helpers cover users/organizations setup.
- Ghost-test audit stands: every required assertion still fails when its corresponding spec'd change is deleted; no assertion depends on incidental behavior (the round-2 occurrence-order strengthening removed the last one).
- Cypress constraint text is accurate per the round-3 trace; nothing in the diff can alter the test's observable flow.

## Findings

- None.

## Amendments Applied

- None.
