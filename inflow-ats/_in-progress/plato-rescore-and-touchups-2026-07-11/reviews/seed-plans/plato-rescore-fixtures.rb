# frozen_string_literal: true

# plato-rescore-fixtures.rb — Layer 5 (Playwright browser QA) fixtures for the
# Plato re-score feature (per-stage bulk re-score checkbox + single-send Regenerate).
#
# RUN ONCE, after the base seed plan (ai-org-with-candidates-plato-rescore.json,
# which seeds 63 candidates on "Senior Engineer"), via:
#
#   test_frr plato-rescore-fixtures.rb        # RAILS_ENV=test foreman run rails runner
#
# Idempotent-enough: re-running self-corrects (credits re-zeroed and re-granted,
# existing fixtures detected and skipped, stage assignment re-applied).
#
# What it builds (see FIXTURE-NOTES.md for the modal-state arithmetic):
#   - Org AI credit balance set to EXACTLY 20 (addon bucket, via GrantAiCredits)
#   - Succeeded AiJobCriteria for "Senior Engineer" (no real extraction call)
#   - Stage A (Inbox):     3 candidates, ALL with succeeded non-stale current reviews
#                          (zero-processable modal state; real bulk re-score pool;
#                          single-send Regenerate candidates)
#   - Stage B (Screen):    5 candidates — 2 with current reviews, 3 bare (no resume)
#   - Stage C (Interview): 55 candidates, all bare (Select-All overestimate state;
#                          no real run possible — no resumes, everything is skipped)
#   - Second job "Design Lead": 2 candidates, both with current reviews
#                          (all-stages modal ZERO-STATE + bounded 2-candidate
#                          all-stages re-score option)
#
# Writes go through models/interactors only. No raw SQL. No find_or_create_by.
# update_columns is used only where the cypress controllers themselves use it
# (last_updated_by_organization_user_id on candidate creation).

abort('FATAL: must run with RAILS_ENV=test (use test_frr)') unless Rails.env.test?

TARGET_CREDITS = 20
RESUME_PDF_PATH = Rails.root.join('spec', 'fixtures', 'files', 'test-resume.pdf')

abort("FATAL: resume fixture PDF missing at #{RESUME_PDF_PATH}") unless File.exist?(RESUME_PDF_PATH)

user = User.first
abort('FATAL: no User found — run the base seed plan first (POST /cypress/users)') unless user

organization = user.organization
abort('FATAL: user has no organization') unless organization

job = Job.find_by(title: 'Senior Engineer')
abort('FATAL: job "Senior Engineer" not found — run the base seed plan first (POST /cypress/jobs)') unless job

abort('FATAL: AI_APPLICANT_SUMMARY flipper is not enabled — the seed plan must enable it before this script runs') \
  unless Flipper.enabled?(:AI_APPLICANT_SUMMARY, organization)

abort('FATAL: job has no description — the cypress job seed should have set one') if job.description.blank?

# Auto-generate must be OFF: TextractResult has an after_commit (queue_ai_summary_job)
# that enqueues real generation (inline in test env!) when the job auto-generates.
abort('FATAL: job.should_auto_generate_ai_summaries? is true — fixtures would trigger real AI calls on TextractResult creation') \
  if job.should_auto_generate_ai_summaries?

puts '== Preconditions OK =='
puts "user: #{user.email} (id #{user.id})  org: #{organization.name} (id #{organization.id})  job: #{job.title} (id #{job.id})"

##############################################################################
# SECTION 1 — AI credit balance: set to exactly TARGET_CREDITS (20)
#
# Order avoids a transient zero balance (which would fire the zero-credit
# notification path): snapshot buckets -> grant 20 into addon -> debit each
# bucket by its snapshot amount. Ends: daily 0, monthly 0, addon_subscription 0,
# addon 20. counter_culture on AiCreditBalanceTransaction maintains the columns.
##############################################################################

organization_ai_credit_balance = OrganizationAiCreditBalance.find_by(organization_id: organization.id)
if organization_ai_credit_balance.nil?
  organization_ai_credit_balance = OrganizationAiCreditBalance.new(organization: organization)
  organization_ai_credit_balance.save!
  puts "created OrganizationAiCreditBalance id #{organization_ai_credit_balance.id}"
end

bucket_snapshot = {
  daily: organization_ai_credit_balance.daily_credits_remaining,
  monthly: organization_ai_credit_balance.monthly_credits_remaining,
  addon_subscription: organization_ai_credit_balance.addon_subscription_credits_remaining,
  addon: organization_ai_credit_balance.addon_credits_remaining
}
puts "== Credits: snapshot before adjustment: #{bucket_snapshot.inspect} (total #{bucket_snapshot.values.sum}) =="

grant_result = GrantAiCredits.call(
  organization: organization,
  amount: TARGET_CREDITS,
  reason: 'QA fixture: known balance for Plato re-score Layer 5',
  granted_by: user
)
abort("FATAL: GrantAiCredits failed: #{grant_result.error} #{grant_result.message}") unless grant_result.success?
puts "granted #{TARGET_CREDITS} addon credits (transaction id #{grant_result.transaction.id})"

