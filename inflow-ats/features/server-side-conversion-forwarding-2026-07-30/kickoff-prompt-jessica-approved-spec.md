Hello use applicable superpowers and skills as you see fit the spec is already in this folder

the local inflow-ats repo is already checked out to branch you should write to server-side-conversion-events

The spec was written by Jessica and another agent collaboratively.  everything in the spec should be respected and followed as stated.  the spec is organised by subsystem, and every section holds decisions Jessica has already reviewed and closed - treat all of it as binding, not only the section that says so.  "Don't fuck with this" lists the specific things agents are predicted to change while believing they are helping.  read the whole spec before doing anything. please first run your own set of reviews on the spec. you should do this with the updated documented and in memory review understanding that as soon as reviews are not getting tangibly different items for the implementation then we should stop and continue.  We dont want to pointlessly burn tokens for nonsense review.

if a review agent finds something it considers blocking - which it really shouldn't - it may raise it in spec-blockers.md.  anything else it thinks should be added to the spec goes in spec-additions.md, never into the spec itself.  spec-blockers.md holds five items at most.  orchestration agents read spec-blockers.md and decide whether each item is valid, writing that judgment into the file - never deleting an item.  jessica reads the file at the end and decides for herself.  this is an autonomous run and she is not available to read it during the run.

then write a plan - you should follow the same logic and review this but not to the point of pointless ticky tacky reviewer issues or ones that don't make tangible difference in implementation.  a solid spec (which we should have once you're done) shouldn't need much crazy plan work imo.

then implement to the local branch making sure to follow all git rules and leave the code unstaged for me when completed

once implemented you should run the same iterative reviews and this time run final blast radius, hygiene, etc checks, this is the final gate and code must be perfect.  but we also don't need to spend 1mm tokens to note a coma was missing from a comment.  Again here running another million token review to catch a nonissue isn't valuable.

follow all claude.md rules especially defined rules regarding comments, lint, analogs, and investigation

always follow the Critical Rules (AI Keeps Getting These Wrong) section in claude.md, and follow /Users/jessica/.claude/projects/-Users-jessica-claude-hub/memory/feedback_investigation_floors.md

rule 0a in that section is absolute - do not write rspec specs, not because the spec asked for one and not because a review flagged missing coverage.  if you think something needs coverage, put it in the final report

please QA if you have any questions.
