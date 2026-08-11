// Job → Applications list — the nested candidate review view.
// Faithful to JobApplicationListContainer + JobApplicationContainer +
// JobApplicationSidebar(+Actions). Uses the real Checkbox + DropdownMenu.
// Tab content (overview/resume/…) is a labeled placeholder — populated next.
const { Button, Checkbox, DropdownMenu, DropdownItem } = window.PolymerATSDesignSystem_3004dc;
const { useTweaks, TweaksPanel, TweakSection, TweakRadio, TweakToggle } = window;

const PLATO_TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "mark": "sparkle",
  "name": "Plato",
  "showCredits": true
}/*EDITMODE-END*/;

function Ic({ name, size = 15, cls }) {
  const ic = window.feather && window.feather.icons[name];
  const svg = ic ? ic.toSvg({ width: size, height: size, "stroke-width": 2 }) : "";
  return <span className={cls} style={{ display: "inline-flex" }} dangerouslySetInnerHTML={{ __html: svg }} />;
}

const CANDIDATES = [
  { id: 1, name: "Aisha Khan", source: "Applied from job board", email: "aisha.khan@gmail.com", phone: "+1 (415) 555-0182", location: "San Francisco, CA", linkedin: "aishakhan", github: "aishak", desired: "$180,000 / year" },
  {
    id: 2, name: "Marcus Lee", source: "Applied from job board", email: "marcus.lee@hey.com", phone: "+1 (212) 555-0147", location: "Brooklyn, NY", linkedin: "marcuslee", website: "marcuslee.dev",
    empty: true,
  },
  { id: 3, name: "Priya Nair", source: "Manually added", email: "priya.nair@outlook.com", location: "Austin, TX", linkedin: "priyanair" },
  { id: 4, name: "Tom Becker", source: "Applied via API", email: "tom@beckerlabs.io", phone: "+1 (503) 555-0193", location: "Portland, OR", github: "tbecker" },
  { id: 5, name: "Sofia Romano", source: "Imported", email: "sofia.romano@gmail.com", location: "Remote — Italy", linkedin: "sofiaromano", dribbble: "sromano" },
  { id: 6, name: "James Okonkwo", source: "Applied from job board", email: "j.okonkwo@gmail.com", phone: "+1 (646) 555-0110", location: "Jersey City, NJ" },
];

const SIDEBAR_TABS = [
  { key: "overview", label: "Overview", icon: "clipboard" },
  { key: "resume", label: "Resume", icon: "file" },
  { key: "messages", label: "Messages", icon: "message-square" },
  { key: "files", label: "Files", icon: "save" },
  { key: "notes", label: "Private notes", icon: "file-text" },
  { key: "ai", label: "Plato", icon: "__wand" },
];

// Star chip for the AI nav item — variant-driven (see PlatoMark)
function NavStar({ variant }) {
  return (
    <span style={{ width: 22, height: 22, borderRadius: 6, flexShrink: 0, background: "var(--accent-gradient)", display: "inline-flex", alignItems: "center", justifyContent: "center", color: "var(--neutral-900)", boxShadow: "inset 0 0 0 1px rgba(0,0,0,0.07)" }}>
      {window.PlatoMark ? <window.PlatoMark variant={variant} size={14} /> : null}
    </span>
  );
}

// Map the faithful-screen candidates onto the real generated summaries
// (window.AI_SAMPLES order: 0 Aneisha[weak] · 1 Noah · 2 Shaun · 3 Can[strong] · 4 Suman).
function getAiSummary(id) {
  const S = window.AI_SAMPLES || [];
  switch (id) {
    case 1: return S[3];                              // Aisha Khan  → strong fit (succeeded)
    case 3: return S[1];                              // Priya Nair  → long history (succeeded)
    case 4: return S[0];                              // Tom Becker  → weak fit, candid gaps
    case 5: return S[4] ? { ...S[4], stale: true } : null; // Sofia Romano → out of date
    case 6: return null;                              // James Okonkwo → no summary yet (generate CTA)
    default: return null;                             // Marcus Lee (empty) → no résumé
  }
}

