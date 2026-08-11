# Layer 2 — Error Class + Gemfile

**Files reviewed:**
- `app/errors/custom_error_structured_extraction.rb`
- `Gemfile` (line 126)
- `Gemfile.lock` (fx resolution)

---

## Error class

**Class hierarchy:** `CustomErrorStructuredExtraction < StandardError` — correct. Matches analogs `CustomErrorTextract` and `CustomErrorAiSummary` exactly (identical class body, only default msg differs).

**Initialize signature vs. call sites:** `initialize(msg = '...', param = '')` accepts one positional arg for the message. Both call sites use `raise CustomErrorStructuredExtraction, e.message` which passes `e.message` as the first positional arg (`msg`). This is correct — Ruby's `raise ErrorClass, string` calls `ErrorClass.new(string)`.

**`param` attribute:** Never read on this error class or its analogs (`CustomErrorTextract`, `CustomErrorAiSummary`). Only `CustomMissingParamError.param` is read (in `unregistered_job_controller.rb`). The `param` attr is dead code on all three classes — but it's inherited from the codebase pattern and harmless.

## Gemfile

**Placement:** `gem 'fx', '~> 0.8.0'` at line 126, immediately after `gem 'pg_search', '2.3.2'` at line 125. Correct grouping.

**Resolution:** `Gemfile.lock` resolves `fx (0.8.0)` with deps `activerecord (>= 6.0.0)` and `railties (>= 6.0.0)`. Project has `activerecord 6.1.7.7` and `railties 6.1.7.7`. Deps satisfied.

**Migration availability:** Confirmed by reading fx 0.8.0 source. `Fx.load` (called via Railtie) includes `Fx::Statements` into `ActiveRecord::ConnectionAdapters::AbstractAdapter`, making `create_trigger` and `drop_trigger` available in migrations.

---

VERDICT: CLEAN — 0 findings
