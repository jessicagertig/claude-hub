# Modals: Frozen-Props Correctness — Round 4

Round scope: `JobCriteriaViewModal.tsx` is in the fix commit (fixes 3, 5, 6, 8); `RegenerateJobCriteriaConfirmModal.tsx` is NOT in the commit file list — verified untouched, honoring the report's "Ruled, DO NOT touch" adjudication (mutation-in-modal rule-22 pattern stays). Rounds 2-3 findings stand for everything behavioral.

## JobCriteriaViewModal changes audited line by line

- Fix 3: local `TIERS` deleted, `JOB_CRITERIA_TIERS` imported and mapped (:32) — rendering logic (`filter` on `criterion.tier === tier.key`, empty-tier `return null`, `React.Fragment key={tier.key}`) unchanged. The shared const's extra glossary fields are unused here — no rendering change.
- Fix 5: CloseButton `border-radius: 5px` → `${t.rounded.sm};` (:95), ListBox `7px` → `${t.rounded.md};` (:140) — value-identical (0.3125rem/0.4375rem).
- Fix 6: Description `${t.text.sm};` (:127), TierHead `.label`/`.count` `${t.text.xs};` (:163, :168) — value-identical.
- Fix 8: CloseButton `&:focus { outline: none; box-shadow: 0 0 0 2px ${t.dark ? t.color.gray[500] : t.color.gray[300]}; }` (:108-111) — byte-identical to ui_styling.md rule 6's example.
- Import reorder (AiJobCriterion moved below the new JOB_CRITERIA_TIERS import) keeps the @ats-then-@shared grouping — consistent with the file's existing convention and `JobCriteriaSection.tsx`.

Frozen-`criteria`-prop stale-viewer behavior: unchanged, consciously accepted in prior rounds — nothing in the fix commit alters the open/close wiring, `FullModal` custom-header pattern, or `onCancel` paths.

## Findings

No issues found.
