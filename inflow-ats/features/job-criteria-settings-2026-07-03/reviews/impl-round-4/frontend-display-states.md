# Frontend Display States, Loading, Payload Contract — Round 4

Round scope: fixes 3-7 of commit 9ed954142 all land in this angle (shared tier metadata, query error state, border-radius/font-size/font-weight token swaps). Full re-read of `JobCriteriaSection.tsx`, `JobSetupAiSettings.tsx`, new `jobCriteriaTiers.ts`.

## Fix 4 — query error state

Shipped (JobCriteriaSection.tsx:51-61): `isError` destructured from `useAiJobCriteria` (:29); when true, renders `FormSection` + `EmptyState icon="alert-triangle" title="Could not load job criteria" message="Something went wrong while loading job criteria. Refresh the page to try again."` — copy byte-identical to the report, sentence case, no em dashes. NO action row in this branch (the entire return short-circuits before `Styled.ActionRow`) — the report's "no Generate button against unknown server state" requirement holds.

**Six-state precedence intact:** `isLoading` (:43) → `isError` (:51) → `isPayloadStatusInFlight` → `failed+zeroCriteriaFailure` → `failed` → `criteria` card → `neverExtracted` (:63-82). The error branch is inserted between loading and the payload-driven ladder exactly as ruled; the ladder itself is character-unchanged from round 3. Flag 5 (failed latest hides older succeeded card) untouched. `isInFlight = isPayloadStatusInFlight || isFetching` untouched; button `loading`/`disabled` wiring untouched.

## Fix 3 — shared tier metadata

`jobCriteriaTiers.ts` (new): `JobCriteriaTier` interface (`key: "tier_1" | "tier_2" | "tier_3"`, label, icon, glossaryLead, glossaryRest) + `JOB_CRITERIA_TIERS` const. Consumed by all three components; both local `TIERS` consts deleted; grep confirms zero remaining local copies among the feature files.

**Copy byte-verification (copy rules binding):** extracted the pre-fix sidebar JSX from `9ed954142^` and normalized JSX whitespace; rendered text is identical for all three tiers — leads ("Must-haves that count most toward a candidate's score." / "Nice-to-haves that count toward the score, less than core criteria." / "A small boost when a candidate has them.") and rests match character-for-character, including the `</b>`-space-rest boundary (`<b>{tier.glossaryLead}</b> {tier.glossaryRest}` preserves the same single space the original same-line JSX produced). Labels/icons/keys (`Core`/`check-circle`/`tier_1` etc.) identical to both deleted TIERS consts. Sidebar data-driven map (`JobSetupAiSettings.tsx:75-85`) reproduces the exact former DOM: `h4 > Icon + label`, `p > b(lead) + rest`, `key={tier.key}` — no boolean variant props forwarded (rule 12 clean).

Note: `ScoringDetail.tsx:28` has a pre-existing local `TIERS` (`{key, label}` shape, no icon/glossary) — outside this branch's diff and outside the report's scope; consolidating it would have been beyond-report fix-agent scope. Correctly untouched.

## Fixes 5-7 — theme tokens

Verified each against `app/javascript/ats/styles/theme.ts`; every utility is a SINGLE complete declaration, so no conflicting-declaration hazard (pipeline rule 1), and every swap is value-identical:
- `t.rounded.sm` = `border-radius: 0.3125rem` (5px) — CloseButton, was `5px`.
- `t.rounded.md` = `border-radius: 0.4375rem` (7px) — ListBox + CriteriaCard, was `7px`.
- `t.text.sm` = `font-size: 0.875rem` (14px) — Description, SectionIntro, TierContent h4, was `14px`/`0.875rem`.
- `t.text.xs` = `font-size: 0.75rem` (12px) — TierHead `.label`/`.count`, was `12px`.
- `t.text.base` = `font-size: 1rem` — Sidebar h3, was `1rem`. Ordering checked: `${t.text.base}` after `t.text.bold` cannot conflict (base carries no font-weight).
- `t.text.medium` = `font-weight: 450` — CountRail `.n`, was `450`. Value-identical, zero visual change.

All standalone usages (`${t.text.sm};`), none inside a `font-size:`/`border-radius:` property. Remaining raw values (15px, 12.5px, 13px, 13.5px, 22px) have no typeScale token and were NOT in the report — correctly untouched (minimal scope).

## Verification

`tsc --noEmit`: zero errors in any jobSetup/jobCriteria file (only pre-existing node_modules @types/react noise). `eslint` on all four files: exit 0.

## Findings

No issues found.
