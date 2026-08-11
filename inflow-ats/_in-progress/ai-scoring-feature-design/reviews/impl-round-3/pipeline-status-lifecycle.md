# pipeline-status-lifecycle -- Round 3

## Files reviewed

- `app/models/ai_job_application_summary.rb` (committed) -- enum definition, callbacks
- `app/services/ai_job_application_action/summary/generate.rb` (committed vs working tree)
- `app/services/ai_job_application_action/orchestrate.rb` (committed)
- `app/services/ai_job_application_action/scoring/score_job_application.rb` (committed)
- `app/services/ai_job_application_action/scoring/integrate_analysis.rb` (committed)
- `app/interactors/create_ai_summary_generation.rb` (committed vs working tree)

## Findings

### BLOCKER: Summary::Generate has 6 stale references to removed enum values (UNCOMMITTED FIX)

The committed code on HEAD (`git show HEAD:app/services/ai_job_application_action/summary/generate.rb`) contains references to `status_in_progress?`, `status: :in_progress`, `status: :extracted`, and `status: :succeeded` -- all of which have been removed from or redefined in the `AiJobApplicationSummary` status enum.

Stale references in committed code:
- Line 31: `existing_ai_summary.status_in_progress?` -- `in_progress` removed from enum
- Line 32: `status: :in_progress` -- removed from enum
- Line 32: `status_in_progress?` -- removed from enum
- Line 38: `status: :in_progress` -- removed from enum
- Line 65: `status: :extracted` -- removed from enum
- Line 163: `status: :succeeded` -- spec says Generate must NOT set `succeeded`

A fix exists as uncommitted local changes in the working tree (replacing with `status_extracting?`, `status: :extracting`, `status: :summarizing`, and removing `status: :succeeded`), but these changes have never been committed to the branch.

**Impact:** Any call to `Summary::Generate` from committed code will throw `ArgumentError: 'in_progress' is not a valid status` at runtime. This blocks the entire pipeline -- no summary can be generated.

**Severity:** BLOCKER

This is a Known Failure Pattern #6 (rename cascades) violation. The plan Phase C explicitly listed these as tasks C.1.1 through C.1.9, and the fix was implemented locally but never committed.
