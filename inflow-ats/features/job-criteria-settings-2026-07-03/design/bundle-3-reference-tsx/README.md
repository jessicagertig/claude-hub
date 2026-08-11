# Handoff: Job criteria in Plato AI settings

Adds a **Job criteria** section to the per-job Plato AI settings tab: a summary card of the criteria Plato extracted from the job description, a view slide-over, manual generate/regenerate behind a confirmation, low/zero-criteria guard modals, empty states, and a tier-glossary sidebar.

**The components carry all the details** (values, copy, rules, lifecycle) in their code and comments. Start there.

## Files
- `JobSetupAiSettings.tsx` — **the extended component.** Drop-in replacement shape for the existing production file (bundled as `JobSetupAiSettings-34f2eed8.tsx` for diffing). Contains the section, card, count rail, empty states (uses the existing `EmptyState` component), guard modals, sidebar glossary, all styled-components, and the extraction-lifecycle + copy rules as header comments.
- `JobCriteriaModals.tsx` — `ViewCriteriaModal` (FullModal right slide-over) + `RegenerateCriteriaModal` (confirmation), with their styled-components.
- `JobSetupAiSettings-34f2eed8.tsx` — current production component, unchanged, for reference.

## Notes for implementation
- These are design references produced outside the codebase: verify import paths, theme keys, `FullModal`/`Modal`/`Button` prop names, and the criteria payload shape (`tier1/tier2/tier3` + `extractedAt` assumed) before shipping.
- The Plato disc uses the existing Plato mark asset; the gradient and sizes are in the `PlatoDisc` styled-component.
- Suggested new hooks: `useJobCriteria(jobId)` and `useRegenerateJobCriteria()`, alongside `useJob`.
- Fidelity is high: recreate pixel-perfectly with the existing primitives and poly theme tokens.
