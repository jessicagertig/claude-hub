# =============================================================================
# STAGING LOAD — org 8488 (Curious): jobs 37555 (SDR) + 33682 (Future Portfolio CEO)
# PASTE THIS ENTIRE FILE into the STAGING Heroku rails console, then it runs.
#
# BEFORE pasting, run these on staging:
#   Flipper.disable(:TEXTRACT_RESUME_PROCESSING)   # so app-create doesn't re-bill AWS
#   User.find_by!(email: 'jessica@polymer.co')     # confirm owner exists (raises if not)
#   # and make sure Sidekiq workers are running (OrgSetupJob creates the Stripe customer)
#
# If a PRIOR run partially created the org, delete it first (see CLEANUP below).
# =============================================================================

# =============================================================================
# 3_load_LOCAL.rb — PASTE WHOLE FILE into your LOCAL rails console.
# SIDEKIQ MUST BE RUNNING (OrgSetupJob makes the Stripe customer + defaults;
# new-application intake callbacks run as background jobs).
# =============================================================================
# Then call (paths match what 2_download_LOCAL.sh created):
#
#   clone_load_org(
#     json_path:      File.expand_path("~/clone_org/org.json"),
#     resumes_dir:    File.expand_path("~/clone_org/resumes"),
#     docx_json_path: File.expand_path("~/clone_org/docx_pdfs.json")   # or nil
#   )
#
# Uses the app's real creation paths so callbacks fire. Owner user + org are
# created the cypress way (is_claimed:true -> Stripe customer). Jobs/candidates/
# applications are the actual prod records recreated through the models.
# =============================================================================

CLONE_NEVER_COPY = %w[id created_at updated_at hash_id slug].freeze

def clone_pick(attrs, extra_drop = [])
  attrs.reject do |k, _|
    CLONE_NEVER_COPY.include?(k) || k.end_with?('_id') || k.end_with?('_count') || extra_drop.include?(k)
  end
end

# No Faker — it's a dev/test-only gem, absent on staging/production. Plain Ruby
# fakes so this runs in any environment.
def clone_fake_candidate_pii!(attrs)
  h = SecureRandom.hex(5)
  attrs['phone']        = "+1#{SecureRandom.random_number(9_000_000_000) + 1_000_000_000}" if attrs['phone'].present?
  attrs['location']     = "Cloneville #{h}"                if attrs['location'].present?
  attrs['website_url']  = "https://example.com/#{h}"       if attrs['website_url'].present?
  attrs['linkedin_url'] = "https://linkedin.com/in/#{h}"   if attrs['linkedin_url'].present?
  attrs['twitter_url']  = "https://twitter.com/#{h}"       if attrs['twitter_url'].present?
  attrs['github_url']   = "https://github.com/#{h}"        if attrs['github_url'].present?
  attrs['dribbble_url'] = "https://dribbble.com/#{h}"      if attrs['dribbble_url'].present?
  attrs
end

def clone_create_owner_and_org!(org_attrs, owner_email: 'jessica@polymer.co')
  # Owner is an existing local user, found by (unique) email. Don't touch their
  # password or confirmation. Promote the org-scoped membership, NOT
  # current_organization_user (the user may belong to many orgs).
  user = User.find_by!(email: owner_email)

  org = Organization.where(name: org_attrs['name']).first_or_create do |o|
    o.owner_id   = user.id
    o.is_claimed = true
  end
  org.users.push(user) unless org.users.include?(user)
  org_user = org.organization_users.find_by(user_id: user.id)
  org_user.org_owner!

  org.update!(settings: org_attrs['settings']) if org_attrs['settings'].present?

  [org_user, org]
end