bucket_snapshot.each do |bucket, amount|
  next unless amount.positive?

  ai_credit_balance_transaction = AiCreditBalanceTransaction.new(
    organization_ai_credit_balance: organization_ai_credit_balance,
    entry_type: :admin_debit,
    bucket: bucket,
    amount: -amount,
    description: "QA fixture: zero pre-existing #{bucket} bucket",
    metadata: { granted_by_user_id: user.id }
  )
  abort("FATAL: failed to zero #{bucket} bucket: #{ai_credit_balance_transaction.errors.full_messages.join(', ')}") \
    unless ai_credit_balance_transaction.save
  puts "debited #{amount} from #{bucket} bucket (transaction id #{ai_credit_balance_transaction.id})"
end

# Fresh read (counter_culture updated the columns SQL-side).
organization_ai_credit_balance = OrganizationAiCreditBalance.find_by!(organization_id: organization.id)
abort("FATAL: balance is #{organization_ai_credit_balance.total_credits_remaining}, expected #{TARGET_CREDITS}") \
  unless organization_ai_credit_balance.total_credits_remaining == TARGET_CREDITS
puts "== Credits: total_credits_remaining = #{organization_ai_credit_balance.total_credits_remaining} " \
     "(daily #{organization_ai_credit_balance.daily_credits_remaining}, " \
     "monthly #{organization_ai_credit_balance.monthly_credits_remaining}, " \
     "addon_subscription #{organization_ai_credit_balance.addon_subscription_credits_remaining}, " \
     "addon #{organization_ai_credit_balance.addon_credits_remaining}) =="

##############################################################################
# SECTION 2 — Succeeded AiJobCriteria for "Senior Engineer" (no extraction call)
#
# Shape copied from spec/services/ai_job_application_action/orchestrate_spec.rb
# (criteria entries: text / tier / contains_title_technology) and
# ExtractCriteria (adds source_heading; metadata title_technology + counts).
# Orchestrate#check_criteria_and_score requires job.latest_ai_job_criteria to be
# status_succeeded, so this row must be the NEWEST criteria row for the job.
##############################################################################

SENIOR_ENGINEER_CRITERIA = [
  { 'text' => '4+ years of professional software engineering experience',
    'tier' => 'tier_1', 'contains_title_technology' => false, 'source_heading' => 'Responsibilities And Duties' },
  { 'text' => 'Native Android application development experience',
    'tier' => 'tier_1', 'contains_title_technology' => true, 'source_heading' => 'Responsibilities And Duties' },
  { 'text' => 'Experience working directly with large enterprise clients',
    'tier' => 'tier_2', 'contains_title_technology' => false, 'source_heading' => 'Responsibilities And Duties' },
  { 'text' => 'Willingness to relocate to client headquarters',
    'tier' => 'tier_2', 'contains_title_technology' => false, 'source_heading' => 'Responsibilities And Duties' },
  { 'text' => 'Experience defining mobile technical strategy',
    'tier' => 'tier_3', 'contains_title_technology' => false, 'source_heading' => 'Responsibilities And Duties' }
].freeze

def ensure_succeeded_ai_job_criteria(job, criteria, title_technology)
  latest_ai_job_criteria = job.latest_ai_job_criteria
  if latest_ai_job_criteria&.status_succeeded?
    puts "AiJobCriteria for job #{job.id}: already succeeded (id #{latest_ai_job_criteria.id}) — skipping"
    return latest_ai_job_criteria
  end

  if latest_ai_job_criteria
    puts "WARNING: job #{job.id} latest AiJobCriteria id #{latest_ai_job_criteria.id} is #{latest_ai_job_criteria.status} — " \
         'creating a newer succeeded row so it becomes latest'
  end

  ai_job_criteria = AiJobCriteria.new(
    job: job,
    status: :succeeded,
    criteria: criteria,
    metadata: {
      'title_technology' => title_technology,
      'raw_criteria_count' => criteria.size,
      'criteria_count' => criteria.size
    }
  )
  ai_job_criteria.save!
  puts "created succeeded AiJobCriteria id #{ai_job_criteria.id} for job #{job.id} (#{criteria.size} criteria)"
  ai_job_criteria
end

puts '== AiJobCriteria (Senior Engineer) =='
ensure_succeeded_ai_job_criteria(job, SENIOR_ENGINEER_CRITERIA, 'Android')

##############################################################################
# SECTION 3 — Stage layout on "Senior Engineer"
#
# Deterministic by job_application id: first 3 stay in Inbox (Stage A),
# next 5 -> Screen (Stage B), next 55 -> Interview (Stage C).
# Moves use the app's normal update path (job_application.update!).
##############################################################################

inbox_stage = job.inbox_hiring_stage
screen_stage = job.hiring_stages.find_by(name: 'Screen')
interview_stage = job.hiring_stages.find_by(name: 'Interview')
abort('FATAL: expected default hiring stages Inbox/Screen/Interview on the job') \
  unless inbox_stage && screen_stage && interview_stage

senior_engineer_job_applications = job.job_applications.order(:id).to_a
if senior_engineer_job_applications.size < 63
  abort("FATAL: expected >= 63 job applications on #{job.title}, found #{senior_engineer_job_applications.size}. " \
        'Seed with ai-org-with-candidates-plato-rescore.json (amount: 63).')
