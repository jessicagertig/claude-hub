# FindOrCreateAiJobApplicationSummaryStatus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize AiJobApplicationSummaryStatus lifecycle into one interactor, called from JobApplication setup and from `generate_ai_summary_with_credit_flow`, replacing scattered `find_or_create_by` calls and the `create_status_record` callback.

**Architecture:** New interactor `FindOrCreateAiJobApplicationSummaryStatus` owns all find-or-create logic using the hand-rolled `build` + `save` pattern (matching `FindOrCreateOrgInterviewerInvite`). A one-line helper on `JobApplication` calls the interactor. Two call sites: `enqueue_new_job_application` (eager creation) and `generate_ai_summary_with_credit_flow` (pre-generation, sets regenerating if applicable). Old ownership removed from `AiJobApplicationSummary` callback and `CreateAiSummaryGeneration`.

**Tech Stack:** Ruby/Rails 6.1, Interactor gem

**Analog:** `app/interactors/find_or_create_org_interviewer_invite.rb`

**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats` on branch `feature-ai-summaries-integrating-scoring-v4`

---

### Task 1: Create the interactor

**Files:**
- Create: `app/interactors/find_or_create_ai_job_application_summary_status.rb`
- Reference: `app/interactors/find_or_create_org_interviewer_invite.rb` (analog)
- Reference: `app/models/ai_job_application_summary_status.rb` (model with enum `none: 0, current: 1, regenerating: 2`)

- [ ] **Step 1: Create the interactor file**

```ruby
# frozen_string_literal: true

class FindOrCreateAiJobApplicationSummaryStatus
  include Interactor

  def call
    job_application = context.job_application

    status_record = job_application.ai_job_application_summary_status

    if status_record
      handle_existing(status_record)
    else
      status_record = create_new(job_application)
    end

    context.ai_job_application_summary_status = status_record
  end

  private

  def handle_existing(status_record)
    summary = status_record.ai_job_application_summary

    return unless summary

    if summary.status_succeeded?
      status_record.update_columns(status: 'regenerating')
    else
      status_record.update_columns(
        ai_job_application_summary_id: nil,
        status: 'none',
        score_percentage: nil,
        headline: nil,
        integrated_role_analysis: nil
      )
    end
  end

  def create_new(job_application)
    succeeded_summary = job_application.ai_job_application_summaries
      .where(stale: false, status: :succeeded)
      .order(created_at: :desc)
      .first

    status_record = job_application.build_ai_job_application_summary_status

    if succeeded_summary
      status_record.ai_job_application_summary = succeeded_summary
      status_record.status = 'current'
      status_record.score_percentage = succeeded_summary.score_percentage
      status_record.headline = succeeded_summary.headline
      status_record.integrated_role_analysis = succeeded_summary.integrated_role_analysis
    else
      status_record.status = 'none'
    end

    unless status_record.save
      context.fail!
    end

    status_record
  rescue ActiveRecord::RecordNotUnique
    job_application.reload.ai_job_application_summary_status
  end
end
```

- [ ] **Step 2: Verify the file loads without syntax errors**

Run: `cd /Users/jessica/wrk/wrk-corp/inflow-ats && bundle exec rails runner "FindOrCreateAiJobApplicationSummaryStatus"`

Expected: No error output (class loads successfully)

---

### Task 2: Add helper method on JobApplication

**Files:**
- Modify: `app/models/job_application.rb`

- [ ] **Step 1: Add the helper method**

Add to `JobApplication` as a public instance method, near `enqueue_new_job_application` (around line 150). Note: `enqueue_new_job_application` is public (the only `private` keyword is at line 896). Place the new method immediately before `enqueue_new_job_application`:

```ruby
def find_or_create_ai_job_application_summary_status
  FindOrCreateAiJobApplicationSummaryStatus.call(job_application: self)
end
```

- [ ] **Step 2: Add the call to `enqueue_new_job_application`**

Add as the last line of `enqueue_new_job_application` (after the Flipper-gated `SubmitResumeToTextractJob` block). The method becomes:

```ruby
def enqueue_new_job_application
  NewJobApplicationJob.perform_later(id)
  DocxToPdfJob.perform_later(id)
  if Flipper.enabled?(:TEXTRACT_RESUME_PROCESSING, job.organization)
    SubmitResumeToTextractJob.perform_later(id)
  end
  find_or_create_ai_job_application_summary_status
