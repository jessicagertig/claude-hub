#!/usr/bin/env bash
# =============================================================================
# 2_download_LOCAL.sh — run locally after PART 1 prints the URLs.
# Paste the URLs from the prod console into the curl lines below.
# =============================================================================
set -euo pipefail

mkdir -p ~/clone_org/resumes
cd ~/clone_org

# 1. Org metadata JSON  (from clone_dump_org_to_s3)
curl -L -o org.json "<JSON URL>"

# 2. docx->pdf JSON     (from clone_dump_docx_pdfs_to_s3 — skip if it said "none")
curl -L -o docx_pdfs.json "<DOCX-PDF URL>"

# 3. One resume zip per job (from clone_export_all_resumes — one Download URL each)
curl -L -o resumes/job1.zip "<ZIP URL 1>"
curl -L -o resumes/job2.zip "<ZIP URL 2>"
# ...add one line per job...

# Unzip all resume zips into resumes/
cd resumes && for z in *.zip; do unzip -o "$z"; done && cd ..

echo "Done. resumes/ holds files named  FirstName-LastName-<prodAppId>.pdf"
echo "Files in ~/clone_org :"
ls -la ~/clone_org ~/clone_org/resumes
