# frozen_string_literal: true

namespace :ai do
  namespace :scoring do
    desc 'Score candidates against extracted criteria. Usage: rake ai:scoring:score_candidates JOB=teamlead|go VERSION=1 BATCH_START=1 BATCH_END=5'
    task score_candidates: :environment do
      job_key = ENV.fetch('JOB') { abort 'JOB is required (teamlead or go)' }
      version = ENV.fetch('VERSION') { abort 'VERSION is required' }
      batch_start = ENV.fetch('BATCH_START', '1').to_i
      batch_end = ENV.fetch('BATCH_END', '20').to_i

      scoring_dir = '/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/test-scoring'

      extraction_file = case job_key
                         when 'teamlead' then "#{scoring_dir}/team-lead-extraction.json"
                         when 'go' then "#{scoring_dir}/go-engineer-extraction.json"
                         when 'da' then "#{scoring_dir}/data-analyst-extraction.json"
                         else abort "Unknown JOB: #{job_key}. Use teamlead, go, or da."
                         end

      resume_prefix = case job_key
                      when 'teamlead' then 'inbox'
                      when 'go' then 'go'
                      when 'da' then 'da'
                      end

      extraction = JSON.parse(File.read(extraction_file))
      criteria = extraction['criteria']['criteria']
      criteria = criteria.reject { |c| c['text'].match?(/lift|carry|sit and use|manual dexterity/i) }
      criteria = criteria.reject { |c| c['duplicate'] }

      prompt_class = AiJobApplicationAction::Scoring::Prompts::CandidateCriteriaScoring
      ai_client = AiClient.new(provider: 'gemini')

      tier_weights = { 'tier_1' => 6, 'tier_2' => 4, 'tier_3' => 2 }
      score_values = { 'full_match' => 1.0, 'partial_match' => 0.5, 'not_found' => 0 }
      title_tech_multiplier = 3
      max_score = criteria.sum { |c| tier_weights[c['tier']] * (c['contains_title_technology'] ? title_tech_multiplier : 1) }

      results = []

      (batch_start..batch_end).each do |i|
        resume_file = "#{scoring_dir}/#{resume_prefix}-#{i}.txt"
        unless File.exist?(resume_file)
          ap "#{i}. SKIPPED (file not found)"
          next
        end

        resume = File.read(resume_file)
        preview = resume.first(50).gsub(/\n/, ' ').strip

        begin
          result = ai_client.chat(
            messages: prompt_class.messages(criteria: criteria, resume_text: resume),
            model: prompt_class.model,
            response_format: prompt_class.response_format
          )
          parsed = JSON.parse(result[:content])
          scores = parsed['scores']

          title_tech_flags = criteria.map { |c| c['contains_title_technology'] }
          points = scores.each_with_index.sum do |s, idx|
            weight = tier_weights[s['tier']] || 4
            value = score_values[s['score']] || 0
            multiplier = title_tech_flags[idx] ? title_tech_multiplier : 1
            weight * value * multiplier
          end

          pct = (points / max_score.to_f * 100).round(1)
          fm = scores.count { |s| s['score'] == 'full_match' }
          pm = scores.count { |s| s['score'] == 'partial_match' }
          nf = scores.count { |s| s['score'] == 'not_found' }

          ap "#{i.to_s.rjust(2)}. #{pct.to_s.rjust(5)}% | FM:#{fm} PM:#{pm} NF:#{nf} | #{preview}"
          results << { num: i, pct: pct, fm: fm, pm: pm, nf: nf }

          output_file = "#{scoring_dir}/#{resume_prefix}-#{i}-scores-v#{version}.json"
          File.write(output_file, JSON.pretty_generate(parsed.merge('computed_score' => { 'points' => points, 'max' => max_score, 'percentage' => pct })))
        rescue StandardError => e
          retries ||= 0
          retries += 1
          if retries <= 2
            ap "#{i.to_s.rjust(2)}. RETRY #{retries}/2: #{e.message[0..60]}"
            sleep 5
            retry
          end
          ap "#{i.to_s.rjust(2)}. FAILED: #{e.message[0..60]}"
        end

        sleep 2
      end

      ap ''
      ap "=== #{job_key.upcase} v#{version} RANKED (batch #{batch_start}-#{batch_end}) ==="
      results.sort_by { |r| -r[:pct] }.each do |r|
        ap "#{r[:num].to_s.rjust(2)}. #{r[:pct].to_s.rjust(5)}%"
      end
    end
  end
end
