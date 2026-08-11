# Sidebar Integration — Round 1

## Findings

- F1 [MED] Spec says "Render `RunPlatoCtaCardV1` inside `Styled.Sidebar`, after the stage navigation list". The sidebar currently contains two `Styled.List` blocks (lines 122-139). The CTA card should go after the second `Styled.List` (the one with setup/distribution/metrics links), before the closing `</Styled.Sidebar>` tag. The `margin-top: auto` on the card's styled component will push it to the bottom. The spec should specify "after the second `Styled.List` block" for precision.

- F2 [LOW] Verified: `Styled.Sidebar` (lines 204-219) has `overflow-y: auto` and no `display: flex` or `flex-direction: column`. The `margin-top: auto` trick only works in flex containers. The CTA card's `margin: auto 0.75rem 1rem` (from the handoff) uses `auto` for the top margin, which only pushes to the bottom if the parent is a flex column. The sidebar is a plain `div` with overflow, so `margin-top: auto` won't pin the card to the bottom — it just collapses to 0.

  This is a CSS implementation concern, not a spec error. The spec says "pinned to sidebar bottom via `margin-top: auto`" which describes the intent. The implementation will need to add `display: flex; flex-direction: column` to `Styled.Sidebar` or use a different pinning technique. The spec should note this dependency.

## Amendments Applied

- Spec "Modified container" section: changed "after the stage navigation list" to "after the second `Styled.List` block (setup/distribution/metrics links), before the closing `Styled.Sidebar` tag"
- Spec "Modified container" section: added note that `Styled.Sidebar` needs `display: flex; flex-direction: column` for the `margin-top: auto` pinning to work — the sidebar is currently a plain `div`
