# Full 180-JD Analysis — Call 1 (v5) + Call 2 (v6)

## Summary

- **180 JDs tested** across 35 batches + original 6
- **160 produced criteria**, 20 were minimal/general postings (correctly skipped)
- **2,959 total criteria extracted** across 160 JDs
- **$0.15 total API cost** (both calls combined)

## Aggregate Tier Distribution

| Tier | Count | % |
|---|---|---|
| tier_1 | 612 | 21% |
| tier_2 | 2,288 | 77% |
| tier_3 | 59 | 2% |

**Per-JD averages:** 18.5 criteria/JD, 19.5% tier_1, 1.2 binary/JD

## Issue Breakdown

### HIGH_T1 — 3 JDs (tier_1 over-assignment)

These JDs have >70% of criteria assigned tier_1:

1. **Fire Alarm Installation Technician** — 31/32 tier_1. JD has explicit "Required" heading for most sections. The model correctly reads the heading signal, but the JD author put EVERYTHING under "Required" including generic duties.
2. **Fire Alarm Test/Inspect/Service Technician** — 30/32 tier_1. Same pattern, same organization.
3. **VP Service & Operations** — 28/39 tier_1. Dense executive JD with many strong-expectation signal words throughout.

**Root cause:** For #1 and #2, the heading says "Required" so the model defaults everything to tier_1 — which is correct per our rules (heading sets default, inline can override). The issue is that the JD author used "Required" loosely. For #3, the JD is saturated with strong-expectation language.

**Verdict:** #1 and #2 are the model respecting the JD's own tier structure (Decision 9). This is correct behavior — we just don't like the result. Not a prompt issue. #3 is borderline — legitimate strong-expectation words appearing everywhere.

### NO_BINARY — 44 JDs flagged, 16 are real misses

- **28 legitimate** — JDs genuinely have no degree/cert/portfolio/vehicle requirements
- **16 real misses** — JDs contain binary-eligible content that wasn't flagged:
  - 8 missed degrees ("Bachelor's degree preferred", etc.)
  - 7 missed vehicle/transport requirements
  - 2 missed certifications
  - 1 missed portfolio

**Root cause:** The prompt defines binary with examples (degree, license, certification, legal authorization) but doesn't mention vehicle ownership or portfolio requirements explicitly. The model sometimes catches these, sometimes doesn't.

### ALL_DECOMPOSED — 23 JDs (text != source_text on every criterion)

The model rewrites criterion text instead of preserving it verbatim from source. Example: source_text says "You have 5+ years of professional software development experience" but text says "5+ years of professional software development experience" (stripped "You have").

**Root cause:** The prompt says "text: the extracted atomic requirement" which the model interprets as permission to clean/rephrase. The non-compound criteria should have text == source_text.

**Verdict:** Cosmetic but worth fixing — downstream scoring should be able to compare text against source_text to detect decomposition.

### NO_CRITERIA — 20 JDs (correctly skipped)

All are minimal/general postings: "Submit your resume", "Open application", "Talent pool", "General interest." Correct behavior.

## What's Working Well

1. **Call 1 section decomposition** — zero null/null violations across 180 JDs
2. **Tier distribution** — 21/77/2 split is healthy and realistic
3. **Non-English handling** — German, Chinese, Norwegian, Spanish, Portuguese JDs all processed correctly
4. **Heading-based tier structure** — Glide need-to-have/nice-to-have correctly mapped
5. **Signal word recognition** — "excellent", "strong", "proficiency", "minimum" reliably caught
6. **Sparse JDs** — correctly extract limited criteria without hallucinating more
7. **Dense JDs** — Graphic Designer with 73 criteria all extracted
8. **General/talent-pool postings** — correctly identified as no-criteria

## Regression Test Set

20 JDs selected — 5 standard, 15 problematic. Located at `benchmark/regression-set/`

### Standard (5)
- video-production — dense, many sections, binary working
- cart-captioner — 6 binary, good tier split
- mechanical-engineer — 6 binary, balanced tiers
- pharmd-saas-business-strategist — 5 binary, domain-specific
- accounting-specialist — degree/cert binary, good split

### Problematic (15)
- fire-alarm-installation-technician — HIGH_T1: 31/32 tier_1
- fire-alarm-test-inspect-and-service-tec — HIGH_T1: 30/32 tier_1
- vice-president-service--operations — HIGH_T1 + ALL_DECOMPOSED
- director-of-development — NO_BINARY: degree missed
- ai-gameplay-programmer — NO_BINARY: degree missed
- project-architect — NO_BINARY: degree + cert missed
- housekeeper---buena-vista — NO_BINARY: vehicle missed
- software-engineer--core-protocol — ALL_DECOMPOSED: 39/39
- host — ALL_DECOMPOSED: 32/32
- sales-manager-de — German language
- devops-engineer-chinese — Chinese language
- elixir — sparse
- housekeeper — prose-heavy
- graphic-designer--e-commerce-social-med — 73 criteria, 0 binary
- glide — two-tier headings

## Prompt Changes Worth Trying

### For binary under-flagging (16 real misses)

Add explicit examples to the binary definition:
- "vehicle ownership or driver's license" → binary: true
- "portfolio, demo reel, or work samples" → binary: true

### For ALL_DECOMPOSED (text rewriting)

Add: "When a criterion is NOT decomposed from a compound, the text field must be identical to source_text. Do not rephrase, clean, or strip prefixes."

### NOT worth changing

- HIGH_T1 on fire alarm JDs — the model is correctly respecting the JD's "Required" heading. The problem is the JD author, not the model.
- tier_3 at 2% — may be genuinely rare. Most JDs don't use "bonus" language much.
