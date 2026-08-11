# Attach downloaded resume files to local candidates/applications.
# Usage: rails runner upload_resumes.rb path/to/resumes_dir path/to/id_mapping.json
#
# Resume filenames from the export ZIP follow the pattern:
#   {FirstName}-{LastName}-{prod_app_id}.pdf
#
# This script maps prod_app_id → local app/candidate and attaches.

resumes_dir = ARGV[0]
mapping_path = ARGV[1]

abort "Usage: rails runner upload_resumes.rb RESUMES_DIR ID_MAPPING_JSON" unless resumes_dir && mapping_path
abort "Directory not found: #{resumes_dir}" unless Dir.exist?(resumes_dir)
abort "Mapping file not found: #{mapping_path}" unless File.exist?(mapping_path)

mapping = JSON.parse(File.read(mapping_path))
app_map = mapping['app_map']

files = Dir.glob(File.join(resumes_dir, '*'))
ap "Found #{files.size} files in #{resumes_dir}"

attached = 0
skipped = 0

files.each do |filepath|
  filename = File.basename(filepath)

  # Extract production app ID from filename: name-parts-{PROD_APP_ID}.ext
  match = filename.match(/-(\d+)\.[^.]+$/)
  unless match
    ap "  SKIP (no ID in filename): #{filename}"
    skipped += 1
    next
  end

  prod_app_id = match[1]
  local_app_id = app_map[prod_app_id]

  unless local_app_id
    ap "  SKIP (no mapping for prod app #{prod_app_id}): #{filename}"
    skipped += 1
    next
  end

  ja = JobApplication.find_by(id: local_app_id)
  unless ja
    ap "  SKIP (local app #{local_app_id} not found): #{filename}"
    skipped += 1
    next
  end

  candidate = ja.candidate

  content_type = case File.extname(filepath).downcase
                 when '.pdf' then 'application/pdf'
                 when '.doc' then 'application/msword'
                 when '.docx' then 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                 else 'application/octet-stream'
                 end

  # Attach to job application
  ja.resume.attach(
    io: File.open(filepath),
    filename: filename,
    content_type: content_type
  )

  # Also attach to candidate (mirrors production behavior)
  unless candidate.resume.attached?
    candidate.resume.attach(
      io: File.open(filepath),
      filename: filename,
      content_type: content_type
    )
  end

  attached += 1
  ap "  Attached: #{filename} → app #{local_app_id} / candidate #{candidate.id}"
end

ap "=== Done! Attached: #{attached}, Skipped: #{skipped} ==="
