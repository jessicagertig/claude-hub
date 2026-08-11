# Production Data Clone

Clone an organization's data from production to local dev.

## What gets cloned

- Organization (name only) + owner user
- Jobs: all fields, hiring stages, questions, country restrictions
- Candidates: all profile fields
- Job applications: stage, status, archive info, question responses, hiring stage visit history
- Resumes: downloaded separately, uploaded via script

## Steps

### 1. Export from production

Copy `export_org_data.rb` to the production server and run:

```
rails runner export_org_data.rb ORG_ID
```

This creates `org_export_{ORG_ID}.json`. Download it to your machine.

### 2. Download resumes from production

Use the existing resume export in the app:
1. Go to a job in the production app
2. Use the resume export feature (downloads a ZIP)
3. Extract the ZIP into a folder locally
4. Repeat for each job

### 3. Stop Sidekiq locally

```
# If running via Foreman, stop it. Or just kill the Sidekiq process.
# This prevents notification jobs and duplicate hiring stage visits during import.
```

### 4. Import locally

```
rails runner import_org_data.rb path/to/org_export_123.json
```

This creates everything and outputs `id_mapping.json` (maps production IDs to local IDs).

### 5. Upload resumes locally

```
rails runner upload_resumes.rb path/to/extracted_resumes/ id_mapping.json
```

### 6. Restart Sidekiq

Start Sidekiq back up. Queued jobs from the import will process (channels, notifications — harmless in dev).

## Notes

- Owner user: `clone-owner@dev.local` / password: `password`
- Re-running import on same org name is safe (uses `first_or_create` for org/user)
- Jobs are created as-is from production (including published status)
- Counter caches may be off after import — Rails will fix them on next relevant action, or run `Job.find_each { |j| Job.reset_counters(j.id, :job_applications) }` etc.
