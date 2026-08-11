# Hardening Report — textract-keyword-search

## Rules Added

### Rule 26: Test assertions must be falsifiable by removing the feature under test

**Source:** impl-round-1 BLOCKER (ghost test)

**Pattern:** A test for `retry_on exhaustion` used `expect(described_class.instance_method(:perform)).to be_a(UnboundMethod)` -- trivially true for any class with `perform`. Also assigned `retry_config = described_class.rescue_handlers` but never asserted on it. The test passed regardless of whether `retry_on` existed.

**Rule scope:** Defines what makes a test a ghost test: an assertion that passes whether or not the feature under test exists. Provides a mental model (delete the declaration, does the test still pass?) and lists common tautological patterns. Gives specific guidance for `retry_on` testing (behavioral test with `have_enqueued_job`, not reflection).

**Why new:** Jessica's memory has "Ghost tests are blockers" (severity guidance) but no CLAUDE.md rule defined how to identify a ghost test. Rule 14 (analog structural matching) mentions retry/exhaustion as a structural concern but does not address test assertion quality. This rule fills the gap between "ghost tests are bad" and "here is how to detect one."

## Existing Rules Violated

**Rule 3 (Specs and plans must include test requirements):** Spec-round-1 HIGH F3 found zero mention of tests in the spec. This is a direct violation of Rule 3, which was added after the email-subjects-phase-1 spec review. The spec author did not check CLAUDE.md before writing. The spec review caught it and the test section was added.

## Findings Skipped (Not Hardened)

### impl-round-1 HIGH: schema.rb not committed

**Reason:** FALSE POSITIVE. The owner explicitly excludes `db/schema.rb` from commits in this workflow. Not a pattern to codify -- it is a deliberate workflow choice, not an error.

### spec-round-1 HIGH F1: Missing trigger SQL file + .gitignore conflict

**Reason:** One-off. Specific to the `fx` gem's `create_trigger` requiring a SQL file at a path that `.gitignore` blocks. The fix (switching to `sql_definition:` inline) is gem-specific, not a generalizable pattern.

### spec-round-1 HIGH F2: Flattening algorithm unspecified

**Reason:** Already covered by general spec quality expectations. The spec said "flattens structured data" without defining the algorithm. This is a spec completeness issue, not a recurring pattern -- every spec should define its algorithms. No new rule needed.

### spec-round-2 MED findings (5 items)

**Reason:** All were internal consistency and completeness issues (stale "OR" language, missing `has_many` declaration, unspecified `call_type` value, unspecified organization navigation path, generic error class name). These are normal spec refinement findings caught and resolved by the review loop. None represent a recurring pattern that would benefit from a rule.

### spec-round-3 MED: Test description contradicts service error behavior

**Reason:** One-off internal inconsistency (test description said "does not raise" while service section said "raises"). Normal spec review fix, not a pattern.

### impl-round-2 LOW: Missing exhaustion block test

**Reason:** The exhaustion block only logs. Testing it requires simulating 3 consecutive failures. The retry_on re-enqueue IS tested. Low value relative to complexity.

### impl-round-3 LOW: Defensive guards on tsvector migration

**Reason:** The migration used `unless column_exists?` / `unless index_exists?` guards that the reference migration did not have. This is a no-op defensive deviation, not a behavioral difference.
