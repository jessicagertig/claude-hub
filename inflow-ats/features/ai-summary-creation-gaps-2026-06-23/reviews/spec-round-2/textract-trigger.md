# textract-trigger ordering & concurrency (W2) — Round 2

Re-verified the docx-guard amendment prevents the PDF double-submit and that the three submit sites are consistent.

## Findings
No new MED+ findings.

## Re-verified correct
- W2 DocxToPdfJob enqueue now gated on `@job_application.resume_is_docx` AND the Flipper -> PDF no longer double-submits (intake `else` submits PDF once; DocxToPdfJob's docx-guarded enqueue does not fire for PDF). CONFIRMED the Round-1 F1 fix resolves the double-submit.
- All three submit sites Flipper-gated (intake `:167`, controller `:113`, new DocxToPdfJob enqueue per spec). CONFIRMED defense-in-depth.
- docx conversion-failure still attempts Textract with raw docx (no regression); only `JobApplication.find` raise skips it (caught by perform rescue). CONFIRMED.
- Controller branch uses the local `job_application` (Round-1 source-accuracy fix). CONFIRMED.

## Amendments Applied (Round 2)
None.