end
```

- [ ] **Step 3: Verify the method exists**

Run: `cd /Users/jessica/wrk/wrk-corp/inflow-ats && bundle exec rails runner "puts JobApplication.instance_method(:find_or_create_ai_job_application_summary_status)"`

Expected: Outputs the method reference without error

---

### Task 3: Add call in `generate_ai_summary_with_credit_flow`

**Files:**
- Modify: `app/models/textract_result.rb`

- [ ] **Step 1: Add the interactor call after the early return guard**

In `generate_ai_summary_with_credit_flow`, after the early return guard at line 68 (`return if latest&.status_succeeded? && !latest.stale?`), before `generate_ai_summary` at line 70, add:

```ruby
job_application.find_or_create_ai_job_application_summary_status
```

The method should now read:
```ruby
def generate_ai_summary_with_credit_flow
  organization = job_application&.job&.organization
  ap '[generate_ai_summary_with_credit_flow] entry'
  ap id
  ap organization&.id

  latest = job_application.latest_ai_job_application_summary
  return if latest&.status_succeeded? && !latest.stale?

  job_application.find_or_create_ai_job_application_summary_status

  generate_ai_summary

  # ... rest unchanged
end
```

---

### Task 4: Remove old ownership — `AiJobApplicationSummary`

**Files:**
- Modify: `app/models/ai_job_application_summary.rb`

- [ ] **Step 1: Delete the callback declaration**

Remove this line (line 27):
```ruby
after_commit :create_status_record, on: :create
```

- [ ] **Step 2: Delete the `create_status_record` method**

Remove this method (lines 45-47):
```ruby
def create_status_record
  AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application)
end
```

---

### Task 5: Remove old ownership — `CreateAiSummaryGeneration`

**Files:**
- Modify: `app/interactors/create_ai_summary_generation.rb`

- [ ] **Step 1: Delete the first `find_or_create_by` call**

Remove line 54 (textract pending path — single line, no block):
```ruby
        AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application)
```

- [ ] **Step 2: Delete the second `find_or_create_by` call**

Remove lines 72-74 (textract ready path — block with `regenerating` reference):
```ruby
      AiJobApplicationSummaryStatus.find_or_create_by(job_application: job_application) do |status_record|
        status_record.regenerating = false
      end
```

- [ ] **Step 3: Verify no other references remain**

Run: `cd /Users/jessica/wrk/wrk-corp/inflow-ats && grep -rn "create_status_record\|find_or_create_by.*AiJobApplicationSummaryStatus\|\.regenerating" app/ --include="*.rb"`

Expected: No output (all references removed)

---

### Task 6: Fix existing spec

**Files:**
- Modify: `spec/models/ai_job_application_summary_status_spec.rb`

- [ ] **Step 1: Update the validations and defaults tests**

The `enqueue_new_job_application` callback eagerly creates the status record, so `create_credit_test_job_application` already creates one. Both the `validations` block (line 12 `create!`) and the `defaults` block (line 23 `create!`) will hit the uniqueness constraint. Rewrite both to use the eagerly-created record:

```ruby
describe 'validations' do
  it 'enforces uniqueness on job_application_id' do
    duplicate = described_class.new(job_application: job_application)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:job_application_id]).to include('has already been taken')
  end
end

describe 'defaults' do
  it 'defaults status to none' do
    status_record = job_application.ai_job_application_summary_status
    expect(status_record.status).to eq('none')
  end

  it 'allows ai_job_application_summary_id to be nil' do
    status_record = job_application.ai_job_application_summary_status
    expect(status_record.ai_job_application_summary_id).to be_nil
  end
