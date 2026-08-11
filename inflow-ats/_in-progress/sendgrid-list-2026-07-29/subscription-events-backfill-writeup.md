# Retroactive conversion events in PostHog

## TL;DR

I added retroactive conversion events for our existing paying customers. They ended up dated
today. The events are `trial_converted_to_paid` and `converted_to_paid`. To separate these from
real, non-retroactive conversions, I'm renaming the events going forward to
`trial_converted_to_paid_subscription` and `converted_to_paid_subscription`, so the two are kept
apart.

Just give me a thumbs up if you understand — you can read the rest later.

## What happened

As part of the PostHog conversion events work, I did a one-time data migration in my own
database, recording every existing paying customer's past conversion so that when one of them
pays their next invoice we don't count it as a new conversion.

Creating those records is also the trigger for the PostHog events, so each one went into
PostHog as a `trial_converted_to_paid` or `converted_to_paid` event.

I didn't intend for them all to be dated today, but retroactive events in PostHog didn't work
as expected.

## The good part

PostHog only started collecting data in February. Every customer who converted before then
had no conversion recorded and wasn't marked as paying. This is the only thing that gives
us that history at all, and I've checked the paying status it set is correct for all of
them.

So the data itself is right and worth keeping. Only the dates are wrong.

## Why I have to use a different name

The retroactive events can't be removed. PostHog has no way to delete individual events — the
only option is deleting the person entirely, which would take their real signup and login
history with them. So the existing event names permanently contain the retroactive set, and any
funnel or conversion chart built on them shows that spike.

The only way to keep real conversions clean is to record them under a new name.

## What I'm doing

Renaming the events going forward, to `converted_to_paid_subscription` and
`trial_converted_to_paid_subscription`.

That separates them permanently and without any filtering: the old names hold only the
retroactive history, the new names only real conversions from here on. We build funnels on the
new names, and the old ones stay available as historical record without ever distorting a live
number.

## PS, something to know

Some of these conversion events are associated with a user who only has an ID and no email
address. These are the owners of the organizations, and PostHog only learns someone's email when
they log in — so it just means that owner hasn't logged into Polymer since PostHog was
implemented in February. Sometimes the owner on record isn't even employed there anymore.

I can fill the emails in later if it turns out to matter.