end
puts "WARNING: #{senior_engineer_job_applications.size} job applications found; using the first 63 by id" \
  if senior_engineer_job_applications.size > 63

stage_a_job_applications = senior_engineer_job_applications[0, 3]
stage_b_job_applications = senior_engineer_job_applications[3, 5]
stage_c_job_applications = senior_engineer_job_applications[8, 55]

def move_to_stage(job_applications, hiring_stage)
  moved = 0
  job_applications.each do |job_application|
    next if job_application.hiring_stage_id == hiring_stage.id

    job_application.update!(hiring_stage_id: hiring_stage.id)
    moved += 1
  end
  moved
end

puts '== Stage layout (Senior Engineer) =='
puts "Stage A (#{inbox_stage.name}, id #{inbox_stage.id}): kept #{stage_a_job_applications.size}, moved #{move_to_stage(stage_a_job_applications, inbox_stage)}"
puts "Stage B (#{screen_stage.name}, id #{screen_stage.id}): moved #{move_to_stage(stage_b_job_applications, screen_stage)} (target #{stage_b_job_applications.size})"
puts "Stage C (#{interview_stage.name}, id #{interview_stage.id}): moved #{move_to_stage(stage_c_job_applications, interview_stage)} (target #{stage_c_job_applications.size})"

##############################################################################
# SECTION 4 — Full fixtures: resume + succeeded TextractResult + succeeded
# non-stale AiJobApplicationSummary + status row "current"
#
# TextractResult shape copied from spec/interactors/create_bulk_ai_summary_generation_spec.rb
# and spec/support/ai_credits_test_helpers.rb (create!, textract_job_result_text,
# textract_job_id, textract_job_status: :succeeded — no real AWS Textract).
# Summary is created with status: :succeeded at CREATE time (the model's
# handle_after_update_commit only fires on :update, so no broadcasts/side effects),
# linked to the fixture TextractResult (required so CreateBulkAiSummaryGeneration's
# textract-mismatch check does not mark it stale).
# The status row is produced by the app's own interactor,
# FindOrCreateAiJobApplicationSummaryStatus, which resolves 'current' and
# denormalizes score/headline/analysis.
##############################################################################

# Plausible resume texts so the REAL re-score calls (openai + gemini) succeed.
# Varied strength against the SENIOR_ENGINEER_CRITERIA so re-scores differ.
def android_strong_resume(name)
  <<~TEXT
    #{name}
    Senior Android Engineer — Chicago, IL — open to relocation

    SUMMARY
    Android engineer with 7 years of experience shipping consumer and enterprise mobile apps.
    Led Android development for two Fortune 500 client engagements at a consultancy, owning
    architecture, release management, and mobile strategy alongside client stakeholders.

    EXPERIENCE
    Lead Android Engineer, Vantage Consulting (2021-present)
    - Embedded on-site with a Fortune 500 retail client; delivered a Kotlin rewrite of their
      flagship Android app (4.6 stars, 2M MAU); defined the client's 3-year mobile roadmap.
    Android Engineer, BrightMobile (2018-2021)
    - Built native Android apps in Kotlin and Java; Jetpack Compose, Coroutines, Room, Dagger/Hilt.
    - Worked directly with enterprise customers on integration requirements and rollouts.

    SKILLS
    Kotlin, Java, Jetpack Compose, Android SDK, MVVM, CI/CD (Bitrise), REST/GraphQL, Firebase

    EDUCATION
    B.S. Computer Science, University of Illinois
  TEXT
end

def backend_medium_resume(name)
  <<~TEXT
    #{name}
    Software Engineer — Denver, CO

    SUMMARY
    Backend-leaning software engineer with 4 years of professional experience. Some exposure
    to mobile through a React Native side project; primarily builds APIs and services.

    EXPERIENCE
    Software Engineer II, Cloudline (2022-present)
    - Ruby on Rails and Go microservices for a B2B logistics platform; on-call rotation.
    - Collaborated with a large enterprise pilot customer on API integration.
    Junior Software Engineer, DataHatch (2020-2022)
    - Built internal dashboards (React, TypeScript) and ETL pipelines (Python).

    SKILLS
    Ruby, Go, TypeScript, PostgreSQL, Docker, AWS, React, React Native (hobby)

    EDUCATION
    B.S. Software Engineering, Colorado State University
  TEXT
end

def qa_weak_resume(name)
  <<~TEXT
    #{name}
    QA Analyst — Remote only

    SUMMARY
    QA analyst with 1 year of experience in manual and exploratory testing of web applications.
    Looking for a remote quality assurance role. Not currently able to relocate.

    EXPERIENCE
    QA Analyst, Testify Labs (2024-present)
    - Wrote manual test plans for a web CRM; logged and triaged defects in Jira.
    - Introduced basic smoke automation with Playwright under mentor guidance.

    SKILLS
    Manual testing, test plans, Jira, basic SQL, basic Playwright

    EDUCATION
    B.A. Communications, Portland State University
  TEXT
end

