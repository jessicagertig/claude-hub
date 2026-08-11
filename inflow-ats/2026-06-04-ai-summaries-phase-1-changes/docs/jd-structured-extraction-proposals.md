# Job Description Structured Extraction — Proposals

## Context

180 sample JDs from 100 active Polymer orgs. Dataset observations:

- **147/180** have identifiable requirements/qualifications sections
- **127/180** have responsibilities sections
- **73/180** mention specific years of experience
- **50/180** mention education/degree requirements
- **151/180** use bullet-point lists (good for extraction)
- **9/180** are very short (<500 chars plain text) — may yield minimal structure
- Mix of industries: tech, marketing, healthcare, manufacturing, finance, creative, hospitality
- Multi-language: mostly English, some German, Spanish

## The Core Problem

A flat "AI fit score" is meaningless without knowing what was compared. To produce a useful score, we need to:

1. Extract *what the role actually requires* from the JD
2. Compare each requirement against the candidate's resume
3. Produce a per-requirement match/miss, not just a single number

Different requirements have different matchability:
- "5+ years Python" → objectively checkable
- "strong communication skills" → not checkable from a resume alone
- "BS in Computer Science" → checkable
- "passion for sports" → irrelevant noise for scoring

---

## Proposal A: Requirements-Only Extraction (Minimal)

Extract only the scorable requirements. Strip everything else (company boilerplate, benefits, responsibilities, EEO).

### Schema

```json
{
  "requirements": [
    {
      "text": "5+ years of customer facing experience in customer success or account management",
      "category": "experience",
      "importance": "required",
      "matchable": true
    },
    {
      "text": "Have experience defining, building, and implementing a customer success process for a SaaS company",
      "category": "domain_experience",
      "importance": "required",
      "matchable": true
    },
    {
      "text": "Strong verbal and written communication skills",
      "category": "soft_skill",
      "importance": "required",
      "matchable": false
    }
  ]
}
```

### Categories

| Category | Description | Examples |
|---|---|---|
| `technical_skill` | Specific tool, language, framework | "Proficient in React", "Experience with PostgreSQL" |
| `experience` | Years or level of experience | "5+ years", "senior-level" |
| `education` | Degree, field of study | "BS in Computer Science" |
| `certification` | Specific cert or license | "CPA preferred", "AWS certified" |
| `domain_experience` | Industry or domain knowledge | "Experience in fintech", "healthcare background" |
| `soft_skill` | Interpersonal or behavioral | "Strong communicator", "team player" |

### `matchable` field

Boolean. Can this requirement be objectively checked against a resume?

- `true`: technical skills, years of experience, education, certifications, domain experience
- `false`: soft skills, culture fit, personality traits

Non-matchable requirements get excluded from automated scoring. They can still be surfaced to humans as "things to evaluate in the interview."

### Applied Example: "Director of Customer Success" (RealResponse, job_id 46)

```json
{
  "requirements": [
    {
      "text": "5+ years of customer facing experience in customer success or account management roles",
      "category": "experience",
      "importance": "required",
      "matchable": true
    },
    {
      "text": "Experience defining, building, and implementing a customer success process for a SaaS company",
      "category": "domain_experience",
      "importance": "required",
      "matchable": true
    },
    {
      "text": "Strong technical acumen, ability to demonstrate product, understand and translate business and technical requirements",
      "category": "soft_skill",
      "importance": "required",
      "matchable": false
    },
    {
      "text": "Proven effectiveness at leading and facilitating executive meetings and workshops",
      "category": "experience",
      "importance": "required",
      "matchable": true
    },
    {
      "text": "Experience delivering and driving software implementation and adoption best practices",
      "category": "domain_experience",
      "importance": "required",
      "matchable": true
    },
    {
      "text": "Capacity to travel up to 20% of the time",
      "category": "logistics",
      "importance": "required",
      "matchable": false
    }
  ]
}
```

### Tradeoffs

- **Pro**: Simple, fast, low token cost per JD
- **Pro**: `matchable` flag lets scoring skip things it can't evaluate
- **Con**: No context about what the role actually does (responsibilities)
- **Con**: Doesn't capture role seniority/level or industry context that might inform scoring
- **Con**: Loses the signal from responsibilities (e.g., "you will manage a team of 10" implies leadership experience is needed even if not in the requirements section)

---

## Proposal B: Full Structured Decomposition

Extract everything useful into a comprehensive schema. Separate signal from noise.

### Schema

