# Volatile JD Analysis — Why Some JDs Produce Different Results Each Run

## Fire Alarm Test/Inspect (most volatile — T1% σ=52.4 across 3 runs, range 0-97%)

Root cause: **heading default vs inline override tension**.

This JD has all content under "Required"-type headings. The model oscillates between two interpretations:

1. **Heading-dominant** (v7, v11): "Required" heading → everything tier_1. Result: 90%+ T1.
2. **Inline-dominant** (v8, v10): Each criterion evaluated independently. Duties without signal words → tier_2. Result: ~80% T1.
3. **Call 1 failure** (v9): Call 1 classified the JD as having NO criteria sections → Call 2 skipped entirely. Result: 0% T1.

The model is correct in both interpretations — the prompt says headings set defaults that inline modifiers can override. The ambiguity is: does "no signal word" count as an override? The prompt says "default — no signal word" = tier_2, which conflicts with the heading default of tier_1.

**Not fixable without choosing a side.** Either:
- Headings always win (even without inline confirmation) → more tier_1 on structured JDs
- Inline always wins (absence of signal = tier_2) → more tier_2 even under "Required" headings

The current prompt tries to balance both, which is why it's nondeterministic.

## Software Engineer | Core Protocol (T1% σ=27.0)

Similar pattern — the model varies on how aggressively to use "Minimum Qualifications" heading to promote items to tier_1. Some runs treat it as deterministic (13 items → T1), others evaluate each item independently (3-8 items → T1).

## CART Captioner (binary σ=2.6)

Binary count swings 1-6 across runs. This JD has certifications, licenses, and schedule requirements — all clearly binary. The model catches different subsets each run. The items ARE binary; the model just doesn't consistently flag all of them.

## Director of Development (binary σ=2.6)

Binary swings 2-7. The JD mentions "Bachelor's degree" and travel requirements in passing. Some runs catch them, some don't.

## Graphic Designer (binary σ=3.1)

Binary swings 0-6. The JD is 73+ criteria — extremely dense. The model's binary attention seems to degrade on very long criteria lists.

## Pattern Summary

| Volatility type | Root cause | Fixable? |
|---|---|---|
| Heading vs inline tier | Prompt tension between heading default and inline override | Only by choosing one over the other |
| Binary under-flagging on long JDs | Model attention degradation on 30+ criteria | Possibly by processing in smaller chunks |
| Binary under-flagging on passing mentions | Degree/cert mentioned casually, not in a "Requirements" section | Hard — requires deeper semantic understanding |
| Call 1 section classification | Model occasionally misclassifies entire JD as non-criteria | Rare (1/5 runs), not addressable via prompt |
