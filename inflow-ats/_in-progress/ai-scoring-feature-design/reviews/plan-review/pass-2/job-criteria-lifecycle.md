# Pass 2 — job-criteria-lifecycle

## Verification of Pass 1 corrections

No corrections in this angle. Pass 1 had no findings.

## Fresh-eyes re-read

Re-examined the interaction between publish and description-change callbacks:

**Scenario: User publishes a job (status changes to published)**
1. `handle_before_update` fires (line 475)
2. `changed?` is true (status changed)
3. `handle_status_change` fires -> `handle_status_changed_to_published` fires -> `extract_job_criteria` called
4. `handle_description_change` fires -> `description_changed?` is false (description didn't change) -> returns immediately

Result: `extract_job_criteria` called once. CORRECT.

**Scenario: User changes both status to published AND description in one save**
1. `handle_status_change` -> `handle_status_changed_to_published` -> `extract_job_criteria` (creates record, enqueues job)
2. `handle_description_change` -> `description_changed?` true -> `published?` true -> `description_meaningfully_changed?` true -> `extract_job_criteria` -> sees `pending` -> returns (debounce)

Result: `extract_job_criteria` called twice, but the second call is debounced. CORRECT.

**Scenario: User changes description of an already-published job, with existing succeeded criteria**
1. `handle_description_change` -> all guards pass -> `extract_job_criteria`
2. `extract_job_criteria` sees existing criteria with `succeeded` status -> resets to `pending` -> enqueues new job

Result: Re-extraction triggered. CORRECT per spec.

## Final completeness sweep

No gaps. The `extract_job_criteria` method handles all status combinations correctly.

## Findings

No findings.
