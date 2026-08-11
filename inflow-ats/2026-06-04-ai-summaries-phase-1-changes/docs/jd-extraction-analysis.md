# JD Extraction Analysis — What's Actually in These Descriptions

180 JDs from 100 active Polymer orgs. This is what the data actually shows.

---

## Finding 1: Only 22% of JDs explicitly separate required vs preferred

- **39/180** (22%) have explicit tiers — separate sections for "Requirements" and "Nice to have" / "Bonus" / "Preferred"
- **113/180** (63%) have section headers + bullets but no tier distinction
- **19/180** (11%) are prose-only, no bullet structure at all
- **6/180** (3%) are too short to extract anything meaningful

**Implication**: The three-tier model (`required` / `standard` / `preferred`) will need AI inference for 78% of JDs. Only 22% give us both poles explicitly.

---

## Finding 2: The requirement language is all over the map

Explicit requirement signals vary wildly in frequency:

| Signal | Count | Usage |
|---|---|---|
| "experience with/in/using" | 107/180 | Most common, but appears in responsibilities too |
| "ability to" | 82/180 | Vague — "ability to lift 50lbs" vs "ability to communicate" |
| "proficient/proficiency" | 42/180 | Strong signal for specific tools |
| "required" (the word) | 40/180 | Explicit, but only 22% of JDs |
| "proven X" | 25/180 | Usually "proven track record" — vague |
| "must have" | 13/180 | Strongest signal, least common |

Preference signals are even rarer:

| Signal | Count |
|---|---|
| "bonus" | 39/180 |
| "preferred" | 31/180 |
| "a plus" | 21/180 |
| "ideally" | 11/180 |
| "nice to have" | 8/180 |

**Implication**: Can't rely on keyword matching to identify tier. The AI needs to understand section context + sentence meaning.

---

## Finding 3: 35% of bullet points don't fit clean categories

2,683 total bullets across 180 JDs (avg 14.9 per JD). Breakdown:

| Category | % | Example |
|---|---|---|
| Uncategorizable | 34.6% | "High humility - we're open-minded and self-aware" |
| Responsibility | 22.0% | "Develop and maintain APIs" |
| Technical skill | 12.8% | "Proficient in React" |
| Soft skill | 11.2% | "Strong communication skills" |
| Education | 10.8% | "Bachelor's degree preferred" |
| Benefit | 4.4% | "401k matching" |
| Years experience | 2.4% | "5+ years" |
| Logistics | 1.2% | "Remote-friendly, EST overlap" |
| Certification | 0.4% | "CPA preferred" |

That 34.6% "uncategorizable" bucket includes things like:
- Norwegian-language requirements: "Relevant høyere utdanning innen markedsføring"
- Chinese-language requirements: "优秀的沟通能力，具备团队合作精神"
- Joke requirements: "You've seen a mountain goat"
- Compound domain-specific: "Deep understanding of funnel math, attribution, and experimentation frameworks"
- Portfolio/demo: "Must provide an online demo reel"

**Implication**: A rigid taxonomy won't capture everything. The extraction schema needs a way to handle requirements that don't fit standard categories.

---

## Finding 4: Different role types have fundamentally different requirement profiles

| Requirement type | Software (62) | Design (24) | Sales (22) | Operations (17) | Science (6) |
|---|---|---|---|---|---|
| Named tools/tech | 82% | 62% | 73% | 53% | 83% |
| Years experience | 40% | 54% | 55% | 47% | 33% |
| Degree required | 47% | 21% | 23% | 29% | 50% |
| Portfolio/samples | 19% | 38% | 5% | 0% | 0% |
| Certification | 3% | 4% | 5% | 6% | 33% |
| Industry/domain | 8% | 4% | 9% | 6% | 17% |

Key differences:
- **Design roles** care more about portfolios than degrees
- **Science/medical** roles care about certifications 10x more than other categories
- **Software eng** names specific tools most often but rarely needs certifications
- **Sales/marketing** names tools (CRMs) nearly as often as software eng (73% vs 82%)

**Implication**: A single scoring rubric won't work across role types. The weight of "has the right tools" vs "has a degree" vs "has a portfolio" depends on the role category.

---

## Finding 5: The combo requirement problem

16% of requirements pack multiple distinct criteria into one sentence. These need decomposition before scoring.

