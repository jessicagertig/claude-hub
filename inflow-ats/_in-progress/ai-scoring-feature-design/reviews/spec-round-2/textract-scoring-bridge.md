# textract-scoring-bridge — Round 2

## Findings

- F1 [MED] `TextractResult#generate_ai_summary` standalone method disposition still unspecified. Round 1 textract-scoring-bridge F2 noted that the spec says to replace the `generate_ai_summary` call inside `generate_ai_summary_with_credit_flow` but doesn't address the standalone `generate_ai_summary` method (textract_result.rb line 52-54). This method is still public and callable directly. If left in place, it provides a bypass around the orchestrator (calling `Summary::Generate` directly without scoring). The spec should state whether to remove it, keep it, or make it private. **Fix:** Add to Section 6 a decision on the standalone `TextractResult#generate_ai_summary` method.

No other new findings. Round 1 amendments to the entry points and bulk path are clear.
