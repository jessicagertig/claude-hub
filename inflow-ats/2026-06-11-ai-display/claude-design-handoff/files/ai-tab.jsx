// AI summary tab — pane-4 content, built ON TOP of the faithful job view.
// Same idiom as JobTabs.jsx: .tab → .tab-title → scrolling body, real DS Button.
// Reads a normalized summary (window.AI_SAMPLES, from lib/samples.js).
const { Button: AiBtn } = window.PolymerATSDesignSystem_3004dc;
const AI_CREDITS = { totalCreditsRemaining: 142, monthlyCreditAllocation: 200, monthlyCreditsRemaining: 142 };

/* Plato mark — three star treatments, switchable via Tweaks.
   sparkle = Lucide single "sparkle" (stroked) — L5, the default
   sparkles= Lucide "sparkles" — big star + dot filled, plus stroked
   wand    = Lucide "wand-sparkles" (stroked) */
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
    inner = (
      <g {...stroke}>
        <path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .962 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.582a.5.5 0 0 1 0 .962L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.962 0z" />
      </g>
    );
  }
  return <span style={{ display: "inline-flex", alignItems: "center", color }}><svg {...base}>{inner}</svg></span>;
}
window.PlatoMark = PlatoMark;

function PlatoStar({ size = 16, color = "currentColor", variant }) {
  return <PlatoMark variant={variant || (window.PLATO_TW && window.PLATO_TW.mark) || "sparkle"} size={size} color={color} />;
}
function PlatoChip({ size = 26, radius = 7, variant }) {
  return (
    <span style={{ width: size, height: size, borderRadius: radius, flexShrink: 0, background: "var(--accent-gradient)", display: "inline-flex", alignItems: "center", justifyContent: "center", color: "var(--neutral-900)", boxShadow: "inset 0 0 0 1px rgba(0,0,0,0.07)" }}>
      <PlatoStar size={Math.round(size * 0.62)} variant={variant} />
    </span>
  );
}
function AiIc({ name, size = 15, color }) {
  const ic = window.feather && window.feather.icons[name];
  const svg = ic ? ic.toSvg({ width: size, height: size, "stroke-width": 2 }) : "";
  return <span style={{ display: "inline-flex", alignItems: "center", color: color || "currentColor" }} dangerouslySetInnerHTML={{ __html: svg }} />;
}

function aiFmtDur(months) {
  if (months == null) return "";
  const y = Math.floor(months / 12), m = months % 12;
  if (y === 0) return `${m}m`;
  if (m === 0) return `${y}y`;
  return `${y}y ${m}m`;
}

/* ── normalize raw DB record → camelCase summary ─────────── */
function aiNormalize(rec) {
  if (!rec) return null;
  const sd = rec.structured_data || {};
  const a = sd.assessment || {};
  return {
    status: rec.status, stale: rec.stale, createdAt: "2d ago",
    headline: rec.headline, summaryText: rec.summary_text,
    d: {
      skills: sd.skills || [], keySkills: a.key_skills || [],
      totalMonthsExperience: sd.total_months_experience, monthsByDomain: sd.months_by_domain || {},
      roleAnalysis: sd.role_analysis, applicableExperience: sd.applicable_experience,
      gaps: sd.gaps, overlapSummary: sd.overlap_summary,
      primaryDomain: a.primary_domain && a.primary_domain.name,
      secondaryDomain: a.secondary_domain && a.secondary_domain.name,
      standoutAccomplishments: a.standout_accomplishments || [],
    },
  };
}
window.AI_SAMPLES = (window.REAL_SAMPLES || []).map(aiNormalize);

/* ── main pane ───────────────────────────────────────────── */
const PLATO_DEFAULT_TW = { mark: "sparkle", name: "Plato", showCredits: true };
function AiSummaryPane({ summary, hasResume = true, tw }) {
  tw = tw || PLATO_DEFAULT_TW;
  const s = summary || { status: "none" };
  const generating = s.status === "pending" || s.status === "in_progress" || s.status === "extracted";
  const succeeded = s.status === "succeeded";

  return (
    <div className="tab">
      <div className="tab-title">
        <div className="tw">
          <PlatoChip size={26} variant={tw.mark} />
          <h2>{tw.name}</h2>
        </div>
        {succeeded
          ? <AiBtn variant="ghost" iconLeft={<AiIc name="refresh-cw" size={15} />}>Regenerate</AiBtn>
          : <button className="iconbtn"><AiIc name="more-vertical" size={16} /></button>}
      </div>
      <div style={{ flex: 1, overflowY: "auto", minHeight: 0 }}>
        <div style={{ maxWidth: 720, margin: "0 auto", padding: "22px 28px 56px" }}>
          {succeeded ? <AiSucceeded s={s} tw={tw} />
            : generating ? <AiGenerating tw={tw} />
            : s.status === "textract_processing" ? <AiProcessing tw={tw} />
            : s.status === "failed" ? <AiFailed tw={tw} />
            : <AiEmpty hasResume={hasResume} tw={tw} />}
        </div>
      </div>
    </div>
  );
}
const platoBy = (tw) => tw.name === "Plato" ? "Generated by Polymer Plato" : "Generated by Polymer AI";

