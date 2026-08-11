def ai_feature_usage_report
  summary_ai_api_requests = AiApiRequest.where(requestable_type: 'AiJobApplicationSummary')

  ap "===== AI FEATURE USAGE REPORT =====", color: { string: :white }

  ap "----- Totals -----", color: { string: :cyan }
  ap({
    ai_job_application_summaries: AiJobApplicationSummary.count,
    ai_job_application_summary_statuses: AiJobApplicationSummaryStatus.count,
    summary_ai_api_requests: summary_ai_api_requests.count
  })

  ap "----- Attempt rollup -----", color: { string: :cyan }
  ap({
    attempts_total: AiJobApplicationSummary.count,
    succeeded: AiJobApplicationSummary.where(status: :succeeded).count,
    failed: AiJobApplicationSummary.where(status: :failed).count,
    in_flight: AiJobApplicationSummary.where.not(status: %i[succeeded failed]).count,
    distinct_job_applications_attempted: AiJobApplicationSummary.distinct.count(:job_application_id)
  })

  ap "----- AiJobApplicationSummary by status -----", color: { string: :cyan }
  ap AiJobApplicationSummary.statuses.keys.index_with { |name| AiJobApplicationSummary.where(status: name).count }

  ap "----- AiJobApplicationSummaryStatus by status -----", color: { string: :cyan }
  ap AiJobApplicationSummaryStatus.statuses.keys.index_with { |name| AiJobApplicationSummaryStatus.where(status: name).count }

  ap "----- Summary AiApiRequest: totals -----", color: { string: :cyan }
  ap({
    requests: summary_ai_api_requests.count,
    input_tokens: summary_ai_api_requests.sum(:input_tokens),
    output_tokens: summary_ai_api_requests.sum(:output_tokens),
    cost: summary_ai_api_requests.sum(:cost).to_f
  })

  ap "----- Summary AiApiRequest by call_type -----", color: { string: :cyan }
  ap summary_ai_api_requests.group(:call_type).count

  ap "----- Summaries by organization -----", color: { string: :cyan }
  ai_job_application_summaries_by_organization_id = AiJobApplicationSummary.joins(job_application: :job).group('jobs.organization_id').count
  organization_names = Organization.where(id: ai_job_application_summaries_by_organization_id.keys).pluck(:id, :name).to_h
  ap ai_job_application_summaries_by_organization_id
    .map { |organization_id, count| { organization_id: organization_id, organization: organization_names[organization_id], summaries: count } }
    .sort_by { |row| -row[:summaries] }

  ap "----- Live summary statuses (current + regenerating) by organization -----", color: { string: :cyan }
  live_ai_job_application_summary_statuses_by_organization_id = AiJobApplicationSummaryStatus.where(status: %i[current regenerating]).joins(job_application: :job).group('jobs.organization_id').count
  live_organization_names = Organization.where(id: live_ai_job_application_summary_statuses_by_organization_id.keys).pluck(:id, :name).to_h
  ap live_ai_job_application_summary_statuses_by_organization_id
    .map { |organization_id, count| { organization_id: organization_id, organization: live_organization_names[organization_id], live_statuses: count } }
    .sort_by { |row| -row[:live_statuses] }

  ap "----- Failed attempts by organization -----", color: { string: :cyan }
  failed_ai_job_application_summaries_by_organization_id = AiJobApplicationSummary.where(status: :failed).joins(job_application: :job).group('jobs.organization_id').count
  failed_organization_names = Organization.where(id: failed_ai_job_application_summaries_by_organization_id.keys).pluck(:id, :name).to_h
  ap failed_ai_job_application_summaries_by_organization_id
    .map { |organization_id, count| { organization_id: organization_id, organization: failed_organization_names[organization_id], failed_attempts: count } }
    .sort_by { |row| -row[:failed_attempts] }

  ap "----- Summaries by job -----", color: { string: :cyan }
  ai_job_application_summaries_by_job_id = AiJobApplicationSummary.joins(:job_application).group('job_applications.job_id').count
  jobs_by_id = Job.where(id: ai_job_application_summaries_by_job_id.keys).pluck(:id, :title, :organization_id).to_h { |id, title, organization_id| [id, { title: title, organization_id: organization_id }] }
  ap ai_job_application_summaries_by_job_id
    .map { |job_id, count| { job_id: job_id, job: jobs_by_id.dig(job_id, :title), organization_id: jobs_by_id.dig(job_id, :organization_id), summaries: count } }
    .sort_by { |row| -row[:summaries] }

  ap "Done", color: { string: :green }
end
