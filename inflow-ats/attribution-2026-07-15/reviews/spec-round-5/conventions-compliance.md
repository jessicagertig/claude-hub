# conventions-compliance — Round 5

This round's conventions file: `cursor_rules/frontend/react_query/react_query_mutations_and_cache.md` (read).

- "You will NEVER edit api.ts" — respected (§7.10; §2 not-touched list).
- Hook-level callbacks for cache invalidation — untouched by the spec (§5.4 keeps `useMagicLink`/`useRegister` wrappers as-is); the new events live in component-level onSuccess callbacks, the placement the two verified analogs use (`NewJobCenterModal.tsx:46`, `CommentTemplateModal.tsx:100`). Events are not cache management; no conflict.
- No mutation definitions added or moved; no cache-invalidation changes anywhere in the diff.

Cumulative spec-stage conventions coverage (one file per round): core_critical_rules.md, backend/migrations.md, frontend/react_hooks.md, backend/controllers/controller_patterns_and_crud.md, frontend/_base.md, frontend/react_query/react_query_mutations_and_cache.md. Per-file fan-out over the full list remains encoded for impl review (REVIEW-ANGLES angle 7).

## Findings

- None.

## Amendments Applied

- None.
