// Job setup, Plato AI settings tab — the DECIDED design (see
// "Job criteria - decisions.html" + notes/job-criteria-design-notes.md):
//   · Automatic reviews setting (org default / always / never), first.
//   · Job criteria section: JobListItem-register card (Plato gradient disc,
//     title + "Plato extracted these..." description, count rail behind a
//     hairline with B2 icons: check-circle / plus-circle / star; Bonus row
//     only when bonus criteria exist). View criteria + Regenerate ride
//     together below the card. Section intro carries the edit-description link.
//   · View criteria: FullModal right slide-over, title + X in the sticky
//     header, tier hints under each tier head, description text 14/400/1.6.
//   · Regenerate: confirmation modal in the Run Plato anatomy (title-only
//     head, lead by trigger, shared advice in the bordered statement box).
//   · Sidebar: tier glossary in the Team roles register.
// Guards: ≤5 criteria → warning modal; 0 → hard-stop modal. Internal
// criteria are deliberately NOT here yet — not settled.
//
// PROTOTYPE: confirming a regeneration cycles the outcome so all states are
// reachable: low (4) → none (0) → full (16) → …
const { Button: PAIButton } = window.PolymerATSDesignSystem_3004dc;

const PAI_FULL = {
  tier_1: [
    "Develop and implement customer service policies and procedures.",
    "Monitor customer service representatives’ performance and provide ongoing coaching and feedback.",
    "Resolve customer complaints and inquiries in a timely and efficient manner.",
    "Analyze customer service trends and recommend improvements.",
    "Train and onboard new customer service representatives.",
    "Monitor customer service representatives’ adherence to company policies and procedures.",
    "Ensure customer service representatives maintain a high level of customer service.",
    "Prepare and analyze customer service reports.",
    "Minimum of 5+ years of experience in customer service.",
    "Proficient in Microsoft Office Suite (Word, Excel, PowerPoint).",
  ],
  tier_2: [
    "Foster an environment of collaboration and teamwork among customer service representatives.",
    "Excellent leadership and organizational skills.",
    "Strong communication, problem-solving, and decision-making skills.",
    "Able to handle multiple tasks and prioritize effectively.",
    "Able to motivate and mentor customer service representatives.",
    "Knowledge of customer service software and systems.",
  ],
  tier_3: [],
};

const PAI_LOW = {
  tier_1: [
    "Minimum of 5+ years of experience in customer service.",
    "Resolve customer complaints and inquiries in a timely and efficient manner.",
    "Proficient in Microsoft Office Suite (Word, Excel, PowerPoint).",
  ],
  tier_2: ["Excellent leadership and organizational skills."],
  tier_3: [],
};

const PAI_NONE = { tier_1: [], tier_2: [], tier_3: [] };

const PAI_TIERS = [
  { key: "tier_1", label: "Core", icon: "check-circle", hint: "Must-haves. These count most toward a candidate's score." },
  { key: "tier_2", label: "Preferred", icon: "plus-circle", hint: "Nice-to-haves. These also count toward the score, less than core criteria." },
  { key: "tier_3", label: "Bonus", icon: "star", hint: "A small boost when a candidate has them." },
];

const PAI_REVIEW_OPTIONS = [
  { value: "org", label: "Use organization setting (auto-review is on)" },
  { value: "always", label: "Always auto-review candidates for this job" },
  { value: "never", label: "Never auto-review candidates for this job" },
];

const paiCount = (c) => (c.tier_1 || []).length + (c.tier_2 || []).length + (c.tier_3 || []).length;

/* ── the decided card: Plato disc + title/description, count rail right ── */
function PAICriteriaCard({ criteria, extractedAt }) {
  const { Ic, PlatoMark } = window;
  return (
    <div className="pai-card">
      <div className="pai-card-main">
        <span className="pai-disc">{PlatoMark ? <PlatoMark size={20} /> : <Ic name="zap" size={18} />}</span>
        <span className="pai-card-tx">
          <p className="pai-card-title">Job criteria</p>
          <div className="pai-card-desc poly-tnum">Plato extracted these from your job description {extractedAt}.</div>
        </span>
      </div>
      <div className="pai-counts">
        <ul>
          {PAI_TIERS.map((tier) => {
            const n = (criteria[tier.key] || []).length;
            if (tier.key === "tier_3" && n === 0) return null;
            return (
              <li key={tier.key}>
                <span className="lw"><Ic name={tier.icon} size={14} /><span>{tier.label}</span></span>
                <span className="n poly-tnum">{n}</span>
              </li>
            );
          })}
        </ul>
      </div>
    </div>
  );
}

