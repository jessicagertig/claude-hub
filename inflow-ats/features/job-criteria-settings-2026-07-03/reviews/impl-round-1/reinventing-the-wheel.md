# Reinventing the Wheel (always-on) — Round 1

Checked every new construct for an existing equivalent:

- **Reused, correctly:** `EmptyState`, `LoadingIndicator`, `FormSection` (+ its existing `intro` prop), `SettingsContainer` `sidebar` prop, `PlatoChip` (not re-styled — DECISIONS-mandated reuse), `Icon`, `Button`, `FullModal`, `CenterModal`, `distanceInWords`, `GlobalChannel`, `exists`/`render_one`/`render_general_errors` helpers, existing `JobPolicy`/`AiJobApplicationSummaryPolicy` methods (no new policy methods), existing validator `fail!` chains, existing `latest_ai_job_criteria`/`latest_succeeded_ai_job_criteria` scopes, react-query `apiGet`/`apiPost` layer, `useModalContext`/`useToastContext`.
- **New where new is right:** the serializer (nothing serialized criteria before — the feature's premise), the singleton controller (ai_credits precedent followed rather than reinvented), the hook file (mirrors `useAiJobApplicationSummary`/`useBulkGenerateAiSummaries` shapes), `zero_criteria_failure?`/`zero_criteria_extraction_failure?` predicates (no existing equivalent), the broadcast helper (structural copy of the analog's, necessarily per-record-type).
- **No duplicate mechanisms:** no second WebSocket channel, no bespoke fetch layer, no new toast system, no custom modal machinery, no new time-formatting helper, no parallel status enum.
- Minor duplication: the `TIERS` constant appears in two new files — recorded as code-quality F2 [LOW], not a reinvention of existing infrastructure.

## Findings

No issues found.
