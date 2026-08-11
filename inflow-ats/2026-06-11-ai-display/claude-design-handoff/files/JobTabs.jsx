// Job application TAB content (pane 4). Faithful to the 5 containers.
// Uses real DS components; sample content stands in for dynamic data.
const { Button: TBtn, DropdownMenu: TDD, DropdownItem: TDDI, UserAvatar: TAvatar, EmptyState: TEmpty } = window.PolymerATSDesignSystem_3004dc;

function TIc({ name, size = 16, cls }) {
  const ic = window.feather && window.feather.icons[name];
  const svg = ic ? ic.toSvg({ width: size, height: size, "stroke-width": 2 }) : "";
  return <span className={cls} style={{ display: "inline-flex" }} dangerouslySetInnerHTML={{ __html: svg }} />;
}

/* ── Overview ───────────────────────────────────────────── */
function ActEvent({ icon, children, ago }) {
  return (
    <div className="ev">
      <span className="ev-icon"><TIc name={icon} size={14} /></span>
      {children}
      <span className="sep">‧</span>
      <span>{ago}</span>
    </div>
  );
}

function ReviewCard({ name, ago, rating, children }) {
  return (
    <div className="comment">
      <div className="comment-ev">
        <div><TAvatar size="sm" user={{ initials: name.split(" ").map((w) => w[0]).join("").slice(0, 2) }} /> {name} left a review <span className="sep">‧</span> <span>{ago}</span></div>
      </div>
      <div className="comment-body">{children}</div>
      <span className="review-rating">{rating}</span>
    </div>
  );
}

function TabOverview({ cand, setTab, tw }) {
  return (
    <div className="tab">
      <div className="tab-title">
        <div className="tw"><h2>Overview</h2></div>
        <TDD label="Overview options">
          <TDDI shortcut="H">Add hiring document</TDDI>
        </TDD>
      </div>
      <div className="feed">
        <div className="activities">
          {/* received event */}
          <div className="ev">
            <span className="ev-icon"><TIc name="inbox" size={14} /></span>
            Application received
            <span className="sep">‧</span>
            <span>2d ago</span>
          </div>

          {/* AI summary entry point */}
          <AiOverviewCallout cand={cand} onOpen={() => setTab && setTab("ai")} tw={tw} />

          {cand.empty ? (
            /* question responses — empty */
            <div className="qr">
              <TEmpty
                borderless
                icon={<TIc name="clipboard" size={20} />}
                title="No question responses to show"
                message="Custom questions can be added from the application tab in job setup"
              />
            </div>
          ) : (
            <React.Fragment>
              {/* question responses */}
              <div className="qr">
                <div className="qr-intro"><span className="ri"><TIc name="file" size={13} /></span>Application question responses</div>
                <div className="qa">
                  <div className="q"><p style={{ margin: 0 }}>Why do you want to work here?</p></div>
                  <div className="a">I've followed Aperture's design work for years and the craft bar is exactly where I want to be. I care about the details and shipping polished, accessible interfaces.</div>
                </div>
                <div className="qa">
                  <div className="q"><p style={{ margin: 0 }}>Years of professional experience</p></div>
                  <div className="a">7 years</div>
                </div>
              </div>

              {/* a comment */}
              <div className="comment">
                <div className="comment-ev">
                  <div><TAvatar size="sm" user={{ initials: "JG" }} /> Jessica Gertig left a comment <span className="sep">‧</span> <span>1d ago</span></div>
                  <div><button>Edit</button><button>Delete</button></div>
                </div>
                <div className="comment-body"><p>Strong portfolio — really liked the systems work. Worth a screen call to dig into the accessibility examples.</p></div>
              </div>

              {/* activity: review requested */}
              <ActEvent icon="edit-3" ago="1d ago">Jessica Gertig requested a review from Marco Chen</ActEvent>

              {/* a review */}
              <ReviewCard name="Marco Chen" ago="5h ago" rating="Strong yes">
                <p>Clean, considered work and a strong grasp of component systems. Happy to move forward to a screen.</p>
              </ReviewCard>

              {/* activity: stage move */}
              <ActEvent icon="corner-right-down" ago="3h ago">Jessica Gertig moved candidate to Screen</ActEvent>
            </React.Fragment>
          )}
        </div>

        <div className="feed-actions">
          <TBtn variant="secondary">Add a comment</TBtn>
          <TBtn variant="secondary">Start a review</TBtn>
          <TBtn variant="secondary">Request a review</TBtn>
        </div>
      </div>
    </div>
  );
}

