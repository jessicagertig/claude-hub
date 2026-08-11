# item1-mailer-recipients — Pass 1

Scope: Task B1 (`bulk_all_stages_ai_summary_result_mailer.rb`, SPEC 1.6) + Task T1 (mailer spec, SPEC 1.7) + B1.6 polymer-mail templates.

## Fact Check

| Claim (plan) | Verify | Result |
|---|---|---|
| `complete(user_id, job_id, succeeded_count, failed_count, skipped_count, total)` 6-arg | mailer line 4 | TRUE |
| `failed(user_id, job_id, total_queued_count)` 3-arg | mailer line 32 | TRUE |
| `@user = User.find(user_id)` in both methods (lines 5, 33) | lines 5, 33 | TRUE |
| `to: [{ name: @user.full_name, email: @user.email }],` in both (lines 12, 40) | lines 12, 40 | TRUE |
| `variables[:user_first_name] = @user.first_name` in both (lines 19, 47) | lines 19, 47 | TRUE |
| `@job = Job.find(job_id)` + `job_link` precede `message_params` | lines 6-10 / 34-38 | TRUE — insertion point valid |
| subject complete "Your Plato reviews for #{@job.title} are ready" | line 14 | TRUE |
| subject failed "We couldn't complete your Plato reviews for #{@job.title}" | line 42 | TRUE |
| tags `['polymer', 'user-facing']` | lines 17, 45 | TRUE |
| recipient analog `job_application_mailer.rb:19,21,28-32` (`recipients`/`return unless recipients.any?`/`to_recipients` map, drops `.receives_new_job_application_emails`) | Read analog | TRUE — analog uses `.actives.receives_new_job_application_emails.includes(:user)`; plan drops the preference scope (owner-ruled) |
| `job.organization_users` = `has_many through: :hiring_team_memberships` (`job.rb:48`) | Read job.rb | TRUE — line 48 |
| `actives` = `where(is_active: true)` (`organization_user.rb:48`) | Read organization_user.rb | TRUE — line 48 |
| callers unchanged (`bulk_generate_ai_summaries_job.rb`) pass same args | lines 174-183, 214-223 | TRUE — `.complete(user.id, job_id, succeeded, failed, skipped, total)` / `.failed(user.id, job_id, total_queued_count)` |
| B1.6 template line 30 `<p>Hi {{user_first_name}},</p>` in both all-stages `.mjml` | grep polymer-mail | TRUE — both files, line 30 |
| per-stage templates NOT touched (single recipient) | grep | TRUE — per-stage `.mjml` also have greeting line 30, correctly left in place |
| `{{user_first_name}}` appears only at line 30 in all-stages templates | grep | TRUE — no dangling reference after deletion |
| `BulkJobApplicationAiSummaryResultMailer` (per-stage) untouched | not in task list | TRUE |

## Greeting-removal consistency (B1.5 / B1.6 / SPEC 1.6 amended)

After B1.2/B1.4 (replace `to:`) + B1.5 (delete `@user` load and `user_first_name` variable): `@user` is referenced ONLY in the two `to:` lines and the two `user_first_name` variables — all removed. No dangling `@user` remains. No other `variables` entry, subject, or spec assertion references `@user` (subject uses `@job.title`; variables use total/counts/job_link). `user_id` stays in both signatures; callers pass it; it is simply unread. Internally consistent with SPEC 1.6 (as amended) and approved-decisions ("no greeting at all"). polymer-mail B1.6 deletes the only `{{user_first_name}}` template reference. CONSISTENT.

Note (informational, not a plan defect): `reviews/SPEC-REVIEW-COMPLETE.md` still shows the pre-ruling state (amendment A1 "retain `@user`"; E1 open). That artifact predates the 2026-07-11 owner ruling; SPEC.md and approved-decisions.md were amended to remove the greeting, and the plan correctly follows the amended source of truth.

## Completeness (SPEC 1.6 / 1.7)

- Recipients = `@job.organization_users.actives.includes(:user)` mapped to `{name,email}`, ONE `to:` array, both methods (B1.1–B1.4). COVERED.
- `return unless recipients.any?` bare guard, both methods (B1.1/B1.3). COVERED (core rule 8).
- No opt-out filter (none exists). COVERED.
- Greeting removed (B1.5 + B1.6). COVERED (SPEC 1.6 amended).
- Spec reconcile (T1): 6-arg `complete` call (T1.2), subject/tags fixes (T1.2/T1.3), multi-recipient assertions active-present/inactive-absent (T1.2/T1.3), `user_first_name` absent assertion (T1.5). Falsifiable (T1.4 — `active_member` distinct user added to hiring team). Helper `create_credit_test_organization_user(org, role:)` exists (`ai_credits_test_helpers.rb:85-92`) and returns an `OrganizationUser` with `.user`. `job.organization_users << member` supported by the has_many-through. COVERED.

## Findings
- No issues found. (Variable naming: plan keeps analog's `recipients`/`to_recipients` collection names and renames the block var to `organization_user` per core rule 9 — pin-faithful; not a finding per REVIEW-ANGLES priority rule.)

## Amendments Applied
- None.