def mobile_solid_resume(name)
  <<~TEXT
    #{name}
    Mobile Engineer — Austin, TX — flexible on location

    SUMMARY
    Mobile engineer with 5 years across Android and iOS. Most recent two years focused on
    native Android in Kotlin for a fintech scale-up serving enterprise banking clients.

    EXPERIENCE
    Mobile Engineer, LedgerPay (2022-present)
    - Native Android (Kotlin, Compose) features for enterprise banking customers.
    - Partnered with two enterprise clients on rollout and compliance requirements.
    Mobile Developer, AppForge Agency (2019-2022)
    - Delivered cross-platform and native client apps; several Android-first engagements.

    SKILLS
    Kotlin, Swift, Jetpack Compose, Android SDK, Flutter, CI/CD, REST

    EDUCATION
    B.S. Computer Science, UT Austin
  TEXT
end

def android_contractor_resume(name)
  <<~TEXT
    #{name}
    Android Developer (Contract) — Raleigh, NC

    SUMMARY
    Android developer with 3 years of contract experience across small-business client apps.
    Comfortable in Kotlin and Java; limited exposure to large enterprise environments.

    EXPERIENCE
    Independent Android Contractor (2022-present)
    - Built and maintained 6 native Android apps for local businesses (Kotlin, Java).
    - Handled the full cycle: requirements, development, Play Store release, support.

    SKILLS
    Kotlin, Java, Android SDK, SQLite, Firebase, Material Design

    EDUCATION
    A.S. Computer Programming, Wake Technical Community College
  TEXT
end

# criteria_results entry shape copied from
# AiJobApplicationAction::Scoring::ScoreJobApplication#run_scoring:
# criterion_text / tier / contains_title_technology / score / reasoning,
# score in full_match | partial_match | not_found (Scoring::Calculate::SCORE_VALUES).
def build_criteria_results(criteria, scores_with_reasoning)
  criteria.each_with_index.map do |criterion, index|
    score, reasoning = scores_with_reasoning[index]
    {
      'criterion_text' => criterion['text'],
      'tier' => criterion['tier'],
      'contains_title_technology' => criterion['contains_title_technology'] || false,
      'score' => score,
      'reasoning' => reasoning
    }
  end
end

# structured_data keys copied from AiJobApplicationAction::Summary::Generate
# (snake_case in the jsonb; the API layer camelizes for the frontend).
def build_structured_data(skills:, key_skills:, standout_accomplishments:, primary_domain:,
                          role_analysis:, applicable_experience:, gaps:, total_months:)
  {
    'skills' => skills,
    'work_experience' => [],
    'total_months_experience' => total_months,
    'stated_experience' => "#{total_months / 12} years",
    'months_by_domain' => {},
    'assessment' => {
      'key_skills' => key_skills,
      'standout_accomplishments' => standout_accomplishments,
      'primary_domain' => { 'name' => primary_domain }
    },
    'role_analysis' => role_analysis,
    'applicable_experience' => applicable_experience,
    'gaps' => gaps
  }
end

# Attaches the fixture PDF (no controller involved, so no DocxToPdfJob /
# SubmitResumeToTextractJob / set_ai_summaries_stale side effects fire),
# creates the succeeded TextractResult (safe: job auto-generate is off, and
# there is no summary in textract_processing at this point), then the
# succeeded summary + current status row.
def ensure_current_review(job_application:, resume_text:, headline:, summary_text:,
                          integrated_role_analysis:, criteria:, scores_with_reasoning:, structured_data:)
  candidate_name = job_application.candidate&.full_name || "job_application #{job_application.id}"

  unless job_application.resume.attached?
    job_application.resume.attach(
      io: File.open(RESUME_PDF_PATH),
      filename: "resume-#{job_application.id}.pdf",
      content_type: 'application/pdf'
    )
    puts "  attached resume PDF to job_application #{job_application.id} (#{candidate_name})"
  end

  textract_result = job_application.latest_textract_result
  unless textract_result&.textract_job_status_succeeded? && textract_result.textract_job_result_text.present?
    textract_result = TextractResult.create!(
      job_application: job_application,
      textract_job_result_text: resume_text,
      textract_job_id: "qa-plato-#{job_application.id}",
      textract_job_status: :succeeded
    )
    puts "  created succeeded TextractResult id #{textract_result.id}"
  end

  ai_job_application_summary = job_application.latest_succeeded_ai_job_application_summary
  if ai_job_application_summary
    puts "  succeeded AiJobApplicationSummary already present (id #{ai_job_application_summary.id}) — skipping"
  else
    criteria_results = build_criteria_results(criteria, scores_with_reasoning)
    score_percentage = AiJobApplicationAction::Scoring::Calculate.compute(criteria_results)
    ai_job_application_summary = AiJobApplicationSummary.create!(
      job_application: job_application,
      textract_result: textract_result,
      status: :succeeded,
      stale: false,
      headline: headline,
      summary_text: summary_text,
      score_percentage: score_percentage,
      criteria_results: criteria_results,
      integrated_role_analysis: integrated_role_analysis,
      structured_data: structured_data
    )
    puts "  created succeeded AiJobApplicationSummary id #{ai_job_application_summary.id} (score #{score_percentage})"
  end

  # Fresh load: this script creates the summary via AiJobApplicationSummary.create!,
  # which does not populate the in-memory record's `latest_ai_job_application_summary`
  # has_one cache — the interactor would read the cached nil and resolve 'none'.
  # (Script-lifecycle artifact only; app flows load records fresh.)
  status_result = FindOrCreateAiJobApplicationSummaryStatus.call(job_application: JobApplication.find(job_application.id))
  abort("FATAL: status row for job_application #{job_application.id} failed: #{status_result.error}") unless status_result.success?
  status_row = status_result.ai_job_application_summary_status
  abort("FATAL: expected status 'current' for job_application #{job_application.id}, got '#{status_row.status}'") \
    unless status_row.status_current?
  puts "  AiJobApplicationSummaryStatus id #{status_row.id}: current (summary #{status_row.ai_job_application_summary_id})"

  ai_job_application_summary
