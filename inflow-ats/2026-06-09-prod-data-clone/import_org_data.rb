# Import exported organization data into local dev.
# Usage: rails runner import_org_data.rb path/to/org_export_123.json
#
# IMPORTANT: Stop Sidekiq before running this to avoid spurious
# notification jobs and duplicate hiring stage visits.
#
# Outputs: id_mapping.json (production ID → local ID for resume upload)

json_path = ARGV[0]
abort "Usage: rails runner import_org_data.rb path/to/org_export.json" unless json_path
abort "File not found: #{json_path}" unless File.exist?(json_path)

data = JSON.parse(File.read(json_path))
org_name = data['organization']['name']

ap "=== Importing org: #{org_name} ==="

# Step 1: Create owner + org (Cypress pattern)
user = User.where(email: 'clone-owner@dev.local').first_or_create! do |u|
  u.first_name = 'Clone'
  u.last_name = 'Owner'
  u.password = 'password'
  u.password_confirmation = 'password'
end
user.confirm

org = Organization.where(name: org_name).first_or_create! do |o|
  o.owner_id = user.id
  o.is_claimed = true
end
org.users.push(user) unless org.users.include?(user)
user.current_organization_user.org_owner!
org_user = user.current_organization_user

ap "Owner: #{user.email} | Org: #{org.name} (ID: #{org.id})"

# ID mappings: production ID → local ID
job_map = {}
stage_map = {}
question_map = {}
candidate_map = {}
app_map = {}

# Step 2: Create jobs
data['jobs'].each do |job_data|
  prod_id = job_data.delete('prod_id')
  stages_data = job_data.delete('hiring_stages')
  questions_data = job_data.delete('questions')
  country_list = job_data.delete('remote_restriction_country_list') || []

  # Create with is_scraped to skip default hiring stage creation
  job = org.jobs.create!(
    title: job_data['title'],
    created_by_organization_user: org_user,
    is_scraped: true,
    skip_country_list_validation: true
  )

  # Now set all production values via update_columns (no callbacks)
  update_attrs = job_data.except(
    'title', 'originally_archived_at'
  ).merge(
    'is_scraped' => false
  )
  # Convert string keys and handle decimal types
  safe_attrs = {}
  update_attrs.each do |k, v|
    next if v.nil? && !job.class.column_names.include?(k)
    safe_attrs[k] = v if job.class.column_names.include?(k)
  end
  job.update_columns(safe_attrs) unless safe_attrs.empty?

  # Set country tags
  if country_list.any?
    job.remote_restriction_country_list.add(country_list)
    job.save!
  end

  job_map[prod_id] = job.id
  ap "  Job: #{job.title} (prod #{prod_id} → local #{job.id})"

  # Create hiring stages
  stages_data.each do |hs_data|
    hs_prod_id = hs_data['prod_id']
    hs = job.hiring_stages.create!(
      name: hs_data['name'],
      kind: hs_data['kind'],
      position: hs_data['position']
    )
    stage_map[hs_prod_id] = hs.id
  end
  ap "    Stages: #{stages_data.size}"

  # Create questions
  questions_data.each do |q_data|
    q_prod_id = q_data['prod_id']
    q = job.questions.create!(
      question_text: q_data['question_text'],
      placeholder_text: q_data['placeholder_text'],
      kind: q_data['kind'],
      position: q_data['position'],
      requirement_setting: q_data['requirement_setting'],
      options: q_data['options'] || {},
      visibility_setting: q_data['visibility_setting']
    )
    question_map[q_prod_id] = q.id
  end
  ap "    Questions: #{questions_data.size}"
end

# Step 3: Create candidates
data['candidates'].each do |c_data|
  prod_id = c_data.delete('prod_id')
  has_resume = c_data.delete('has_resume')

  candidate = Candidate.create!(
    first_name: c_data['first_name'],
    last_name: c_data['last_name'],
    email: c_data['email'],
    phone: c_data['phone'],
    location: c_data['location'],
    cover_letter: c_data['cover_letter'],
    linkedin_url: c_data['linkedin_url'],
    website_url: c_data['website_url'],
    github_url: c_data['github_url'],
    twitter_url: c_data['twitter_url'],
    dribbble_url: c_data['dribbble_url'],
    organization_id: org.id,
    created_via: c_data['created_via'] || 0,
    private_note: c_data['private_note'],
    has_valid_email: c_data.fetch('has_valid_email', true),
    src: c_data['src'],
    privacy_status: c_data['privacy_status'] || 0,
    consent_expiration: c_data['consent_expiration']
  )
  candidate_map[prod_id] = candidate.id
end
ap "Candidates: #{data['candidates'].size}"

# Step 4: Create job applications
data['job_applications'].each do |ja_data|
  prod_id = ja_data.delete('prod_id')
  prod_job_id = ja_data.delete('prod_job_id')
  prod_candidate_id = ja_data.delete('prod_candidate_id')
  prod_hiring_stage_id = ja_data.delete('prod_hiring_stage_id')
  has_resume = ja_data.delete('has_resume')
  visits_data = ja_data.delete('hiring_stage_visits')
  responses_data = ja_data.delete('question_responses')

  local_job_id = job_map[prod_job_id]
  local_candidate_id = candidate_map[prod_candidate_id]
  local_stage_id = stage_map[prod_hiring_stage_id]

  unless local_job_id && local_candidate_id
    ap "  SKIP app prod #{prod_id}: missing job or candidate mapping"
    next
  end

  ja = JobApplication.create!(
    job_id: local_job_id,
    candidate_id: local_candidate_id,
    hiring_stage_id: local_stage_id,
    stage: ja_data['stage'],
    status: ja_data['status'],
    archive_reason: ja_data['archive_reason'],
    archive_note: ja_data['archive_note'],
    possible_future_candidate: ja_data['possible_future_candidate'],
    shared_document: ja_data['shared_document'],
    created_via: ja_data['created_via'] || 0,
    desired_compensation: ja_data['desired_compensation'],
    source: ja_data['source'],
    settings: ja_data['settings'] || {},
    external_resume_url: ja_data['external_resume_url'],
    external_resume_status: ja_data['external_resume_status']
  )
  app_map[prod_id] = ja.id

  # Create hiring stage visits
  visits_data.each do |v_data|
    local_current_stage = stage_map[v_data['prod_current_hiring_stage_id']]
    local_source_stage = v_data['prod_source_hiring_stage_id'] ? stage_map[v_data['prod_source_hiring_stage_id']] : nil

    HiringStageVisit.create!(
      job_application_id: ja.id,
      current_hiring_stage_id: local_current_stage || local_stage_id,
      source_hiring_stage_id: local_source_stage,
      current_stage_name_at_move: v_data['current_stage_name_at_move'],
      moved_by_organization_user_id: org_user.id
    )
  end

  # Create question responses
  responses_data.each do |qr_data|
    local_question_id = question_map[qr_data['prod_question_id']]
    next unless local_question_id

    QuestionResponse.create!(
      job_application_id: ja.id,
      question_id: local_question_id,
      body: qr_data['body'],
      response_array: qr_data['response_array']
    )
  end
end
ap "Applications: #{data['job_applications'].size}"

# Output ID mapping for resume upload
mapping = {
  'org_id' => org.id,
  'job_map' => job_map.transform_keys(&:to_s),
  'candidate_map' => candidate_map.transform_keys(&:to_s),
  'app_map' => app_map.transform_keys(&:to_s)
}
mapping_path = 'id_mapping.json'
File.write(mapping_path, JSON.pretty_generate(mapping))
ap "=== Done! ID mapping saved to #{mapping_path} ==="
