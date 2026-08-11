// PlatoMark + PlatoChip — the Plato AI star mark and its gradient chip.
// Self-contained. Requires React on window (no other deps).
//
// <PlatoMark size={16} />                      → the star glyph (inherits color)
// <PlatoChip size={28} radius={7} />           → star in the accent-gradient chip
// variant: "sparkle" (default · single 4-pt star) | "sparkles" | "wand"
//
// Needs the DS color tokens loaded (uses var(--accent-gradient), var(--neutral-900)).

function PlatoMark({ variant = "sparkle", size = 16, color = "currentColor" }) {
  const base = { width: size, height: size, viewBox: "0 0 24 24", style: { display: "block" } };
  const stroke = { fill: "none", stroke: "currentColor", strokeWidth: 2, strokeLinecap: "round", strokeLinejoin: "round" };
  let inner;
  if (variant === "wand") {
    inner = (
      <g {...stroke}>
        <path d="m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.2 1.2 0 0 0 1.72 0L21.64 5.36a1.2 1.2 0 0 0 0-1.72" />
        <path d="m14 7 3 3" /><path d="M5 6v4" /><path d="M19 14v4" /><path d="M10 2v2" /><path d="M7 8H3" /><path d="M21 16h-4" /><path d="M11 3H9" />
      </g>
    );
  } else if (variant === "sparkles") {
    inner = (
      <g>
        <path d="M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0-1.594 1.594l-1.051 5.558a1 1 0 0 1-1.966 0l-1.051-5.558a2 2 0 0 0-1.594-1.594l-5.558-1.051a1 1 0 0 1 0-1.966l5.558-1.051a2 2 0 0 0 1.594-1.594z" fill="currentColor" />
        <circle cx="4" cy="20" r="2" fill="currentColor" />
        <path d="M20 2v4" {...stroke} /><path d="M22 4h-4" {...stroke} />
      </g>
    );
  } else {
    // "sparkle" — single 4-point star (Lucide), stroked. The default Plato mark.
    inner = (
      <g {...stroke}>
        <path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .962 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.582a.5.5 0 0 1 0 .962L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.962 0z" />
      </g>
    );
  }
  return <span style={{ display: "inline-flex", alignItems: "center", color }}><svg {...base}>{inner}</svg></span>;
}

// The premium Plato marker: star centered in the pink→peach accent-gradient chip.
function PlatoChip({ size = 28, radius = 7, variant = "sparkle" }) {
  return (
    <span style={{
      width: size, height: size, borderRadius: radius, flexShrink: 0,
      background: "var(--accent-gradient)", display: "inline-flex",
      alignItems: "center", justifyContent: "center", color: "var(--neutral-900)",
      boxShadow: "inset 0 0 0 1px rgba(0,0,0,0.07)",
    }}>
      <PlatoMark variant={variant} size={Math.round(size * 0.62)} />
    </span>
  );
}

// If using as separate <script type="text/babel"> files, expose globally:
window.PlatoMark = PlatoMark;
window.PlatoChip = PlatoChip;
