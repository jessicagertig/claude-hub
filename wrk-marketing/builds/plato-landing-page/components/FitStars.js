import styled from "@emotion/styled";
import { css, keyframes } from "@emotion/react";
import { useState } from "react";

// Marketing-site version of inflow-ats `FitStars` (from FitIndicator.tsx).
// The 5 stars (Plato's Sparkle) are drawn as ONE masked SVG: a single gradient
// rect masked by the union of filled star shapes. That single-masked-SVG shape
// is what lets the fill be revealed with a left-to-right "sweep" keyframe.
//
// value: 0-5 filled stars.
// sweep: when true, the gradient fill sweeps in left-to-right instead of showing
//        fully at once. Drive it from the parent timeline (flip the prop on cue).
// Conventions matched from the marketing codebase: Styled namespace, `label:`,
// prop-driven styling, plain JS. Dark-mode branch dropped (marketing has no dark theme).

const SPARKLE_PATH =
  "M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .962 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.582a.5.5 0 0 1 0 .962L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.962 0z";

// Fit-score gradient carried over from inflow FitIndicator (FIT_GRAD).
const FIT_GRAD = ["#F1BC8C", "#E3A1DA"];

let fitStarsCounter = 0;

export default function FitStars({
  value,
  label,
  size = 19,
  gap = 2,
  sweep = false,
  sweepDuration = 800,
}) {
  const fill = Math.max(0, Math.min(5, value | 0));
  const totalW = 5 * size + 4 * gap;
  const fillW = Math.max(fill * size + (fill - 1) * gap, 1);
  const [uid] = useState(() => ++fitStarsCounter);
  const gradId = `fit-grad-${uid}`;
  const maskId = `fit-mask-${uid}`;
  const sc = size / 24;

  const filled = [];
  const outlines = [];
  for (let i = 1; i <= 5; i++) {
    const tf = `translate(${(i - 1) * (size + gap)},0) scale(${sc})`;
    if (i <= fill) {
      filled.push(
        <g key={i} transform={tf}>
          <path d={SPARKLE_PATH} fill="#fff" stroke="#fff" strokeWidth={1.7} strokeLinejoin="round" />
        </g>
      );
    } else {
      outlines.push(
        <g key={i} transform={tf}>
          <path d={SPARKLE_PATH} fill="none" stroke="#D5D5D5" strokeWidth={1.7} strokeLinejoin="round" />
        </g>
      );
    }
  }

  return (
    <Styled.Inline title={label}>
      <svg width={totalW} height={size} viewBox={`0 0 ${totalW} ${size}`}>
        <defs>
          <linearGradient id={gradId} gradientUnits="userSpaceOnUse" x1={0} y1={0} x2={fillW} y2={0}>
            <stop offset="0%" stopColor={FIT_GRAD[0]} />
            <stop offset="100%" stopColor={FIT_GRAD[1]} />
          </linearGradient>
          <mask id={maskId}>{filled}</mask>
        </defs>
        <Styled.Fill sweep={sweep} sweepDuration={sweepDuration} mask={`url(#${maskId})`}>
          <rect x={0} y={0} width={fillW} height={size} fill={`url(#${gradId})`} />
        </Styled.Fill>
        {outlines}
      </svg>
    </Styled.Inline>
  );
}

const Styled = {};

// Left-to-right reveal of the masked gradient fill.
const sweepIn = keyframes`
  from { clip-path: inset(0 100% 0 0); }
  to   { clip-path: inset(0 0 0 0); }
`;

Styled.Inline = styled.span`
  label: FitStars;
  display: inline-flex;
  align-items: center;
  flex-shrink: 0;

  svg {
    display: block;
  }
`;

Styled.Fill = styled.g((props) => {
  return css`
    label: FitStars_Fill;

    ${props.sweep &&
    css`
      animation: ${sweepIn} ${props.sweepDuration}ms ease forwards;

      @media (prefers-reduced-motion: reduce) {
        animation: none;
      }
    `}
  `;
});
