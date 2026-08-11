# Layer 1 Round 2 — Migrations + Trigger (Deviation Assessment)

## L1-MT-1: `unless column_exists?` / `unless index_exists?` guards

**Assessment: ACCEPTED DEVIATION — justified but not strictly necessary.**

The `keyword-search-connect-version` branch was **never merged to develop** (`git merge-base --is-ancestor` confirms). Its migrations (`20260106002106`, `20260106002844`) do not appear in `db/schema.rb`'s version list. So there is no production or shared environment where the column/index already exists from the reference branch.

The guards are defensive against Jessica's local dev database if she previously ran the reference branch's migrations during development. This is a reasonable local-dev safeguard but not strictly required for the codebase at large. Since it doesn't change behavior (column/index still get created on clean databases) and only prevents an error on databases where Jessica tested the reference branch, this is a safe deviation.

**Verdict: ACCEPTED.** The guards are harmless and defensively useful in the developer's environment.

## L1-MT-2: `def up/down` instead of `def change`

**Assessment: ACCEPTED DEVIATION — but for different reasons than originally stated.**

Reading the fx 0.8.0 source reveals that `create_trigger` with `sql_definition:` IS reversible under `def change`:

- `CommandRecorder::Trigger#invert_create_trigger(args)` returns `[:drop_trigger, args]`
- `Statements::Trigger#drop_trigger` only uses `options.fetch(:on)` (ignores `sql_definition`)
- Rollback would execute `DROP TRIGGER tsvectorupdate ON textract_results;`

So `def change` WOULD work — rollback would drop the trigger. The original assessment ("fx cannot auto-reverse inline SQL") was **incorrect**.

However, `def up/down` is still a justified deviation for a DIFFERENT reason: the `down` method doesn't just drop the trigger — it **recreates it with `textract_job_result_text`**, restoring the old reference trigger behavior. A `def change` rollback would only drop the trigger entirely, leaving the database with no trigger at all. The `def up/down` approach provides a **richer rollback** that restores the prior state.

The `execute 'DROP TRIGGER IF EXISTS tsvectorupdate ON textract_results'` in `up` is also justified: it handles the case where the reference branch's trigger already exists (same trigger name, different source column), preventing `PG::DuplicateObject`.

**Verdict: ACCEPTED.** `def up/down` provides better rollback semantics than `def change` (restores old trigger vs. drops entirely), and the `DROP IF EXISTS` handles pre-existing trigger conflicts.

---

**VERDICT: CLEAN — 0 findings (2 accepted deviations from R1)**

Both deviations are justified:
- L1-MT-1: Harmless defensive guards for local dev environment
- L1-MT-2: Richer rollback behavior + pre-existing trigger conflict handling (note: original "can't reverse" rationale was wrong — fx CAN reverse, but the implementation's rollback is intentionally richer)
