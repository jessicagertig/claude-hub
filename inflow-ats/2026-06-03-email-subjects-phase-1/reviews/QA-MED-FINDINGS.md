# QA MED Findings — Email Subjects Phase 1a

Consolidated MED findings from all layers across both QA runs. Deduplicated aggressively per the QA prompt. These do not block approval but are recommended for review.

---

### 1. CSS font-size bug in SubjectPreview

**File:** `ChannelMessageTemplateSelectionModal.tsx` line 207
**Issue:** `font-size: ${t.text.sm};` produces invalid CSS because `t.text.sm` is a complete CSS declaration including `font-size:`. The output is `font-size: font-size: 0.875rem;`. The browser silently drops the property.
**Fix:** Replace with `${t.text.sm};` (standalone).
**Impact:** Subject preview text renders at inherited font size instead of intended small font. Cosmetic.
**Source:** C-001, flagged by 5 agents across L1 and L4. Already documented in pipeline Known Failure Pattern #1.

---

### 2. Automation modal existing-template preview doesn't show subject

**File:** `HiringStageAutomationModal.tsx` lines 401-406
**Issue:** When selecting an existing template in the automation modal, the preview renders `selectedTemplate.body` but not `selectedTemplate.subject`. The spec says "show the saved template's subject as-is."
**Fix:** Add subject display above the body preview in the existing-template preview section.
**Impact:** Users can't see what subject will be sent when selecting an existing template for automation. Low frequency (automation setup is infrequent).
**Source:** C-002, confirmed by L4 Agent 5.

---

### 3. Template modal missing subject repopulation on validation error

**File:** `ChannelMessageTemplateModal.tsx` handleSubmit else branch
**Issue:** When subject validation fails with an empty field, the error is shown but the field is not repopulated with the default. `BulkMessageModal` and `ChannelMessageNew` both repopulate.
**Fix:** Add subject repopulation logic matching the pattern in the other two modals.
**Impact:** User must manually re-enter the subject after clearing and failing validation. Minor UX inconsistency.
**Source:** C-003, confirmed by L4 Agent 5.

---

### 4. BulkChannelMessageSendJob rescue block missing :subject error check

**File:** `bulk_channel_message_send_job.rb` lines 26-35
**Issue:** The `RecordInvalid` rescue checks `e.record.errors.messages[:message]` and `[:body]` but not `[:subject]`. If subject validation fails (e.g., unsubstituted `{{placeholder}}`), the error is logged but the user gets no growl notification. The message silently fails for that candidate.
**Fix:** Add an `elsif` branch checking `:subject` errors.
**Impact:** Edge case — requires a `{{placeholder}}` pattern surviving through `parse_text` substitution, which is unlikely in normal usage.
**Source:** C-006, confirmed at runtime by L2 Agent 12.

---

### 5. Validator can reject inbound candidate emails with {{placeholder}} in subject

**File:** `channel_message.rb` line 25 (`validates :subject, custom_channel_message: true`)
**Issue:** The `CustomChannelMessageValidator` rejects any value matching `/{{\s*[\w.]+\s*}}/i`. It applies to all `sent_by` types including `sent_by_candidate`. If a candidate's email reply subject contains `{{word}}`, the inbound message silently fails to save.
**Fix:** Add `unless: :sent_by_candidate?` to both subject and body validations (body has the same pre-existing issue).
**Impact:** Extremely unlikely — candidates rarely type `{{word}}` in email subjects. The body validator has the same risk and has been running in production without incident. Spec explicitly says to apply the validator "the same way it is currently applied to body."
**Source:** L2-008, classified HIGH by Agent 8, consolidated as MED.

---

### 6. HTML sanitizer inappropriate for plain-text subjects

**Files:** `channel_messages_controller.rb`, `bulk_channel_messages_controller.rb`
**Issue:** The spec says to use the same `Sanitizer#sanitize` call as body. But body is HTML (from ProseMirror rich-text editor) while subject is plain text (from a regular `<input>`). The HTML sanitizer:
- Encodes `&` to `&amp;` — "R&D Department" becomes "R&amp;D Department" in the email
- Strips angle-bracket content — "RE: <Please Read>" becomes "RE: Your Application"
**Fix:** Use a plain-text sanitizer for subject (strip control chars, don't HTML-encode).
**Impact:** Real UX issue for subjects containing `&` or angle brackets. Moderate frequency.
**Source:** L2-009 + L2-010 (same root cause).

---

### 7. Template controller doesn't sanitize template subjects

**File:** `channel_message_templates_controller.rb`
**Issue:** Permits `:subject` but never calls `sanitize()`. Body is also not sanitized at template level (consistent pre-existing behavior). XSS payloads in template subjects are stored but currently not exploitable (React auto-escapes JSX text).
**Fix:** Either add sanitization or document the intentional omission. Low priority since the existing body behavior is the same.
**Impact:** Stored XSS concern if `dangerouslySetInnerHTML` is ever used for subject rendering.
**Source:** L2-011.

---

### 8. blank? before scrub ordering (pre-existing)

**Files:** `bulk_channel_message_send_job.rb`, `create_stage_automation_message.rb`, `job_application.rb`
**Issue:** `return '' if text.blank?` comes before `text.scrub`. `blank?` raises `ArgumentError` on malformed UTF-8 before `scrub` can clean it. Caught by outer rescue handlers (no crash) but prevents message delivery.
**Fix:** Swap ordering: `text = text.scrub; return '' if text.blank?`
**Impact:** Pre-existing — affects body identically. Browsers always send valid UTF-8, so the scenario is near-impossible in practice.
**Source:** L2-012.
