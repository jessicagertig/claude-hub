# Nick's Current Process — from Slack 2026-06-02

Key quotes from Nick describing his actual current workflow:

> I have my agents write specs and iteratively adversarial review specs with workflow agents, and then write a plan and review it TWICE (fixed count), then implement and run full iterative adversarial reviews until consecutive convergence runs of no issues on the implementation before commit.

> I don't read the spec ever. I require them to always present me a plain english rendition of what their doing with a blast radius analysis

> blast radius to understand how every consumer or supplier touches something im changing will effect things along with the methods they are using and adversarial review lane specifically at "reinventing the wheel or not using codebase exiting patterns"

> afterwards i go through and have other agents pick it apart for issues then immediately have those agents write FAILURE reports then get my action agents to update all claude.md files to make sure the actions are not repeated

> its as easy as at the end of an implementation now I just say "validate all claude.md instructions are thoroughly followed"

> I've found reviewing plans turns into agents nit picking the shit out of eachother over dumb shit that doesn't matter. 2 passes is always enough to catch big errors

> I generally try to just go to the correct directory for the applicable claude.md trees to load... so like cd /convox/v2/patches && claude... that dude will know how to write v2 patches for convox

> makefile is mostly retired except for QA runs because the prompts help to setup a lot of our release context

> ultracode workflows > superpowers, but my claude.md all instruct to use superpower and applicable skills

> I've found plans to be less helpful than spec
