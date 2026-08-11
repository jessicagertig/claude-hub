# Other Specs Audit — Round 2 (4 files)

**Branch:** `UI-polishes` | **Date:** 2026-06-18
**Totals:** 11 findings (0 BLOCKER, 0 HIGH, 11 MED), 1 convention issues, 0 clean specs

## Files

| # | File | Findings | Status |
|---|------|----------|--------|
| 1 | `ai_credit_notification_mailer_spec.rb` | 2M, 1C | MED |
| 2 | `organization_ai_credit_balance_policy_spec.rb` | 3M | MED |
| 3 | `organization_ai_credit_balance_serializer_spec.rb` | 4M | MED |
| 4 | `ai_credits_test_helpers.rb` | 2M | MED |

## Findings

### `ai_credit_notification_mailer_spec.rb`

**Code under test:** `app/mailers/ai_credit_notification_mailer.rb`
**File chain:** spec/mailers/ai_credit_notification_mailer_spec.rb -> app/mailers/ai_credit_notification_mailer.rb -> app/mailers/application_mailer.rb -> app/services/emails/send_template_email.rb -> app/models/organization_ai_credit_balance.rb -> app/models/organization_user.rb (is_admin, line 54) -> config/initializers/01_variables.rb

**Summary:** The AiCreditNotificationMailer spec is functional and not a ghost test. The three audit prongs found no BLOCKERs or HIGHs. The spec correctly exercises the production mailer's admin_recipients filtering, low_credits email dispatch, and zero_credits email dispatch. The have_received block-form assertions do propagate failures and run for each invocation, so the tests are real. Two MED-level coverage gaps exist: (1) the zero_credits describe block lacks the send-count assertion and variable assertions that the low_credits block has, creating asymmetric coverage for two structurally identical methods; (2) neither method's test asserts on from, list_unsubscribe, or all template variables (user_first_name, billing_url). One minor convention issue: a block-local variable named 'ou' instead of a model-matching name. Overall, this is a reasonable spec with moderate coverage gaps but no misleading assertions.

**F1 [MED] [Prong 3: drift] zero_credits test missing send-count assertion and variable assertions**
- Location: `spec/mailers/ai_credit_notification_mailer_spec.rb:68-88`
- The low_credits describe block (lines 60-65) has a dedicated test verifying send is called exactly once per admin recipient. The zero_credits describe block has no equivalent test. Additionally, the zero_credits test does not assert on any template variables (user_first_name, organization_name, billing_url), while the production code at app/mailers/ai_credit_notification_mailer.rb:44-47 passes all three. The low_credits test at least asserts on credits_remaining and organization_name. This is an asymmetric coverage gap between the two methods that share the same structure.
- Evidence: Production code zero_credits (line 30-53) iterates admin_recipients and calls SendTemplateEmail.new(...).send for each, passing variables: { user_first_name:, organization_name:, billing_url: }. The spec (lines 77-87) only asserts on to, subject, template, template_version, and tags. No assertion on variables content. No assertion on send count. Compare with low_credits spec which has both (lines 46-65).

**F2 [MED] [Prong 3: drift] Neither test asserts on from, list_unsubscribe, or all template variables**
- Location: `spec/mailers/ai_credit_notification_mailer_spec.rb:46-57 and 77-87`
- Both low_credits and zero_credits production methods build message_params with from: { name: 'Polymer', email: Variables::DEFAULT_EMAIL_FROM_ADDRESS }, list_unsubscribe: mailto address, and full variables hashes. The spec asserts on a subset: to, subject, template, template_version, tags, and partial variables for low_credits only. The from and list_unsubscribe fields are not asserted anywhere. The user_first_name and billing_url variables are not asserted for either method.
- Evidence: Production low_credits (lines 10-26): builds message_params with :from, :to, :list_unsubscribe, :subject, :template, :template_version, :tags, :variables (user_first_name, organization_name, credits_remaining, billing_url). Spec low_credits test (lines 49-57): asserts to, subject, template, template_version, tags, variables[:credits_remaining], variables[:organization_name]. Missing: from, list_unsubscribe, variables[:user_first_name], variables[:billing_url].

**C1 [Convention] backend/_base.md rule 9 (variable names must match model names)**
- Location: `spec/mailers/ai_credit_notification_mailer_spec.rb:8`
- The block-local variable 'ou' is an abbreviated name for an OrganizationUser record. Per convention, it should be 'organization_user' or similar. This is a block-local in a let declaration so it is minor, but it deviates from the naming convention.

---

### `organization_ai_credit_balance_policy_spec.rb`