end

puts '== Stage A fixtures (3 current reviews — real re-score pool) =='
stage_a_profiles = [
  {
    resume_builder: :android_strong_resume,
    headline: 'Seeded review — strong native Android match',
    summary_text: 'Seeded fixture review. Seven years of Android experience with Fortune 500 client work; strong match for the role.',
    integrated_role_analysis: 'Seeded fixture analysis: deep native Android experience (Kotlin, Compose) with direct enterprise client delivery and mobile strategy ownership. Relocation flexibility stated. Strong overall alignment with the role requirements.',
    scores: [['full_match', 'Seven years of professional software engineering experience.'],
             ['full_match', 'Native Android in Kotlin/Java across two roles, including a flagship rewrite.'],
             ['full_match', 'Embedded on-site with Fortune 500 clients at a consultancy.'],
             ['full_match', 'States openness to relocation.'],
             ['partial_match', 'Defined a client mobile roadmap; strategy work is client-scoped.']],
    structured_data: {
      skills: ['Kotlin', 'Java', 'Jetpack Compose', 'Android SDK', 'MVVM', 'CI/CD', 'GraphQL', 'Firebase'],
      key_skills: ['Kotlin', 'Jetpack Compose', 'Enterprise delivery'],
      standout_accomplishments: ['Kotlin rewrite of a Fortune 500 flagship Android app (2M MAU)',
                                 'Defined a 3-year mobile roadmap for an enterprise client'],
      primary_domain: 'Mobile Engineering',
      role_analysis: 'Seeded fixture analysis: strong native Android profile with enterprise consulting background.',
      applicable_experience: 'Seven years of Android development, including embedded enterprise client engagements.',
      gaps: 'Mobile strategy ownership has been client-scoped rather than organization-wide.',
      total_months: 84
    }
  },
  {
    resume_builder: :backend_medium_resume,
    headline: 'Seeded review — backend profile, light mobile exposure',
    summary_text: 'Seeded fixture review. Four years of backend experience; mobile exposure limited to a React Native side project.',
    integrated_role_analysis: 'Seeded fixture analysis: meets the general engineering experience bar but native Android experience is absent; enterprise exposure limited to one pilot customer. Moderate-to-weak alignment for an Android-focused role.',
    scores: [['full_match', 'Four years of professional software engineering experience.'],
             ['partial_match', 'Mobile exposure is a React Native side project, not native Android.'],
             ['partial_match', 'Worked with one enterprise pilot customer on API integration.'],
             ['not_found', 'No relocation statement in the resume.'],
             ['not_found', 'No mobile strategy experience evident.']],
    structured_data: {
      skills: ['Ruby', 'Go', 'TypeScript', 'PostgreSQL', 'Docker', 'AWS', 'React'],
      key_skills: ['Ruby', 'Go', 'API design'],
      standout_accomplishments: ['Built logistics microservices handling enterprise pilot integrations'],
      primary_domain: 'Backend Engineering',
      role_analysis: 'Seeded fixture analysis: capable backend engineer without native mobile depth.',
      applicable_experience: 'Four years of services and API work; hobby-level React Native only.',
      gaps: 'No native Android experience; no stated relocation flexibility.',
      total_months: 48
    }
  },
  {
    resume_builder: :qa_weak_resume,
    headline: 'Seeded review — early-career QA, weak fit',
    summary_text: 'Seeded fixture review. One year of manual QA experience; remote-only; no development background.',
    integrated_role_analysis: 'Seeded fixture analysis: early-career QA analyst without software engineering or Android development experience; remote-only preference conflicts with the relocation requirement. Weak alignment.',
    scores: [['not_found', 'One year of QA experience; no professional software engineering roles.'],
             ['not_found', 'No Android development experience.'],
             ['not_found', 'No enterprise client work evident.'],
             ['not_found', 'States remote-only; cannot relocate.'],
             ['not_found', 'No mobile strategy experience.']],
    structured_data: {
      skills: ['Manual testing', 'Jira', 'SQL (basic)', 'Playwright (basic)'],
      key_skills: ['Manual testing'],
      standout_accomplishments: ['Introduced smoke automation with Playwright within first year'],
      primary_domain: 'Quality Assurance',
      role_analysis: 'Seeded fixture analysis: QA-focused background without engineering experience.',
      applicable_experience: 'One year of manual/exploratory web testing.',
      gaps: 'No software engineering or Android experience; remote-only.',
      total_months: 12
    }
  }
]

