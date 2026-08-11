# Round 1 — Angle 3: Job gating change, ExtractJobCriteriaJob signature (FLAG 4 — DECIDED HERE), WebSocket broadcast lifecycle

## FLAG 4 DECISION (deferred to this review by the orchestrator; decided here as Jessica's proxy)

**Decision: the optional POSITIONAL signature stands — `def perform(ai_job_criteria_id, requesting_organization_user_id = nil)`. The spec is NOT converted to the analog's kwargs form.**

### Evidence (both job files opened and compared)

Analog — `app/jobs/generate_ai_job_application_summary_job.rb`:
- Signature KWARGS: `def perform(textract_result_id:, requesting_organization_user_id: nil)` (:24).
- Exhaustion block reads `job.arguments.first[:textract_result_id]` (:16) and `job.arguments.first[:requesting_organization_user_id]` (:20).
- All its enqueue sites already pass kwargs (`textract_result.rb:130-133, :144`; `ai_job_criteria.rb:25-28`; `create_ai_summary_generation.rb:71-74`).

Current job — `app/jobs/extract_job_criteria_job.rb`:
- Signature POSITIONAL: `def perform(ai_job_criteria_id)` (:12); exhaustion reads `job.arguments.first` (:8).
- Four production enqueue sites, all single positional: `job.rb:707` (`set(wait: 30.seconds).perform_later(id)`), :709, :723, :732.
- Its spec calls positionally throughout: `spec/jobs/extract_job_criteria_job_spec.rb:15, 30, 49, 63` (`described_class.perform_now(id)`).
- `retry_on CustomErrorAiSummary, wait: 2.minutes, attempts: 3` (:5) — retry waves keep positional payloads alive up to ~6 minutes.

### Why kwargs is technically blocked (not a churn argument)

At deploy time, positional `[id]` payloads exist in the queue and the scheduled set (30-second `set(wait:)` enqueues at job.rb:707; 2-minute retry waves; ordinary queue latency). Against a kwargs signature, ActiveJob deserializes and invokes `perform(123)` → `ArgumentError: missing keyword: :ai_job_criteria_id` **at method invocation, before the body runs**. Consequences:
- Method-level `rescue CustomErrorAiSummary` / `rescue StandardError` never fire (arity errors raise in the caller, not the body).
- `retry_on CustomErrorAiSummary` does not match ArgumentError — no exhaustion block, no failure write.
- The `AiJobCriteria` row is stranded `pending`/`in_progress` forever; the new serializer reports in-flight forever; the frontend Regenerate button spins forever. This is precisely the class of harm the feature exists to avoid.
- No single-deploy mitigation exists short of a hybrid dual-form signature (rejected: uglier than either pure form and matches no codebase pattern) or a two-deploy migration (out of scope for this feature).

Checked `git log --follow` on the analog: it was built kwargs-first (no positional→kwargs conversion precedent exists in its history to borrow a migration pattern from).

### Rule-14 accounting

The deviation is the signature FORM only. The structural pattern that matters — "the exhaustion block reads `job.arguments` in the signature's own shape; broadcast sites, terminal-status guard, auto-path-nil-never-broadcasts all mirror the analog" — is preserved. The orchestrator's directive was "align with the analog unless technically blocked"; the in-flight-payload breakage is a genuine technical block, verified against the live `retry_on`/`set(wait:)` enqueue mechanics, not a convenience rationalization.

## Verified against source (rest of the angle)

**Gating change (SPEC 4.1):**
- Worktree still has the OLD form — guards in `_if_needed` (job.rb:726-733 `_immediately`, :737-743 `_if_needed`) ✓ spec premise holds.
- Replacement matches DECISIONS verbatim except the approved kwarg (flag 1, RULED — honored) ✓.
- Caller trace (grep, exhaustive): `_immediately` called only by `_if_needed` (job.rb:742); `_if_needed` called only by textract_result.rb:70; `auto_extract_job_criteria` called only by `handle_criteria_extraction_after_commit` (:748, :750); `extract_job_criteria` called by score_job_application.rb:23/:45 and orchestrate.rb:80. All unchanged by the spec ✓.
- Guard-set asymmetry (Phase-1 trace note 4) ADJUDICATED: `auto_extract_job_criteria`/`extract_job_criteria` guard `pending` + Flipper (:697-701, :714-718) while post-change `_immediately` guards `in_progress`/`retrying` + description. The spec touches neither of the former and does not harmonize in either direction — correct per DECISIONS verbatim code. The documented pending-row double-POST consequence stays as documented; no pending guard added ✓.

