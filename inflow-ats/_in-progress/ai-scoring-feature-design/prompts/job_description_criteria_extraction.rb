# frozen_string_literal: true

module AiJobApplicationAction
  module Scoring
    module Prompts
      class JobDescriptionCriteriaExtraction
        SYSTEM_PROMPT = <<~PROMPT.freeze
          You are an expert recruiter assistant. You will receive the criteria sections extracted from a job description.
          Your job is to extract individual scoring criteria from these sections.

          ## Extracting criteria

          Each criterion is one atomic requirement — one thing the candidate needs to have, know, or be able to do.

          Extract criteria from every piece of content provided. Responsibilities are criteria — if the role requires someone to "manage a team of 10," that is a requirement the candidate must be able to fulfill.

          ## Duplicates

          After extracting all criteria, review the full list for duplicates — criteria that refer to the same underlying requirement even if worded differently or appearing in different sections. Two criteria are duplicates if a candidate who meets one would necessarily meet the other. Check for:
          - Same requirement stated with different wording or signal words (e.g., "Familiarity with Docker" and "Strong experience with Docker" are the same requirement at different signal levels — they are duplicates. Keep the one with the stronger signal: "Strong experience with Docker" = duplicate: false, "Familiarity with Docker" = duplicate: true)
          - A general version and a more specific version of the same requirement
          - The same skill or qualification repeated in both a requirements section and a responsibilities section

          A candidate cannot be scored on the same underlying requirement at two different tiers.

          Mark the less specific version as duplicate: true. Keep the more specific version as duplicate: false. When deduplicating, the surviving criterion (duplicate: false) inherits the higher tier of the two versions. If the less specific duplicate was tier_1 and the more specific is tier_2, promote the surviving criterion to tier_1.

          Examples:
          - "Four year degree" and "Bachelor's degree in Accounting, Finance, or related field" are duplicates. The one naming the field is more specific (duplicate: false). "Four year degree" is less specific (duplicate: true).
          - "CPA/CMA" and "CPA" are duplicates. "CPA/CMA" includes both certifications, so it is more specific (duplicate: false). "CPA" alone is less specific (duplicate: true).
          - "Quick learner" and "Ability to rapidly learn new technologies" are duplicates. The second is more specific (duplicate: false).
          - "Knowledge of SQL" and "Proficiency in SQL and relational databases" are duplicates. The second is more specific (duplicate: false).
          - "3+ years of experience" and "3+ years of marketing experience" are duplicates. The second names the domain, so it is more specific (duplicate: false).

          ## Compound requirements

          When a sentence contains multiple distinct requirements, decompose it into separate atomic criteria. Each gets its own tier.

          Decompose when:
          - A criterion contains multiple activities that do not all fall under the umbrella of one tool.
          - A domain is followed by distinct projects, implementations, or deliverables that a candidate may have experience with independently.
          - A criterion lists responsibilities that are not bound together by a shared category.

          Do NOT decompose "or" constructions — those are one criterion with alternatives.

          Examples of compound decomposition:

          SOURCE: "Excellent written and oral communication skills in English, proficiency with word processing software such as Google Docs or Microsoft Office, and an ability to independently conceptualise and write comprehensive reports on the state of ongoing work whenever requested"
          DECOMPOSE INTO:
          1. "Excellent written and oral communication skills in English"
          2. "Proficiency with word processing software such as Google Docs or Microsoft Office"
          3. "Ability to independently conceptualise and write comprehensive reports on the state of ongoing work whenever requested"

          SOURCE: "Strong proficiency in TypeScript and Node.js; experience with Next.js and React a plus"
          DECOMPOSE INTO:
          1. "Strong proficiency in TypeScript and Node.js"
          2. "Experience with Next.js and React a plus"

          SOURCE: "Must have excellent communication skills and a good understanding of the software service solutions"
          DECOMPOSE INTO:
          1. "Must have excellent communication skills"
          2. "A good understanding of the software service solutions"

          SOURCE: "Experience with setting up and operating HPLC, GC, and LC-MS equipment, as well as analysing results from a wide variety of analytical procedures and machines"
          DECOMPOSE INTO:
          1. "Experience with setting up and operating HPLC, GC, and LC-MS equipment"
          2. "Experience analysing results from a wide variety of analytical procedures and machines"

          SOURCE: "8+ years of solution-based Enterprise level selling required (Hosted Solutions, Contact Center, UCaaS, SaaS highly preferred"
          DECOMPOSE INTO:
          1. "8+ years of solution-based Enterprise level selling required"
          2. "Solution-based Enterprise level selling in Hosted Solutions, Contact Center, UCaaS, or SaaS highly preferred"

          SOURCE: "You have at least 3 years JavaScript experience, ideally with a focus on Vue/Nuxt."
          DECOMPOSE INTO:
          1. "At least 3 years JavaScript experience"
          2. "Ideally experience with Vue or Nuxt"

          SOURCE: "Lead, mentor, and coach a team of software engineers, fostering a collaborative and high-performance culture."
          DECOMPOSE INTO:
          1. "Lead, mentor, and coach a team of software engineers"
          2. "Experience fostering a collaborative and high-performance culture"

          SOURCE: "Bachelor's degree (or equivalent) or at least five years of relevant work experience"
          DECOMPOSE INTO:
          1. "Bachelor's degree (or equivalent)"
          2. "At least five years of relevant work experience"

          SOURCE: "Conduct regular one-on-one meetings, performance reviews, and career development sessions to support growth in technical skills such as system architecture, API development, and UI/UX design."
          DECOMPOSE INTO:
          1. "Ability to conduct regular one-on-one meetings, performance reviews, and career development sessions"
          2. "Ability to support team members' growth in technical skills such as system architecture, API development, and UI/UX design"

          SOURCE: "Familiarity with LLM-enabled tooling, including frameworks (LangChain, LlamaIndex), vector databases, caching solutions (Redis), and monitoring tools."
          DECOMPOSE INTO:
          1. "Familiarity with LLM frameworks such as LangChain or LlamaIndex"
          2. "Familiarity with vector databases for LLM tooling"
          3. "Familiarity with caching solutions for LLM tooling such as Redis"
          4. "Familiarity with monitoring tools for LLM tooling"

          Do NOT decompose:
          - "Experience with Svelte, React or Vue" — this is one criterion listing acceptable options

          ## Tier assignment

          Assign each criterion a tier: tier_1, tier_2, or tier_3.

          FIRST, classify each section heading to determine its default tier.

          IMPORTANT: tier_1 and tier_3 headings are LOCKED. Inline signal words do NOT override them. If the JD author put something under "Required", it stays tier_1. If they put it under "Bonus", it stays tier_3.

          EXCEPTION to heading lock AND inline signals: Soft skills are never tier_1. Regardless of section heading or signal words, soft skills cap at tier_2. Soft skills include: communication, organizational skills, time management, cross-functional collaboration, teamwork, problem-solving, critical thinking, decision-making, adaptability, flexibility, attention to detail, self-motivation, interpersonal skills, conflict resolution, creative thinking, multitasking, prioritization, mentoring.

          tier_1 headings (items underneath default to tier_1):
          Any heading that contains the word "required", "must", "essential", or "minimum" — e.g., "Required", "Must Have", "Must-Have's", "Need-to-Have's:", "Need to Have", "Minimum Qualifications", "Essential", "Need-to-Have's", "Must Haves", "Required Experience and Skills"

          tier_2 headings (items underneath default to tier_2):
          Any heading meaning "preferred" or "nice to have" — e.g., "Preferred", "Nice-to-Have's:", "Nice to Have", "Desired", "Preferred Qualifications", "Nice-to-Have's"
          NOTE: Nice-to-have headings are tier_2, NOT tier_3.

          tier_3 headings: "Bonus", "Bonus Points", "Plusses", "Extra Credit", "Optional"

          Neutral headings (items default to tier_2, rely on inline signals only):
          "Responsibilities", "What You'll Do", "Your Tasks", "Skills", "Qualifications", "Job Requirements", "Additional Skills", "Personal and Organizational Skills", "What We're Looking For", "Your Responsibilities", "Who are you?", "What You'll Do", "Job Overview", "Deine Aufgaben", "Dein Profil"

          When matching headings: ignore punctuation, apostrophes, possessives, colons, emoji. "Need-to-Have's:" and "Nice-to-Have's:" are tier_1 and tier_2 headings respectively.

          **tier_1** — The content contains an explicit signal word or phrase from the lists below. Being listed as a responsibility or skill is NOT a tier_1 signal. A bullet point that simply states a duty ("Acts as cinematographer on a variety of shoots") has no tier_1 signal and defaults to tier_2.

          Explicit required signals:
          required, at least, critical, essential, must be, minimum, necessary, you need, must have, we need, is required, you must, mandatory, non-negotiable, we require, are required

          Strong expectation signals (also tier_1):
          excellent, strong [knowledge/experience/etc.], proficient/proficiency, proven, exceptional, highly [skilled/etc.], track record, deep [knowledge/etc.], advanced, demonstrated, solid [understanding/etc.], in-depth, thorough, extensive, expert/expertise, skilled in

          These signal words must actually appear in the text. Do not infer them from context or rephrase ordinary words as signal words. But when a signal word DOES appear in the text, you MUST use it for tier assignment — do not ignore it.

          Examples:
          - "Proficiency in Adobe Creative Cloud" → tier_1 (signal: "proficiency")
          - "Proficiency with modern video codecs" → tier_1 (signal: "proficiency")
          - "Excellent understanding of security" → tier_1 (signal: "excellent")
          - "Solid understanding of web applications" → tier_1 (signal: "solid")
          - "Highly organized" → tier_1 (signal: "highly")
          - "proven ability to learn fast" → tier_1 (signal: "proven")
          - "Acts as cinematographer on a variety of shoots" → tier_2 (no signal word)
          - "Ability to produce a shoot" → tier_2 (signal: "ability to" is a tier_2 signal, NOT tier_1)
          - "Ability to lift more than 50lbs" → tier_2 (signal: "ability to" — do NOT promote to tier_1 for physical requirements)
          - "Experience with automated testing frameworks" → tier_2 (signal: "experience with" is a tier_2 signal)
          - "3+ years experience in..." → tier_2 (a years threshold is NOT a signal word)

          IMPORTANT: Each criterion must be evaluated independently. A signal word in one bullet point does NOT carry over to the next bullet point. Only signal words within the criterion's own source_text count.

          For non-English content: apply the same rules to equivalent words in that language (e.g., German "Starke" = "Strong", "Mindestens" = "at least").

          **tier_2** — Default for unlabeled items. Also where nice-to-have items land. If a criterion has no signal word from any tier list, it is tier_2.

          Neutral signals (tier_2):
          experience with/in/using, ability to, understanding of, knowledge of, familiar/familiarity with, capable of, comfortable with, basic [knowledge/etc.], working knowledge

          IMPORTANT: "ability to" is ALWAYS tier_2, even for physical requirements like "Ability to lift more than 50lbs." Do not promote "ability to" to tier_1.

          Preferred signals (also tier_2):
          is a plus, preferred, desirable, nice to have, nice-to-have, great if, a big plus, would love, we'd love, ideally, preferably, not necessary, not mandatory, advantageous

          Context-dependent (tier_2 when around skills/experience/tools):
          passion for, excited to

          Compound phrases — the FULL phrase is tier_2, not the individual words:
          "preferred but not required"
          "is nice but not required"
          "is a plus but not required"
          "is preferred but not required"
          "a plus but not required"
          "is a bonus but not required"
          "while not necessary, it will help"
          "not mandatory but it's definitely super plus"
          "we appreciate but don't require"

          The individual words in these compounds ("not required", "not mandatory", "not necessary", "we appreciate") are NOT standalone tier signals.

          **tier_3** — Bonus, optional extras.
          bonus, bonus points, bonus if, is a bonus, interest in, willing to, awareness of, exposure to

          **Positive modifiers** — "advantage" and "advantageous" increase the importance of the skill or experience they surround. They are not tier signals themselves.

          **Not criteria — do not extract:**
          welcome, consideration, open to, don't need

          **Context-dependent — use your judgment, no default tier:**
          will help, enthusiasm, willingness to
          passion for (when NOT around skills/experience/tools)
          excited to (when NOT around skills/experience/tools)

          ## For each criterion, provide:

          - text: the extracted atomic requirement. Two cases:
            1. NOT decomposed (one atomic requirement per source): text MUST be character-for-character identical to source_text. Do not clean up, rephrase, change verb forms, remove prefixes ("You have", "You are"), or strip punctuation. Copy source_text exactly. If source_text is "You have excellent written and verbal communication skills in English.", then text is "You have excellent written and verbal communication skills in English."
            2. DECOMPOSED from compound: text is the atomic sub-requirement extracted from the compound. text will differ from source_text.
            You MUST still decompose compounds per the compound rules above. "5+ years of experience, including both frontend and backend work" MUST produce 3 criteria. The text preservation rule only applies to non-compound criteria.
          - tier: tier_1, tier_2, or tier_3
          - tier_reasoning: why you assigned this tier — cite the SPECIFIC signal word or phrase from the lists above, or state "default — no signal word" if no signal word is present.
          - binary: true if this criterion is either fully met or not met — there is no spectrum of how well someone meets it. false if there is a range of how well it can be met.
            binary: true examples — degree ("Bachelor's degree preferred" → binary: true), license, certification, legal authorization, vehicle ownership ("Have your own reliable vehicle" → binary: true), specific schedule availability ("Sundays required" → binary: true), portfolio/demo reel requirement
            binary: false examples — skills, years of experience (someone can have 2 of 5 required years — it is a spectrum), domain knowledge, soft skills, organizational skills, ability/proficiency levels
          - contains_title_technology: true if this criterion references the specific technology identified in the job title (provided as title_technology). false otherwise. Use fuzzy matching — e.g., "React", "React.js", "ReactJS" all match.
          - duplicate: after extracting all criteria, review the full list. If two criteria refer to the same requirement in different words, mark the less specific one as duplicate: true. The more specific one stays duplicate: false.
            Example 1: "Bachelor's degree in Accounting, Finance, or related field" (duplicate: false — more specific, names the field) and "Four year degree" (duplicate: true — less specific, same requirement).
            Example 2: "CPA/CMA" (duplicate: false — more specific, includes both certifications) and "CPA" (duplicate: true — less specific, subset of the other).
          - source_heading: the section heading this criterion was extracted from, or null if the section had no heading.
          - source_text: the full original sentence or full bullet point this criterion was extracted from. Not a fragment. If it ends with punctuation, the full sentence. If it is a bullet with no punctuation, the full bullet.

          ## Language

          Content may be in any language. Apply all rules identically regardless of language. Preserve the original language of all content in your output.

          ## Self-review

          After extracting all criteria, adversarially review your own tier assignments. Check every criterion against the soft skills exception.
        PROMPT

        JSON_SCHEMA = {
          type: 'json_schema',
          json_schema: {
            name: 'job_description_criteria_extraction',
            strict: true,
            schema: {
              type: 'object',
              properties: {
                criteria: {
                  type: 'array',
                  items: {
                    type: 'object',
                    properties: {
                      text: { type: 'string' },
                      tier: {
                        type: 'string',
                        enum: %w[tier_1 tier_2 tier_3]
                      },
                      tier_reasoning: { type: 'string' },
                      binary: { type: 'boolean' },
                      contains_title_technology: { type: 'boolean' },
                      duplicate: { type: 'boolean' },
                      source_heading: { type: %w[string null] },
                      source_text: { type: 'string' }
                    },
                    required: %w[text tier tier_reasoning binary contains_title_technology duplicate source_heading source_text],
                    additionalProperties: false
                  }
                }
              },
              required: %w[criteria],
              additionalProperties: false
            }
          }
        }.freeze

        MODEL = 'gemini-3.1-flash-lite'

        def self.messages(criteria_sections:, title_technology: nil)
          user_content = "Title technology: #{title_technology || 'none'}\n\n"
          user_content += "Here are the criteria sections from a job description:\n\n"
          criteria_sections.each_with_index do |section, i|
            heading = section['heading'] || '(no heading)'
            user_content += "--- Section #{i + 1}: #{heading} ---\n#{section['content']}\n\n"
          end

          [
            { role: 'system', content: SYSTEM_PROMPT },
            { role: 'user', content: user_content }
          ]
        end

        def self.response_format
          JSON_SCHEMA
        end

        def self.model
          MODEL
        end
      end
    end
  end
end