**Code under test:** `app/policies/organization_ai_credit_balance_policy.rb`
**File chain:** spec/policies/organization_ai_credit_balance_policy_spec.rb -> app/policies/organization_ai_credit_balance_policy.rb -> app/policies/application_policy.rb (is_org_user?, is_org_admin?, is_org_owner?, is_god_admin?) -> app/models/organization_user.rb (role enum: org_user=0, org_admin=1, org_owner=2, org_interviewer=3, god_admin=99) -> app/models/user.rb (current_organization_user belongs_to) -> spec/support/ai_credits_test_helpers.rb (create_credit_test_organization)

**Summary:** The spec is not a ghost test -- it directly exercises the production policy's show? method without stubs and would fail if the production code were deleted. However, it has three MED-level issues around test adequacy. First, both test subjects (owner and hiring_team_user) end up with the same effective role (org_user) due to how create_credit_test_organization creates the OrganizationUser record with the default role before the owner_org_user let block runs, meaning the owner never actually tests as org_owner. Second, the spec lacks a negative test for org_interviewer denial, which is the critical boundary this policy enforces (is_org_user? explicitly excludes org_interviewer from the permission chain). Third, the record argument passed to the policy constructor (:ai_credit) differs from what the controller actually passes (:organization_ai_credit_balance), though this has no behavioral impact. No drift was detected -- the production policy has only show? and the spec covers it.

**F1 [MED] [Prong 2: tests what it claims] No negative test for org_interviewer denial at policy boundary**
- Location: `spec/policies/organization_ai_credit_balance_policy_spec.rb:33-36`
- The policy's show? method calls is_org_user?, which in ApplicationPolicy (line 54-56) checks org_user? || is_org_admin?. This role chain explicitly excludes org_interviewer (the lowest role in the hierarchy). The spec only tests two positive cases (both effectively org_user role) and never tests that an org_interviewer is denied. For a policy spec, the denial boundary is the critical behavior to verify.
- Evidence: Production code (application_policy.rb:54-56): is_org_user? returns user.current_organization_user&.org_user? || is_org_admin?. The role hierarchy goes god_admin -> org_owner -> org_admin -> org_user -> org_interviewer, and is_org_user? stops at org_user. An org_interviewer would get false from show?. The spec (lines 33-36) only asserts be true for owner and hiring_team_user, both of whom have effective role org_user. No it block tests that org_interviewer returns false.

**F2 [MED] [Prong 2: tests what it claims] Owner variable has org_user role, not org_owner -- misleading test setup**
- Location: `spec/policies/organization_ai_credit_balance_policy_spec.rb:6-12`
- The let(:owner) variable is named 'owner' implying an org_owner role, but the actual OrganizationUser record for this user has role org_user (the default). create_credit_test_organization (ai_credits_test_helpers.rb:66) calls organization.users << user which creates an OrganizationUser with default role org_user. The owner_org_user let (line 9-12) uses find_by which finds this existing record with org_user role, so the OrganizationUser.create! fallback with role: :org_owner never executes. The test appears to verify that an owner is allowed, but actually verifies the same role (org_user) twice.
- Evidence: ai_credits_test_helpers.rb:66: organization.users << user -- creates OrganizationUser with default role org_user (enum value 0). Spec line 9-12: owner_org_user does OrganizationUser.find_by(user: owner, organization: organization) which finds the already-created org_user record. The || branch with role: :org_owner never fires. Both owner and hiring_team_user end up with role org_user. The test says 'allows any org user' but tests the same role twice rather than testing distinct roles (org_owner, org_admin, org_user).

**F3 [MED] [Prong 2: tests what it claims] Record argument differs from controller usage**
- Location: `spec/policies/organization_ai_credit_balance_policy_spec.rb:34`
- The spec passes :ai_credit as the record argument to the policy constructor, but the controller (organization_ai_credit_balance_controller.rb:5) passes :organization_ai_credit_balance. While this does not affect test behavior because show? only calls is_org_user? (which ignores the record), the spec does not mirror how the policy is actually invoked in production.
- Evidence: Spec line 34: described_class.new(owner, :ai_credit). Controller line 5: authorize :organization_ai_credit_balance, :show? -- Pundit translates this to OrganizationAiCreditBalancePolicy.new(current_user, :organization_ai_credit_balance). The record argument is different (:ai_credit vs :organization_ai_credit_balance).

---

### `organization_ai_credit_balance_serializer_spec.rb`

