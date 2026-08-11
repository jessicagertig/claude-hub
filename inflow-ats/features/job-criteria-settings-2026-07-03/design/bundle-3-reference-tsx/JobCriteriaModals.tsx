// REFERENCE IMPLEMENTATION — written against the ATS codebase's imports and
// patterns, but produced outside it. Treat as a strong starting point, not a
// drop-in: verify prop names against the real FullModal / Modal / Button and
// the actual criteria payload shape before shipping.
//
// Two components:
//   <ViewCriteriaModal>       FullModal right slide-over, read-only tier list.
//   <RegenerateCriteriaModal> Center confirmation in the Run Plato anatomy.
//
// Criteria payload shape assumed (adjust to the real API):
//   { tier1: string[], tier2: string[], tier3: string[], extractedAt: string }

import React from "react";
import styled from "@emotion/styled";

import FullModal from "@ats/src/components/modals/FullModal";
import Modal from "@ats/src/components/modals/Modal"; // CenterModal
import Button from "@ats/src/components/shared/Button";
import Icon from "@ats/src/components/shared/Icon"; // Feather wrapper

export type JobCriteria = {
  tier1: string[];
  tier2: string[];
  tier3: string[];
  extractedAt: string; // ISO; render relative ("2 hours ago")
};

const TIERS = [
  {
    key: "tier1" as const,
    label: "Core",
    icon: "check-circle",
    hint: "Must-haves. These count most toward a candidate's score.",
  },
  {
    key: "tier2" as const,
    label: "Preferred",
    icon: "plus-circle",
    hint: "Nice-to-haves. These also count toward the score, less than core criteria.",
  },
  {
    key: "tier3" as const,
    label: "Bonus",
    icon: "star",
    hint: "A small boost when a candidate has them.",
  },
];

/* ═══════════════ View criteria — FullModal slide-over ═══════════════ */

export function ViewCriteriaModal({
  criteria,
  onClose,
}: {
  criteria: JobCriteria;
  onClose: () => void;
}) {
  return (
    // If FullModal's header can't render a custom right accessory, render the
    // header inside children instead (headerTitleText omitted) as below.
    <FullModal onCancel={onClose}>
      <SlideHead>
        <h2>Job criteria</h2>
        <CloseX type="button" aria-label="Close" onClick={onClose}>
          <Icon name="x" size={16} />
        </CloseX>
      </SlideHead>
      <SlideBody>
        <Description>
          New reviews score candidates against these. To change them, edit the
          job description. Reviews that have already run keep the criteria they
          were scored against.
        </Description>
        <ListBox>
          {TIERS.map((tier) => {
            const rows = criteria[tier.key] || [];
            if (rows.length === 0) return null; // empty tiers are omitted
            return (
              <React.Fragment key={tier.key}>
                <TierHead>
                  <Icon name={tier.icon} size={13} />
                  <span className="label">{tier.label}</span>
                  <span className="count">{rows.length}</span>
                </TierHead>
                <TierHint>{tier.hint}</TierHint>
                {rows.map((text, i) => (
                  <Row key={i}>{text}</Row>
                ))}
              </React.Fragment>
            );
          })}
        </ListBox>
      </SlideBody>
    </FullModal>
  );
}

/* ═══════════ Regenerate — confirmation, Run Plato anatomy ═══════════ */

export function RegenerateCriteriaModal({
  onConfirm,
  onCancel,
  isLoading,
}: {
  onConfirm: () => void;
  onCancel: () => void;
  isLoading?: boolean;
}) {
  return (
    <Modal onCancel={onCancel}>
      <ModalTitle>Regenerate job criteria?</ModalTitle>
      <Description>
        Plato will re-extract scoring criteria from the current job
        description. Reviews that have already run keep the criteria they were
        scored against.
      </Description>
      <Statement>
        <span className="ic">
          <Icon name="refresh-cw" size={15} />
        </span>
        <span>
          Regenerating works best when you have changed the parts of the
          description that affect scoring, like requirements or
          responsibilities. Keeping regenerations rare keeps scores comparable
          across candidates. If the criteria change significantly, you can also
          regenerate all candidate reviews.
        </span>
      </Statement>
      <Foot>
        <Button type="button" onClick={onConfirm} loading={isLoading}>
          Regenerate criteria
        </Button>
        <Button type="button" styleType="secondary" onClick={onCancel}>
          Cancel
        </Button>
      </Foot>
    </Modal>
  );
}

/* ═══════════════════════════ styles ═══════════════════════════
   Values per the handoff README. Swap raw values for poly theme
   tokens where the codebase has them. */

const SlideHead = styled.div`
  position: sticky;
  top: 0;
  z-index: 1;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 20px 12px;
  background: ${({ theme }: any) => theme.color.canvas};
  border-bottom: 1px solid ${({ theme }: any) => theme.color.border};
  h2 {
    margin: 0;
    font-size: 22px;
    font-weight: 600;
    letter-spacing: -0.02em;
  }
`;

const CloseX = styled.button`
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border: none;
  background: transparent;
  border-radius: 5px;
  cursor: pointer;
  color: ${({ theme }: any) => theme.color.textSecondary};
  transition: background 0.2s ease, color 0.2s ease;
  &:hover {
    background: ${({ theme }: any) => theme.color.hoverSubtle};
    color: ${({ theme }: any) => theme.color.textLoud};
  }
`;

const SlideBody = styled.div`
  padding: 2px 20px 24px;
`;

/* THE description spec: 14px / 400 / 1.6 / secondary — all four matter. */
const Description = styled.p`
  margin: 14px 0 0;
  font-size: 14px;
  font-weight: 400;
  line-height: 1.6;
  color: ${({ theme }: any) => theme.color.textSecondary};
`;

const ListBox = styled.div`
  margin-top: 16px;
  border: 1px solid ${({ theme }: any) => theme.color.border};
  border-radius: 7px;
`;

const TierHead = styled.div`
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 12px 14px 2px;
  color: ${({ theme }: any) => theme.color.textSecondary};
  &:not(:first-of-type) {
    border-top: 1px solid ${({ theme }: any) => theme.color.border};
    margin-top: 6px;
  }
  .label {
    font-size: 12px;
    font-weight: 600;
    color: ${({ theme }: any) => theme.color.textLoud};
  }
  .count {
    font-size: 12px;
    font-variant-numeric: tabular-nums;
  }
`;

const TierHint = styled.p`
  margin: 0;
  padding: 0 14px 6px;
  font-size: 12px;
  line-height: 1.5;
  color: ${({ theme }: any) => theme.color.textSecondary};
`;

const Row = styled.div`
  padding: 7px 14px;
  font-size: 13.5px;
  line-height: 1.45;
  border-top: 1px solid ${({ theme }: any) => theme.color.neutral100};
`;

const ModalTitle = styled.h2`
  margin: 0;
  font-size: 24px;
  font-weight: 600;
  line-height: 1.4;
`;

const Statement = styled.div`
  display: flex;
  gap: 10px;
  margin: 20px 0 0;
  padding: 13px 15px;
  border: 1px solid ${({ theme }: any) => theme.color.border};
  border-radius: 7px;
  font-size: 13px;
  line-height: 1.5;
  color: ${({ theme }: any) => theme.color.textSecondary};
  .ic {
    display: inline-flex;
    flex-shrink: 0;
    margin-top: 1px;
    color: ${({ theme }: any) => theme.color.textPlaceholder};
  }
`;

const Foot = styled.div`
  display: flex;
  gap: 10px;
  margin-top: 24px;
`;
