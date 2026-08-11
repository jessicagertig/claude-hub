# =============================================================================
# 1_extract_PROD.rb — PASTE WHOLE FILE into: heroku run rails console -a <app>
# =============================================================================
# Then call, with the prod organization id (job_ids: optional — omit for ALL jobs):
#
#   clone_dump_org_to_s3(<ORG_ID>)                          # all jobs
#   clone_dump_org_to_s3(<ORG_ID>, job_ids: [123, 456])     # only these jobs
#   clone_export_all_resumes(<ORG_ID>, job_ids: [123, 456])
#   clone_dump_docx_pdfs_to_s3(<ORG_ID>, job_ids: [123, 456])
#
# Emails are scrubbed here (SecureRandom; Faker is not available on prod).
# Names + resumes leave verbatim. phone/urls are faked later on local.
# =============================================================================

# Streams the org graph as JSON directly to S3 (never builds the whole thing in
# memory). find_each keeps only ~one batch of records live at a time, so peak
# memory is flat regardless of row count. Output JSON shape is unchanged.
def clone_dump_org_to_s3(org_id, job_ids: nil)
  org = Organization.find(org_id)
  jobs_scope = job_ids ? org.jobs.where(id: job_ids) : org.jobs
  cand_scope = if job_ids
                 cand_ids = JobApplication.where(job_id: jobs_scope.select(:id)).distinct.pluck(:candidate_id)
                 org.candidates.where(id: cand_ids)
               else
                 org.candidates
               end

  service = ActiveStorage::Blob.service
  key = "exports/#{SecureRandom.uuid}/clone_org_#{org_id}.json"
  counts = { candidates: 0, jobs: 0, apps: 0 }

  service.bucket.object(key).upload_stream(content_type: 'application/json') do |io|
    io.write('{"organization":')
    io.write(org.attributes.to_json)

    io.write(',"candidates":[')
    first = true
    cand_scope.find_each(batch_size: 100) do |c|
      io.write(',') unless first
      first = false
      a = c.attributes
      a['email'] = c.email.blank? ? nil : "zzz.careers+#{SecureRandom.hex(8)}@gmail.com"
      io.write({ '_prod_id' => c.id, 'attributes' => a }.to_json)
      counts[:candidates] += 1
    end
    io.write(']')

    io.write(',"jobs":[')
    firstj = true
    jobs_scope.find_each(batch_size: 25) do |job|
      io.write(',') unless firstj
      firstj = false
      counts[:jobs] += 1
      io.write('{"_prod_id":')
      io.write(job.id.to_json)
      io.write(',"attributes":')
      io.write(job.attributes.to_json)
      io.write(',"hiring_stages":')
      io.write(job.hiring_stages.map { |hs| { '_prod_id' => hs.id, 'attributes' => hs.attributes } }.to_json)
      io.write(',"questions":')
      io.write(job.questions.map { |q| { '_prod_id' => q.id, 'attributes' => q.attributes } }.to_json)
      io.write(',"job_applications":[')
      firsta = true
      job.job_applications.find_each(batch_size: 100) do |ja|
        io.write(',') unless firsta
        firsta = false
        counts[:apps] += 1
        row = {
          '_prod_id'              => ja.id,
          '_prod_candidate_id'    => ja.candidate_id,
          '_prod_hiring_stage_id' => ja.hiring_stage_id,
          'attributes'            => ja.attributes,
          'question_responses'    => ja.question_responses.map { |qr| { '_prod_id' => qr.id, '_prod_question_id' => qr.question_id, 'attributes' => qr.attributes } },
          # Textract is dumped separately (clone_dump_textract_to_s3) to keep this
          # JSON lean — the resume text is the per-app memory hog.
        }
        io.write(row.to_json)
      end
      io.write(']}')
    end
    io.write(']}')
  end

  url = service.url(
    key,
    expires_in: 7.days,
    filename: ActiveStorage::Filename.new("clone_org_#{org_id}.json"),
    disposition: 'attachment',
    content_type: 'application/json'
  )
  ap "candidates: #{counts[:candidates]}, jobs: #{counts[:jobs]}, apps: #{counts[:apps]}"
  ap "DOWNLOAD JSON: #{url}"
