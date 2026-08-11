# Failure Report -- Implementation Round 1

## Issues to fix

### 1. [BLOCKER] Ghost test: retry_on exhaustion

**File:** `spec/jobs/extract_structured_resume_data_job_spec.rb:44-49`

**Problem:** The `describe 'retry_on exhaustion'` block does not test what it claims. The only assertion is:

```ruby
expect(described_class.instance_method(:perform)).to be_a(UnboundMethod)
```

This is trivially true for any class that defines `perform`. The test also assigns `retry_config = described_class.rescue_handlers` but never asserts on it. The test passes regardless of whether `retry_on` exists, what error class it targets, how many attempts are configured, or whether an exhaustion block is present.

**Fix options:**

Option A -- Replace with a real test that verifies retry_on behavior:
```ruby
describe 'retry_on exhaustion' do
  it 'logs when retries are exhausted' do
    allow(ExtractStructuredResumeData).to receive(:new)
      .and_return(instance_double(ExtractStructuredResumeData, extract: nil))

    error = CustomErrorStructuredExtraction.new('persistent failure')

    # Verify the exhaustion block runs
    expect(Rails.logger).to receive(:error).with(/exhausted retries/)

    described_class.new(textract_result_id).rescue_with_handler(error)
  end
end
```

Option B -- Remove the test entirely and verify retry_on by class-level assertion:
```ruby
describe 'retry_on configuration' do
  it 'retries on CustomErrorStructuredExtraction' do
    # ActiveJob stores retry_on handlers in rescue_handlers
    handler_classes = described_class.rescue_handlers.map { |h| h[0] }
    expect(handler_classes).to include('CustomErrorStructuredExtraction')
  end
end
```

Option C -- Remove the test entirely. The retry_on declaration is visible in the class definition and is covered indirectly by the `'re-raises the error for retry_on to catch'` test which verifies the error propagation that triggers retry.

### 2. [HIGH] schema.rb not committed

**File:** `db/schema.rb`

**Problem:** Migrations were run locally but `db/schema.rb` was not staged or committed. The committed schema.rb on the branch does not include the new columns, GIN index, or trigger definition.

**Fix:** Stage and commit `db/schema.rb`:
```bash
git add db/schema.rb
git commit -m "Update schema.rb with structured extraction columns and tsvector trigger"
```

Note: If `db/structure.sql` is also used (check `config/application.rb` for `config.active_record.schema_format`), verify it is also up to date.
