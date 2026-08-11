# Call 1 + Call 2 Issues Found During Go Engineer Review

## Call 1 — Fixed (testing)
- Sub-headings in p/strong tags not recognized as headings
- "Nice to Have" and "Required Experience and Skills" buried in content instead of extracted as headings
- Fix: added heading examples list, sub-heading concatenation rule, p tag guidance

## Call 2 — Needs work
- Duplicate criteria not detected when the same concept appears in both responsibilities and requirements sections
- Go appears in criteria 1 (responsibilities) AND criteria 7 (requirements) — not flagged
- Kubernetes appears in criteria 2 (responsibilities) AND criteria 8 (requirements) — not flagged
- Terraform appears in criteria 2 (responsibilities) AND criteria 9 (requirements) — not flagged
- Marketplace integrations appears in criteria 4 (responsibilities), criteria 12 (requirements), AND criteria 13 (nice to have) — not flagged
- Monitoring/logging appears in criteria 5 (responsibilities) AND criteria 17 (nice to have) — not flagged
- Call 2 should keep the more specific version and flag the other as duplicate