**"5+ years of professional software development experience, including both frontend and backend work"**
→ Three separate things:
1. 5+ years of professional software development
2. Frontend development experience
3. Backend development experience

**"8+ years of fundraising experience, ideally in the social sector"**
→ Two things, different tiers:
1. 8+ years of fundraising experience (`required`)
2. Social sector experience (`preferred` — signaled by "ideally")

**"3+ years experience in an agency, production house, or other content production environment"**
→ Two things:
1. 3+ years of content production experience
2. Agency/production house context specifically

A candidate could have 10 years of video production experience but NOT in an agency. Without decomposition, that's a binary match/miss on the whole sentence. With decomposition, it's 1/2 — much more useful.

**Implication**: The extraction step should decompose combo requirements into atomic criteria. Each atomic criterion gets its own tier and matchability assessment.

---

## Finding 6: Signal-to-noise ratio varies from 16% to 78%

Five JDs analyzed for what percentage of content is actually scorable requirements:

| JD | Requirements | Total items | Signal % |
|---|---|---|---|
| Elixir Developer (Select) | 7 | 9 | 78% |
| Sales Director (Amide) | 9 | 18 | 50% |
| Housekeeper (Renjoy) | 10 | 19 | 53% |
| Video Production (Walrus) | 21 | 44 | 48% |
| Full Stack Eng (Levellr) | 4 | 25 | 16% |

Levellr scores lowest because it uses "Who are you?" as its requirements header (non-standard) and embeds requirements in conversational prose: "You ship beautiful web apps with frontend frameworks like Svelte, React or Vue."

**Implication**: Extraction can't rely on section headers. It needs to identify requirements from sentence content regardless of surrounding structure.

---

## Finding 7: Only 38% of extracted requirements are cleanly matchable

From a hand-categorized sample across 8 diverse JDs:

| Matchability | % | Types |
|---|---|---|
| **Matchable** (can check against resume) | 38% | Specific tools, degree, certification, portfolio, named platforms |
| **Partial** (needs decomposition or fuzzy matching) | 38% | Combo requirements, industry/domain, vague experience claims |
| **Unmatchable** (need interview, not resume) | 25% | Personality traits, physical requirements, work style |

The 38% that are cleanly matchable are almost entirely **specific tools/technologies** and **education requirements**. Everything else requires either decomposition (combos), semantic matching (industry experience), or should be excluded from automated scoring (personality).

**Implication**: Automated scoring will have strong opinions on about 38% of requirements and weaker opinions on another 38%. The remaining 25% should be surfaced to the human reviewer, not scored.

---

## Finding 8: Section header language has 30+ variations

The top headers that signal "here are our requirements":

```
31x  qualifications
17x  requirements
10x  about you
 8x  required
 7x  what we're looking for
 6x  required qualifications
 6x  who you are
 5x  what we're looking for
 3x  job requirements
 3x  desired qualifications
 3x  required skills and qualifications
 3x  what we look for
 3x  skills
```

And responsibility headers:
```
29x  responsibilities
17x  key responsibilities
 6x  what you'll do
 5x  what you'll do
 5x  job responsibilities
 4x  what you'll be doing
 3x  your responsibilities
```

Some JDs use unique/creative headers: "Who are you?", "About You", "Our dream Character Artist", "You might be a good fit if you have:". These are functionally requirement sections but don't match standard patterns.

**Implication**: Section detection needs LLM understanding, not regex.

---

## What This Means for the Extraction Schema

1. **Decompose combo requirements into atomic criteria.** This is the single highest-value transformation — it turns binary match/miss into granular scoring.

2. **Don't try to match years.** You said the LLM sucks at it. The data confirms years appear in only 40% of JDs anyway and usually as part of a combo requirement. Extract the number for display but don't score on it.

3. **Tag matchability honestly.** 38% matchable, 38% partial, 25% unmatchable. Don't pretend the score covers what it doesn't.

4. **The three-tier system works, but 78% of JDs need inference.** The AI has to assign tiers based on context, not just section headers.

5. **Role category matters for scoring weights.** A "Portfolio required" criterion should weigh heavily for design roles and be ignored for engineering roles. The extraction should include role category so scoring can adjust.

6. **Non-English JDs work fine.** The LLM translates during extraction. No special handling needed.

7. **Minimal JDs (6/180) should skip scoring entirely.** "Please apply via the co-op portal" produces nothing scorable. Flag and skip.