def clone_load_org(json_path:, resumes_dir:, owner_email: 'jessica@polymer.co', docx_json_path: nil, textract_json_path: nil)
  data = JSON.parse(File.read(json_path))

  resume_paths = {}
  Dir.glob(File.join(resumes_dir, '*')).each do |path|
    m = File.basename(path, File.extname(path)).match(/-(\d+)\z/)
    resume_paths[m[1]] = path if m
  end
  docx_pdfs = docx_json_path && File.exist?(docx_json_path) ? JSON.parse(File.read(docx_json_path)) : {}
  # Textract: either inline in each app (jaw['textract_results']) or in a separate
  # file keyed by prod app id. Separate file wins when inline is absent.
  textract_by_app = textract_json_path && File.exist?(textract_json_path) ? JSON.parse(File.read(textract_json_path)) : {}

  org_user, org = clone_create_owner_and_org!(data['organization'], owner_email: owner_email)

  # Candidate attrs indexed by prod id. Candidates are created THROUGH a job
  # (job.candidates.create!) so the has_many-through builds a job_application at
  # the same time — Candidate#validates(attr) reads job_applications.first.job,
  # so a candidate with no application raises NoMethodError. (Matches the
  # cypress candidates_controller pattern.)
  cand_attrs_by_prod = data['candidates'].each_with_object({}) { |cw, h| h[cw['_prod_id'].to_s] = cw['attributes'] }
  candidate_by_prod  = {}

  data['jobs'].each do |jw|
    ja_attrs = jw['attributes']
    job = org.jobs.build(clone_pick(ja_attrs, %w[status]))
    job.created_by_organization_user = org_user
    job.job_category = JobCategory.first
    job.save!

    job.update_columns(
      status: Job.statuses[ja_attrs['status']] || ja_attrs['status'],
      published_at: ja_attrs['published_at'],
      originally_published_at: ja_attrs['originally_published_at']
    )

    stage_by_prod = {}
    jw['hiring_stages'].each do |hw|
      stage_by_prod[hw['_prod_id'].to_s] = job.hiring_stages.create!(clone_pick(hw['attributes']))
    end

    question_by_prod = {}
    jw['questions'].each do |qw|
      question_by_prod[qw['_prod_id'].to_s] = job.questions.create!(clone_pick(qw['attributes']))
    end

    jw['job_applications'].each do |jaw|
      prod_cand_id = jaw['_prod_candidate_id'].to_s
      cand = candidate_by_prod[prod_cand_id]
      app_attrs = clone_pick(jaw['attributes'])

      if cand.nil?
        # First time we see this candidate: create it THROUGH this job. The
        # through-association builds one job_application, which we then update
        # with the cloned application attrs.
        ca = clone_pick(cand_attrs_by_prod[prod_cand_id])
        clone_fake_candidate_pii!(ca)
        ca['organization_id'] = org.id
        cand = job.candidates.create!(ca)
        candidate_by_prod[prod_cand_id] = cand
        app = cand.job_applications.find_by(job_id: job.id)
        app.update!(app_attrs)
      else
        # Candidate already exists (applied to another job): create the
        # application directly — candidate already has an application, so the
        # presence-validation helper is safe.
        app = job.job_applications.create!(app_attrs.merge(candidate: cand))
      end

      target_stage = stage_by_prod[jaw['_prod_hiring_stage_id'].to_s]
      app.update!(hiring_stage_id: target_stage.id) if target_stage && app.hiring_stage_id != target_stage.id

      prod_app_id = jaw['_prod_id'].to_s
      if (rpath = resume_paths[prod_app_id])
        app.resume.attach(io: File.open(rpath), filename: File.basename(rpath))
      end
      if (dp = docx_pdfs[prod_app_id])
        app.resume_docx_to_pdf.attach(io: StringIO.new(Base64.strict_decode64(dp['data_b64'])),
                                      filename: dp['filename'], content_type: dp['content_type'])
      end

      # Copy cached Textract rows callback-free (insert_all skips
      # queue_ai_summary_job, so seeding doesn't auto-fire 954 AI summary jobs).
      src_trs = jaw['textract_results'] || textract_by_app[prod_app_id] || []
      tr_rows = src_trs.map { |tr| tr.except('id').merge('job_application_id' => app.id) }
      TextractResult.insert_all(tr_rows) if tr_rows.any?

      jaw['question_responses'].each do |qrw|
        q = question_by_prod[qrw['_prod_question_id'].to_s]
        next unless q
        app.question_responses.create!(clone_pick(qrw['attributes']).merge(question: q))
      end
    end
  end

  Organization.reset_counters(org.id, :jobs)
  org.jobs.each do |job|
    Job.reset_counters(job.id, :job_applications)
    job.hiring_stages.each { |hs| HiringStage.reset_counters(hs.id, :job_applications) }
  end
  org.candidates.each { |cand| Candidate.reset_counters(cand.id, :job_applications) }

  ap "Cloned org ##{org.id} (#{org.name}) — owner org_user ##{org_user.id}"
  ap "jobs: #{org.jobs.count}, candidates: #{org.candidates.count}, applications: #{JobApplication.joins(:job).where(jobs: { organization_id: org.id }).count}"
end

# =============================================================================
# STAGING entry point — run on a Heroku staging rails console (no local disk).
# Downloads every artifact from its S3 URL into /tmp, unzips resumes, then loads.
# Pass one json_url per job. Disable Textract env-wide on staging FIRST so app
# creation doesn't re-submit resumes to AWS.
#
#   clone_load_org_from_urls(
#     json_urls:       ["<job1 json url>", "<job2 json url>"],
#     resume_zip_urls: ["<job1 zip url>",  "<job2 zip url>"],
#     docx_url:        "<docx json url>",      # or nil
#     textract_url:    "<textract json url>",  # or nil (37555 has it inline)
#     owner_email:     "jessica@polymer.co"
#   )
# =============================================================================
def clone_download(url, path)
  require 'open-uri'
  URI.parse(url).open { |io| File.open(path, 'wb') { |f| IO.copy_stream(io, f) } }
end