end

# Streams Textract rows to S3, keyed by prod job_application id (drops the huge
# textract_job_result jsonb, keeps textract_job_result_text). Separate file so
# the org JSON stays lean.  Shape: {"<app_id>": [ {textract row}, ... ], ...}
def clone_dump_textract_to_s3(org_id, job_ids: nil)
  org = Organization.find(org_id)
  scope = job_ids ? org.jobs.where(id: job_ids) : org.jobs
  service = ActiveStorage::Blob.service
  key = "exports/#{SecureRandom.uuid}/clone_org_#{org_id}_textract.json"
  count = 0

  service.bucket.object(key).upload_stream(content_type: 'application/json') do |io|
    io.write('{')
    first = true
    scope.each do |job|
      job.job_applications.find_each(batch_size: 100) do |ja|
        # SELECT only the kept columns so the huge textract_job_result jsonb is
        # never loaded from the DB (excepting it after a SELECT * still loads it).
        rows = ja.textract_results
                 .select(:id, :textract_job_id, :textract_job_status, :textract_job_result_text, :job_application_id, :created_at, :updated_at)
                 .map(&:attributes)
        next if rows.empty?
        io.write(',') unless first
        first = false
        io.write(ja.id.to_s.to_json)
        io.write(':')
        io.write(rows.to_json)
        count += 1
      end
    end
    io.write('}')
  end

  url = service.url(key, expires_in: 7.days,
                    filename: ActiveStorage::Filename.new("clone_org_#{org_id}_textract.json"),
                    disposition: 'attachment', content_type: 'application/json')
  ap "textract apps: #{count}"
  ap "DOWNLOAD TEXTRACT JSON: #{url}"
end

def clone_export_all_resumes(org_id, job_ids: nil)
  org = Organization.find(org_id)
  scope = job_ids ? org.jobs.where(id: job_ids) : org.jobs
  scope.each do |job|
    ap "=== job #{job.id}: #{job.title} ==="
    JobResumeExport.export_for_job(job.id, skip_limit: true)
  end
  ap 'All resume exports triggered. Copy each "Download URL" above.'
end

# Streams base64'd resume_docx_to_pdf blobs to S3 one at a time (never holds all
# PDFs in memory). Output: {"<app_id>": {filename, content_type, data_b64}, ...}.
def clone_dump_docx_pdfs_to_s3(org_id, job_ids: nil)
  org = Organization.find(org_id)
  scope = job_ids ? org.jobs.where(id: job_ids) : org.jobs

  service = ActiveStorage::Blob.service
  key = "exports/#{SecureRandom.uuid}/clone_org_#{org_id}_docx_pdfs.json"
  count = 0

  service.bucket.object(key).upload_stream(content_type: 'application/json') do |io|
    io.write('{')
    first = true
    scope.each do |job|
      job.job_applications.find_each(batch_size: 50) do |ja|
        next unless ja.resume_docx_to_pdf.attached?
        io.write(',') unless first
        first = false
        entry = {
          'filename'     => ja.resume_docx_to_pdf.filename.to_s,
          'content_type' => ja.resume_docx_to_pdf.content_type,
          'data_b64'     => Base64.strict_encode64(ja.resume_docx_to_pdf.download),
        }
        io.write(ja.id.to_s.to_json)
        io.write(':')
        io.write(entry.to_json)
        count += 1
      end
    end
    io.write('}')
  end

  if count.zero?
    ap 'No resume_docx_to_pdf attachments — empty file uploaded (loader treats as none).'
  end
  url = service.url(
    key,
    expires_in: 7.days,
    filename: ActiveStorage::Filename.new("clone_org_#{org_id}_docx_pdfs.json"),
    disposition: 'attachment',
    content_type: 'application/json'
  )
  ap "docx->pdf attachments: #{count}"
  ap "DOWNLOAD DOCX-PDF JSON: #{url}"
end