**Code under test:** `app/serializers/api/v1/organization_ai_credit_balance_serializer.rb`
**File chain:** spec/serializers/api/v1/organization_ai_credit_balance_serializer_spec.rb -> app/serializers/api/v1/organization_ai_credit_balance_serializer.rb -> app/models/organization_ai_credit_balance.rb -> app/services/plan_feature_gate.rb, app/models/organization.rb -> app/services/stripe/subscription_status_checker.rb

**Summary:** The spec at spec/serializers/api/v1/organization_ai_credit_balance_serializer_spec.rb is not a ghost test -- it exercises the real serializer with a database-backed model instance and no stubs, so removing the production serializer attributes would cause failures. However, every assertion is limited to key-presence checks (have_key) with a single type check (be_a(Integer)). There are zero value assertions across all three test blocks. The total_credits_remaining computation is exercised only with default-zero column values, so the sum is trivially 0 and never tested with meaningful data. The monthly_credit_allocation exercises the full PlanFeatureGate path but only verifies the result is an Integer, not that it returns the expected 50 for the starter plan. current_period_end_at only checks key existence, meaning a broken delegation returning nil would still pass. The id attribute is declared in the serializer but not tested. No drift was found between the serializer and the spec -- the attributes list matches. No convention violations were identified. The spec provides minimal contract verification (attributes are exposed) but no behavioral verification (attributes have correct values).

**F1 [MED] [Prong 2: tests what it claims] monthly_credit_allocation test asserts type but not value**
- Location: `spec/serializers/api/v1/organization_ai_credit_balance_serializer_spec.rb:7-11`
- The test verifies that monthly_credit_allocation exists and is an Integer, but never verifies the actual value. The helper creates an org with plan plan_ats_tier_starter_v2, which maps to STARTER_AI_CREDIT_ALLOCATION (50) via PlanFeatureGate. The test could assert the expected value to catch regressions where the plan-to-allocation mapping changes or the PlanFeatureGate lookup fails silently.
- Evidence: Spec line 10: expect(serialized[:monthly_credit_allocation]).to be_a(Integer). Production path: OrganizationAiCreditBalance#monthly_credit_allocation (model line 20-22) checks monthly_ai_credits_override.presence (nil for test org) then falls back to PlanFeatureGate.new(organization).monthly_ai_credit_allocation which returns 50 for plan_ats_tier_starter_v2. The test does not verify the value is 50.

**F2 [MED] [Prong 2: tests what it claims] current_period_end_at test only checks key existence, not value**
- Location: `spec/serializers/api/v1/organization_ai_credit_balance_serializer_spec.rb:13-15`
- The test verifies that current_period_end_at exists as a key but does not verify its value matches the organization's stripe_current_period_end_at. The helper sets stripe_current_period_end_at to 1.month.from_now. A broken delegation (e.g., returning nil or a wrong field) would still pass if the key is present with any value including nil.
- Evidence: Spec line 14-15: expect(serialized).to have_key(:current_period_end_at) only. Production: OrganizationAiCreditBalance#current_period_end_at (model line 24-26) delegates to organization.stripe_current_period_end_at. The have_key matcher succeeds even if the value is nil, so a broken delegation that returns nil would not be caught.

**F3 [MED] [Prong 2: tests what it claims] Bucket attribute test checks key presence only, never verifies computed total**
- Location: `spec/serializers/api/v1/organization_ai_credit_balance_serializer_spec.rb:18-29`
- The test verifies five bucket attribute keys exist but never asserts their values. total_credits_remaining is a computed method (sum of four columns), but with all columns at their default of 0, the sum is trivially 0. The test does not verify the computation works with non-zero values, nor does it verify the individual bucket values. This means a regression in the total_credits_remaining computation (model line 9-13) would not be caught.
- Evidence: Spec lines 20-28: iterates over five symbols and calls expect(serialized).to have_key(attr) for each. Production: total_credits_remaining (model lines 9-13) computes (daily_credits_remaining || 0) + (monthly_credits_remaining || 0) + (addon_subscription_credits_remaining || 0) + (addon_credits_remaining || 0). All four columns default to 0 in the schema (db/schema.rb lines 946-949), so the sum is always 0 in this test. The test never creates a balance with non-zero values to verify the computation.

**F4 [MED] [Prong 3: drift] id attribute declared in serializer but not tested in spec**
- Location: `spec/serializers/api/v1/organization_ai_credit_balance_serializer_spec.rb:1-30`
- The serializer declares :id as its first attribute (serializer line 4), but no test verifies that id appears in the serialized output. This is a minor coverage gap -- id is a standard database column that AMS handles automatically, but the spec claims to verify 'the existing bucket attributes' without including id.
- Evidence: Serializer line 4: attributes :id, :daily_credits_remaining, ... The spec tests 7 of 8 attributes. No test checks for :id.

