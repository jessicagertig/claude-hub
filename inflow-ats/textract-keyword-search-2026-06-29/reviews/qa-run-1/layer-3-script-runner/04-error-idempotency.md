# Layer 3 — Error Handling + Idempotency

**Runner:** `RAILS_ENV=test bundle exec rails runner`
**Server:** `http://app.lvh.me:5007` (test mode)

## Results

| # | Test | Result |
|---|------|--------|
| 1 | Service guard: missing TextractResult (id -999) → returns nil, no error | PASS |
| 2 | Service guard: TextractResult with nil text → returns nil, AiClient not called | PASS |
| 3 | Idempotency: write structured_extraction twice → second value wins, clean overwrite | PASS |
| 4 | CustomErrorStructuredExtraction: message, param, is_a?(StandardError) | PASS |
| 5 | AiApiRequest polymorphic association: responds_to + reflection confirms :requestable | PASS |

**VERDICT: 5/5 PASS — 0 findings**
