# Conventions Pass — serializers.md

Diff: `git diff develop...HEAD -- app/serializers/api/v1/job_ai_job_criteria_serializer.rb` (new file, 21 lines)
Rules file: cursor_rules/backend/serializers.md

No issues found.

Verification detail:
- Rule 1 (no redundant methods for regular columns / JSONB pass-through): none of `criteria`, `extracted_at`, `status`, `zero_criteria_failure` are columns on the serialized object (Job); all reach through the `ai_job_criteria` association or a model predicate, so explicit methods are required per the rules table ("Computed value" / predicate rows). The `status` method (serializer line 14-16) returns `object.latest_ai_job_criteria&.status`, a computed value — not the prohibited `object.status` redundant-delegation pattern.
- Rules 2/3 (no `?` in attribute names; explicit predicate delegation): `zero_criteria_failure` (serializer line 18-20) delegates to `object.zero_criteria_extraction_failure?`. Compliant.
- Rule 4 (snake_case): all four attributes snake_case. Compliant.
- Rule 5 (one method per attribute): four attributes, four single-purpose methods. Compliant.
- Rule 6 (conditional attributes need approval): no conditional visibility logic present. Compliant.
- Rule 7 (model-level computation delegation): all computation lives in the model — `latest_ai_job_criteria` (app/models/job.rb:688), `latest_succeeded_ai_job_criteria` (app/models/job.rb:692), `zero_criteria_extraction_failure?` (app/models/job.rb:696). Serializer methods are pure delegation, matching the rule's sanctioned `object.total_applications_count` pattern.