stage_a_job_applications.each_with_index do |job_application, index|
  profile = stage_a_profiles[index]
  candidate = job_application.candidate
  puts "Stage A candidate #{index + 1}: #{candidate.full_name} (job_application #{job_application.id})"
  ensure_current_review(
    job_application: job_application,
    resume_text: send(profile[:resume_builder], candidate.full_name),
    headline: profile[:headline],
    summary_text: profile[:summary_text],
    integrated_role_analysis: profile[:integrated_role_analysis],
    criteria: SENIOR_ENGINEER_CRITERIA,
    scores_with_reasoning: profile[:scores],
    structured_data: build_structured_data(**profile[:structured_data])
  )
end

puts '== Stage B fixtures (2 current reviews + 3 bare) =='
stage_b_profiles = [
  {
    resume_builder: :mobile_solid_resume,
    headline: 'Seeded review — solid mobile engineer',
    summary_text: 'Seeded fixture review. Five years of mobile experience, recent native Android focus for enterprise fintech.',
    integrated_role_analysis: 'Seeded fixture analysis: solid native Android depth in recent roles with enterprise banking clients; location-flexible. Good alignment.',
    scores: [['full_match', 'Five years of professional mobile engineering experience.'],
             ['full_match', 'Recent two years native Android in Kotlin/Compose.'],
             ['full_match', 'Enterprise banking client rollouts.'],
             ['partial_match', 'States flexibility on location, not an explicit relocation commitment.'],
             ['not_found', 'No mobile strategy ownership evident.']],
    structured_data: {
      skills: ['Kotlin', 'Swift', 'Jetpack Compose', 'Android SDK', 'Flutter', 'CI/CD'],
      key_skills: ['Kotlin', 'Jetpack Compose'],
      standout_accomplishments: ['Enterprise banking Android features through compliance-heavy rollouts'],
      primary_domain: 'Mobile Engineering',
      role_analysis: 'Seeded fixture analysis: recent native Android focus after cross-platform years.',
      applicable_experience: 'Five years mobile, two years native Android for enterprise fintech.',
      gaps: 'Mobile strategy ownership not demonstrated.',
      total_months: 60
    }
  },
  {
    resume_builder: :android_contractor_resume,
    headline: 'Seeded review — Android contractor, small-business scope',
    summary_text: 'Seeded fixture review. Three years of contract Android work for small businesses; limited enterprise exposure.',
    integrated_role_analysis: 'Seeded fixture analysis: hands-on native Android contractor experience, but engagement scale is small-business and total experience is below the stated bar. Mixed alignment.',
    scores: [['partial_match', 'Three years of professional experience against a 4+ year requirement.'],
             ['full_match', 'Native Android apps built and shipped in Kotlin/Java.'],
             ['not_found', 'Client base is local small businesses, not large enterprises.'],
             ['not_found', 'No relocation statement.'],
             ['not_found', 'No strategy-level work evident.']],
    structured_data: {
      skills: ['Kotlin', 'Java', 'Android SDK', 'SQLite', 'Firebase'],
      key_skills: ['Kotlin', 'Android SDK'],
      standout_accomplishments: ['Solo-delivered six native Android apps end-to-end'],
      primary_domain: 'Mobile Engineering',
      role_analysis: 'Seeded fixture analysis: independent Android contractor with full-cycle delivery.',
      applicable_experience: 'Three years of native Android contract development.',
      gaps: 'Below the experience bar; no enterprise client exposure.',
      total_months: 36
    }
  }
]

stage_b_job_applications[0, 2].each_with_index do |job_application, index|
  profile = stage_b_profiles[index]
  candidate = job_application.candidate
  puts "Stage B reviewed candidate #{index + 1}: #{candidate.full_name} (job_application #{job_application.id})"
  ensure_current_review(
    job_application: job_application,
    resume_text: send(profile[:resume_builder], candidate.full_name),
    headline: profile[:headline],
    summary_text: profile[:summary_text],
    integrated_role_analysis: profile[:integrated_role_analysis],
    criteria: SENIOR_ENGINEER_CRITERIA,
    scores_with_reasoning: profile[:scores],
    structured_data: build_structured_data(**profile[:structured_data])
  )
end
puts "Stage B bare candidates (no resume, no review): #{stage_b_job_applications[2, 3].map(&:id).join(', ')}"
puts "Stage C bare candidates: #{stage_c_job_applications.size} (ids #{stage_c_job_applications.first.id}..#{stage_c_job_applications.last.id})"

##############################################################################
# SECTION 5 — Second job "Design Lead": all-stages modal ZERO-STATE
# (2 candidates, both with current reviews). Creation pattern copied from
# Cypress::JobsController#create / Cypress::CandidatesController#create.
# AI_APPLICANT_SUMMARY is toggled off around publish so the publish hook
# (auto_extract_job_criteria) cannot enqueue a REAL inline extraction call.
##############################################################################

