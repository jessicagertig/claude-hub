def ai_summary_failures_for_organization(organization_id)
  organization = Organization.find(organization_id)
  ap "===== AI SUMMARY FAILURES: #{organization.name} (##{organization.id}) =====", color: { string: :white }

  failed_ai_job_application_summaries = AiJobApplicationSummary
    .where(status: :failed)
    .joins(job_application: :job)
    .where(jobs: { organization_id: organization.id })
    .includes(job_application: :job)
    .order(:created_at)

  ap "----- Count -----", color: { string: :cyan }
  ap failed_ai_job_application_summaries.count

  ap "----- By error_message -----", color: { string: :cyan }
  ap failed_ai_job_application_summaries.group(:error_message).count

  ap "----- Detail -----", color: { string: :cyan }
  ap failed_ai_job_application_summaries.map { |ai_job_application_summary|
    {
      id: ai_job_application_summary.id,
      job_application_id: ai_job_application_summary.job_application_id,
      job_id: ai_job_application_summary.job_application.job_id,
      job: ai_job_application_summary.job_application.job.title,
      requested_by_organization_user_id: ai_job_application_summary.requested_by_organization_user_id,
      error_message: ai_job_application_summary.error_message,
      created_at: ai_job_application_summary.created_at,
      updated_at: ai_job_application_summary.updated_at
    }
  }

  ap "Done", color: { string: :green }
end
