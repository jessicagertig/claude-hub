# criteria-enqueue transaction safety (W3) — Round 2

Re-reviewed the amended W3 (option b primary, string-key fix, skip_update_callback, only-the-call-relocates) end to end.

## Findings
- F1 [HIGH] -- (carried from source-accuracy R2) the Round-1 amendment used symbol keys for `previous_changes`; `previous_changes` is string-keyed (analog `:497` maps to_sym). Fixed in Round 2 (string keys / `saved_change_to_*`). Without this, option (b) detection would silently never fire. APPLIED (Round 2).

## Re-verified correct
- skip_update_callback non-gating requirement: confirmed `handle_after_update_commit` returns at `:492` on the flag, set by `Settingsable` (`:22,40,51`); the amendment requires the criteria extraction to run irrespective of it (before `:492` or a dedicated after_commit). CONFIRMED preserves today's before_update behavior (which ignores the flag).
- description dirty-tracking trap: `description_meaningfully_changed?` reads `description_was` (`:735`) -> reset in after_commit; amendment mandates `previous_changes['description']`/`saved_change_to_description` rewrite. CONFIRMED.
- only the `auto_extract_job_criteria` call relocates (`:560`,`:731`); `touch`/`update_column`/other perform_laters stay. CONFIRMED.
- V1 race + post-commit save-then-enqueue fix; out-of-txn callers untouched (`orchestrate.rb:80`, `score_job_application.rb:23,45`). CONFIRMED.
- debounce/Flipper/poison guards preserved (live inside `auto_extract_job_criteria`, called whole). CONFIRMED.

## Amendments Applied (Round 2)
- (via source-accuracy) SPEC.md W3 line 74: string keys / saved_change_to_* for previous_changes.