/* ── succeeded ───────────────────────────────────────────── */
function AiSucceeded({ s, tw }) {
  const d = s.d;
  return (
    <React.Fragment>
      <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12.5, color: "var(--text-secondary)", marginBottom: 18 }}>
        <span>{platoBy(tw)}</span>
        {s.createdAt && <><span style={{ color: "var(--neutral-300)" }}>·</span><span className="poly-tnum">{s.createdAt}</span></>}
      </div>

      {s.stale && <AiStaleBanner tw={tw} />}

      <h1 style={{ fontSize: 23, lineHeight: 1.28, fontWeight: 600, letterSpacing: "-0.02em", color: "var(--text-loud)", textWrap: "pretty", margin: "0 0 10px" }}>{s.headline}</h1>

      <AiDomainLabel d={d} />

      {/* Fit for this role — the lead nugget (falls back to summary if absent) */}
      {(d.roleAnalysis || s.summaryText) && <AiRoleFit text={d.roleAnalysis || s.summaryText} />}

      {d.standoutAccomplishments && d.standoutAccomplishments.length > 0 && (
        <AiBlock eyebrow="Notable achievements"><AiStandout items={d.standoutAccomplishments} /></AiBlock>
      )}

      {d.applicableExperience && <AiBlock eyebrow="Relevant experience"><AiProse>{d.applicableExperience}</AiProse></AiBlock>}

      {d.gaps && <AiBlock eyebrow="Gaps to probe"><AiProse>{d.gaps}</AiProse></AiBlock>}

      {d.skills && d.skills.length > 0 && <AiBlock eyebrow="Skills"><AiSkillCloud skills={d.skills} keySkills={d.keySkills} /></AiBlock>}

      <AiFooter tw={tw} />
    </React.Fragment>
  );
}

function AiDomainLabel({ d }) {
  const parts = [d.primaryDomain, d.secondaryDomain].filter(Boolean);
  if (!parts.length) return null;
  const cap = (x) => x.charAt(0).toUpperCase() + x.slice(1);
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 16, flexWrap: "wrap" }}>
      {parts.map((p, i) => (
        <React.Fragment key={p}>
          {i > 0 && <span aria-hidden="true" style={{ width: 3, height: 3, borderRadius: "50%", background: "var(--neutral-500)", flexShrink: 0 }} />}
          <span style={{ fontSize: 13, fontWeight: 500, whiteSpace: "nowrap", color: i === 0 ? "var(--text-loud)" : "var(--text-secondary)" }}>{cap(p)}</span>
        </React.Fragment>
      ))}
    </div>
  );
}

function AiStandout({ items }) {
  return (
    <div style={{ margin: 0, display: "flex", flexDirection: "column", gap: 9 }}>
      {items.map((it, i) => (
        <div key={i} style={{ display: "flex", gap: 10, alignItems: "flex-start" }}>
          <span style={{ flexShrink: 0, marginTop: 2, color: "var(--neutral-700)", display: "inline-flex" }}><AiIc name="award" size={15} /></span>
          <span style={{ fontSize: 14, lineHeight: "21px", color: "var(--text-primary)", textWrap: "pretty" }}>{it}</span>
        </div>
      ))}
    </div>
  );
}