/* ── Resume ─────────────────────────────────────────────── */
function TabResume({ cand }) {
  return (
    <div className="tab">
      <div className="resume-header">
        <h2>Resume</h2>
        <TDD label="Resume options">
          <TDDI>{cand.empty ? "Upload resume" : "Replace resume"}</TDDI>
          {!cand.empty && <TDDI>Download PDF</TDDI>}
        </TDD>
      </div>
      <div className="resume-body">
        {cand.empty ? (
          <div className="resume-dropzone">
            <span className="dz-icon"><TIc name="file" size={18} /></span>
            <h2 className="dz-title">No resume to show</h2>
            <p className="dz-text">You can drag and drop one here to upload it or...</p>
            <TBtn variant="secondary">Select a file</TBtn>
          </div>
        ) : (
          <div className="resume-doc">
            <div className="resume-page">
              <h3>{cand.name}</h3>
              <div className="role">Senior Frontend Engineer · {cand.location || "Remote"}</div>
              <div className="sec">Experience</div>
              <div className="line" style={{ width: "62%" }}></div>
              <div className="line" style={{ width: "94%" }}></div>
              <div className="line" style={{ width: "88%" }}></div>
              <div className="line" style={{ width: "70%" }}></div>
              <div className="sec">Skills</div>
              <div className="line" style={{ width: "80%" }}></div>
              <div className="line" style={{ width: "55%" }}></div>
              <div className="sec">Education</div>
              <div className="line" style={{ width: "66%" }}></div>
              <div className="line" style={{ width: "40%" }}></div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

/* ── Messages ───────────────────────────────────────────── */
function Msg({ who, name, badge, ago, children }) {
  return (
    <div className="msg">
      <div className="msg-head">
        <div className="msg-sender">
          <TAvatar size="lg" user={{ initials: name.split(" ").map((w) => w[0]).join("").slice(0, 2) }} />
          <div className="msg-attr">
            <div className="line1">
              <h3>{name}</h3>
              {badge && <span className="cand-badge">Candidate</span>}
              <span className="sep">‧</span>
              <span className="ago">{ago}</span>
            </div>
            <p>Sent via email</p>
          </div>
        </div>
        <TDD label="Message options">
          <TDDI>{who === "user" ? "Create template" : "View original"}</TDDI>
        </TDD>
      </div>
      <div className="msg-body">{children}</div>
    </div>
  );
}
function TabMessages({ cand }) {
  return (
    <div className="tab">
      <div className="tab-title"><div className="tw"><h2>Messages</h2></div></div>
      <div className="msg-feed">
        <div className="msg-history"><span className="mh-icon"><TIc name="flag" size={13} /></span>This is the beginning of your message history with this candidate</div>
        <Msg who="user" name="Jessica Gertig" ago="2d ago">
          <p>Hi {cand.name.split(" ")[0]} — thanks so much for applying to the Senior Frontend Engineer role. We loved your portfolio. Would you have time for a 30-minute intro call this week?</p>
        </Msg>
        <Msg who="candidate" name={cand.name} badge ago="1d ago">
          <p>Thanks Jessica! I'd love to. I'm free Wednesday or Thursday afternoon (PT) — whatever works best on your end.</p>
        </Msg>
      </div>
      <div className="msg-new">
        <div className="msg-field"><span className="ph">Type a message to the candidate here...</span></div>
        <div className="msg-controls">
          <TBtn variant="primary">Send message</TBtn>
          <TBtn variant="secondary">Use template</TBtn>
        </div>
      </div>
    </div>
  );
}

/* ── Files ──────────────────────────────────────────────── */
function FileRow({ name, canDelete }) {
  return (
    <div className="file-item">
      <div className="fn"><TIc name="file" size={16} />{name}</div>
      <div className="fr">
        <a className="file-dl" href="#">Download</a>
        {canDelete && <TDD label="Options"><TDDI>Delete</TDDI></TDD>}
      </div>
    </div>
  );
}
function TabFiles({ cand }) {
  const first = cand.name.split(" ")[0].toLowerCase();
  return (
    <div className="tab">
      <div className="tab-title"><div className="tw"><h2>Files</h2></div></div>
      <div className="files-body">
        <div className="files-section">
          <div className="sl">Application attachments</div>
          <div className="file-list"><FileRow name={`${first}-resume.pdf`} /></div>
        </div>
        <div className="files-section">
          <div className="sl">Message attachments</div>
          <div className="no-files">No file attachments have been received from this candidate</div>
        </div>
        <div className="files-section">
          <div className="sl">Additional file storage</div>
          <div className="no-files">No additional files have been uploaded to this job application</div>
          <div className="files-upload"><TBtn variant="secondary">Upload file</TBtn></div>
        </div>
      </div>
    </div>
  );
}

/* ── Private notes ──────────────────────────────────────── */
function TabNotes({ cand }) {
  const tools = ["bold", "italic", "list", "link", null, "code", "image"];
  return (
    <div className="notes">
      <div className="notes-menubar">
        {tools.map((t, i) => t === null
          ? <span key={i} className="mb-div"></span>
          : <span key={i} className="mb"><TIc name={t === "list" ? "list" : t} size={16} /></span>)}
      </div>
      <div className="notes-editor">This is a private document for notes...</div>
      <div className="notes-bottombar">
        <TBtn variant="primary">Save changes</TBtn>
        <span className="status">No unsaved changes</span>
      </div>
    </div>
  );
}

function JobTab({ tab, cand, setTab, tw }) {
  switch (tab) {
    case "resume": return <TabResume cand={cand} />;
    case "messages": return <TabMessages cand={cand} />;
    case "files": return <TabFiles cand={cand} />;
    case "notes": return <TabNotes cand={cand} />;
    case "ai": return <AiSummaryPane summary={cand.aiSummary} hasResume={!cand.empty} tw={tw} />;
    default: return <TabOverview cand={cand} setTab={setTab} tw={tw} />;
  }
}

Object.assign(window, { JobTab });