DESIGN_LEAD_DESCRIPTION = <<~HTML
  <p>We are hiring a Design Lead to own product design across our hiring platform. You will lead a small team of product designers, run critique, and partner with product and engineering on roadmap-level decisions.</p>
  <p>Requirements:</p>
  <ul>
    <li>5+ years of product design experience, with 2+ years leading or mentoring designers</li>
    <li>Expert-level Figma skills, including design systems and component libraries</li>
    <li>A portfolio demonstrating shipped B2B or SaaS product work</li>
    <li>Strong written communication for async design reviews</li>
  </ul>
  <p>Bonus: experience with usability research programs.</p>
HTML

DESIGN_LEAD_CRITERIA = [
  { 'text' => '5+ years of product design experience',
    'tier' => 'tier_1', 'contains_title_technology' => false, 'source_heading' => 'Requirements' },
  { 'text' => '2+ years leading or mentoring designers',
    'tier' => 'tier_1', 'contains_title_technology' => false, 'source_heading' => 'Requirements' },
  { 'text' => 'Expert-level Figma skills including design systems',
    'tier' => 'tier_1', 'contains_title_technology' => true, 'source_heading' => 'Requirements' },
  { 'text' => 'Portfolio of shipped B2B or SaaS product work',
    'tier' => 'tier_2', 'contains_title_technology' => false, 'source_heading' => 'Requirements' },
  { 'text' => 'Experience with usability research programs',
    'tier' => 'tier_3', 'contains_title_technology' => false, 'source_heading' => 'Bonus' }
].freeze

def design_lead_resume(name, seniority)
  if seniority == :lead
    <<~TEXT
      #{name}
      Design Lead — Brooklyn, NY

      SUMMARY
      Product design lead with 8 years of experience, the last 3 leading a team of four designers
      at a B2B SaaS company. Built and maintains the company design system in Figma.

      EXPERIENCE
      Design Lead, Fieldstone (2022-present)
      - Lead four product designers; run weekly critique and quarterly research programs.
      - Own the Figma design system (350+ components) used across three product lines.
      Senior Product Designer, Coreline (2018-2022)
      - Shipped onboarding, billing, and analytics surfaces for a B2B analytics suite.

      SKILLS
      Figma (expert), design systems, usability research, prototyping, design ops

      EDUCATION
      BFA Interaction Design, Parsons School of Design
    TEXT
  else
    <<~TEXT
      #{name}
      Product Designer — Chicago, IL

      SUMMARY
      Product designer with 4 years of experience at SaaS startups. Strong Figma craft;
      has mentored one junior designer informally. Growing toward leadership.

      EXPERIENCE
      Product Designer, Brightpath (2022-present)
      - Designed and shipped scheduling and reporting features for an HR SaaS product.
      - Contributed components to the team design library in Figma.
      UX Designer, Loopwire (2021-2022)
      - Wireframes, prototypes, and usability tests for a marketplace app.

      SKILLS
      Figma, prototyping, usability testing, design libraries

      EDUCATION
      B.S. Human-Computer Interaction, DePaul University
    TEXT
  end
end

puts '== Second job: Design Lead (all-stages zero-state) =='
design_lead_job = Job.find_by(title: 'Design Lead')
if design_lead_job
  puts "job 'Design Lead' already exists (id #{design_lead_job.id}) — skipping creation"
else
  design_lead_job = organization.jobs.build(title: 'Design Lead', description: DESIGN_LEAD_DESCRIPTION)
  design_lead_job.created_by_organization_user = user.current_organization_user
  design_lead_job.job_category = JobCategory.first if JobCategory.first
  design_lead_job.save!
  begin
    # Publish with the flag off so auto_extract_job_criteria no-ops (it would
    # otherwise run a REAL criteria extraction inline in test env).
    Flipper.disable(:AI_APPLICANT_SUMMARY)
    design_lead_job.published!
  ensure
    Flipper.enable(:AI_APPLICANT_SUMMARY)
  end
  design_lead_job.create_default_hiring_stages
  puts "created + published job 'Design Lead' (id #{design_lead_job.id})"
end
abort('FATAL: Design Lead job is not published') unless design_lead_job.published?

ensure_succeeded_ai_job_criteria(design_lead_job, DESIGN_LEAD_CRITERIA, 'Figma')