function AiExpStrip({ d }) {
  const domains = d.monthsByDomain ? Object.entries(d.monthsByDomain).sort((a, b) => b[1] - a[1]) : [];
  const max = domains.reduce((m, [, v]) => Math.max(m, v), 0) || 1;
  const cap = (x) => x.charAt(0).toUpperCase() + x.slice(1);
  return (
    <div style={{ marginTop: 18, border: "1px solid var(--border)", borderRadius: 8, padding: "14px 16px" }}>
      <div style={{ display: "flex", alignItems: "baseline", gap: 8, marginBottom: domains.length ? 13 : 0 }}>
        <span style={{ fontSize: 22, fontWeight: 600, letterSpacing: "-0.02em", color: "var(--text-loud)" }} className="poly-tnum">{aiFmtDur(d.totalMonthsExperience)}</span>
        <span style={{ fontSize: 13, color: "var(--text-secondary)" }}>total experience · by domain</span>
      </div>
      {domains.length > 0 && (
        <div style={{ display: "flex", flexDirection: "column", gap: 9 }}>
          {domains.map(([name, v]) => (
            <div key={name} style={{ display: "grid", gridTemplateColumns: "150px 1fr 52px", alignItems: "center", gap: 12 }}>
              <span style={{ fontSize: 12.5, color: "var(--text-secondary)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{cap(name)}</span>
              <span style={{ height: 6, borderRadius: 3, background: "var(--neutral-150)", overflow: "hidden", display: "block" }}>
                <span style={{ display: "block", height: "100%", width: `${Math.max(5, (v / max) * 100)}%`, background: "var(--neutral-700)", borderRadius: 3 }} />
              </span>
              <span style={{ fontSize: 12, color: "var(--text-placeholder)", textAlign: "right" }} className="poly-tnum">{aiFmtDur(v)}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function AiRoleFit({ text }) {
  return (
    <div style={{ position: "relative", border: "1px solid var(--border)", borderRadius: 9, padding: "16px 20px 20px", marginBottom: 24, overflow: "hidden" }}>
      <span style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: 3, background: "var(--accent-gradient)" }} />
      <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 10 }}>
        <span style={{ color: "var(--neutral-700)", display: "inline-flex" }}><PlatoStar size={15} /></span>
        <span style={{ fontSize: 13.5, fontWeight: 600, color: "var(--text-loud)", whiteSpace: "nowrap" }}>Fit for this role</span>
      </div>
      <p style={{ fontSize: 15, lineHeight: "24px", color: "var(--text-primary)", margin: 0, textWrap: "pretty" }}>{text}</p>
    </div>
  );
}

function AiBlock({ eyebrow, children }) {
  return (
    <div style={{ marginBottom: 22 }}>
      <div className="poly-eyebrow" style={{ marginBottom: 8 }}>{eyebrow}</div>
      {children}
    </div>
  );
}
function AiSupportRow({ icon, label, children }) {
  return (
    <div style={{ display: "flex", gap: 12, padding: "14px 0", borderTop: "1px solid var(--divider)" }}>
      <span style={{ width: 26, height: 26, flexShrink: 0, borderRadius: 6, background: "var(--neutral-100)", border: "1px solid var(--border)", display: "inline-flex", alignItems: "center", justifyContent: "center", color: "var(--text-secondary)" }}><AiIc name={icon} size={14} /></span>
      <div>
        <div style={{ fontSize: 13, fontWeight: 500, color: "var(--text-loud)", marginBottom: 3 }}>{label}</div>
        <div style={{ fontSize: 14, lineHeight: "21px", color: "var(--text-secondary)", textWrap: "pretty" }}>{children}</div>
      </div>
    </div>
  );
}
function AiProse({ children }) {
  return <p style={{ fontSize: 14.5, lineHeight: "23px", color: "var(--text-primary)", margin: 0, maxWidth: "66ch", textWrap: "pretty" }}>{children}</p>;
}
function AiSkillCloud({ skills, keySkills }) {
  const keys = keySkills || [];
  const isKey = (x) => keys.some((k) => x === k || x.toLowerCase().startsWith(k.toLowerCase()));
  const ordered = [...skills].sort((a, b) => (isKey(b) ? 1 : 0) - (isKey(a) ? 1 : 0));
  return (
    <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
      {ordered.map((sk) => (
        <span key={sk} style={{ fontSize: 13, fontWeight: 450, lineHeight: "20px", color: isKey(sk) ? "var(--text-loud)" : "var(--text-primary)", border: "1px solid var(--chip-border)", borderRadius: 4, padding: "3px 10px", background: isKey(sk) ? "var(--neutral-100)" : "transparent" }}>{sk}</span>
      ))}
    </div>
  );
}
function AiStaleBanner({ tw }) {
  const subj = tw && tw.name === "Plato" ? "Plato wrote" : "this summary was generated";
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "10px 12px", borderRadius: 7, background: "var(--well-canvas)", marginBottom: 18 }}>
      <AiIc name="alert-triangle" size={15} color="var(--text-secondary)" />
      <span style={{ fontSize: 13, color: "var(--text-secondary)", flex: 1 }}>The resume changed after {subj} this summary.</span>
      <button style={{ fontSize: 13, fontWeight: 500, color: "var(--text-loud)", background: "none", border: "none", cursor: "pointer", padding: 0, display: "inline-flex", alignItems: "center", gap: 5, fontFamily: "var(--font-sans)" }}><AiIc name="refresh-cw" size={13} />Regenerate · 1 credit</button>
    </div>
  );
}
function AiFooter({ tw }) {
  const subj = tw && tw.name === "Plato" ? "Plato can be wrong." : "AI summaries can be imperfect.";
  return (
    <div style={{ marginTop: 30, paddingTop: 14, borderTop: "1px solid var(--divider)", display: "flex", alignItems: "center", gap: 8 }}>
      <AiIc name="info" size={13} color="var(--neutral-400)" />
      <span style={{ fontSize: 12, color: "var(--text-placeholder)" }}>{subj} Always confirm against the resume before deciding.</span>
    </div>
  );
}

/* ── zero / progress / error states ──────────────────────── */
function AiZero({ children }) {
  return <div style={{ display: "flex", flexDirection: "column", alignItems: "center", textAlign: "center", padding: "52px 24px 44px" }}>{children}</div>;
}
function AiEmpty({ hasResume, tw }) {
  tw = tw || PLATO_DEFAULT_TW;
  const credits = AI_CREDITS.totalCreditsRemaining;
  const isP = tw.name === "Plato";
  return (
    <AiZero>
      <PlatoChip size={40} radius={11} variant={tw.mark} />
      <h2 style={{ fontSize: 18, fontWeight: 600, letterSpacing: "-0.01em", color: "var(--text-loud)", margin: "16px 0 6px" }}>{hasResume ? (isP ? "Plato hasn't reviewed this candidate yet" : "No AI summary yet") : (isP ? "Plato needs a resume" : "No resume to summarize")}</h2>
      <p style={{ fontSize: 14, lineHeight: "22px", color: "var(--text-secondary)", maxWidth: 380, margin: "0 0 18px" }}>
        {hasResume ? (isP ? "Plato will analyze the resume for role fit, relevant experience, skills, and gaps." : "Generate a summary to see role fit, relevant experience, skills, and gaps pulled straight from the resume.") : (isP ? "Plato reviews a candidate from their resume. Add one to this candidate to get started." : "AI summaries are built from the candidate's resume — this one hasn't attached one yet.")}
      </p>
      {hasResume && (
        <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
          <AiBtn variant="primary" iconLeft={<AiIc name="zap" size={15} />}>Generate summary</AiBtn>
          {tw.showCredits && <span style={{ fontSize: 13, color: "var(--text-placeholder)" }} className="poly-tnum">Uses 1 credit · {credits} remaining</span>}
        </div>
      )}
    </AiZero>
  );
}
function AiGenerating({ tw }) {
  const isP = !tw || tw.name === "Plato";
  const sh = { background: "var(--neutral-100)", borderRadius: 4 };
  return (
    <React.Fragment>
      <div style={{ display: "inline-flex", alignItems: "center", gap: 8, marginBottom: 22, padding: "6px 12px", borderRadius: 999, background: "var(--well-canvas)" }}>
        <span style={{ display: "inline-flex", gap: 3 }}>{[0, 1, 2].map((i) => <span key={i} className="ai-dot" style={{ width: 5, height: 5, borderRadius: "50%", background: "var(--neutral-500)", animationDelay: `${i * 0.16}s` }} />)}</span>
        <span style={{ fontSize: 13, color: "var(--text-secondary)" }}>{isP ? "Plato is reading the resume and writing the summary…" : "Reading the resume and writing the summary…"}</span>
      </div>
      <div className="ai-shimmer" style={{ ...sh, width: "92%", height: 22, marginBottom: 10 }} />
      <div className="ai-shimmer" style={{ ...sh, width: "70%", height: 22, marginBottom: 20 }} />
      {["100%", "97%", "99%", "58%"].map((w, i) => <div key={i} className="ai-shimmer" style={{ ...sh, width: w, height: 13, marginBottom: 9 }} />)}
      <div className="ai-shimmer" style={{ ...sh, width: "100%", height: 84, borderRadius: 8, margin: "16px 0 22px" }} />
      <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>{[64, 52, 78, 46, 70, 58].map((w, i) => <span key={i} className="ai-shimmer" style={{ height: 26, width: w, borderRadius: 4, background: "var(--neutral-100)" }} />)}</div>
    </React.Fragment>
  );
}
function AiProcessing({ tw }) {
  const isP = !tw || tw.name === "Plato";
  return (
    <AiZero>
      <span style={{ width: 40, height: 40, borderRadius: 11, background: "var(--neutral-100)", border: "1px solid var(--border)", display: "inline-flex", alignItems: "center", justifyContent: "center", color: "var(--text-secondary)" }}><AiIc name="file-text" size={18} /></span>
      <h2 style={{ fontSize: 17, fontWeight: 600, color: "var(--text-loud)", margin: "16px 0 6px" }}>{isP ? "Plato is waiting on the resume" : "Processing resume"}</h2>
      <p style={{ fontSize: 14, lineHeight: "22px", color: "var(--text-secondary)", maxWidth: 360, margin: 0 }}>{isP ? "We're reading the resume file first. Plato will summarize automatically once it's ready — no action needed." : "We're reading the resume file first. The summary will generate automatically once it's ready — no action needed."}</p>
    </AiZero>
  );
}
function AiFailed({ tw }) {
  const isP = !tw || tw.name === "Plato";
  return (
    <AiZero>
      <span style={{ width: 40, height: 40, borderRadius: 11, background: "var(--neutral-100)", border: "1px solid var(--border)", display: "inline-flex", alignItems: "center", justifyContent: "center", color: "var(--text-secondary)" }}><AiIc name="alert-circle" size={18} /></span>
      <h2 style={{ fontSize: 17, fontWeight: 600, color: "var(--text-loud)", margin: "16px 0 6px" }}>{isP ? "Plato couldn't generate the summary" : "Couldn't generate the summary"}</h2>
      <p style={{ fontSize: 14, lineHeight: "22px", color: "var(--text-secondary)", maxWidth: 360, margin: "0 0 18px" }}>Something went wrong while analyzing the resume. <strong style={{ color: "var(--text-loud)", fontWeight: 500 }}>No credit was used.</strong> You can try again.</p>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
        <AiBtn variant="primary" iconLeft={<AiIc name="refresh-cw" size={15} />}>Try again</AiBtn>
        {(!tw || tw.showCredits) && <span style={{ fontSize: 13, color: "var(--text-placeholder)" }} className="poly-tnum">Uses 1 credit</span>}
      </div>
    </AiZero>
  );
}

Object.assign(window, { AiSummaryPane, AiOverviewCallout });

/* ── Overview entry point — callout into the AI tab ──────── */
function AiOverviewCallout({ cand, onOpen, tw }) {
  tw = tw || PLATO_DEFAULT_TW;
  const isP = tw.name === "Plato";
  const s = cand.aiSummary;
  const working = s && ["pending", "in_progress", "extracted", "textract_processing"].includes(s.status);
  let title, sub, cta;
  if (s && s.status === "succeeded") {
    title = isP ? (s.stale ? "Plato's review is out of date" : "Read what Plato thinks about this candidate") : (s.stale ? "AI summary · out of date" : "AI summary ready");
    sub = s.headline; cta = "View";
  } else if (cand.empty) {
    title = isP ? "Plato needs a resume" : "No resume to summarize"; sub = isP ? "Add one to this candidate and Plato can review them." : "Add a resume to generate a summary."; cta = "View";
  } else if (s && s.status === "failed") {
    title = isP ? "Plato couldn't finish" : "AI summary failed"; sub = "No credit was used — open to retry."; cta = "View";
  } else if (working) {
    title = isP ? "Plato is reading the resume…" : "AI summary generating…"; sub = "This will be ready in a moment."; cta = "View";
  } else {
    title = isP ? "Ask Plato to review this candidate" : "Generate an AI summary"; sub = isP ? "Plato reads the resume for role fit, experience, skills and gaps." : "See role fit, experience, skills and gaps from the resume."; cta = "Generate";
  }
  return (
    <div className="ai-callout" onClick={onOpen}>
      <span className="ai-callout-bar" />
      <PlatoChip size={32} radius={8} variant={tw.mark} />
      <div className="ai-callout-text">
        <div className="t">{title}</div>
        <div className="s">{sub}</div>
      </div>
      <span className="ai-callout-cta">{cta}<AiIc name="chevron-right" size={15} /></span>
    </div>
  );
}
