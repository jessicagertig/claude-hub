// JobSetupAiSettings.tsx — EXTENDED with the Job criteria section.
// Everything you need is in this file and JobCriteriaModals.tsx; the README
// is only an index.
//
// EXTRACTION LIFECYCLE (backend already behaves this way; UI must reflect it):
//   · Criteria are extracted automatically when the job is PUBLISHED.
//   · While published, they re-extract automatically whenever the job
//     description is updated (updates must involve letters).
//   · The Generate / Regenerate buttons are the DRAFT-time manual trigger.
//   · Scoring is point-in-time: each review uses the criteria as they stand
//     when it runs. Regeneration never rewrites existing reviews.
//   · Extracted criteria are read-only in the UI. The only way to change
//     them is editing the job description (auditability requirement).
//   · No reviews may run while the job has zero criteria.
//
// GUARDS (fire after any extraction completes, on the returned total):
//   · total === 0  → "No criteria found" hard-stop modal.
//   · total <= 5   → "Only {n} criteria found" warning modal (can continue).
//
// BINDING COPY RULES for every user-visible string:
//   · No em dashes. Sentence case. No emoji.
//   · Say "extract", never "read". Say "count most/less toward the score",
//     never "weight/heaviest".
//   · Button labels are static; counts may appear in titles/body, never in
//     button labels. Timestamps live in the card description, never beside
//     buttons.
//
import React, { useState } from "react";
import styled from "@emotion/styled";

import {
  jobAutoGenerateAiSummariesOptions,
  AutoGenerateAiSummaries,
} from "@ats/src/lib/newLookups";

import SettingsContainer from "@ats/src/components/shared/SettingsContainer";
import FormSection from "@ats/src/components/forms/FormSection";
import FormSelect from "@ats/src/components/forms/FormSelect";
import Button from "@ats/src/components/shared/Button";
import Icon from "@ats/src/components/shared/Icon";
import Modal from "@ats/src/components/modals/Modal";
import EmptyState from "@ats/src/components/shared/EmptyState";
import PlatoMark from "@ats/src/components/shared/PlatoMark"; // the sparkle mark
import { useToastContext } from "@shared/context/ToastContext";
import { useUpdateJob } from "@shared/queryHooks/useJob";
// Suggested new hooks (create alongside useJob):
//   useJobCriteria(jobId)        → { data: JobCriteria, isLoading }
//   useRegenerateJobCriteria()   → { mutate, isLoading }

import {
  ViewCriteriaModal,
  RegenerateCriteriaModal,
  JobCriteria,
} from "./JobCriteriaModals";

const TIERS = [
  { key: "tier1" as const, label: "Core", icon: "check-circle" },
  { key: "tier2" as const, label: "Preferred", icon: "plus-circle" },
  { key: "tier3" as const, label: "Bonus", icon: "star" },
];

const criteriaCount = (c: JobCriteria) =>
  c.tier1.length + c.tier2.length + c.tier3.length;

