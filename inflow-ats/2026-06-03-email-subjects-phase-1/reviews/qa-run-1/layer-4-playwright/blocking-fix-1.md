# Blocking Fix 1 — TypeScript compilation failure

## Error
Webpack compilation fails with:
```
TS2741: Property 'subject' is missing in type '{ id: null; name: string; body: any; }' 
but required in type '{ id: any; name: any; body: any; subject: any; }'.
```

**File:** `app/javascript/ats/src/views/jobApplications/channelMessages/ChannelMessageListItem.tsx:40`

## Root cause
The implementation added `subject` to `ChannelMessageTemplateModal` Props (making it required) but missed updating `ChannelMessageListItem.tsx`, which creates a template object to pass to that modal.

## Fix applied
Added `subject: ""` to the object literal:
```diff
- channelMessageTemplate={{ id: null, name: "", body: message.body }}
+ channelMessageTemplate={{ id: null, name: "", body: message.body, subject: "" }}
```

Empty string is correct — the template modal defaults null/empty subjects to `"{{JobTitle}} at {{OrganizationName}}"`.

## Verification
Webpack compiles cleanly after the fix.