---

### `ai_credits_test_helpers.rb`

**Code under test:** `app/models/organization.rb (and Organization, OrganizationAiCreditBalance, User, OrganizationUser, Job, Candidate, JobApplication, TextractResult, AiJobApplicationSummary models)`
**File chain:** spec/support/ai_credits_test_helpers.rb -> app/models/organization.rb -> app/models/organization_ai_credit_balance.rb, app/models/user.rb, app/models/organization_user.rb, app/models/job.rb, app/models/candidate.rb, app/models/job_application.rb -> app/interactors/find_or_create_ai_job_application_summary_status.rb, app/models/textract_result.rb -> app/models/ai_job_application_summary.rb

**Summary:** This is a spec/support helper module (not a spec itself), so ghost test detection and assertion auditing do not apply directly. The module provides 6 helper methods for creating test data across AI credit specs. All model references, enum values, and association names are current and valid. Two MED-severity drift findings: (1) the with_settings parameter is dead code after the OrganizationAiSetting model was removed -- it is silently accepted and ignored while 3 spec files pass with_settings: false expecting it to do something; (2) the balance creation path in the helper diverges from the production callback (no monthly credits set, bang vs non-bang) without documenting why. No convention issues found -- the helper correctly uses bang methods (acceptable per core_critical_rules.md rule 11 exception for spec files), properly stubs callbacks at the instance level rather than mutating the class callback chain, and follows snake_case naming. The singleton_method stubs for complete_setup_workers and create_ai_credit_state_if_needed are a sound pattern that avoids cross-test pollution from skip_callback/set_callback.

**F1 [MED] [Prong 3: drift] with_settings parameter is dead code after OrganizationAiSetting removal**
- Location: `spec/support/ai_credits_test_helpers.rb:24`
- The with_settings parameter is accepted (with a rubocop:disable for Lint/UnusedMethodArgument) but does nothing. It was originally used to conditionally create an OrganizationAiSetting record (confirmed via git history at commit 6c8bc2ad). That model was removed and AI settings now live in organizations.settings jsonb (Organization model line 29 comment confirms this). Three spec files pass with_settings: false (organization_ai_credit_purchase_spec.rb:6, ai_credit_balance_transaction_spec.rb:6, organization_ai_credits_spec.rb:25) expecting it to prevent settings creation, but the parameter is silently ignored. The code is functionally harmless (there are no settings to skip), but is misleading to future readers and maintainers.
- Evidence: The helper method signature at line 21-24 accepts with_settings: true with rubocop:disable Lint/UnusedMethodArgument. Git history shows commit 6c8bc2ad had: 'if with_settings && defined?(OrganizationAiSetting) then OrganizationAiSetting.find_or_create_by!(organization: organization) end'. The current version has no code path that reads with_settings. Organization model line 29: '# organization_ai_setting table removed -- AI settings now live in organizations.settings jsonb'. The module docstring at line 8 still references 'AI settings now live in organizations.settings jsonb' but the parameter no longer controls anything.

**F2 [MED] [Prong 3: drift] Balance created by helper differs from production callback behavior**
- Location: `spec/support/ai_credits_test_helpers.rb:69`
- The helper creates OrganizationAiCreditBalance via find_or_create_by! (bang version) at line 69 but does NOT set monthly_credits_remaining. The production callback create_ai_credit_state_if_needed (Organization model lines 200-201) uses non-bang find_or_create_by AND sets monthly_credits_remaining to PlanFeatureGate::MINIMUM_AI_CREDIT_ALLOCATION (25) when the value is zero. This means test orgs get a balance with 0 monthly credits while production orgs get 25. This appears intentional (consumer specs explicitly set credit values in before blocks), but the behavioral divergence between test setup and production is undocumented in the helper.
- Evidence: Helper line 69: OrganizationAiCreditBalance.find_or_create_by!(organization: organization). Production Organization model lines 200-201: balance = OrganizationAiCreditBalance.find_or_create_by(organization_id: id); balance.update_columns(monthly_credits_remaining: PlanFeatureGate::MINIMUM_AI_CREDIT_ALLOCATION) if balance.monthly_credits_remaining.zero?. Consumer specs like create_ai_credit_balance_transaction_spec.rb line 12 explicitly set credits: balance.update!(monthly_credits_remaining: 5, addon_credits_remaining: 10).

---
