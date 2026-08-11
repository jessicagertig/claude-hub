# QA Run 2 - Layer 2 (Code Correctness) - Round 1 Summary (COMPRESSED)

**Date:** 2026-07-16 09:39-09:56 CT | **Tree:** attribution-work-qa at 299cf9465
**Team:** 3 fresh cold readers (deadline-compressed from 5-15; coordinator directive, logged). A: backend Ruby; B: frontend capture/SSO; C: events + all test files.
**Convergence rule for this run:** one round; the single HIGH went through the fix loop (gated commit) rather than a full run restart - coordinator relaxation, logged.

## Result: 1 HIGH, 4 MED, 9 LOW

- **l2-B1 (HIGH, agent B; orchestrator-reproduced both halves):** .slice(0,255) truncation can split a surrogate pair; ES2019 JSON.stringify emits a lone \udXXX escape; Rails json 2.6.1 raises JSON::ParserError -> the entire /magic_login or /sign_up POST 400s. FIXED: surrogate-safe truncation (drop trailing lone high surrogate) + 2 Jest regression tests; commit gated behind the shared-DB serialization (see FAILURE-REPORT.md).
- MEDs (4) and LOWs (9): consolidated in reviews/QA-MED-FINDINGS.md. Notable verifications that came back CLEAN: prototype-pollution via utm_data keys (query-string returns null-prototype objects + utm_ prefix filter), XSS via SSO hidden inputs (React attribute escaping), redirect header-injection/open-redirect at confirmations#show (integer id + CGI.escape verified), creation-time-only semantics on every write path, analog structural matching for all extended patterns (referral/partner threading, created_via copy, options: {} permit, trackEvent-in-onSuccess).