def clone_load_org_from_urls(json_urls:, resume_zip_urls: [], docx_url: nil, textract_url: nil, owner_email: 'jessica@polymer.co')
  require 'tmpdir'
  require 'shellwords'
  dir = Dir.mktmpdir('clone')
  resumes_dir = File.join(dir, 'resumes')
  FileUtils.mkdir_p(resumes_dir)

  resume_zip_urls.each_with_index do |u, i|
    zip = File.join(dir, "resumes_#{i}.zip")
    clone_download(u, zip)
    raise "unzip failed for #{u}" unless system("unzip -o #{Shellwords.escape(zip)} -d #{Shellwords.escape(resumes_dir)} > /dev/null")
    File.delete(zip)
  end

  docx_path = nil
  if docx_url
    docx_path = File.join(dir, 'docx_pdfs.json')
    clone_download(docx_url, docx_path)
  end

  textract_path = nil
  if textract_url
    textract_path = File.join(dir, 'textract.json')
    clone_download(textract_url, textract_path)
  end

  json_urls.each_with_index do |u, i|
    jp = File.join(dir, "org_#{i}.json")
    clone_download(u, jp)
    clone_load_org(
      json_path: jp,
      resumes_dir: resumes_dir,
      owner_email: owner_email,
      docx_json_path: docx_path,
      textract_json_path: textract_path
    )
  end
ensure
  FileUtils.remove_entry(dir) if dir && Dir.exist?(dir)
end

# =============================================================================
# RUN — pulls all artifacts from S3 into /tmp, unzips resumes, loads both jobs.
# =============================================================================
clone_load_org_from_urls(
  json_urls: [
    "https://inflow-production.s3.amazonaws.com/exports/fb7bc1e3-ac90-4ef2-a3b2-48939d1fa026/clone_org_8488.json?response-content-disposition=attachment%3B%20filename%3D%22clone_org_8488.json%22%3B%20filename%2A%3DUTF-8%27%27clone_org_8488.json&response-content-type=application%2Fjson&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJHVSUE4JSPSCLQ2Q%2F20260617%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260617T230320Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=250d7ca4709c88fe64da9e68d89452653a5ce5ecb57585ae2ebcaba0b0553252",
    "https://inflow-production.s3.amazonaws.com/exports/3aeb6d8b-0368-4118-bd37-0b324d84d33f/clone_org_8488.json?response-content-disposition=attachment%3B%20filename%3D%22clone_org_8488.json%22%3B%20filename%2A%3DUTF-8%27%27clone_org_8488.json&response-content-type=application%2Fjson&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJHVSUE4JSPSCLQ2Q%2F20260617%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260617T231337Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=7cefbd81d29d4508943f38ba5ccb8ea181848571717d6c682039f298335ba0eb"
  ],
  resume_zip_urls: [
    "https://inflow-production.s3.amazonaws.com/exports/6ded58bd-2b29-49b7-85c6-5d7102901506/Sales-Development-Representative-resumes-20260617-222226.zip?response-content-disposition=attachment%3B%20filename%3D%22Sales-Development-Representative-resumes-20260617-222226.zip%22%3B%20filename%2A%3DUTF-8%27%27Sales-Development-Representative-resumes-20260617-222226.zip&response-content-type=application%2Fzip&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJHVSUE4JSPSCLQ2Q%2F20260617%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260617T222309Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=3b783cce875b2cfe99c6c2113ff48ed9692b6b662e47422b87d90d26e0d92f27",
    "https://inflow-production.s3.amazonaws.com/exports/41390d92-cef8-43d3-a27f-bc4fa1f83400/Future-Portfolio-CEO-resumes-20260617-221956.zip?response-content-disposition=attachment%3B%20filename%3D%22Future-Portfolio-CEO-resumes-20260617-221956.zip%22%3B%20filename%2A%3DUTF-8%27%27Future-Portfolio-CEO-resumes-20260617-221956.zip&response-content-type=application%2Fzip&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJHVSUE4JSPSCLQ2Q%2F20260617%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260617T222226Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=206b6776e7ecc3314c890383319a604c1e5af705f09d03f9afeef41a66a27527"
  ],
  docx_url: "https://inflow-production.s3.amazonaws.com/exports/0d1f340b-5492-4a3d-9bc1-826d46b3e400/clone_org_8488_docx_pdfs.json?response-content-disposition=attachment%3B%20filename%3D%22clone_org_8488_docx_pdfs.json%22%3B%20filename%2A%3DUTF-8%27%27clone_org_8488_docx_pdfs.json&response-content-type=application%2Fjson&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJHVSUE4JSPSCLQ2Q%2F20260617%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260617T230419Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=5d7b6fe3503f170948223b1bed84553abc2761b389d3fa1a0158bde55a6830a2",
  textract_url: "https://inflow-production.s3.amazonaws.com/exports/2940b781-f932-4ab5-a3b7-7ea3051b905c/clone_org_8488_textract.json?response-content-disposition=attachment%3B%20filename%3D%22clone_org_8488_textract.json%22%3B%20filename%2A%3DUTF-8%27%27clone_org_8488_textract.json&response-content-type=application%2Fjson&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJHVSUE4JSPSCLQ2Q%2F20260617%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20260617T231706Z&X-Amz-Expires=604800&X-Amz-SignedHeaders=host&X-Amz-Signature=3bfc6a66f551c5deacede4d08b888d73980f11a2973d21b0065227589d7ebaa7",
  owner_email: "jessica@polymer.co"
)