function JobSetupAiSettings(props) {
  const { setIsDirty, job: passedJob } = props;
  const addToast = useToastContext();
  const { mutate: updateJob, isLoading: isLoadingUpdateJob } = useUpdateJob();

  // ── existing auto-generate setting (unchanged) ──
  const [autoGenerateSetting, setAutoGenerateSetting] =
    useState<AutoGenerateAiSummaries>(
      passedJob.autoGenerateAiSummaries || "default",
    );

  // ── new: criteria state ──
  // const { data: criteria } = useJobCriteria(passedJob.id);
  // const { mutate: regenerateCriteria, isLoading: isRegenerating } = useRegenerateJobCriteria();
  const criteria: JobCriteria = passedJob.jobCriteria; // adjust to real source
  const [viewOpen, setViewOpen] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [guard, setGuard] = useState<"low" | "none" | null>(null);

  const total = criteria ? criteriaCount(criteria) : 0;
  // "Never extracted" (no extraction has run; draft job) vs
  // "extraction ran and found nothing" (payload present, total === 0).
  const neverExtracted = !criteria || !criteria.extractedAt;

  const onFormInputChange = (name: string, value: AutoGenerateAiSummaries) => {
    setAutoGenerateSetting(value);
    setIsDirty(true);
  };

  const onSubmit = (e) => {
    e.preventDefault();
    updateJob(
      { id: passedJob.id, autoGenerateAiSummaries: autoGenerateSetting },
      {
        onSuccess: () => {
          setIsDirty(false);
          addToast({ title: "Plato AI settings updated", kind: "success" });
        },
        onError: (error: any) => {
          addToast({
            title:
              error?.data?.errors?.general?.[0] ||
              "Could not update Plato AI settings",
            kind: "warning",
            delay: 10000,
          });
        },
      },
    );
  };

  const onConfirmRegenerate = () => {
    setConfirmOpen(false);
    // regenerateCriteria({ jobId: passedJob.id }, {
    //   onSuccess: (next) => {
    //     const n = criteriaCount(next);
    //     if (n === 0) setGuard("none");
    //     else if (n <= 5) setGuard("low");
    //   },
    //   onError: () => addToast({ title: "Could not regenerate job criteria", kind: "warning" }),
    // });
  };

  const goToDescription = () => {
    setGuard(null);
    // navigate to Job setup → Job description (existing router path)
  };

  const BottomBarContent = (
    <Button
      className="submit-button"
      type="button"
      size="medium"
      onClick={onSubmit}
      loading={isLoadingUpdateJob}
      aria-label="Save changes"
    >
      Save changes
    </Button>
  );

  // ── sidebar: tier glossary (Team roles register) ──
  // SettingsContainer already supports a sidebar; pass this through it.
  const Sidebar = (
    <AsideGlossary>
      <h3>Criteria tiers</h3>
      <p>
        Plato extracts scoring criteria from the job description and sorts them
        into tiers. Section titles decide the tier; words inside an item can
        also signal it, but the title always wins.
      </p>
      <AsideEntry>
        <div className="head">
          <Icon name="check-circle" size={13} />
          Core
        </div>
        <p>
          <b>Must-haves. These count most toward a candidate's score.</b> Plato
          takes them from sections titled Requirements or Must-haves, and from
          items with words like critical, required, or essential.
        </p>
      </AsideEntry>
      <AsideEntry>
        <div className="head">
          <Icon name="plus-circle" size={13} />
          Preferred
        </div>
        <p>
          <b>
            Nice-to-haves. These also count toward the score, less than core
            criteria.
          </b>{" "}
          From sections titled Preferred or Nice to have. Criteria without a
          strong core or bonus signal land here.
        </p>
      </AsideEntry>
      <AsideEntry>
        <div className="head">
          <Icon name="star" size={13} />
          Bonus
        </div>
        <p>
          <b>A small boost when a candidate has them.</b> Usually only from
          sections literally titled Bonus. Not every description produces them.
        </p>
      </AsideEntry>
    </AsideGlossary>
  );

  return (
    <SettingsContainer
      title="Plato AI settings"
      description="Configure Plato for this job. Each successful Plato review consumes one credit from your organization's balance."
      bottomBar={BottomBarContent}
      sidebar={Sidebar}
    >
      {/* existing section, unchanged */}
      <FormSection title="Plato reviews">
        <FormSelect
          onChange={onFormInputChange}
          name="autoGenerateAiSummaries"
          label="Auto-generation"
          description="Automatically generate a Plato review for each new applicant to this job."
          value={autoGenerateSetting}
          options={jobAutoGenerateAiSummariesOptions}
        />
      </FormSection>

      {/* new section */}
      <FormSection title="Job criteria">
        <SectionIntro>
          Each review scores a candidate against these, as they stand when it
          runs. To change them, edit your{" "}
          <a onClick={goToDescription}>job description</a>.
        </SectionIntro>

        {total > 0 ? (
          <CriteriaCard>
            <div className="main">
              <PlatoDisc>
                <PlatoMark size={20} />
              </PlatoDisc>
              <div className="tx">
                <p className="title">Job criteria</p>
                <div className="desc">
                  Plato extracted these from your job description{" "}
                  {/* relativeTime(criteria.extractedAt) */}2 hours ago.
                </div>
              </div>
            </div>
            <CountRail>
              <ul>
                {TIERS.map((tier) => {
                  const n = criteria[tier.key].length;
                  if (tier.key === "tier3" && n === 0) return null; // Bonus row only when present
                  return (
                    <li key={tier.key}>
                      <span className="lw">
                        <Icon name={tier.icon} size={14} />
                        <span>{tier.label}</span>
                      </span>
                      <span className="n">{n}</span>
                    </li>
                  );
                })}
              </ul>
            </CountRail>
          </CriteriaCard>
        ) : neverExtracted ? (
          <EmptyState
            icon="file-text"
            title="No job criteria have been generated"
            message="Plato extracts scoring criteria when you publish the job, or you can generate them now."
          />
        ) : (
          <EmptyState
            icon="alert-triangle"
            title="No criteria found"
            message="No scoring criteria were found in the job description. Plato won't review candidates until it has criteria to score against."
          />
        )}

        <ActionRow>
          {total > 0 && (
            <Button
              type="button"
              styleType="secondary"
              onClick={() => setViewOpen(true)}
            >
              View criteria
            </Button>
          )}
          <Button
            type="button"
            styleType="secondary"
            // loading={isRegenerating}
            onClick={() => setConfirmOpen(true)}
          >
            {neverExtracted ? "Generate criteria" : "Regenerate criteria"}
          </Button>
        </ActionRow>
      </FormSection>

      {viewOpen && (
        <ViewCriteriaModal
          criteria={criteria}
          onClose={() => setViewOpen(false)}
        />
      )}
      {confirmOpen && (
        <RegenerateCriteriaModal
          onConfirm={onConfirmRegenerate}
          onCancel={() => setConfirmOpen(false)}
        />
      )}
      {guard != null && (
        <Modal onCancel={() => setGuard(null)}>
          <GuardTitle>
            {guard === "low" ? `Only ${total} criteria found` : "No criteria found"}
          </GuardTitle>
          <GuardBody>
            {guard === "low"
              ? `Plato found only ${total} scoring criteria for this job. That usually means the job description is missing a requirements or responsibilities section, or is too general to score against reliably.`
              : "Plato couldn't find any scoring criteria for this job. This can happen when the description only covers things like the company or benefits so far."}
          </GuardBody>
          <GuardBody>
            {guard === "low"
              ? "You can keep these criteria and reviews will run against them, but results may be less useful."
              : "Candidates won't be reviewed until this job has criteria to score against."}
          </GuardBody>
          <GuardFoot>
            <Button type="button" onClick={goToDescription}>
              Edit job description
            </Button>
            <Button
              type="button"
              styleType="secondary"
              onClick={() => setGuard(null)}
            >
              {guard === "low" ? "Keep criteria" : "Close"}
            </Button>
          </GuardFoot>
        </Modal>
      )}
    </SettingsContainer>
  );
}

