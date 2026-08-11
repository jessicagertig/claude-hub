import styled from "@emotion/styled";
import { css, keyframes } from "@emotion/react";

// Marketing-site version of inflow-ats `PlatoMark`.
// Sparkle is the ONLY variant (the other inflow variants are dropped by design).
// Conventions matched from the marketing codebase: Styled namespace, `label:`,
// theme via props.theme, prop-driven styling (no inline style), plain JS.

const SPARKLE_PATH =
  "M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .962 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.582a.5.5 0 0 1 0 .962L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.962 0z";

export default function PlatoMark({ size = 16, color = "currentColor", spinning = false }) {
  return (
    <Styled.Mark color={color} spinning={spinning}>
      <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true">
        <g fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
          <path d={SPARKLE_PATH} />
        </g>
      </svg>
    </Styled.Mark>
  );
}

export function PlatoChip({ size = 26, radius, spinning = false }) {
  return (
    <Styled.Chip size={size} radius={radius}>
      <PlatoMark size={Math.round(size * 0.62)} spinning={spinning} />
    </Styled.Chip>
  );
}

const Styled = {};

const spin = keyframes`
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
`;

Styled.Mark = styled.span((props) => {
  return css`
    label: PlatoMark;
    display: inline-flex;
    align-items: center;
    color: ${props.color};

    svg {
      display: block;
    }

    ${props.spinning &&
    css`
      animation: ${spin} 1.2s linear infinite;

      @media (prefers-reduced-motion: reduce) {
        animation: none;
      }
    `}
  `;
});

Styled.Chip = styled.span((props) => {
  const t = props.theme;
  return css`
    label: PlatoChip;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    width: ${props.size}px;
    height: ${props.size}px;
    color: ${t.color.black};
    background: linear-gradient(120deg, #fbd7ff 10%, #ffdec1 90%);
    ${props.radius ? `border-radius: ${props.radius}px;` : t.rounded.md}
    box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.07);
  `;
});
