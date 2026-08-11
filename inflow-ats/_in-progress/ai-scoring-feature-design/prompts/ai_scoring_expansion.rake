# frozen_string_literal: true

namespace :ai do
  namespace :scoring do
    desc 'Run criteria expansion (Call 3) on Team Lead criteria. Usage: rake ai:scoring:expand VERSION=1'
    task expand: :environment do
      version = ENV.fetch('VERSION') { abort 'VERSION is required. Usage: rake ai:scoring:expand VERSION=1' }

      scoring_dir = '/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/test-scoring'
      extraction = JSON.parse(File.read("#{scoring_dir}/team-lead-extraction.json"))

      # Filter out physical demands criteria (not scored)
      physical_keywords = ['desktop computing', 'manual dexterity', 'lift and carry']
      criteria = extraction['criteria']['criteria'].reject do |c|
        physical_keywords.any? { |kw| c['text'].downcase.include?(kw) }
      end

      prompt_class = AiJobApplicationAction::Scoring::Prompts::CriteriaExpansion

      # Save prompt snapshot
      prompt_path = "#{scoring_dir}/expansion-v#{version}-prompt.txt"
      File.write(prompt_path, prompt_class::SYSTEM_PROMPT)

      provider = if prompt_class.model.start_with?('gemini')
                   'gemini'
                 elsif prompt_class.model.start_with?('claude')
                   'anthropic'
                 else
                   'openai'
                 end

      ai_client = AiClient.new(provider: provider)

      ap "[expansion-v#{version}] Running #{criteria.length} criteria through #{prompt_class.model}..."

      messages = prompt_class.messages(criteria: criteria)

      result = ai_client.chat(
        messages: messages,
        model: prompt_class.model,
        response_format: prompt_class.response_format
      )

      content = result[:content].gsub(/\A```json\s*\n?/, '').gsub(/\n?\s*```\z/, '')
      parsed = JSON.parse(content)
      input_tokens = result[:input_tokens] || 0
      output_tokens = result[:output_tokens] || 0
      cost = AiClient.calculate_cost(model: prompt_class.model, input_tokens: input_tokens, output_tokens: output_tokens)

      output = {
        meta: {
          version: version.to_i,
          model: prompt_class.model,
          criteria_count: criteria.length,
          input_tokens: input_tokens,
          output_tokens: output_tokens,
          cost: cost.to_f.round(6)
        },
        result: parsed
      }

      results_path = "#{scoring_dir}/expansion-v#{version}-results.json"
      File.write(results_path, JSON.pretty_generate(output))

      # Generate readable markdown
      readable_path = "#{scoring_dir}/expansion-v#{version}-readable.md"
      expansions = parsed['expansions']
      md = "# Criteria Expansions — v#{version}\n\n"
      expansions.each_with_index do |exp, i|
        md += "## #{i + 1}. #{exp['criterion_text']}\n\n"

        full_key = exp.keys.find { |k| k.include?('full') || k == 'matched_by' }
        partial_key = exp.keys.find { |k| k.include?('partial') || k == 'partially_matched_by' }

        if full_key
          md += "**#{full_key.gsub('_', ' ').capitalize}:**\n"
          exp[full_key].each { |item| md += "- #{item}\n" }
        end

        if partial_key
          md += "\n**#{partial_key.gsub('_', ' ').capitalize}:**\n"
          exp[partial_key].each { |item| md += "- #{item}\n" }
        end

        md += "\n---\n\n"
      end

      File.write(readable_path, md)

      ap "[expansion-v#{version}] Done. #{expansions.length} criteria expanded."
      ap "  Cost: $#{'%.4f' % cost}"
      ap "  Prompt: #{prompt_path}"
      ap "  Results: #{results_path}"
      ap "  Readable: #{readable_path}"
    end

    desc 'Run candidate scoring (Call 4) with expansions. Usage: rake ai:scoring:score VERSION=1 EXPANSION_VERSION=1'
    task score: :environment do
      version = ENV.fetch('VERSION') { abort 'VERSION is required' }
      expansion_version = ENV.fetch('EXPANSION_VERSION') { abort 'EXPANSION_VERSION is required' }

      scoring_dir = '/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/test-scoring'

      # Load criteria
      extraction = JSON.parse(File.read("#{scoring_dir}/team-lead-extraction.json"))
      physical_keywords = ['desktop computing', 'manual dexterity', 'lift and carry']
      criteria = extraction['criteria']['criteria'].reject do |c|
        physical_keywords.any? { |kw| c['text'].downcase.include?(kw) }
      end

      # Load expansions
      expansion_file = "#{scoring_dir}/expansion-v#{expansion_version}-results.json"
      abort "Expansion file not found: #{expansion_file}" unless File.exist?(expansion_file)
      expansions = JSON.parse(File.read(expansion_file))['result']['expansions']

      prompt_class = AiJobApplicationAction::Scoring::Prompts::JobApplicationScoring
      prompt_path = "#{scoring_dir}/scoring-v#{version}-prompt.txt"
      File.write(prompt_path, prompt_class::SYSTEM_PROMPT)

      provider = if prompt_class.model.start_with?('gemini')
                   'gemini'
                 elsif prompt_class.model.start_with?('claude')
                   'anthropic'
                 else
                   'openai'
                 end

      ai_client = AiClient.new(provider: provider)
      results_dir = "#{scoring_dir}/scoring-v#{version}-results"
      FileUtils.mkdir_p(results_dir)

      total_cost = 0.0
      resume_files = Dir.glob("#{scoring_dir}/inbox-*.txt").sort_by { |f| f[/inbox-(\d+)/, 1].to_i }

      resume_files.each_with_index do |resume_file, i|
        num = resume_file[/inbox-(\d+)/, 1]
        resume_text = File.read(resume_file)

        ap "[scoring-v#{version}] [#{i + 1}/#{resume_files.length}] inbox-#{num}"

        messages = prompt_class.messages(criteria: criteria, resume_text: resume_text, expansions: expansions)

        result = ai_client.chat(
          messages: messages,
          model: prompt_class.model,
          response_format: prompt_class.response_format
        )

        content = result[:content].gsub(/\A```json\s*\n?/, '').gsub(/\n?\s*```\z/, '')
        parsed = JSON.parse(content)
        input_tokens = result[:input_tokens] || 0
        output_tokens = result[:output_tokens] || 0
        cost = AiClient.calculate_cost(model: prompt_class.model, input_tokens: input_tokens, output_tokens: output_tokens)
        total_cost += cost.to_f

        # Compute score
        tier_weights = { 'tier_1' => 6, 'tier_2' => 4, 'tier_3' => 2 }
        score_multipliers = { 'matched' => 1.0, 'partial' => 0.5, 'not_found' => 0.0 }
        total_possible = 0
        total_earned = 0.0
        parsed['scores'].each do |s|
          weight = tier_weights[s['tier']] || 4
          total_possible += weight
          total_earned += weight * (score_multipliers[s['score']] || 0)
        end
        pct = total_possible > 0 ? (total_earned / total_possible * 100).round(1) : 0

        output = {
          meta: {
            version: version.to_i,
            expansion_version: expansion_version.to_i,
            resume: "inbox-#{num}",
            model: prompt_class.model,
            input_tokens: input_tokens,
            output_tokens: output_tokens,
            cost: cost.to_f.round(6),
            score_pct: pct
          },
          result: parsed
        }

        File.write("#{results_dir}/inbox-#{num}.json", JSON.pretty_generate(output))
        ap "  Score: #{pct}% | Cost: $#{'%.4f' % cost}"

        sleep 2 if i < resume_files.length - 1
      end

      ap "\n[scoring-v#{version}] Total cost: $#{'%.4f' % total_cost}"
      ap "  Results: #{results_dir}/"
    end
  end
end
