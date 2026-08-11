# PlatoHero — component structure & animation ownership

Build the hero as the components below, with animation ownership exactly as specified. Content, copy, and timeline are already finalized — this only covers how to structure the components and where each spring lives.

## Components

```
PlatoHero (parent)
├─ big title + the two hook-text lines   → inline, not separate components
├─ <animated.div> { Roster } </animated.div>
└─ <animated.div> { Card }   </animated.div>
```

- **PlatoHero** — parent. Owns the timeline. Renders the big title and both hook-text lines inline. Wraps Roster and Card each in an `animated` element.
- **Roster** — its own component: the scrolling list of names plus its own styles.
- **Card** — its own component: all its sub-parts (date, tag, stars (Plato's Sparkle), headline, meta, fit) inline within it.

## Spring ownership

**Entrance / placement of a unit → PlatoHero owns it.** PlatoHero wraps Roster and Card in `animated` elements and drives their entrance/position springs:
- Roster: centered/large → moved left, settled.
- Card: slide/fade in.

Roster and Card are presentational inside those wrappers — they do not own their own entrance.

**Internal animation → the unit owns it.**
- **Roster** owns the clone spring — a name enlarges within the roster, then shrinks back.
- **Card** owns its content cascade — the field-by-field reveal.

PlatoHero sequences the whole timeline. When a child owns an internal spring, PlatoHero triggers *when* it fires (via a prop or a shared spring ref), but the spring itself lives in the child.

Many-node reveals (the stars / Plato's Sparkle populating across rows) use CSS `@keyframes` + `animation-delay`, not a spring per node.

## Hard rules

1. **No class names.** Style everything through styled-components. Never add a `className` for styling or for targeting animation — use props or refs. (This is the failure mode to avoid: stray class names slipping into the output.)
2. **Conditional styling goes through props**, read inside the styled-component — not class toggling. E.g. `background-color: ${props.isActive ? "#F5F5F5" : "transparent"};`.
3. **Prop names are camelCase** — `isActive`, `showDivider`, `cloneActive`. Never snake_case or kebab-case.
