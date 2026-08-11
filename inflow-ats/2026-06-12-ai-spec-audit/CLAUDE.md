# AI Backend Spec Audit

**Round 2 branch:** `UI-polishes` (2026-06-18)
**Round 1 branch:** `feature-ai-summaries-integrating-scoring-v3` (2026-06-12)
**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats`
**Scope:** All new/modified backend spec files for AI features (summaries, credits, scoring). NOT Cypress.
**Source handoff:** `~/claude-hub/inflow-ats/_in-progress/ai-scoring-feature-design/HANDOFF-TEST-VERIFICATION.md`

## Three audit prongs

Every spec file is audited on three axes:

1. **Does the test work?** — Runs, passes, is not a ghost (assertions actually exercise the subject, not stubs or factory side effects).
2. **Does the test test what it claims?** — Stubs match real method signatures and return types. Assertions target the right behavior. Coverage spans the code paths described in the `describe`/`context` blocks.
3. **Has the spec drifted from the code under test?** — Read the production code and compare against what the spec exercises. Flag: branches the production code has that the spec doesn't cover, method signatures that changed since the spec was written, callbacks or error paths added to production that the spec doesn't know about, stubs referencing old argument shapes or return types.

Prong 3 is NOT a production code review. The production code is not in scope for correctness. Prong 3 asks only: does the spec still reflect the production code's actual shape?

## Terminology

- **"spec file"** — the test code (e.g., `apply_ai_credit_purchase_spec.rb`)
- **"code under test"** — the production code the spec targets (e.g., `ApplyAiCreditPurchase` interactor)
- **"file chain"** — spec file → code under test → its dependencies (e.g., `apply_ai_credit_purchase_spec.rb → ApplyAiCreditPurchase → OrganizationAiCreditBalance → AiCreditBalanceTransaction`)

Do NOT use the word "implementation" — it is ambiguous in a test-audit context (could mean "how the test is implemented" or "the production code").

## Methodology: Deep Investigation Per Spec

This is NOT a feature lifecycle. No spec writing, no planning, no feature implementation. This is a code investigation — each spec file gets the full investigation discipline treatment.

### Required reading BEFORE starting any audit work

Read these once at session start. Do not skip. Do not assume you know what's in them.

- `cursor_rules/core_critical_rules.md`
- `cursor_rules/backend/_base.md`
- `cursor_rules/backend/core_critical_rules.md`
- The source repo's `CLAUDE.md`

If an area-specific `cursor_rules/backend/` file exists for the type under audit (e.g., `services.md`, `interactors/`, `background_jobs.md`), read that too.

### Per-spec investigation protocol

For EACH spec file, execute ALL of the following steps. Do not skip steps. Do not batch multiple specs into one pass.

#### Step 1: Read the spec file (Prong 1 + 2)

Read the entire spec file. Note every:
- `describe`/`context`/`it` block and what it claims to test
- `let`/`let!` declarations and what they set up
- `before`/`after` blocks
- Every stub (`allow`, `expect(...).to receive`, `instance_double`, `class_double`)
- Every factory call and its traits/overrides
- Every assertion (`expect`, `is_expected`)

#### Step 2: Read the code under test (Prong 2 + 3)

Read the FULL production file that the spec targets. Not a summary — the entire file. For every identifier encountered in the code under test (methods called, constants referenced, classes instantiated, modules included, concerns extended, callbacks registered), trace to its definition. Continue tracing until every identifier's definition has been located and read. Stop tracing at the framework/gem boundary.

Print the file chain before any finding (e.g., `apply_ai_credit_purchase_spec.rb → ApplyAiCreditPurchase → OrganizationAiCreditBalance → AiCreditBalanceTransaction`).

#### Step 3: Stub audit (Prong 2)

For EACH stub in the spec:
1. Find the real method being stubbed in the code under test (or its dependencies)
2. Compare the stub's argument expectations to what production code actually passes
3. Compare the stub's return value to what the real method actually returns
4. Flag any mismatch — argument types, argument count, return shape, side effects the stub hides

This is Known Failure Pattern #7. Stubs that accept arguments the real code never passes, or return shapes the real code never returns, mask production failures.

#### Step 4: Ghost test detection (Prong 1)

For each `it` block, answer: "If I deleted the production code this test claims to exercise, would this test fail?"

Ghost test indicators:
- Test asserts on factory-created data without exercising the subject
- Test stubs the method under test and then asserts on the stub's return value
- Test asserts on a side effect that happens in a `before` block, not in the subject call
- Test uses `is_expected` but the subject doesn't invoke the code path being described
- Test passes because the stub does the work, not because the production code does

If you suspect a ghost, describe exactly which `it` block, what it claims to test, and why the assertion would pass even without the production code.

#### Step 5: Drift detection (Prong 3)

Compare the spec's test cases against the code under test's CURRENT state:
- Every conditional branch (`if`/`unless`/`case`/`when`) in production — does the spec have a test for each branch?
- Every error/exception path in production — `raise`, `fail!`, `context.fail!` — does the spec exercise it?
- Every guard clause and early return in production — is there a corresponding test?
- Every callback (`before_validation`, `after_commit`, `after_create`, etc.) in production — does the spec know about it?
- Method signatures — do the spec's stubs and calls use the current argument list?
- Return types — do the spec's assertions match what the production code currently returns?

A passing spec does NOT mean there is no drift. Stubs hardcode old return values and argument shapes — the spec passes because the stub returns what the test expects, not because the production code still works that way. Ghost tests pass regardless of what production does. The ONLY way to detect drift is to read the code under test and compare it against what the spec exercises. A green test suite is not evidence of alignment.

This step is about alignment, not coverage perfection. The question is: "Does this spec reflect the production code as it exists NOW, or has the production code moved on?"

List drifted paths by production file and line number.

#### Step 6: Convention check (Prong 2)

Compare against `cursor_rules/backend/_base.md` and area-specific rules. Check:
- Factory usage patterns (traits vs. overrides, `create` vs. `build`)
- Stub patterns (which things should be stubbed, which should not)
- `describe`/`context`/`it` naming conventions
- Shared example usage where appropriate
- `subject` declaration patterns
- Raw integer enum references (should use symbols)

#### Step 7: Write findings

For each spec, write findings to the appropriate category file. Each finding must include:
- **Prong** — which of the three prongs (works / tests what it claims / drift)
- **File chain traced** — spec file → code under test → dependencies
- **Severity** — BLOCKER (test is fundamentally broken/misleading, OR is a ghost test), HIGH (masks a real bug or missing critical coverage), MED (convention violation or minor gap). **Ghost tests are always BLOCKER** — a test that doesn't test what it claims is worse than no test, because it creates false confidence that coverage exists.
- **Location** — exact file and line number(s)
- **Evidence** — what the spec does, what the code under test does, why they don't match
- **No speculation** — if you can't verify a finding by reading the code, it's not a finding

## Files by category (Round 2 — 42 specs)

- `interactors.md` — 13 specs (3B/10H/25M)
- `jobs.md` — 5 specs (5B/10H/8M)
- `models.md` — 12 specs (2B/5H/24M)
- `services.md` — 8 specs (4B/12H/11M)
- `other.md` — 4 specs (0B/0H/11M)

**Total: 14 BLOCKER, 37 HIGH, 79 MED across 42 specs (2 clean)**
