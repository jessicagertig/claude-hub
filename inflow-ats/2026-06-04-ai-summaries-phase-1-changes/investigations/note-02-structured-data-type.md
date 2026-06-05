# Investigation — Note #2: AiResumeStructuredData type drift

## File chain
`app/javascript/shared/types/aiJobApplicationSummary.ts`
→ `app/serializers/api/v1/ai_job_application_summary_serializer.rb` (attributes include `:structured_data`, passed verbatim; API layer camelCases all JSONB keys per core rule #7)
→ `app/services/ai_job_application_action/summary/generate.rb:58-167` (structured_data writes)
→ `app/services/ai_job_application_action/summary/prompts/resume_structured_data.rb` (Call 1 JSON schema)
→ `app/javascript/ats/src/views/jobApplications/activities/AiJobApplicationSummaryFeedItem.tsx` (only consumer)

## Actual backend structured_data keys (camelCased to FE)
Call 1: name, email, phone, location, links, workExperience[], education[], skills[], certifications[]
  - workExperience item: company, title, startDate, endDate, description (NO roleCategory, NO relevantToJobTitle)
  - education item: institution, degree, fieldOfStudy, graduationYear
post-Call-1: totalMonthsExperience
Call 2: assessment (obj), monthsByDomain (obj)
Call 3: comparison (obj)
Call 4 merge: roleAnalysis, applicableExperience, gaps, overlapSummary

## TS type drift (current `AiResumeStructuredData` / `AiWorkExperience`)
- Phantom (never written): totalYearsExperience, relevantYearsExperience, jobTitleRoleCategory (on AiResumeStructuredData); roleCategory, relevantToJobTitle (on AiWorkExperience).
- Misnamed: years vs months — backend is totalMonthsExperience.
- Missing from type: totalMonthsExperience, assessment, monthsByDomain, comparison, roleAnalysis, applicableExperience, gaps, overlapSummary.

## Consumption (ground truth)
- Sole importer of these types: `AiJobApplicationSummaryFeedItem.tsx`.
- It reads ONLY: structuredData.workExperience, .education, .skills, .certifications.
- NO frontend file reads any evaluative field (assessment/monthsByDomain/comparison/roleAnalysis/applicableExperience/overlapSummary/totalMonthsExperience). Confirmed by grep across app/javascript — only hits are the type definition itself.
- AiJobApplicationSummary.status union already matches backend enum (pending/in_progress/extracted/succeeded/failed/textract_processing). No drift.

## Decision fork
- Option A (recommended): type the resume-extraction shape only — keep name/email/phone/location/links/workExperience/education/skills/certifications, add totalMonthsExperience, drop all 5 phantom fields. Do NOT add evaluative fields (UI renders none; they aren't "resume structured data").
- Option B: full backend mirror — also add assessment/monthsByDomain/comparison/roleAnalysis/applicableExperience/gaps/overlapSummary with their own nested interfaces.
