# A3 — Ripple-Site Completeness for Renames — Pass 1

## Verification

### `auto_generate_ai_summaries_setting` -> `auto_generate_ai_summaries`

| File | Plan Step | Verified in Codebase |
|------|-----------|---------------------|
| `app/models/job.rb` (enum + cascade method) | C.3.1, C.3.2 | YES — grep confirmed lines 158, 878-884 |
| `app/serializers/api/v1/job_serializer.rb` | C.3.3 | YES — grep confirmed line 5 |
| `app/controllers/api/v1/jobs_controller.rb` (strong params + key check) | C.3.4 | YES — grep confirmed lines 163, 218 |
| `app/models/organization.rb` (method + settings dig) | C.3.5 | YES — grep confirmed lines 947-948 |
| `app/controllers/api/v1/organizations_controller.rb` | C.3.6 | YES — grep confirmed line 128 |
| `app/models/textract_result.rb` | C.3.7 | YES — grep confirmed line 119 |
| `newLookups.ts` (type + array + values) | H.1.4 | YES — grep confirmed lines 38-41 |
| `JobSetupAiSettings.tsx` | H.6 | YES — exists |
| `organization.ts` | H.1.3 | YES — grep confirmed line 3 |
| `OrganizationAiSettings.tsx` | H.7 | YES — exists |
| Migration file | B.3 | YES — referenced |
| Data migration | B.6 | YES — referenced |

### `AiCreditPacks.*` -> `OrganizationAiCreditPurchase.*`

| File | Plan Step | Verified in Codebase |
|------|-----------|---------------------|
| `app/models/organization_ai_credit_purchase.rb` (validation) | C.1.3 | YES — line 14 |
| `app/jobs/stripe_webhook_handler_job.rb` (3 references: lines 111, 151, 242) | C.14.1 | YES — grep confirmed 3 refs |
| `app/interactors/apply_ai_credit_purchase.rb` (2 references: lines 48, 95) | C.14.2 | YES — grep confirmed |
| `config/initializers/ai_credit_packs.rb` (deleted) | C.1.5 | YES |
| Old controllers (deleted) | D.5 | YES — deletion handles refs |

### `ConsumeAiCredits` -> `CreateAiCreditBalanceTransaction`

| File | Plan Step | Verified in Codebase |
|------|-----------|---------------------|
| `app/interactors/consume_ai_credits.rb` (class name) | C.4.1 | YES — line 19 |
| `app/models/textract_result.rb` (call site) | C.4.2 | YES — line 81 |
| `app/interactors/notify_zero_ai_credits.rb` (comment) | C.4.3 | YES — line 8 |
| Internal logger strings (2 occurrences) | C.4.4 | YES — lines 30, 60 |
| `spec/interactors/consume_ai_credits_spec.rb` (rename) | K.3.1 | YES — line 5 |
| `spec/interactors/credit_consumption_with_notifications_spec.rb` (3 call sites + comment) | K.3.3 | YES — lines 5, 37, 88, 139 |

## Findings

No issues found. All ripple sites are covered.

## Amendments Applied

(none)