```json
{
  "role": {
    "title": "Senior Backend Engineer",
    "seniority": "senior",
    "department": "engineering",
    "employment_type": "full_time",
    "location": {
      "type": "remote",
      "region": null,
      "timezone_overlap": null
    }
  },
  "requirements": {
    "required": [
      {
        "text": "8+ years of experience in software development with strong fluency in Python",
        "category": "technical_skill",
        "skills": ["Python"],
        "years": 8
      }
    ],
    "preferred": [
      {
        "text": "Leadership or mentoring experience",
        "category": "experience",
        "skills": [],
        "years": null
      }
    ]
  },
  "responsibilities": [
    "Build core systems using Python, Postgres, and AWS",
    "Design and maintain APIs for real-time video chat and AI agent behavior",
    "Optimize performance and scalability",
    "Harden security in cloud environments"
  ],
  "implied_requirements": [
    {
      "text": "API design experience",
      "source": "responsibility: Design and maintain APIs",
      "category": "technical_skill"
    },
    {
      "text": "Cloud security experience",
      "source": "responsibility: Harden security in cloud environments",
      "category": "technical_skill"
    }
  ],
  "industry": "AI / SaaS",
  "company_stage": "startup"
}
```

### The `implied_requirements` Concept

Many JDs bury critical requirements in the responsibilities section rather than stating them as requirements. Example from Rep.ai Senior Backend Engineer:

- **Responsibility says**: "Harden security, especially in cloud environments"
- **Requirements section says**: nothing about security
- **Implied requirement**: Cloud security experience

A candidate with zero security background will fail at this responsibility. The implied requirement should factor into scoring.

### Applied Example: "Elixir Developer" (Select, job_id 13033)

This JD is interesting because it has explicit "Base Requirements" and "bonus" items:

```json
{
  "role": {
    "title": "Elixir Developer",
    "seniority": "mid",
    "department": "engineering",
    "employment_type": "full_time",
    "location": {
      "type": "remote",
      "region": null
    }
  },
  "requirements": {
    "required": [
      {
        "text": "Knowledge of Elixir and OTP at the level that allows you to write working, high-quality code",
        "category": "technical_skill",
        "skills": ["Elixir", "OTP"],
        "years": null
      },
      {
        "text": "Able to fine-tune Postgres queries with Ecto or SQL",
        "category": "technical_skill",
        "skills": ["PostgreSQL", "Ecto", "SQL"],
        "years": null
      },
      {
        "text": "Ability to write clear and maintainable tests",
        "category": "technical_skill",
        "skills": ["testing"],
        "years": null
      },
      {
        "text": "Good understanding of common architectural patterns and design principles",
        "category": "technical_skill",
        "skills": ["software architecture"],
        "years": null
      },
      {
        "text": "Solid understanding of modern web applications and API design",
        "category": "technical_skill",
        "skills": ["web development", "API design"],
        "years": null
      }
    ],
    "preferred": [
      {
        "text": "Experience with mentoring or pair programming",
        "category": "experience",
        "skills": ["mentoring", "pair programming"],
        "years": null
      },
      {
        "text": "DevOps understanding and ability to set up CI pipeline and deployment",
        "category": "technical_skill",
        "skills": ["DevOps", "CI/CD"],
        "years": null
      }
    ]
  },
  "responsibilities": [],
  "implied_requirements": [],
  "industry": "consumer brand marketing / CPG",
  "company_stage": "established"
}
```

### Tradeoffs

- **Pro**: Rich context for scoring — seniority, industry, implied requirements
- **Pro**: `skills` array enables direct matching against resume skill lists
- **Pro**: Required vs preferred separation lets scoring weight appropriately
- **Con**: More expensive — larger prompt, more tokens per JD
- **Con**: `implied_requirements` is the hardest part to get right and most prone to hallucination
- **Con**: Some fields (company_stage, industry) may not matter for scoring

---

## Proposal C: Scoring-Optimized Extraction

Designed specifically to produce a scoring rubric. Each requirement includes a `matching_strategy` that tells the scoring system HOW to compare it against a resume.

### Schema

