# Backfill job-criteria extraction for published jobs in orgs on an active paid plan.
# Base prep — runs regardless of the AI_APPLICANT_SUMMARY flipper.
# Set dry_run = false to actually enqueue. Set org_id to target one org (nil = all orgs).
dry_run = true
org_id  = nil

organizations = org_id ? Organization.where(id: org_id) : Organization.all

eligible = 0
orgs_with_paid_plan = 0
skipped_no_paid_plan = 0
skipped_existing_criteria = 0
skipped_in_flight = 0
skipped_no_description = 0

organizations.find_each do |organization|
  unless organization.active_paid_plan?
    skipped_no_paid_plan += 1
    next
  end
  orgs_with_paid_plan += 1

  organization.jobs.published.find_each do |job|
    if job.description.blank?
      skipped_no_description += 1
      next
    end
    if job.latest_succeeded_ai_job_criteria.present?
      skipped_existing_criteria += 1
      next
    end
    latest_ai_job_criteria = job.latest_ai_job_criteria
    if latest_ai_job_criteria&.status_pending? || latest_ai_job_criteria&.status_in_progress? || latest_ai_job_criteria&.status_retrying?
      skipped_in_flight += 1
      next
    end

    eligible += 1
    job.extract_job_criteria_immediately unless dry_run
    ap "#{dry_run ? 'would enqueue' : 'enqueued'} job #{job.id} (org #{organization.id})"
  end
end

ap(
  dry_run: dry_run,
  orgs_with_paid_plan: orgs_with_paid_plan,
  eligible: eligible,
  skipped_no_paid_plan: skipped_no_paid_plan,
  skipped_existing_criteria: skipped_existing_criteria,
  skipped_in_flight: skipped_in_flight,
  skipped_no_description: skipped_no_description
)
