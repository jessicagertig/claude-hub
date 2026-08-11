# Round 2 — Angle 5: Frontend display states, loading, payload contract

SPEC.md re-read in full. Round 1's two MED amendments verified in place and correct:
- §8.2 row 1 (underlying content = row 4 card / row 5 EmptyState; rows 2-3 unreachable) — re-derived from the serializer contract: with an in-flight latest row, `status` ∈ pending/in_progress/retrying and `zeroCriteriaFailure` = false; only `criteria` presence discriminates. Correct.
- §8.2 action-row placement paragraph — consistent with EmptyState.tsx:7-13 (re-checked) and with §8.3's action-row description.
Citation fixes (RunPlatoAddDescriptionModal :32, FormSection :11/:36/:47, OrganizationAiUsage :17-19) verified against source.

New check this round (fresh eyes on §8.1 interfaces vs actual stored data):

- F1 evidence: stored criteria entries are written with keys required by the extraction response schema — `text, tier, tier_reasoning, binary, contains_title_technology, duplicate, source_heading, source_text` (job_description_criteria_extraction.rb:249), with `source_heading` typed `string | null` (:246); dedup deletes only the `duplicate` key (extract_criteria.rb:118-119). So `sourceHeading` arrives with a possibly-null VALUE (key present). The declared `sourceHeading?: string` permits absence but not null. The UI reads only `text`/`tier`, so no runtime impact — but the interface is the declared payload contract and should match the wire format. (Extra keys like `tierReasoning` need no declaration — TS structural typing ignores undeclared keys; §5.3's "{text, tier, source_heading, …}" ellipsis already documents them.)

## Findings

- F1 [LOW] §8.1 `AiJobCriterion.sourceHeading?: string` misdescribes the wire format — stored `source_heading` values can be null (schema-required key, nullable value). Fix: `sourceHeading?: string | null`.

## Amendments Applied

1. §8.1 interface: `sourceHeading?: string | null` (F1). Patched block re-read and verified.
