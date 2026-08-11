# Spec review round 1 — findings rejected, with the evidence that refutes them

## R1. "Use `app/jobs/export_job_candidates_to_csv_job.rb` as the job-level error-logging analog"

**Finding text:** "Replace the bullet with: **Job-level error logging**: `app/jobs/export_job_candidates_to_csv_job.rb`
... writing `ap` with a message, `ap` with the exception, `Rails.logger.error` with a message, and
`Rails.logger.error` with the exception."

**Refuted by** `app/jobs/export_job_candidates_to_csv_job.rb:19-22`:

    rescue StandardError => e
      Rails.logger.error 'Could not export Candidates'
      Rails.logger.error e
    end

Two `Rails.logger.error` lines and no `ap` — the same defect the finding correctly identifies in
`app/jobs/discord/notify_trial_converted_to_paid_job.rb:19-22`. The named replacement has the same problem as
the file it replaces.

**What was applied instead:** `app/jobs/export_organization_candidates_to_csv_job.rb:22-25`, which does carry
the full pattern (`Rails.logger.error e`, `ap 'Could not export organization candidates to CSV'`, `ap e`) and
matches `cursor_rules/backend/_base.md:91-96` exactly. A parallel finding proposed
`app/jobs/hiring_stage_message_automation_job.rb:43-46`; that file writes one `ap` label plus
`Rails.logger.error e` and then broadcasts a UI error message, which is a shape these three jobs must not
copy, so the export job was preferred.

## R2. "`Api::V1::OrganizationsController#create` gains a method-level rescue because `perform_later` introduces a new failure mode there"

**Finding text:** "`Api::V1::OrganizationsController#create` enqueues nothing today, so it gains a
method-level `rescue StandardError` ... so a queue failure cannot turn a saved organization into a 500."

**Refuted by** `app/models/organization.rb:56` and `:180-190`:

    after_commit  :complete_setup_workers, on: [:create]

    def complete_setup_workers
      create_careers_page
      OrgSetupJob.perform_later(id)
      NotifyNewOrganizationJob.perform_later(id)
      Discord::NotifyNewOrganizationJob.perform_later(id)
    end

`@organization.save` at `organizations_controller.rb:48` fires that callback, so the action already performs
three `perform_later` calls — and already raises on a Redis outage — before control reaches the line the new
enqueues would occupy. The premise "enqueues nothing today" is false, the failure mode is pre-existing, and
adding a rescue to a controller action that no finding identified as defective is out-of-scope work under
pipeline rule 23.

The same review run's failure-and-absence angle reached this conclusion independently and recorded it as a
check that passed.

## R3. "The event-name → conversion-action-ID mapping is a frozen hash constant on `SendGoogleAdsConversionJob`"

**Finding text:** "The mapping from event name to conversion action ID is a frozen hash constant on
`SendGoogleAdsConversionJob` ... `GoogleDataManagerApi::Client` receives the resolved conversion action ID and
never sees the event name."

**Refuted by** `cursor_rules/backend/background_jobs.md:97-99` ("Jobs Orchestrate — Don't Contain Business
Logic. Delegate actual work to models or services") and by three other findings in the same run that place the
mapping in the service. Selecting a destination's payload identifier from a destination-facing event name is
destination-payload logic, not orchestration.

**What was applied instead:** the mapping lives on `GoogleDataManagerApi::Client` as an explicit frozen hash
constant with the five verbatim camelCase keys; the job passes the event name and never sees a conversion
action ID. The rest of that finding — pin the five strings verbatim, no `underscore`/`camelize`/`const_get`
derivation, no snake_case spelling anywhere — was applied in full.
