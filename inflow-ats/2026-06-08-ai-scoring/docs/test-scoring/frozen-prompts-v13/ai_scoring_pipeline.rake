# frozen_string_literal: true

namespace :ai do
  namespace :scoring do
    desc 'Full pipeline: Call 1 + Call 2 + Call 2b (with batching). Usage: rake ai:scoring:pipeline JOB=go|teamlead'
    task pipeline: :environment do
      job_key = ENV.fetch('JOB') { abort 'JOB is required (teamlead, go, or da)' }
      scoring_dir = '/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/test-scoring'
      output_suffix = ENV.fetch('SUFFIX', '')

      jd_file = case job_key
                when 'teamlead' then "#{scoring_dir}/team-lead-jd.html"
                when 'go' then "#{scoring_dir}/go-engineer-jd.html"
                else abort "Unknown JOB: #{job_key}. Use teamlead or go."
                end

      abort "JD file not found: #{jd_file}" unless File.exist?(jd_file)
      jd_html = File.read(jd_file)

      call1_class = AiJobApplicationAction::Scoring::Prompts::JobDescriptionStructuredData
      call2_class = AiJobApplicationAction::Scoring::Prompts::JobDescriptionCriteriaExtraction
      call2b_class = AiJobApplicationAction::Scoring::Prompts::CriteriaReview

      openai_client = AiClient.new(provider: 'openai')
      gemini_client = AiClient.new(provider: 'gemini')

      total_cost = 0.0

      # Call 1: Section decomposition (gpt-4.1-mini via OpenAI)
      ap "[pipeline] Call 1: section decomposition..."
      c1_result = openai_client.chat(
        messages: call1_class.messages(job_description_html: jd_html),
        model: call1_class.model,
        response_format: call1_class.response_format
      )
      c1_parsed = JSON.parse(c1_result[:content])
      c1_cost = AiClient.calculate_cost(model: call1_class.model, input_tokens: c1_result[:input_tokens] || 0, output_tokens: c1_result[:output_tokens] || 0).to_f
      total_cost += c1_cost

      title_technology = c1_parsed['title_technology']
      criteria_sections = c1_parsed['sections'].select { |s| s['type'] == 'criteria' }
      ap "  #{criteria_sections.length} criteria sections | title_tech: #{title_technology || 'none'} | $#{'%.4f' % c1_cost}"

      sleep 2

      # Call 2: Criteria extraction (gemini-3.1-flash-lite)
      ap "[pipeline] Call 2: criteria extraction..."
      c2_result = gemini_client.chat(
        messages: call2_class.messages(criteria_sections: criteria_sections, title_technology: title_technology),
        model: call2_class.model,
        response_format: call2_class.response_format
      )
      c2_content = c2_result[:content].gsub(/\A```json\s*\n?/, '').gsub(/\n?\s*```\z/, '')
      c2_parsed = JSON.parse(c2_content)
      c2_cost = AiClient.calculate_cost(model: call2_class.model, input_tokens: c2_result[:input_tokens] || 0, output_tokens: c2_result[:output_tokens] || 0).to_f
      total_cost += c2_cost

      c2_criteria = c2_parsed['criteria']
      non_dup_criteria = c2_criteria.reject { |c| c['duplicate'] }
      ap "  #{c2_criteria.length} criteria (#{non_dup_criteria.length} after dedup) | $#{'%.4f' % c2_cost}"

      sleep 2

      # Call 2b: Decomposition review (gemini-3.1-flash-lite) — with batching
      ap "[pipeline] Call 2b: decomposition review..."
      batch_size = 15
      max_decompositions = 5
      all_decisions = []

      batches = non_dup_criteria.each_slice(batch_size).to_a
      c2b_total_cost = 0.0

      batches.each_with_index do |batch, batch_idx|
        ap "  Batch #{batch_idx + 1}/#{batches.length}: #{batch.length} criteria..." if batches.length > 1

        retries = 0
        begin
          c2b_result = gemini_client.chat(
            messages: call2b_class.messages(criteria: batch, title_technology: title_technology),
            model: call2b_class.model,
            response_format: call2b_class.response_format
          )
          c2b_content = c2b_result[:content].gsub(/\A```json\s*\n?/, '').gsub(/\n?\s*```\z/, '')
          c2b_parsed = JSON.parse(c2b_content)
        rescue StandardError => e
          retries += 1
          if retries <= 2
            ap "    Retry #{retries}/2: #{e.message[0..60]}"
            sleep 5
            retry
          end
          ap "    FAILED — keeping batch criteria as-is"
          batch.each { |c| all_decisions << { 'action' => 'keep', 'original' => c, 'decomposed' => [] } }
          next
        end

        batch_cost = AiClient.calculate_cost(model: call2b_class.model, input_tokens: c2b_result[:input_tokens] || 0, output_tokens: c2b_result[:output_tokens] || 0).to_f
        c2b_total_cost += batch_cost

        returned_count = c2b_parsed['criteria'].length
        if returned_count < batch.length
          ap "    WARNING: Call 2b returned #{returned_count}/#{batch.length} criteria (lost #{batch.length - returned_count})"
        end

        all_decisions.concat(c2b_parsed['criteria'])
        sleep 2 if batch_idx < batches.length - 1
      end

      total_cost += c2b_total_cost

      # Enforce max decompositions: keep only top N by part count
      decompose_decisions = all_decisions.select { |d| d['action'] == 'decompose' && d['decomposed']&.any? }
      if decompose_decisions.length > max_decompositions
        decompose_decisions.sort_by! { |d| -d['decomposed'].length }
        kept_decompositions = decompose_decisions.first(max_decompositions)
        reverted = decompose_decisions[max_decompositions..]
        reverted.each { |d| d['action'] = 'keep' }
        ap "  Enforced max #{max_decompositions} decompositions (reverted #{reverted.length})"
      end

      final_criteria = []
      all_decisions.each do |decision|
        if decision['action'] == 'decompose' && decision['decomposed']&.any?
          final_criteria.concat(decision['decomposed'])
        else
          final_criteria << decision['original']
        end
      end

      decomp_count = all_decisions.count { |d| d['action'] == 'decompose' }
      ap "  #{batches.length > 1 ? "#{batches.length} batches | " : ''}#{non_dup_criteria.length} in → #{final_criteria.length} out (#{decomp_count} decomposed) | $#{'%.4f' % c2b_total_cost}"

      # Save output in extraction format (compatible with score_candidates)
      output = {
        'sections' => {
          'title_technology' => title_technology,
          'sections' => c1_parsed['sections']
        },
        'criteria' => {
          'criteria' => final_criteria
        },
        'meta' => {
          'call_1_cost' => c1_cost.round(6),
          'call_2_cost' => c2_cost.round(6),
          'call_2_criteria_count' => c2_criteria.length,
          'call_2_dedup_count' => non_dup_criteria.length,
          'call_2b_criteria_count' => final_criteria.length,
          'total_cost' => total_cost.round(6)
        }
      }

      output_name = "#{job_key}-extraction#{output_suffix.empty? ? '' : "-#{output_suffix}"}.json"
      output_path = "#{scoring_dir}/#{output_name}"
      File.write(output_path, JSON.pretty_generate(output))

      tier_counts = { 'tier_1' => 0, 'tier_2' => 0, 'tier_3' => 0 }
      final_criteria.each { |c| tier_counts[c['tier']] += 1 }
      ap "\n[pipeline] Done: #{final_criteria.length} final criteria | T1:#{tier_counts['tier_1']} T2:#{tier_counts['tier_2']} T3:#{tier_counts['tier_3']}"
      ap "  Total cost: $#{'%.4f' % total_cost}"
      ap "  Saved: #{output_path}"
    end

    desc 'Stability test: run pipeline N times. Usage: rake ai:scoring:stability JOB=go|teamlead RUNS=10 VERSION=13'
    task stability: :environment do
      job_key = ENV.fetch('JOB') { abort 'JOB is required (teamlead or go)' }
      runs = ENV.fetch('RUNS', '10').to_i
      version = ENV.fetch('VERSION', '13')
      scoring_dir = '/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/test-scoring'
      results_dir = "#{scoring_dir}/stability-v#{version}"
      FileUtils.mkdir_p(results_dir)

      jd_file = case job_key
                when 'teamlead' then "#{scoring_dir}/team-lead-jd.html"
                when 'go' then "#{scoring_dir}/go-engineer-jd.html"
                else abort "Unknown JOB: #{job_key}. Use teamlead or go."
                end

      abort "JD file not found: #{jd_file}" unless File.exist?(jd_file)
      jd_html = File.read(jd_file)

      call1_class = AiJobApplicationAction::Scoring::Prompts::JobDescriptionStructuredData
      call2_class = AiJobApplicationAction::Scoring::Prompts::JobDescriptionCriteriaExtraction
      call2b_class = AiJobApplicationAction::Scoring::Prompts::CriteriaReview

      openai_client = AiClient.new(provider: 'openai')
      gemini_client = AiClient.new(provider: 'gemini')

      batch_size = 15
      total_cost = 0.0
      all_runs = []

      runs.times do |run_idx|
        run_num = run_idx + 1
        ap "\n========== RUN #{run_num}/#{runs} =========="

        run_cost = 0.0

        # Call 1
        c1_result = openai_client.chat(
          messages: call1_class.messages(job_description_html: jd_html),
          model: call1_class.model,
          response_format: call1_class.response_format
        )
        c1_parsed = JSON.parse(c1_result[:content])
        c1_cost = AiClient.calculate_cost(model: call1_class.model, input_tokens: c1_result[:input_tokens] || 0, output_tokens: c1_result[:output_tokens] || 0).to_f
        run_cost += c1_cost

        title_technology = c1_parsed['title_technology']
        criteria_sections = c1_parsed['sections'].select { |s| s['type'] == 'criteria' }
        sleep 2

        # Call 2
        c2_result = gemini_client.chat(
          messages: call2_class.messages(criteria_sections: criteria_sections, title_technology: title_technology),
          model: call2_class.model,
          response_format: call2_class.response_format
        )
        c2_content = c2_result[:content].gsub(/\A```json\s*\n?/, '').gsub(/\n?\s*```\z/, '')
        c2_parsed = JSON.parse(c2_content)
        c2_cost = AiClient.calculate_cost(model: call2_class.model, input_tokens: c2_result[:input_tokens] || 0, output_tokens: c2_result[:output_tokens] || 0).to_f
        run_cost += c2_cost

        c2_criteria = c2_parsed['criteria']
        non_dup_criteria = c2_criteria.reject { |c| c['duplicate'] }
        sleep 2

        # Call 2b with batching + max 5 enforcement
        max_decompositions = 5
        all_decisions = []
        batches = non_dup_criteria.each_slice(batch_size).to_a

        batches.each_with_index do |batch, batch_idx|
          retries = 0
          begin
            c2b_result = gemini_client.chat(
              messages: call2b_class.messages(criteria: batch, title_technology: title_technology),
              model: call2b_class.model,
              response_format: call2b_class.response_format
            )
            c2b_content = c2b_result[:content].gsub(/\A```json\s*\n?/, '').gsub(/\n?\s*```\z/, '')
            c2b_parsed = JSON.parse(c2b_content)
          rescue StandardError => e
            retries += 1
            if retries <= 2
              ap "  Call 2b batch #{batch_idx + 1} retry #{retries}/2: #{e.message[0..60]}"
              sleep 5
              retry
            end
            ap "  Call 2b batch #{batch_idx + 1} FAILED — keeping as-is"
            batch.each { |c| all_decisions << { 'action' => 'keep', 'original' => c, 'decomposed' => [] } }
            next
          end

          c2b_cost = AiClient.calculate_cost(model: call2b_class.model, input_tokens: c2b_result[:input_tokens] || 0, output_tokens: c2b_result[:output_tokens] || 0).to_f
          run_cost += c2b_cost

          all_decisions.concat(c2b_parsed['criteria'])
          sleep 2 if batch_idx < batches.length - 1
        end

        # Enforce max decompositions
        decompose_decisions = all_decisions.select { |d| d['action'] == 'decompose' && d['decomposed']&.any? }
        if decompose_decisions.length > max_decompositions
          decompose_decisions.sort_by! { |d| -d['decomposed'].length }
          decompose_decisions[max_decompositions..].each { |d| d['action'] = 'keep' }
        end

        final_criteria = []
        all_decisions.each do |decision|
          if decision['action'] == 'decompose' && decision['decomposed']&.any?
            final_criteria.concat(decision['decomposed'])
          else
            final_criteria << decision['original']
          end
        end

        tier_counts = { 'tier_1' => 0, 'tier_2' => 0, 'tier_3' => 0 }
        final_criteria.each { |c| tier_counts[c['tier']] += 1 }
        decomposed_count = final_criteria.length - non_dup_criteria.length

        ap "  Run #{run_num}: #{final_criteria.length} criteria (#{non_dup_criteria.length} base + #{decomposed_count} from decomp) | T1:#{tier_counts['tier_1']} T2:#{tier_counts['tier_2']} T3:#{tier_counts['tier_3']} | $#{'%.4f' % run_cost}"

        run_data = {
          'run' => run_num,
          'criteria_count' => final_criteria.length,
          'call2_count' => non_dup_criteria.length,
          'decomposed_delta' => decomposed_count,
          'tier_counts' => tier_counts,
          'cost' => run_cost.round(6),
          'title_technology' => title_technology,
          'criteria' => final_criteria
        }

        File.write("#{results_dir}/#{job_key}-run#{run_num}.json", JSON.pretty_generate(run_data))
        all_runs << run_data
        total_cost += run_cost

        sleep 3 if run_idx < runs - 1
      end

      # Summary
      ap "\n========== STABILITY SUMMARY (#{job_key}, #{runs} runs) =========="
      counts = all_runs.map { |r| r['criteria_count'] }
      t1_counts = all_runs.map { |r| r['tier_counts']['tier_1'] }
      decomp_deltas = all_runs.map { |r| r['decomposed_delta'] }

      ap "  Criteria count: #{counts.min}-#{counts.max} (mean #{(counts.sum.to_f / counts.length).round(1)})"
      ap "  T1 count: #{t1_counts.min}-#{t1_counts.max}"
      ap "  Decomposition delta: #{decomp_deltas.min}-#{decomp_deltas.max}"
      ap "  Total cost: $#{'%.4f' % total_cost}"

      # Find always-present criteria (normalized text matching)
      all_texts = all_runs.map { |r| r['criteria'].map { |c| c['text'].downcase.strip.chomp('.') } }
      every_run_texts = all_texts.first
      all_texts[1..].each { |texts| every_run_texts = every_run_texts & texts }
      ap "  Always-present criteria: #{every_run_texts.length}/#{counts.max}"

      summary = {
        'job' => job_key,
        'runs' => runs,
        'criteria_range' => "#{counts.min}-#{counts.max}",
        'criteria_mean' => (counts.sum.to_f / counts.length).round(1),
        't1_range' => "#{t1_counts.min}-#{t1_counts.max}",
        'decomp_delta_range' => "#{decomp_deltas.min}-#{decomp_deltas.max}",
        'always_present_count' => every_run_texts.length,
        'always_present' => every_run_texts.sort,
        'total_cost' => total_cost.round(4),
        'per_run' => all_runs.map { |r| { 'run' => r['run'], 'count' => r['criteria_count'], 't1' => r['tier_counts']['tier_1'], 'decomp' => r['decomposed_delta'], 'cost' => r['cost'] } }
      }

      File.write("#{results_dir}/#{job_key}-summary.json", JSON.pretty_generate(summary))
      ap "  Summary: #{results_dir}/#{job_key}-summary.json"
    end

    desc 'Score variance: score candidates against multiple criteria sets. Usage: rake ai:scoring:score_variance JOB=go|teamlead VERSION=13'
    task score_variance: :environment do
      job_key = ENV.fetch('JOB') { abort 'JOB is required (teamlead or go)' }
      version = ENV.fetch('VERSION', '13')
      scoring_dir = '/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/test-scoring'
      results_dir = "#{scoring_dir}/stability-v#{version}"

      resume_prefix = case job_key
                      when 'teamlead' then 'inbox'
                      when 'go' then 'go'
                      else abort "Unknown JOB: #{job_key}."
                      end

      candidates = case job_key
                   when 'teamlead' then [3, 8, 9, 13, 17]
                   when 'go' then [1, 2, 3, 4, 5]
                   end

      run_files = Dir.glob("#{results_dir}/#{job_key}-run*.json").sort
      abort "No stability run files found in #{results_dir}" if run_files.empty?

      prompt_class = AiJobApplicationAction::Scoring::Prompts::CandidateCriteriaScoring
      gemini_client = AiClient.new(provider: 'gemini')

      tier_weights = { 'tier_1' => 6, 'tier_2' => 4, 'tier_3' => 2 }
      score_values = { 'full_match' => 1.0, 'partial_match' => 0.5, 'not_found' => 0 }
      title_tech_multiplier = 3

      all_scores = {}

      candidates.each do |cand_num|
        resume_file = "#{scoring_dir}/#{resume_prefix}-#{cand_num}.txt"
        unless File.exist?(resume_file)
          ap "Candidate #{cand_num}: SKIPPED (no resume file)"
          next
        end
        resume = File.read(resume_file)
        all_scores[cand_num] = []

        run_files.each_with_index do |run_file, run_idx|
          run_data = JSON.parse(File.read(run_file))
          criteria = run_data['criteria']
          run_num = run_data['run']

          max_score = criteria.sum { |c| tier_weights[c['tier']] * (c['contains_title_technology'] ? title_tech_multiplier : 1) }

          begin
            result = gemini_client.chat(
              messages: prompt_class.messages(criteria: criteria, resume_text: resume),
              model: prompt_class.model,
              response_format: prompt_class.response_format
            )
            content = result[:content].gsub(/\A```json\s*\n?/, '').gsub(/\n?\s*```\z/, '')
            parsed = JSON.parse(content)
            scores = parsed['scores']

            title_tech_flags = criteria.map { |c| c['contains_title_technology'] }
            points = scores.each_with_index.sum do |s, idx|
              weight = tier_weights[s['tier']] || 4
              value = score_values[s['score']] || 0
              multiplier = title_tech_flags[idx] ? title_tech_multiplier : 1
              weight * value * multiplier
            end

            pct = (points / max_score.to_f * 100).round(1)
            all_scores[cand_num] << { 'run' => run_num, 'pct' => pct, 'criteria_count' => criteria.length }
            ap "  #{resume_prefix}-#{cand_num} run#{run_num}: #{pct}% (#{criteria.length} criteria)"
          rescue StandardError => e
            retries ||= 0
            retries += 1
            if retries <= 2
              sleep 5
              retry
            end
            ap "  #{resume_prefix}-#{cand_num} run#{run_num}: FAILED #{e.message[0..60]}"
          end

          sleep 2
        end

        pcts = all_scores[cand_num].map { |s| s['pct'] }
        if pcts.any?
          mean = (pcts.sum / pcts.length.to_f).round(1)
          variance = (pcts.max - pcts.min).round(1)
          ap "  #{resume_prefix}-#{cand_num}: mean=#{mean}% range=#{pcts.min}-#{pcts.max}% variance=#{variance}pp"
        end
      end

      # Summary
      ap "\n========== SCORE VARIANCE SUMMARY (#{job_key}) =========="
      variance_data = {}
      all_scores.each do |cand_num, scores|
        pcts = scores.map { |s| s['pct'] }
        next if pcts.empty?

        mean = (pcts.sum / pcts.length.to_f).round(1)
        variance = (pcts.max - pcts.min).round(1)
        ap "  #{resume_prefix}-#{cand_num}: #{mean}% ± #{(variance / 2.0).round(1)}pp (#{pcts.min}-#{pcts.max}%)"
        variance_data[cand_num] = { 'mean' => mean, 'min' => pcts.min, 'max' => pcts.max, 'variance_pp' => variance, 'scores' => scores }
      end

      variances = variance_data.values.map { |v| v['variance_pp'] }
      if variances.any?
        avg_variance = (variances.sum / variances.length.to_f).round(1)
        max_variance = variances.max
        ap "  Average variance: #{avg_variance}pp | Max variance: #{max_variance}pp"
        ap "  #{max_variance <= 5.0 ? 'PASS' : 'FAIL'}: target is ≤5pp"
      end

      File.write("#{results_dir}/#{job_key}-score-variance.json", JSON.pretty_generate(variance_data))
      ap "  Saved: #{results_dir}/#{job_key}-score-variance.json"
    end
  end
end