/* ── View criteria: FullModal right slide-over, title + X ── */
function PAIViewModal({ open, criteria, onClose }) {
  const { Ic } = window;
  React.useEffect(() => {
    if (!open) return;
    const esc = (e) => { if (e.key === "Escape") onClose(); };
    window.addEventListener("keydown", esc);
    return () => window.removeEventListener("keydown", esc);
  }, [open, onClose]);
  if (!open) return null;
  return (
    <div className="pai-scrim" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="pai-slide" role="dialog" aria-label="Job criteria">
        <div className="pai-slide-head">
          <h2>Job criteria</h2>
          <button type="button" className="pai-x" title="Close" onClick={onClose}><Ic name="x" size={16} /></button>
        </div>
        <div className="pai-slide-body">
          <p className="pai-desc">New reviews score candidates against these. To change them, edit the job description. Reviews that have already run keep the criteria they were scored against.</p>
          <div className="pai-cbox">
            {PAI_TIERS.map((tier) => {
              const rows = criteria[tier.key] || [];
              if (rows.length === 0) return null;
              return (
                <React.Fragment key={tier.key}>
                  <div className="pai-cbox-tier">
                    <span className="ti"><Ic name={tier.icon} size={13} /></span>
                    <span className="l">{tier.label}</span>
                    <span className="c poly-tnum">{rows.length}</span>
                  </div>
                  <p className="pai-cbox-hint">{tier.hint}</p>
                  {rows.map((t, i) => <div className="pai-cbox-row" key={i}>{t}</div>)}
                </React.Fragment>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ── Regenerate confirmation: Run Plato anatomy ── */
const PAI_REGEN_ADVICE = "Regenerating works best when you have changed the parts of the description that affect scoring, like requirements or responsibilities. Keeping regenerations rare keeps scores comparable across candidates. If the criteria change significantly, you can also regenerate all candidate reviews.";
function PAIRegenConfirm({ open, onConfirm, onClose }) {
  const { Ic } = window;
  if (!open) return null;
  return (
    <div className="pai-scrim center" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="pai-modal" role="dialog" aria-label="Regenerate job criteria?">
        <h2>Regenerate job criteria?</h2>
        <p className="pai-desc">Plato will re-extract scoring criteria from the current job description. Reviews that have already run keep the criteria they were scored against.</p>
        <div className="pai-statement">
          <span className="ic"><Ic name="refresh-cw" size={15} /></span>
          <span>{PAI_REGEN_ADVICE}</span>
        </div>
        <div className="pai-modal-foot">
          <PAIButton variant="primary" onClick={onConfirm}>Regenerate criteria</PAIButton>
          <PAIButton variant="secondary" onClick={onClose}>Cancel</PAIButton>
        </div>
      </div>
    </div>
  );
}

/* ── Guard modals (≤5 / 0), same shell ── */
function PAIGuardModal({ kind, total, onEdit, onClose }) {
  if (!kind) return null;
  const low = kind === "low";
  return (
    <div className="pai-scrim center" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="pai-modal" role="dialog" aria-label={low ? "Only a few criteria found" : "No criteria found"}>
        <h2>{low ? `Only ${total} criteria found` : "No criteria found"}</h2>
        <p className="pai-desc">
          {low
            ? `Plato found only ${total} scoring criteria for this job. That usually means the job description is missing a requirements or responsibilities section, or is too general to score against reliably.`
            : "Plato couldn't find any scoring criteria for this job. This can happen when the description only covers things like the company or benefits so far."}
        </p>
        <p className="pai-desc">
          {low
            ? "You can keep these criteria and reviews will run against them, but results may be less useful."
            : "Candidates won't be reviewed until this job has criteria to score against."}
        </p>
        <div className="pai-modal-foot">
          <PAIButton variant="primary" onClick={onEdit}>Edit job description</PAIButton>
          <PAIButton variant="secondary" onClick={onClose}>{low ? `Keep ${total} criteria` : "Close"}</PAIButton>
        </div>
      </div>
    </div>
  );
}

function JobSetupPlatoAI() {
  const { SettingsContainer, FormSection, FormSelect, Ic } = window;
  const [autoReview, setAutoReview] = React.useState("org");
  const [extracted, setExtracted] = React.useState(PAI_FULL);
  const [extractedAt, setExtractedAt] = React.useState("2 hours ago");
  const [extracting, setExtracting] = React.useState(false);
  const [view, setView] = React.useState(false);
  const [confirm, setConfirm] = React.useState(false);
  const [guard, setGuard] = React.useState(null); // "low" | "none" | null
  const cycleRef = React.useRef(0);

  const total = paiCount(extracted);

  const regenerate = () => {
    setConfirm(false);
    if (extracting) return;
    setExtracting(true);
    setTimeout(() => {
      const outcome = ["low", "none", "full"][cycleRef.current % 3];
      cycleRef.current += 1;
      const next = outcome === "low" ? PAI_LOW : outcome === "none" ? PAI_NONE : PAI_FULL;
      setExtracted(next);
      setExtractedAt("just now");
      setExtracting(false);
      const n = paiCount(next);
      if (n === 0) setGuard("none");
      else if (n <= 5) setGuard("low");
    }, 1600);
  };

  const goDescription = () => {
    setGuard(null);
    window.dispatchEvent(new CustomEvent("jobsetup-goto", { detail: { section: "description" } }));
  };

  const sidebar = (
    <div className="js-aside">
      <h3>Criteria tiers</h3>
      <p>Plato extracts scoring criteria from the job description and sorts them into tiers. Section titles decide the tier; words inside an item can also signal it, but the title always wins.</p>
      {PAI_TIERS.map((tier) => (
        <div className="pai-aside-entry" key={tier.key}>
          <div className="h"><Ic name={tier.icon} size={13} />{tier.label}</div>
          <p>
            <b>{tier.hint}</b>{" "}
            {tier.key === "tier_1" && "Plato takes them from sections titled Requirements or Must-haves, and from items with words like critical, required, or essential."}
            {tier.key === "tier_2" && "From sections titled Preferred or Nice to have. Criteria without a strong core or bonus signal land here."}
            {tier.key === "tier_3" && "Usually only from sections literally titled Bonus. Not every description produces them."}
          </p>
        </div>
      ))}
    </div>
  );

  return (
    <SettingsContainer
      title="Plato AI settings"
      description="How Plato reviews and scores candidates for this job."
      sidebar={sidebar}
      bottomBar={<PAIButton variant="primary">Save changes</PAIButton>}
    >
      <FormSection title="Automatic reviews">
        <FormSelect
          label="Review new candidates"
          description="Applies when a candidate applies or is added to this job."
          name="autoReview"
          value={autoReview}
          options={PAI_REVIEW_OPTIONS}
          onChange={(name, v) => setAutoReview(v)}
        />
      </FormSection>

      <FormSection
        title="Job criteria"
        intro={
          <React.Fragment>
            Each review scores a candidate against these, as they stand when it runs. To change them, edit your{" "}
            <a className="pai-link" onClick={goDescription}>job description</a>.
          </React.Fragment>
        }
      >
        {total > 0 ? (
          <PAICriteriaCard criteria={extracted} extractedAt={extractedAt} />
        ) : (
          <div className="pai-empty">
            <Ic name="alert-triangle" size={15} style={{ flexShrink: 0, marginTop: 2 }} />
            <span>No scoring criteria were found in the job description. Plato won't review candidates for this job until it has criteria to score against.</span>
          </div>
        )}
        <div className="pai-actions">
          {total > 0 && <PAIButton variant="secondary" onClick={() => setView(true)}>View criteria</PAIButton>}
          <PAIButton variant="secondary" loading={extracting} onClick={() => setConfirm(true)}>Regenerate criteria</PAIButton>
        </div>
      </FormSection>

      <PAIViewModal open={view} criteria={extracted} onClose={() => setView(false)} />
      <PAIRegenConfirm open={confirm} onConfirm={regenerate} onClose={() => setConfirm(false)} />
      <PAIGuardModal kind={guard} total={total} onEdit={goDescription} onClose={() => setGuard(null)} />
    </SettingsContainer>
  );
}

window.JobSetupPlatoAI = JobSetupPlatoAI;