design_lead_candidates = [
  { first_name: 'Quinn', last_name: 'Barrett', email: 'qa-fixture-quinn.barrett@example.com', seniority: :lead,
    headline: 'Seeded review — experienced design lead',
    summary_text: 'Seeded fixture review. Eight years of product design with three leading a team; owns a large Figma design system.',
    integrated_role_analysis: 'Seeded fixture analysis: meets every stated requirement, including team leadership and design-system ownership. Strong alignment.',
    scores: [['full_match', 'Eight years of product design experience.'],
             ['full_match', 'Three years leading a team of four designers.'],
             ['full_match', 'Owns a 350+ component Figma design system.'],
             ['full_match', 'B2B SaaS product work across two companies.'],
             ['full_match', 'Runs quarterly usability research programs.']],
    structured: { skills: ['Figma', 'Design systems', 'Usability research', 'Prototyping'],
                  key_skills: ['Figma', 'Design systems', 'Team leadership'],
                  standout_accomplishments: ['Built a 350+ component design system across three product lines'],
                  primary_domain: 'Product Design',
                  role_analysis: 'Seeded fixture analysis: experienced design lead.',
                  applicable_experience: 'Eight years product design; three leading a team.',
                  gaps: 'None significant against the stated requirements.',
                  total_months: 96 } },
  { first_name: 'Rowan', last_name: 'Ellis', email: 'qa-fixture-rowan.ellis@example.com', seniority: :mid,
    headline: 'Seeded review — mid-level designer, growing to lead',
    summary_text: 'Seeded fixture review. Four years of SaaS product design; informal mentoring only.',
    integrated_role_analysis: 'Seeded fixture analysis: solid craft but below the experience bar and without formal leadership experience. Mixed alignment.',
    scores: [['partial_match', 'Four years against a 5+ year requirement.'],
             ['partial_match', 'Informal mentoring of one junior designer.'],
             ['partial_match', 'Contributes to a design library; does not own a design system.'],
             ['full_match', 'Shipped features for two SaaS products.'],
             ['partial_match', 'Ran usability tests, not a research program.']],
    structured: { skills: ['Figma', 'Prototyping', 'Usability testing'],
                  key_skills: ['Figma', 'Prototyping'],
                  standout_accomplishments: ['Shipped scheduling and reporting surfaces for an HR SaaS product'],
                  primary_domain: 'Product Design',
                  role_analysis: 'Seeded fixture analysis: mid-level SaaS product designer.',
                  applicable_experience: 'Four years of SaaS product design.',
                  gaps: 'Below the experience bar; no formal leadership.',
                  total_months: 48 } }
]

design_lead_candidates.each do |candidate_spec|
  candidate = organization.candidates.where(email: candidate_spec[:email]).first
  if candidate
    puts "candidate #{candidate_spec[:email]} already exists (id #{candidate.id})"
  else
    candidate = design_lead_job.candidates.build(
      first_name: candidate_spec[:first_name],
      last_name: candidate_spec[:last_name],
      email: candidate_spec[:email],
      organization_id: organization.id
    )
    candidate.save!
    # Same post-create step the cypress candidates controller performs.
    candidate.job_applications.first.update_columns(last_updated_by_organization_user_id: user.current_organization_user.id)
    puts "created candidate #{candidate.full_name} (id #{candidate.id})"
  end

  design_lead_job_application = candidate.job_applications.detect { |job_application| job_application.job_id == design_lead_job.id }
  abort("FATAL: candidate #{candidate.id} has no job application on Design Lead") unless design_lead_job_application

  ensure_current_review(
    job_application: design_lead_job_application,
    resume_text: design_lead_resume(candidate.full_name, candidate_spec[:seniority]),
    headline: candidate_spec[:headline],
    summary_text: candidate_spec[:summary_text],
    integrated_role_analysis: candidate_spec[:integrated_role_analysis],
    criteria: DESIGN_LEAD_CRITERIA,
    scores_with_reasoning: candidate_spec[:scores],
    structured_data: build_structured_data(**candidate_spec[:structured])
  )
end

##############################################################################
# SECTION 6 — Final summary
##############################################################################

puts
puts '=================================================================='
puts '== FIXTURE SUMMARY =='
puts '=================================================================='
final_balance = OrganizationAiCreditBalance.find_by!(organization_id: organization.id)
puts "Org #{organization.name} (id #{organization.id}) — AI credits: #{final_balance.total_credits_remaining} " \
     "(daily #{final_balance.daily_credits_remaining} / monthly #{final_balance.monthly_credits_remaining} / " \
     "addon_subscription #{final_balance.addon_subscription_credits_remaining} / addon #{final_balance.addon_credits_remaining})"
puts

[job, design_lead_job].each do |summary_job|
  fresh_job = Job.find(summary_job.id)
  puts "Job: #{fresh_job.title} (id #{fresh_job.id}) — job_applications_count #{fresh_job.job_applications_count}, " \
       "ai_job_application_summaries_count #{fresh_job.ai_job_application_summaries_count}, " \
       "latest criteria: #{fresh_job.latest_ai_job_criteria&.status || 'NONE'}"
  fresh_job.hiring_stages.order(:id).each do |hiring_stage|
    stage_job_applications = fresh_job.job_applications.where(hiring_stage_id: hiring_stage.id).order(:id)
    next if stage_job_applications.empty?

    reviewed = stage_job_applications.select do |job_application|
      job_application.ai_job_application_summary_status&.status_current?
    end
    puts "  #{hiring_stage.name} (stage id #{hiring_stage.id}): #{stage_job_applications.size} candidates, #{reviewed.size} with current reviews"
    if stage_job_applications.size <= 10
      stage_job_applications.each do |job_application|
        status_row = job_application.ai_job_application_summary_status
        puts "    ja #{job_application.id} — #{job_application.candidate&.full_name} — resume: #{job_application.resume.attached?} — " \
             "textract: #{job_application.latest_textract_result&.textract_job_status || 'none'} — " \
             "status row: #{status_row&.status || 'none'}#{status_row&.status_current? ? " (score #{status_row.score_percentage})" : ''}"
      end
    else
      puts "    (ids #{stage_job_applications.first.id}..#{stage_job_applications.last.id}; per-candidate detail omitted for stages over 10)"
    end
  end
  puts
end
puts 'Done. See FIXTURE-NOTES.md for the modal-state arithmetic and QA cautions.'
