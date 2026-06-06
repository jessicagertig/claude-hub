# Layer 4 Failure Report — QA Run 1

## BLOCKER: Webpack compilation fails — missed file in implementation

**File:** `app/javascript/ats/src/views/jobApplications/channelMessages/ChannelMessageListItem.tsx` line 40

**Error:**
```
TS2741: Property 'subject' is missing in type '{ id: null; name: string; body: any; }' 
but required in type '{ id: any; name: any; body: any; subject: any; }'.

    channelMessageTemplate={{ id: null, name: "", body: message.body }}
```

**Root cause:** The implementation added `subject` to the `ChannelMessageTemplateModal` Props type (making it required), but `ChannelMessageListItem.tsx` was never updated. This file creates a template object to pass to that modal when a user clicks to create a template from a sent message. The object literal is missing the `subject` property.

**Impact:** Webpack cannot compile the frontend. The React app does not load. The entire feature is non-functional in the browser.

**Fix:** Add `subject` to the template object literal at `ChannelMessageListItem.tsx:40`. The value should be `message.subject || ""` (or just `""` since this is creating a new template from a message body — the user can edit the subject in the template modal).

## MED Findings (collected, do not block)

The following MED findings from Layers 1-2 are carried forward for the final report:

- C-001: CSS font-size bug in SubjectPreview (`font-size: ${t.text.sm}`)
- C-002: Automation modal existing-template preview doesn't show subject
- C-003: Template modal missing subject repopulation on validation error
- C-006/L2-006: Bulk job rescue missing :subject error check
- L2-008: Validator can reject inbound emails with {{placeholder}} in subject
- L2-009: HTML sanitizer encodes ampersands in subjects
- L2-010: HTML sanitizer strips angle-brackets from subjects
- L2-011: Template controller doesn't sanitize subject
- L2-012: blank? before scrub ordering (pre-existing)