export default JobSetupAiSettings;

/* ═══════════════════════════ styles ═══════════════════════════
   Values per the handoff README. Swap raw values for poly theme
   tokens where the codebase has them. */

const SectionIntro = styled.p`
  margin: 0 0 14px;
  font-size: 14px;
  font-weight: 400;
  line-height: 1.6;
  color: ${({ theme }: any) => theme.color.textSecondary};
  a {
    color: ${({ theme }: any) => theme.color.textLoud};
    font-weight: 500;
    text-decoration: none;
    cursor: pointer;
    &:hover {
      text-decoration: underline;
    }
  }
`;

const CriteriaCard = styled.div`
  display: flex;
  align-items: stretch;
  max-width: 560px;
  background: ${({ theme }: any) => theme.color.canvas};
  border: 1px solid ${({ theme }: any) => theme.color.border};
  border-radius: 7px;

  .main {
    flex: 1;
    min-width: 0;
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 14px 16px;
  }
  .tx {
    min-width: 0;
  }
  .title {
    margin: 0;
    font-size: 15px;
    font-weight: 600;
    color: ${({ theme }: any) => theme.color.textLoud};
  }
  .desc {
    margin-top: 2px;
    font-size: 12.5px;
    line-height: 1.3;
    color: ${({ theme }: any) => theme.color.textSecondary};
    font-variant-numeric: tabular-nums;
  }
`;

const PlatoDisc = styled.span`
  width: 36px;
  height: 36px;
  border-radius: 50%;
  flex-shrink: 0;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(120deg, #fbd7ff 10%, #ffdec1 90%);
  color: ${({ theme }: any) => theme.color.neutral900};
  box-shadow: inset 0 0 0 1px rgba(0, 0, 0, 0.07);
`;

const CountRail = styled.div`
  width: 186px;
  flex-shrink: 0;
  display: flex;
  align-items: center;
  padding: 10px 16px;
  border-left: 1px solid ${({ theme }: any) => theme.color.border};

  ul {
    margin: 0;
    padding: 0;
    width: 100%;
  }
  li {
    list-style: none;
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 13px;
    color: ${({ theme }: any) => theme.color.textSecondary};
  }
  .lw {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .n {
    color: ${({ theme }: any) => theme.color.textLoud};
    font-weight: 450;
    font-variant-numeric: tabular-nums;
  }
`;

const ActionRow = styled.div`
  display: flex;
  align-items: center;
  gap: 14px;
  margin-top: 14px;
`;

const AsideGlossary = styled.div`
  h3 {
    margin: 4px 0 0;
    font-size: 16px;
    font-weight: 600;
    color: ${({ theme }: any) => theme.color.textLoud};
  }
  p {
    margin: 12px 0 0;
    font-size: 12px;
    line-height: 1.5;
    color: ${({ theme }: any) => theme.color.textSecondary};
  }
`;

const AsideEntry = styled.div`
  margin-top: 18px;
  .head {
    display: flex;
    align-items: center;
    gap: 7px;
    font-size: 13px;
    font-weight: 600;
    color: ${({ theme }: any) => theme.color.textLoud};
  }
  p {
    margin: 6px 0 0;
  }
  b {
    color: ${({ theme }: any) => theme.color.textPrimary};
    font-weight: 500;
  }
`;

const GuardTitle = styled.h2`
  margin: 0;
  font-size: 24px;
  font-weight: 600;
  line-height: 1.4;
`;

const GuardBody = styled.p`
  margin: 14px 0 0;
  font-size: 14px;
  font-weight: 400;
  line-height: 1.6;
  color: ${({ theme }: any) => theme.color.textSecondary};
`;

const GuardFoot = styled.div`
  display: flex;
  gap: 10px;
  margin-top: 24px;
`;