end
```

---

### Task 7: Add interactor spec

**Files:**
- Create: `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb`

- [ ] **Step 1: Write the spec**

Note: `create_credit_test_job_application` triggers `after_commit :enqueue_new_job_application`, which calls `find_or_create_ai_job_application_summary_status`. So a status record is eagerly created with `status: :none` for every test job_application. The "record does not exist" tests must destroy it first. The "record exists" tests use the eagerly-created record directly.

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FindOrCreateAiJobApplicationSummaryStatus, type: :interactor do
  let(:organization) { create_credit_test_organization }
  let(:job_record) { create_credit_test_job(organization: organization) }
  let(:job_application) { create_credit_test_job_application(job: job_record) }

  describe 'record does not exist' do
    before { job_application.ai_job_application_summary_status&.destroy }

    context 'no succeeded summary' do
      it 'creates with status none' do
        result = described_class.call(job_application: job_application.reload)

        expect(result).to be_success
        expect(result.ai_job_application_summary_status).to be_persisted
        expect(result.ai_job_application_summary_status.status).to eq('none')
        expect(result.ai_job_application_summary_status.ai_job_application_summary_id).to be_nil
      end
    end

    context 'succeeded non-stale summary exists' do
      let!(:summary) do
        job_application.ai_job_application_summaries.create!(
          status: :succeeded,
          stale: false,
          score_percentage: 85.0,
          headline: 'Strong candidate',
          integrated_role_analysis: 'Good fit'
        )
      end

      it 'creates with status current and denormalized columns' do
        result = described_class.call(job_application: job_application.reload)

        status_record = result.ai_job_application_summary_status
        expect(status_record.status).to eq('current')
        expect(status_record.ai_job_application_summary_id).to eq(summary.id)
        expect(status_record.score_percentage).to eq(85.0)
        expect(status_record.headline).to eq('Strong candidate')
        expect(status_record.integrated_role_analysis).to eq('Good fit')
      end
    end
  end

  describe 'record exists' do
    context 'ai_job_application_summary is nil' do
      it 'makes no changes' do
        status_record = job_application.ai_job_application_summary_status

        result = described_class.call(job_application: job_application)

        expect(result).to be_success
        status_record.reload
        expect(status_record.status).to eq('none')
      end
    end

    context 'ai_job_application_summary is present and succeeded' do
      let!(:summary) do
        job_application.ai_job_application_summaries.create!(
          status: :succeeded,
          score_percentage: 75.0,
          headline: 'Decent candidate',
          integrated_role_analysis: 'Reasonable fit'
        )
      end

      before do
        job_application.ai_job_application_summary_status.update_columns(
          ai_job_application_summary_id: summary.id,
          status: 'current',
          score_percentage: 75.0,
          headline: 'Decent candidate',
          integrated_role_analysis: 'Reasonable fit'
        )
      end

      it 'sets status to regenerating' do
        result = described_class.call(job_application: job_application)

        expect(result).to be_success
        job_application.ai_job_application_summary_status.reload
        expect(job_application.ai_job_application_summary_status.status).to eq('regenerating')
      end
    end

    context 'ai_job_application_summary is present but not succeeded' do
      let!(:summary) do
        job_application.ai_job_application_summaries.create!(status: :failed)
      end

      before do
        job_application.ai_job_application_summary_status.update_columns(
          ai_job_application_summary_id: summary.id,
          status: 'current',
          score_percentage: 50.0,
          headline: 'Old headline',
          integrated_role_analysis: 'Old analysis'
        )
      end

      it 'clears the association, sets status to none, clears denormalized columns' do
        result = described_class.call(job_application: job_application)

        expect(result).to be_success
        status_record = job_application.ai_job_application_summary_status.reload
        expect(status_record.ai_job_application_summary_id).to be_nil
        expect(status_record.status).to eq('none')
        expect(status_record.score_percentage).to be_nil
        expect(status_record.headline).to be_nil
        expect(status_record.integrated_role_analysis).to be_nil
      end
    end
  end
end
```

---

### Task 8: Add TextractResult spec for interactor call

