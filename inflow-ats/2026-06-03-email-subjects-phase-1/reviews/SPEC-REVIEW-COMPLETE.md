# Spec Review Complete -- Email Subjects Phase 1

## Final Verdict: READY FOR PLANNING

Two consecutive PASS rounds achieved (Round 1 and Round 2). No BLOCKER or HIGH findings. The spec is accurate, complete, and ready for implementation planning.

## Plain English Summary

This feature adds a "subject line" field to outbound emails sent from the Inflow ATS app to job candidates. Today, every outbound email uses a single hardcoded subject: "[Job Title] at [Organization Name]". After this change, users can write custom subjects for single-send messages, bulk messages, automated stage messages, and apply-response confirmation emails. Inbound emails (candidate replies) will also have their subject captured and stored. The feature adds nullable columns to three database tables, a new text input on five frontend surfaces, and pipes the subject through every existing code path that currently handles only the body -- sanitization, mail-merge variable substitution, mailer delivery, serialization, and GDPR anonymization.

## Blast Radius

**What changes:** 3 database tables get new columns (4 total, including `mailgun_message_id` groundwork). 1 validator class renamed. 2 private methods renamed. 5 controllers gain new permitted params/sanitization. 4 serializers gain new attributes. 1 mailer changes from hardcoded to dynamic subject. 6 backend files gain `subject:` in their outbound params or capture. 5 frontend modals/views get subject inputs. 2 yup schemas add subject validation. Default seed data and apply-response defaults get subject values.

**What breaks if wrong:** Subject silently reverts to hardcoded fallback (no crash, but user's custom subject lost). Validator rename leaving stale reference causes total messaging outage. Missing sanitization creates XSS vector. Missing anonymization creates GDPR compliance gap. Missing seeds cause every new org to rely on fallback for all sends.

## Round Summaries

### Round 1 -- PASS
All 6 thematic angles plus 4 always-on checks verified. 0 BLOCKER, 0 HIGH, 6 MED findings:
- PP-F1 (MED): `parse_text` rename needs generalized argument -- spec wording sufficient
- TR-F1 (MED): `clean_incoming_message` boundary -- spec language clear
- TR-F2 (MED): `html_safe_apply_email` ends with `.html_safe` not needed for subject -- spec boundary sufficient
- FC-F1 (MED): No single-send yup schema exists today -- implementer must investigate
- SD-F1 (MED): Legacy NULL-subject templates on edit should show default -- implementation concern
- AO-F2 (MED): No test plan in spec -- implementation-plan concern

No spec amendments needed. All MED findings are implementation-level details where the spec provides sufficient guidance.

### Round 2 -- PASS
Deepened verification on all angles. Checked all 7 channel_message creation paths, email delivery chain (`SendTemplateEmail#add_subject` raises on blank), XSS vectors (header injection, `dangerouslySetInnerHTML`), anonymization nil handling, token-to-literal consistency, and backward compatibility of template interactors. 0 new findings.

## Open Questions

None remaining. All spec claims verified against source. The 6 MED findings from Round 1 are implementation-level details that do not require spec amendments.
