# Angle 5 — Frontend display states, loading states, payload contract — Round 2

## Round-1 F1 [HIGH] fix — VERIFIED CLOSED

Commit `e7b8cef0a` ("Disable regenerate button while criteria extraction is in flight"): exactly ONE insertion in exactly ONE file — `disabled={isInFlight}` added at `JobCriteriaSection.tsx:153`, adjacent to the existing `loading={isInFlight}`. Verified in the working file: the Generate/Regenerate Button now carries BOTH behavioral props (pipeline rule 11; PlatoTab.tsx analog parity). Fix-agent scope check PASSES: `git show e7b8cef0a --stat` = 1 file, +1/−0; nothing else changed in the commit.

## Re-verified at HEAD (files otherwise byte-identical to round-1 state)

- Display-state precedence exactly per SPEC 8.2: `isLoading` → in-flight (layered: card if `criteria` else never-extracted) → failed+zero → failed-other → card → never-ran (`JobCriteriaSection.tsx:64-76`). Flag 5 honored (failed latest hides older succeeded card).
- View-button-during-in-flight-over-older-success: ADJUDICATED CORRECT in round 1 (SPEC 8.2 row 4 includes that state by definition) — not re-opened; implementation unchanged.
- `isInFlight = isPayloadStatusInFlight || isFetching` (D-5, deliberate) — unchanged.
- Loading: initial fetch renders `LoadingIndicator label="Loading..."` inside the FormSection; button loading driven by backend status, survives reload.
- Payload contract: `AiJobCriteriaPayload`/`AiJobCriterion` match the serializer (camelCase keys, snake_case enum values). Hook key `["aiJobCriteria", jobId]` numeric; `enabled: jobId != undefined`; mutation invalidates the same key.
- No fabricated fallbacks / no `??` (diff grep clean this round). EmptyStates standard variant; action row outside EmptyState.
- Merge check: develop touched no frontend file this feature owns (`useBulkGenerateAiSummaries.ts` / `BulkGenerateAiSummariesConfirmModal.tsx` are develop's own bulk-rescore files, byte-identical to develop at HEAD).

## Findings

No issues found. (Round-1 LOW carryovers — TIERS constant duplication, `<a onClick>` without href — remain open; recorded in code-quality.md; not re-opened as new findings.)