**Files:**
- Create or modify: `spec/models/textract_result_spec.rb` (or `spec/models/textract_result_ai_trigger_spec.rb` if that's where the existing generate tests live)

- [ ] **Step 1: Add tests for `generate_ai_summary_with_credit_flow` interactor call**

```ruby
describe '#generate_ai_summary_with_credit_flow' do
  let(:organization) { create_credit_test_organization }
  let(:job_record) { create_credit_test_job(organization: organization) }
  let(:job_application) { create_credit_test_job_application(job: job_record) }
  let(:textract_result) { job_application.textract_results.create!(textract_job_status: :succeeded, textract_job_result_text: 'resume text') }

  before do
    allow(textract_result).to receive(:generate_ai_summary)
  end

  context 'when latest summary is succeeded and not stale' do
    let!(:summary) do
      job_application.ai_job_application_summaries.create!(
        status: :succeeded,
        stale: false,
        textract_result: textract_result
      )
    end

    it 'returns early without calling the interactor' do
      expect(FindOrCreateAiJobApplicationSummaryStatus).not_to receive(:call)
      textract_result.generate_ai_summary_with_credit_flow
    end
  end

  context 'when latest summary is stale' do
    let!(:summary) do
      job_application.ai_job_application_summaries.create!(
        status: :succeeded,
        stale: true,
        textract_result: textract_result
      )
    end

    it 'calls the interactor before generate_ai_summary' do
      call_order = []
      allow(FindOrCreateAiJobApplicationSummaryStatus).to receive(:call) { call_order << :interactor }
      allow(textract_result).to receive(:generate_ai_summary) { call_order << :generate }

      textract_result.generate_ai_summary_with_credit_flow

      expect(call_order).to eq([:interactor, :generate])
    end
  end

  context 'when no summary exists' do
    it 'calls the interactor before generate_ai_summary' do
      call_order = []
      allow(FindOrCreateAiJobApplicationSummaryStatus).to receive(:call) { call_order << :interactor }
      allow(textract_result).to receive(:generate_ai_summary) { call_order << :generate }

      textract_result.generate_ai_summary_with_credit_flow

      expect(call_order).to eq([:interactor, :generate])
    end
  end
end
```

---

### Task 9: Add JobApplication spec for status record creation

**Files:**
- Create or modify: `spec/models/job_application_spec.rb`

- [ ] **Step 1: Add test for `enqueue_new_job_application` creating status record**

```ruby
describe '#enqueue_new_job_application' do
  let(:organization) { create_credit_test_organization }
  let(:job_record) { create_credit_test_job(organization: organization) }

  it 'creates an AiJobApplicationSummaryStatus with status none' do
    job_application = create_credit_test_job_application(job: job_record)

    status_record = job_application.ai_job_application_summary_status
    expect(status_record).to be_present
    expect(status_record.status).to eq('none')
  end
end
```

---

### Task 10: Verify all generation flows

- [ ] **Step 1: Verify manual generation path**

Run: `cd /Users/jessica/wrk/wrk-corp/inflow-ats && bundle exec rails runner "
ja = JobApplication.find(6797)
puts 'Status record exists: ' + ja.ai_job_application_summary_status.present?.to_s
puts 'Status: ' + (ja.ai_job_application_summary_status&.status || 'nil')
"`

Expected: Status record exists with `status: current`

- [ ] **Step 2: Verify the interactor runs on an existing record with succeeded summary**

Run: `cd /Users/jessica/wrk/wrk-corp/inflow-ats && bundle exec rails runner "
ja = JobApplication.find(6797)
result = FindOrCreateAiJobApplicationSummaryStatus.call(job_application: ja)
puts 'Success: ' + result.success?.to_s
puts 'Status: ' + result.ai_job_application_summary_status.status
"`

Expected: `Success: true`, `Status: regenerating`

- [ ] **Step 3: Verify the interactor creates a record for a job_application without one**

Run: `cd /Users/jessica/wrk/wrk-corp/inflow-ats && bundle exec rails runner "
ja = JobApplication.where.not(id: AiJobApplicationSummaryStatus.pluck(:job_application_id)).first
puts 'JA ID: ' + ja.id.to_s
result = FindOrCreateAiJobApplicationSummaryStatus.call(job_application: ja)
puts 'Success: ' + result.success?.to_s
puts 'Status: ' + result.ai_job_application_summary_status.status
"`

Expected: `Success: true`, `Status: none`

---

### Task 11: Commit

- [ ] **Step 1: Stage all changed files**

```bash
cd /Users/jessica/wrk/wrk-corp/inflow-ats
git add app/interactors/find_or_create_ai_job_application_summary_status.rb \
  app/models/job_application.rb \
  app/models/textract_result.rb \
  app/models/ai_job_application_summary.rb \
  app/interactors/create_ai_summary_generation.rb \
  spec/models/ai_job_application_summary_status_spec.rb \
  spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb \
  spec/models/textract_result_spec.rb \
  spec/models/job_application_spec.rb
```

- [ ] **Step 2: Review the diff**

Run: `cd /Users/jessica/wrk/wrk-corp/inflow-ats && git diff --cached`

Verify:
- New file: `find_or_create_ai_job_application_summary_status.rb`
- New file: `spec/interactors/find_or_create_ai_job_application_summary_status_spec.rb`
- `job_application.rb`: new method + call in `enqueue_new_job_application`
- `textract_result.rb`: one new line in `generate_ai_summary_with_credit_flow`
- `ai_job_application_summary.rb`: callback + method removed
- `create_ai_summary_generation.rb`: `find_or_create_by` calls removed (line 54 and lines 72-74)
- `ai_job_application_summary_status_spec.rb`: `regenerating` test replaced with `status` test

- [ ] **Step 3: Commit**

```bash
cd /Users/jessica/wrk/wrk-corp/inflow-ats && nvm use && git commit -m "feat: centralize AiJobApplicationSummaryStatus lifecycle into FindOrCreateAiJobApplicationSummaryStatus interactor

Replace scattered find_or_create_by calls and create_status_record callback
with a single interactor using the hand-rolled build+save pattern. Called from
JobApplication setup (eager creation) and generate_ai_summary_with_credit_flow
(pre-generation regenerating check). Sets status to :regenerating when a
succeeded summary exists and new generation is starting.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```