function AutomationInfo({ stageName, templateName = "Moved to next stage", frequency = "once" }) {
  const [open, setOpen] = React.useState(false);
  const [skip, setSkip] = React.useState(false);
  const ref = React.useRef(null);
  React.useEffect(() => {
    const onDoc = (e) => { if (ref.current && !ref.current.contains(e.target)) setOpen(false); };
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, []);
  return (
    <div className="automation-info" ref={ref}>
      <div className="ai-details" onClick={() => setOpen((o) => !o)}>
        <Ic name={skip ? "zap-off" : "zap"} size={15} />
        <span>{skip ? "Skip automation once" : "1 automation will run"}</span>
        <Ic name={open ? "chevron-up" : "chevron-down"} size={15} />
      </div>
      {open && (
        <div className="ai-dropdown" onClick={(e) => e.stopPropagation()}>
          Move to <b>{stageName}</b> triggers an automated email to the candidate using the <b>"{templateName}"</b> template, sent <b>{frequency === "once" ? "once" : "every time"}</b>.
          <div className="ai-skip">
            <Checkbox label="Skip automation" checked={skip} onChange={setSkip} />
          </div>
        </div>
      )}
    </div>
  );
}

function CandidateSidebar({ cand, tab, setTab, tw }) {
  return (
    <div className="jac-sidebar">
      <div className="cp">
        <div className="cp-header">
          <h1>{cand.name}</h1>
          <div className="meta">
            <span className="cp-tag">{cand.source}</span>
            <span className="cp-perma" title="Copy link to candidate"><Ic name="link" size={13} /></span>
          </div>
        </div>

        <div className="cp-nav">
          {SIDEBAR_TABS.map((t) => (
            <div key={t.key} className={"navitem" + (tab === t.key ? " active" : "")} onClick={() => setTab(t.key)}>
              {t.icon === "__wand" ? <span className="ni-icon"><NavStar variant={tw.mark} /></span> : <Ic name={t.icon} size={16} cls="ni-icon" />}
              <span className="ni-label">{t.key === "ai" ? tw.name : t.label}</span>
              <Ic name="chevron-right" size={15} cls="ni-chevron" />
            </div>
          ))}
        </div>

        <hr className="cp-divider" />

        <div className="cp-info">
          <div className="it">Contact information</div>
          {cand.phone && <div className="ir"><Ic name="phone" size={13} /><a href={`tel:${cand.phone}`}>{cand.phone}</a></div>}
          {cand.email && <div className="ir"><Ic name="mail" size={13} /><a href={`mailto:${cand.email}`}>{cand.email}</a></div>}
          {cand.location && <div className="ir"><Ic name="map-pin" size={13} /><span>{cand.location}</span></div>}
        </div>

        {(cand.linkedin || cand.github || cand.website || cand.dribbble) && (
          <div className="cp-info">
            <div className="it">Links</div>
            {cand.linkedin && <div className="ir"><Ic name="linkedin" size={13} /><a href="#">linkedin.com/in/{cand.linkedin}</a></div>}
            {cand.github && <div className="ir"><Ic name="github" size={13} /><a href="#">github.com/{cand.github}</a></div>}
            {cand.dribbble && <div className="ir"><Ic name="dribbble" size={13} /><a href="#">dribbble.com/{cand.dribbble}</a></div>}
            {cand.website && <div className="ir"><Ic name="globe" size={13} /><a href="#">{cand.website}</a></div>}
          </div>
        )}

        {cand.desired && (
          <div className="cp-info">
            <div className="it">Desired compensation</div>
            <div className="ir"><Ic name="refresh-cw" size={13} /><span>{cand.desired}</span></div>
          </div>
        )}
      </div>

      <div className="cp-actions">
        <div className="cp-buttons">
          <Button variant="primary">Move to Screen</Button>
          <DropdownMenu hpos="right" vpos="top" button>
            <DropdownItem>Edit candidate</DropdownItem>
            <DropdownItem shortcut="M">Move to stage</DropdownItem>
            <DropdownItem>Move to job</DropdownItem>
            <DropdownItem>Delete candidate data</DropdownItem>
          </DropdownMenu>
          <Button variant="secondary">Archive</Button>
        </div>
        <AutomationInfo stageName="Screen" />
      </div>
    </div>
  );
}

function JobApplicationsView() {
  const [t, setTweak] = useTweaks(PLATO_TWEAK_DEFAULTS);
  window.PLATO_TW = t;
  const [selectedId, setSelectedId] = React.useState(1);
  const [checked, setChecked] = React.useState(() => new Set());
  const [allChecked, setAllChecked] = React.useState(false);
  const [tab, setTab] = React.useState("ai");

  const cand = CANDIDATES.find((c) => c.id === selectedId);
  const candAi = { ...cand, aiSummary: getAiSummary(cand.id) };
  const toggle = (id) => setChecked((prev) => { const n = new Set(prev); n.has(id) ? n.delete(id) : n.add(id); return n; });
  const toggleAll = () => {
    if (allChecked) { setAllChecked(false); setChecked(new Set()); }
    else { setAllChecked(true); setChecked(new Set(CANDIDATES.map((c) => c.id))); }
  };
  const isOn = (id) => allChecked || checked.has(id);

  return (
    <div className="jalc">
      {/* Pane 2 — candidates list */}
      <div className="jalc-sidebar">
        <div className="jalc-header">
          <div className="hc">
            <Checkbox checked={allChecked} onChange={toggleAll} label=" " />
            <h3>Inbox</h3>
          </div>
          <DropdownMenu label="Bulk options" hpos="right">
            <DropdownItem>Message candidates</DropdownItem>
            <DropdownItem>Move candidates</DropdownItem>
            <DropdownItem>Generate AI summaries</DropdownItem>
          </DropdownMenu>
        </div>
        <div className="jalc-list">
          {CANDIDATES.map((c) => (
            <div key={c.id} className={"ja-row" + (selectedId === c.id ? " active" : "")} onClick={() => setSelectedId(c.id)}>
              <span className="ja-cb" onClick={(e) => e.stopPropagation()}>
                <Checkbox checked={isOn(c.id)} onChange={() => toggle(c.id)} label=" " />
              </span>
              <div className="ja-navitem">
                <span className="ja-name">{c.name}</span>
                <Ic name="chevron-right" size={15} cls="ja-chevron" />
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Pane 3 + 4 */}
      <div className="jalc-content">
        <div className="jac">
          <CandidateSidebar cand={candAi} tab={tab} setTab={setTab} tw={t} />
          <div className="jac-content">
            <JobTab tab={tab} cand={candAi} setTab={setTab} tw={t} />
          </div>
        </div>
      </div>

      <TweaksPanel>
        <TweakSection label="Identity" />
        <TweakRadio label="Mark" value={t.mark}
          options={["sparkle", "sparkles", "wand"]}
          onChange={(v) => setTweak("mark", v)} />
        <TweakRadio label="Name" value={t.name}
          options={["Plato", "AI summary"]}
          onChange={(v) => setTweak("name", v)} />
        <TweakSection label="Cost" />
        <TweakToggle label="Show credit hint" value={t.showCredits}
          onChange={(v) => setTweak("showCredits", v)} />
      </TweaksPanel>
    </div>
  );
}

Object.assign(window, { JobApplicationsView });
