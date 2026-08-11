# Export organization data from production for local clone.
# Usage: rails runner export_org_data.rb ORG_ID
#
# Outputs: org_export.json in current directory

org_id = ARGV[0] || ENV['ORG_ID']
abort "Usage: rails runner export_org_data.rb ORG_ID" unless org_id

org = Organization.find(org_id)
ap "Exporting org: #{org.name} (ID: #{org.id})"

SKIP_JOB_FIELDS = %w[
  id organization_id user_id created_by_organization_user_id
  hash_id slug webflow_item_id clone_of_job_id
  process_template_id organization_department_id job_category_id
  job_applications_count inbox_stage_count interview_stage_count
  decide_stage_count screen_stage_count offer_stage_count
  published_jobs_count
  is_scraped scraped_at scraped_from_url scraped_from_source
  scraped_title scraped_description is_manually_verified
  thirdparty_ats_job_id imported_from_ats internal_admin_status
  description_legacy_markdown shared_document_template_legacy_markdown
  created_at updated_at discarded_at
].freeze

SKIP_CANDIDATE_FIELDS = %w[
  id organization_id hash_id anonymous_id
  job_applications_count
  created_at updated_at
].freeze

SKIP_JOB_APP_FIELDS = %w[
  id hash_id ahoy_visit_id clone_of_job_application_id
  last_updated_by_user_id last_updated_by_organization_user_id
  created_at updated_at
].freeze

jobs_data = org.jobs.kept.includes(:hiring_stages, :questions, :job_applications).map do |job|
  job_attrs = job.attributes.except(*SKIP_JOB_FIELDS)
  job_attrs['prod_id'] = job.id
  job_attrs['remote_restriction_country_list'] = job.remote_restriction_country_list.to_a

  job_attrs['hiring_stages'] = job.hiring_stages.kept.order(:kind, :position).map do |hs|
    {
      'prod_id' => hs.id,
      'name' => hs.name,
      'kind' => hs.kind,
      'position' => hs.position
    }
  end

  job_attrs['questions'] = job.questions.kept.order(:position).map do |q|
    {
      'prod_id' => q.id,
      'question_text' => q.question_text,
      'placeholder_text' => q.placeholder_text,
      'kind' => q.kind,
      'position' => q.position,
      'requirement_setting' => q.requirement_setting,
      'options' => q.options,
      'visibility_setting' => q.visibility_setting
    }
  end

  job_attrs
end

candidate_ids = org.candidates.pluck(:id)
candidates_data = org.candidates.map do |c|
  attrs = c.attributes.except(*SKIP_CANDIDATE_FIELDS)
  attrs['prod_id'] = c.id
  attrs['has_resume'] = c.resume.attached?
  attrs
end

job_apps_data = JobApplication.where(job_id: org.jobs.kept.pluck(:id))
  .includes(:hiring_stage_visits, :question_responses)
  .map do |ja|
    attrs = ja.attributes.except(*SKIP_JOB_APP_FIELDS)
    attrs['prod_id'] = ja.id
    attrs['prod_job_id'] = ja.job_id
    attrs['prod_candidate_id'] = ja.candidate_id
    attrs['prod_hiring_stage_id'] = ja.hiring_stage_id
    attrs.delete('job_id')
    attrs.delete('candidate_id')
    attrs.delete('hiring_stage_id')

    attrs['has_resume'] = ja.resume.attached?

    attrs['hiring_stage_visits'] = ja.hiring_stage_visits.order(:created_at).map do |v|
      {
        'prod_current_hiring_stage_id' => v.current_hiring_stage_id,
        'prod_source_hiring_stage_id' => v.source_hiring_stage_id,
        'current_stage_name_at_move' => v.current_stage_name_at_move,
        'created_at' => v.created_at.iso8601
      }
    end

    attrs['question_responses'] = ja.question_responses.map do |qr|
      {
        'prod_question_id' => qr.question_id,
        'body' => qr.body,
        'response_array' => qr.response_array
      }
    end

    attrs
  end

export = {
  'organization' => { 'name' => org.name },
  'jobs' => jobs_data,
  'candidates' => candidates_data,
  'job_applications' => job_apps_data
}

output_path = "org_export_#{org.id}.json"
File.write(output_path, JSON.pretty_generate(export))
ap "Exported to #{output_path}"
ap "  Jobs: #{jobs_data.size}"
ap "  Candidates: #{candidates_data.size}"
ap "  Applications: #{job_apps_data.size}"