```json
{
  "scorable_criteria": [
    {
      "criterion": "Python proficiency",
      "original_text": "8+ years of experience in software development with strong fluency in Python",
      "weight": "required",
      "matching_strategy": "skill_and_years",
      "skill_keywords": ["Python", "python3", "CPython"],
      "min_years": 8,
      "scoring_notes": "Look for Python in work experience descriptions, not just a skills list. 8+ years means multiple roles using Python."
    },
    {
      "criterion": "PostgreSQL and SQL knowledge",
      "original_text": "Deep knowledge of Postgres and SQL",
      "weight": "required",
      "matching_strategy": "skill_presence",
      "skill_keywords": ["PostgreSQL", "Postgres", "SQL", "database"],
      "min_years": null,
      "scoring_notes": "Any mention of Postgres or SQL in work experience. 'Deep knowledge' is subjective — treat as present/absent."
    },
    {
      "criterion": "AWS production experience",
      "original_text": "Production experience with AWS services",
      "weight": "required",
      "matching_strategy": "skill_with_context",
      "skill_keywords": ["AWS", "Amazon Web Services", "EC2", "S3", "Lambda", "ECS", "EKS"],
      "min_years": null,
      "scoring_notes": "Must appear in a work context, not just a skills list. 'Production experience' means deployed and operated, not just experimented."
    },
    {
      "criterion": "Computer Science degree",
      "original_text": "Bachelor's degree in Computer Science or related field",
      "weight": "preferred",
      "matching_strategy": "education_match",
      "skill_keywords": ["Computer Science", "Software Engineering", "Information Technology", "Mathematics"],
      "min_years": null,
      "scoring_notes": "Check education section. 'Related field' broadens acceptable matches significantly."
    }
  ],
  "non_scorable_criteria": [
    {
      "criterion": "Problem-solving and communication skills",
      "original_text": "Excellent problem-solving and communication skills",
      "reason_non_scorable": "Cannot be determined from resume text alone"
    }
  ],
  "role_context": {
    "seniority": "senior",
    "industry": "AI / SaaS",
    "remote": true
  }
}
```

### Matching Strategies

| Strategy | How scoring system uses it |
|---|---|
| `skill_presence` | Binary: does any keyword appear in the resume? |
| `skill_and_years` | Find the skill, then check if total relevant experience >= min_years |
| `skill_with_context` | Find the skill in a work experience entry (not just a bare skills list) |
| `education_match` | Check education section for degree level + field match |
| `certification_match` | Check for exact certification name |
| `industry_experience` | Check if any past employer/role is in the relevant industry |
| `years_total` | Check total years of professional experience |

### Applied Example: "Full Stack Engineer" (Levellr, job_id 30664)

```json
{
  "scorable_criteria": [
    {
      "criterion": "5+ years professional software development",
      "original_text": "5+ years of professional software development experience, including both frontend and backend work",
      "weight": "required",
      "matching_strategy": "years_total",
      "skill_keywords": ["software", "developer", "engineer"],
      "min_years": 5
    },
    {
      "criterion": "TypeScript or JavaScript proficiency",
      "original_text": "Strong knowledge of TypeScript and/or JavaScript",
      "weight": "required",
      "matching_strategy": "skill_presence",
      "skill_keywords": ["TypeScript", "JavaScript", "JS", "TS"]
    },
    {
      "criterion": "Frontend framework experience",
      "original_text": "Ship beautiful web apps with frontend frameworks like Svelte, React or Vue",
      "weight": "required",
      "matching_strategy": "skill_presence",
      "skill_keywords": ["Svelte", "React", "Vue", "Next.js", "Nuxt"]
    },
    {
      "criterion": "SQL / relational database experience",
      "original_text": "Not afraid of SQL and getting your hands dirty with relational databases like PostgreSQL",
      "weight": "required",
      "matching_strategy": "skill_presence",
      "skill_keywords": ["SQL", "PostgreSQL", "MySQL", "database", "relational"]
    },
    {
      "criterion": "Git version control",
      "original_text": "Know your way around GitHub and you're comfortable with Git",
      "weight": "required",
      "matching_strategy": "skill_presence",
      "skill_keywords": ["Git", "GitHub", "GitLab", "version control"]
    },
    {
      "criterion": "Startup or growth-stage experience",
      "original_text": "Previous startup/growth-stage experience",
      "weight": "preferred",
      "matching_strategy": "industry_experience",
      "skill_keywords": ["startup", "early-stage", "seed", "Series A"]
    },
    {
      "criterion": "Remote work experience",
      "original_text": "Previous remote-work experience",
      "weight": "preferred",
      "matching_strategy": "skill_with_context",
      "skill_keywords": ["remote", "distributed"]
    }
  ],
  "non_scorable_criteria": [
    {
      "criterion": "Self-motivated and proactive",
      "original_text": "You are self-motivated and proactive with an independent working style",
      "reason_non_scorable": "Personality trait, not verifiable from resume"
    },
    {
      "criterion": "English communication skills",
      "original_text": "Excellent written and verbal communication skills in English",
      "reason_non_scorable": "Resume language provides some signal, but not definitive"
    }
  ],
  "role_context": {
    "seniority": "mid_to_senior",
    "industry": "gaming / community / SaaS",
    "remote": true,
    "timezone": "European"
  }
}
```

