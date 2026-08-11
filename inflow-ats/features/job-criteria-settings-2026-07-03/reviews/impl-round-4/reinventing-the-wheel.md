# Reinventing the Wheel — Round 4

The one new artifact, `jobCriteriaTiers.ts`, was checked against the codebase for a pre-existing equivalent: the only other tier-metadata constant is `ScoringDetail.tsx:28`'s local `TIERS` (`{key: CriterionTier; label: string}` — no icon, no glossary copy; pre-existing on develop, outside this diff). Nothing existing provided the icon+label+glossary shape the three jobSetup components need, and the report explicitly ordered the new shared module. Not a reinvention.

Theme tokens (fixes 5-7) and the rule-6 focus block are the OPPOSITE of reinvention — they replace hand-rolled values with the existing system utilities.

No new helpers, hooks, or formatting utilities added elsewhere in the commit.

## Findings

No issues found.
