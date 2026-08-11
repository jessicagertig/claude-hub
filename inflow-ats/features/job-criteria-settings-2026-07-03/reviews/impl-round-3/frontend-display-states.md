# Angle 5 — Frontend display states, loading states, payload contract — Round 3

This round's directed deep-dive (no frontend test infra): read `JobCriteriaSection.tsx`, `useAiJobCriteria.ts`, `JobSetupAiSettings.tsx` line by line against SPEC §8 and DECISIONS.

- **Six-state walk through the actual code** (JobCriteriaSection.tsx:63-74), against the verified wire format (see api-surface.md for the `render_one root: nil` + `allKeysToCamel` proof):
  - never ran → status null → `neverExtracted`; `zeroCriteriaFailure` null falls through the `status === "failed" && zeroCriteriaFailure` check safely (nil-vs-false edge verified).
  - first-run in-flight → `isPayloadStatusInFlight`, criteria null → never-extracted underlay, button `loading` + `disabled`, label `Generate criteria` (SPEC 8.2 "state 1 layered over state 5" rule honored).
  - succeeded → card; regenerating-over-success → card + loading (label `Regenerate criteria`).
  - failed+zero → zero-found EmptyState; failed-other → failure EmptyState; both hide an older succeeded card — flag 5 / Jessica's final display-precedence verdict honored, not re-opened.
  - Undefined payload after load (query error) renders the never-extracted row — same branch as status null; no error row exists in the spec's table and no fabricated state was invented; consistent with prior rounds' acceptance.
- **Loading states** (named recent failure mode): initial fetch → `LoadingIndicator label="Loading..."` inside the FormSection; button driven by BACKEND status (`isPayloadStatusInFlight`) OR `isFetching` (D-5, covers the just-POSTed refetch window); survives reload. Button carries BOTH `loading={isInFlight}` and `disabled={isInFlight}` (round-1 F1 fix intact at :151-152).
- **Types at both casing boundaries**: `AiJobCriteriaPayload`/`AiJobCriterion` match the serializer wire shape key-for-key and value-form-for-value-form (camelCase keys; snake_case enum VALUES `"in_progress"`/`"tier_1"` — core rule 7 exception). `distanceInWords` is an untyped JS-style export (time.ts:88) — no TS conflict from the `?.` access; extractedAt is co-present with criteria by serializer construction (both read the same succeeded row).
- No fabricated fallbacks: no `|| 0`/`|| []`/`?? ` in any new frontend file (grep re-run); null criteria handled by explicit conditionals (`displayState === "card" && criteria`).
- EmptyState: all three standard variant (no `roomy`/`borderless`); action row is a section-level `Styled.ActionRow` OUTSIDE EmptyState; View button rendered only in the card state.
- `TIERS` uses stored `tier_1`-form values; Bonus row only when count > 0; tabular figures on counts and card description; `PlatoChip size={36} radius={18}` un-restyled; card 560px/7px/186px rail per DECISIONS.
- Hook: key `["aiJobCriteria", jobId]` (numeric `job.id`), `enabled: jobId != undefined`, hook-level `invalidateQueries` in `onSuccess` — analog-form.
- Emotion: text utilities standalone only (`${t.text.sm}`, `${[t.text.sm, t.mt(2)]}`); no `font-size: ${t.text.*}` anywhere (pipeline rule 1 sweep re-run on all four frontend files). Separate styled components per variant, no boolean variant props forwarded to DOM (rule 12). Poly/theme tokens only; raw px values are the DECISIONS visual-spec values.
- `JobSetupAiSettings.tsx`: existing Plato-reviews FormSection, dirty tracking, Save flow preserved (additive changes only); sidebar glossary via the `sidebar` prop in the AccountTeam register; tier leads DECISIONS-verbatim.

## Findings

No issues found. (LOW carryovers — TIERS duplication, `<a onClick>` without href — remain open in code-quality.md; not re-opened.)