### Tradeoffs

- **Pro**: Directly usable by a scoring algorithm — no interpretation step needed
- **Pro**: `matching_strategy` makes scoring deterministic and explainable
- **Pro**: `skill_keywords` include synonyms/aliases — handles resume vocabulary variation
- **Pro**: `non_scorable_criteria` explicitly acknowledges what can't be scored, preventing false confidence
- **Con**: Most expensive to generate — requires deep understanding of each requirement
- **Con**: `scoring_notes` and keyword lists are where hallucination risk is highest
- **Con**: Maintaining the matching_strategy taxonomy adds complexity

---

## Comparison Matrix

| Aspect | A: Requirements-Only | B: Full Decomposition | C: Scoring-Optimized |
|---|---|---|---|
| Token cost per JD | Low (~300 output) | Medium (~600 output) | High (~800 output) |
| Scoring utility | Medium | High | Very High |
| Handles poor JDs | Poorly (no responsibilities to infer from) | Well (implied_requirements) | Medium |
| Hallucination risk | Low | Medium (implied_requirements) | Medium (keyword lists, scoring_notes) |
| Explainability | Low (just a list) | Medium | High (per-criterion match/miss) |
| Implementation complexity | Low | Medium | High |
| Handles non-tech roles | Yes | Yes | Yes |
| Handles multi-language JDs | Yes (AI translates) | Yes | Yes |

---

## Edge Cases from This Dataset

### 1. Bare-minimum JDs

Example: "U of T Co-op" (Unemit, job_id 33296) — "Please first apply via the U of T Co-op Portal, and then complete your application here."

No requirements extractable. All proposals return empty/minimal. The system needs a fallback: score based on title match and any resume keywords that relate to the company.

### 2. Non-English JDs

Example: "Sales Manager (m/w/d)" (Franklin Institute, job_id 28340) — entirely in German.

The extraction prompt needs to handle multi-language input and produce English-language structured output. All three proposals handle this since the LLM translates during extraction.

### 3. "General Applicant" / catch-all postings

Examples: "Open Role" (Colleva), "General Applicant" (Sesame Sustainability), "Freelancers/Short-Term Contractors" (8020)

These have no specific requirements. Extraction should flag them as `general_applicant: true` so scoring can handle them differently (e.g., skip automated scoring entirely).

### 4. Non-standard requirement locations

Example: "Housekeeper" (Renjoy, job_id 30828) — requirements are embedded in prose paragraphs, not bulleted lists. "Are physically up for the work", "Have your own reliable vehicle", "comfortable using a smartphone app."

The LLM needs to extract from prose, not just parse bullet lists. All proposals handle this since extraction is LLM-based, not regex-based.

### 5. JDs with "DO NOT APPLY" / test data

Example: "Product Designer" and "Full-Stack Software Engineer" from Tablespace Games — "THIS IS NOT A REAL JOB."

These exist in real data. The extraction layer doesn't need to filter them — that's a data quality concern upstream.

---

## Recommendation

**Start with Proposal A (Requirements-Only), with the `matchable` flag.**

Reasons:

1. **Cheapest to iterate on.** This is infant-stage — you need to test whether extracted requirements actually produce better scores before investing in richer schemas.
2. **Fastest to implement.** One prompt, one pass, simple output.
3. **The `matchable` flag is the key insight.** It lets you build scoring that's honest about what it can and can't evaluate. A score of "3/5 matchable requirements met" is more useful than "67% fit" with no explanation.
4. **You can upgrade incrementally.** Once A is working, add `skills` arrays (from B) or `matching_strategy` (from C) to the schema without redesigning.

**If you want richer scoring from day one**, go with a hybrid: Proposal A's simplicity + Proposal C's `matching_strategy` field. Skip everything else from C (scoring_notes, keyword lists) — let the scoring LLM handle synonyms at match time rather than pre-computing them at extraction time.

### Hybrid A+C Schema

```json
{
  "requirements": [
    {
      "text": "5+ years of professional software development experience",
      "category": "experience",
      "importance": "required",
      "matchable": true,
      "matching_strategy": "years_total",
      "min_years": 5
    },
    {
      "text": "Strong knowledge of TypeScript and/or JavaScript",
      "category": "technical_skill",
      "importance": "required",
      "matchable": true,
      "matching_strategy": "skill_presence"
    },
    {
      "text": "Self-motivated and proactive",
      "category": "soft_skill",
      "importance": "required",
      "matchable": false,
      "matching_strategy": null
    }
  ]
}
```

This gives you per-requirement scoring with clear match strategies, without the overhead of keyword lists or scoring notes.