**Broadcast lifecycle:**
- Site 1 (end of perform): unreachable mid-retry — ExtractCriteria sets `:retrying` and re-raises (extract_criteria.rb:143-147), job re-raises (:19-22) ✓.
- Site 2 (exhaustion block): failure write exists at :9; ActiveJob `retry_on` block is instance_exec'd on the job instance (proven by the analog calling its private `broadcast_completion` at :20 from the same context) ✓.
- Site 3 (StandardError rescue): failure write at :28 ✓.
- Helper structure diffed against analog :50-80: OrganizationUser lookup → user → reload → terminal guard (`status_succeeded? || status_failed?` = analog :62) → camelCase payload → conditional errorMessage (= analog :73) → `GlobalChannel.broadcast_to` (channel verified, global_channel.rb:3) ✓.
- `reload` necessity verified: failure writes use `update_columns` on a DIFFERENT in-memory instance inside ExtractCriteria (@ai_job_criteria found independently at extract_criteria.rb:14) ✓.
- JSON::ParserError path (flag 3 dependency): extract_criteria.rb:148-151 writes failed WITHOUT re-raise, perform continues, broadcast fires with failed status ✓ — the behavior flag 3's approval depends on is real.
- Auto path: all four model-side enqueues pass no requesting id → nil → helper's `OrganizationUser.find_by(id: nil)` → nil → return; never broadcasts ✓ (analog-identical).

**Tests (SPEC 12):** behavioral broadcast assertions, `have_enqueued_job` for the retry path, no-requesting-user → no broadcast; gating additions in `job_criteria_lifecycle_spec.rb` (exists) — rule 26 compliant as written ✓.

## Taken on trust from the spec
Nothing — every citation used above was re-read this round.

## Findings

- F1 [MED] SPEC 7 signature bullet / justification for the positional deviation read "converting all to kwargs is churn with no behavioral gain" — a rationalization, and exactly the framing the orchestrator's flag-4 directive prohibited deciding on. The real ground is in-flight Sidekiq payload compatibility (ArgumentError at invocation bypasses every rescue and `retry_on`, stranding rows in-flight with no failure write). Evidence above. Fix: replace the justification with the technical grounds and mark flag 4 resolved.
- F2 [MED] SPEC 7 exhaustion-block and StandardError-rescue bullets did not guard the broadcast on ROW PRESENCE. The analog guards both sites (`if textract_result`, generate_ai_job_application_summary_job.rb:17-21; `if textract_result && requesting_organization_user_id`, :45). As written, a nil row (e.g., deleted between enqueue and exhaustion) with a requesting user present would hit `ai_job_criteria.reload` → NoMethodError inside the exhaustion handler. Rare path, but an error-handling-shape deviation from the analog (rule 14 / angles always-on). Fix: mirror the analog's guards at both sites.
- F3 [LOW] SPEC 4.1 kwarg parenthetical said "all four existing callers unchanged: `job.rb` enqueue sites and `textract_result.rb:70`" — conflated callers of `_immediately` (only `_if_needed`) with `ExtractJobCriteriaJob` enqueue sites. Fix: precise caller wording.

## Amendments Applied

1. SPEC 7 signature bullet rewritten: flag 4 resolved, positional stands, full deploy-compatibility rationale inline (F1).
2. SPEC 14 flag 4 line updated to RESOLVED with pointer to this file (F1).
3. SPEC 7 exhaustion bullet: broadcast only when the row exists, mirroring analog :17-21; StandardError bullet: gate on requesting id AND row presence, mirroring analog :45 (F2).
4. SPEC 4.1 caller parenthetical made precise (F3).

All four patched sections re-read and verified.
