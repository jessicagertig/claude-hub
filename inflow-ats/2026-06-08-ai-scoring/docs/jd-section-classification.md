# JD Section Classification — Which Sections Produce Scoring Criteria

Every JD gets extracted into structured sections. Only some sections feed into scoring criteria. This doc classifies every section heading found in the dataset.

---

## CRITERIA SOURCE — these sections produce scoring criteria

Sections where the content describes what the candidate needs to have, know, or be.

```
 32  qualification
 14  requirement
  9  about you
  8  what we are looking for
  6  who you are
  5  required qualification
  5  what we're looking for
  3  desired qualification
  3  who are you?
  3  skill
  3  required skills and qualification
  2  candidate requirement
  2  preferred skills and qualification
  2  preferred qualification
  2  what makes you a great fit?
  2  enough about us, let's talk about you
  2  you'd be a good fit if
  2  must have quality
  2  education
  2  knowledge
  2  work experience
  2  experience
  2  license/certification
  2  required skill
  2  what we look for
  2  need-to-have's
  2  🛠qualification
  2  🗝️ what we are looking for
  2  ⚡️what we are looking for
  1  key qualification and skill
  1  requirement for this role
  1  requirement for the position
  1  what are we looking for?
  1  preferred background
  1  we are looking for content writers who
  1  you might be a good fit if you have
  1  must have
  1  must haves
  1  person specification
  1  qualification / work experience
  1  basic expectation
  1  additional expectation
  1  latch might be a good fit for you if
  1  ideal candidate
  1  preferred candidate
  1  what a great fit looks like
  1  you will excel if
  1  who you are and your qualification
  1  your profile
  1  meritorious experience
  1  minimum qualification
  1  ideal quality
  1  a bit about you
  1  does this sound like you? if so, you will thrive at opensend
  1  knowledge, skills & abilities focus
  1  what kind of person succeeds in this role?
  1  experience level
  1  anforderungen
  1  理想候选人
  1  kvalifikasjoner
  1  requerimientos
  1  🌸 our dream character artist 🌸
  1  🌸 our dream environment artist 🌸
```

## CRITERIA SOURCE (PREFERRED TIER) — these sections produce preferred-tier criteria only

Everything extracted from these sections gets tier = `preferred`.

```
  6  nice to have
  2  bonus point
  2  nice-to-have's
  2  🎈bonus point if
  1  nice to haves
  1  nice-to-have
  1  nice-to-haves
  1  bonus / nice-to-have
  1  bonus qualification
  1  plusses
  1  preferred
  1  preferred experience
  1  we appreciate, but do not require
  1  good to have
```

## EXCLUDED — these sections do NOT produce scoring criteria

### Company / about

```
 19  about us
  6  who we are
  4  overview
  3  about the team
  3  company
  2  company overview
  2  about airboxr
  2  about deepfleet
  2  about opensend
  2  about berachain
  2  who are we?
  1  about us & our mission
  1  about our company
  1  about orion brands
  1  about remedial health
  1  about recess pickleball
  1  about unemit
  1  about themis
  1  about pelicargo
  1  about solidec
  1  about sesame sustainability
  1  about circularity fuels
  1  about cemvision
  1  about superform
  1  about neuroscale
  1  about &facts
  1  about osmoses 🌱🌍
  1  about ownhome 🏠
  1  🌸 about studio drydock 🌸
  1  ✨ about neuroscale.ai (arbiai team)
  1  om arbeidsgiveren
  1  公司简介
  1  职位介绍
```

### Benefits / compensation / perks

```
 10  benefit
  8  what we offer
  5  salary
  5  compensation
  3  compensation & benefit
  3  opportunity
  2  compensation and benefit
  2  salary & benefit
  2  perk and benefit
  2  perk
  2  heyo offers a variety of benefit, including
  2  💸 competitive compensation
  2  💻 best tool
  2  ⚕️benefit
  2  condition
  1  compensation + benefit
  1  compensation & perk
  1  schedule and compensation
  1  remuneration
  1  in return for your hard work, we will give you
  1  we will give you
  1  what you will get from ownhome
  1  what you will get
  1  what we can offer you?
  1  ❤️ wellbeing credit
  1  🥗 lunch on us
  1  💎 what you will gain
  1  ❤️ benefit for intern
  1  🌸 salary 🌸
```

### Application process / EEO / meta

```
  6  how to apply
  2  our hiring process
  2  hiring process
  2  equal employment opportunity
  2  everyone is welcome
  2  any question?
  2  faq
  2  learn more
  2  additional detail
  1  application and process
  1  application assessment
  1  diversity, equity, and inclusion
  1  our commitment 🌈
  1  the interview process
  1  interested?
  1  🌸 how to apply: 🌸
  1  🚀 ready to join?
  1  don't see a direct fit?
```

### Culture / values / why join

```
  2  culture
  2  team value
  2  our promise to you
  2  why join mutual
  2  why join empiredrop?
  1  why work with us?
  1  why runloop?
  1  why latch?
  1  why join?
  1  why join us
  1  why join us?
  1  why renjoy
  1  why cemvision?
  1  why you should join
  1  our operating principle
  1  our culture
  1  our commitment to you
  1  company culture
  1  company values and culture
  1  spaeth hill core values
  1  key personal value
  1  3 obsession
  1  mission statement: purpose
```

## NEEDS DECISION — responsibilities

```
 29  responsibility
 17  key responsibility
 15  the role
 14  about the role
  6  what you will do
  5  job responsibility
  4  your responsibility
  3  what you will be doing
  2  duty & responsibility
  2  essential job duty and responsibility
  2  description of duty and task
  2  responsibility include
  2  what will your typical day look like?
  2  role overview
  2  role
  2  📓responsibility
  2  🌸 what you will be doing 🌸
  1  your main responsibility
  1  what you will contribute
  1  core responsibility
  1  your main task
  1  your primary task
  1  what the job entails
  1  responsibility?
  1  what will your day to day look like?
  1  responsabilidades
  1  ansvarsområder
  1  岗位职责
  1  aufgaben
  1  🌐 what you will do
```

Responsibilities contain implied requirements but are not stated as criteria. Options:

1. **Exclude** — only stated requirements become criteria. Simpler, less hallucination risk.
2. **Include as secondary source** — extract implied requirements from responsibilities, mark them with a flag so scoring knows they're inferred.
3. **Include in structured output but don't generate criteria** — responsibilities get extracted for display/context but don't feed the scoring pipeline.

## NEEDS DECISION — physical / logistics requirements

```
  2  physical requirement
  2  pre-employment requirement
  2  location
  1  schedule
  1  🌸 this is a full time, fixed-contract and permanently-remote-working position 🌸
```

These are real requirements (reliable vehicle, ability to lift 50lbs, Sunday availability) but unmatchable from a resume. Options:

1. **Extract but exclude from scoring** — present to human reviewer only.
2. **Extract and score where possible** — location/remote might be matchable if resume has address.

## NEEDS DECISION — ambiguous headings

Some headings sit between requirements and responsibilities, or between requirements and company description:

```
  2  position overview — sometimes requirements, sometimes company context
  2  what would you be doing? — responsibilities phrased as question
  2  role overview — could be either
  2  sounds amazing! what now!? — application process disguised
  1  a bit about the role — could be either
  1  a bit about the work — could be either
  1  the gaia fit — requirements phrased as culture
  1  in the first 6 months you will — responsibilities with timeline
```

These need to be classified by content, not heading. The AI extraction should read the content and route to the right bucket regardless of what the heading says.
