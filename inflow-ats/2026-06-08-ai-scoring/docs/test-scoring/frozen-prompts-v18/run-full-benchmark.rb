# Full pipeline benchmark: 10 runs per job, score candidates using run 10
# Usage: bundle exec rails runner docs/test-scoring/run-full-benchmark.rb

scoring_dir = '/Users/jessica/claude-hub/inflow-ats/2026-06-08-ai-scoring/docs/test-scoring'
output_dir = "#{scoring_dir}/benchmark-v18"
FileUtils.mkdir_p(output_dir)

call1_class = AiJobApplicationAction::Scoring::Prompts::JobDescriptionStructuredData
call2_class = AiJobApplicationAction::Scoring::Prompts::JobDescriptionCriteriaExtraction
judge_class = AiJobApplicationAction::Scoring::Prompts::CriteriaReview
decomp_class = AiJobApplicationAction::Scoring::Prompts::CriteriaDecomposer
scoring_class = AiJobApplicationAction::Scoring::Prompts::CandidateCriteriaScoring

openai = AiClient.new(provider: 'openai')
gemini = AiClient.new(provider: 'gemini')

soft_skills = %w[communication organizational time\ management cross-functional\ collaboration teamwork problem-solving critical\ thinking decision-making adaptability flexibility attention\ to\ detail self-motivation interpersonal conflict\ resolution creative\ thinking multitasking prioritization mentoring]
t1_heading_words = %w[required must essential minimum]
t3_heading_words = ['bonus', 'optional', 'extra credit']

tier_weights = { 'tier_1' => 6, 'tier_2' => 4, 'tier_3' => 2 }
score_values = { 'full_match' => 1.0, 'partial_match' => 0.5, 'not_found' => 0 }
title_tech_multiplier = 3

def run_pipeline(jd_html:, openai:, gemini:, call1_class:, call2_class:, judge_class:, decomp_class:, soft_skills:, t1_heading_words:, t3_heading_words:)
  # Call 1: section decomposition (gpt-4.1-mini)
  c1_result = openai.chat(messages: call1_class.messages(job_description_html: jd_html), model: call1_class.model, response_format: call1_class.response_format)
  c1_parsed = JSON.parse(c1_result[:content])
  title_tech = c1_parsed['title_technology']
  criteria_sections = c1_parsed['sections'].select { |s| s['type'] == 'criteria' }
  sleep 2

  # Call 2: criteria extraction (gemini-3.1-flash-lite)
  c2_result = gemini.chat(messages: call2_class.messages(criteria_sections: criteria_sections, title_technology: title_tech), model: call2_class.model, response_format: call2_class.response_format)
  c2_content = c2_result[:content].gsub(/\A```json\s*\n?/, '').gsub(/\n?\s*```\z/, '')
  c2_parsed = JSON.parse(c2_content)
  non_dup = c2_parsed['criteria'].reject { |c| c['duplicate'] }
  sleep 2

  # Heading tier override
  overrides = 0
  non_dup.each do |c|
    heading = (c['source_heading'] || '').downcase
    next if heading.empty?
    is_soft = soft_skills.any? { |ss| c['text'].downcase.include?(ss) }
    if t1_heading_words.any? { |w| heading.include?(w) } && !is_soft && c['tier'] != 'tier_1'
      c['tier'] = 'tier_1'
      c['tier_reasoning'] = "heading override: #{c['source_heading']}"
      overrides += 1
    elsif t3_heading_words.any? { |w| heading.include?(w) } && c['tier'] != 'tier_3'
      c['tier'] = 'tier_3'
      c['tier_reasoning'] = "heading override: #{c['source_heading']}"
      overrides += 1
    end
  end

  # Judge: gpt-4o-mini (strip source_text)
  judge_input = non_dup.map { |c| c.except('source_text') }
  judge_result = openai.chat(messages: judge_class.messages(criteria: judge_input, title_technology: title_tech), model: 'gpt-4o-mini', response_format: judge_class.response_format)
  judge_parsed = JSON.parse(judge_result[:content])
  flagged = judge_parsed['criteria'].select { |d| d['action'] == 'decompose' }
  sleep 2

  # Decompose: gpt-4.1-mini (max 3 parts per criterion)
  flagged_texts = flagged.map { |d| d['original']['text'] }
  final = non_dup.reject { |c| flagged_texts.include?(c['text']) }

  decomp_parsed = nil
  if flagged.any?
    to_decompose = flagged.map { |d| d['original'] }
    decomp_result = openai.chat(messages: decomp_class.messages(criteria: to_decompose), model: 'gpt-4.1-mini', response_format: decomp_class.response_format)
    decomp_parsed = JSON.parse(decomp_result[:content])
    decomp_parsed['results'].each do |r|
      original = non_dup.find { |c| c['text'] == r['original_text'] }
      r['decomposed'].each do |d|
        d['tier'] = original['tier'] if original
        d['contains_title_technology'] = original['contains_title_technology'] if original
        d['binary'] = original['binary'] if original
        d['source_text'] = r['original_text']
      end
      final.concat(r['decomposed'])
    end
  end

  {
    call1: c1_parsed,
    call2: c2_parsed,
    call2_non_dup: non_dup,
    heading_overrides: overrides,
    judge: judge_parsed,
    decomp: decomp_parsed,
    final_criteria: final,
    title_technology: title_tech,
    flagged_count: flagged.length,
    flagged_texts: flagged_texts
  }
end

jobs = {
  'go' => {
    jd_file: "#{scoring_dir}/go-engineer-jd.html",
    resume_prefix: 'go',
    candidates: (1..20).to_a
  },
  'teamlead' => {
    jd_file: "#{scoring_dir}/team-lead-jd.html",
    resume_prefix: 'inbox',
    candidates: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
  }
}

jobs.each do |job_key, config|
  ap "\n#{'=' * 60}"
  ap "JOB: #{job_key.upcase}"
  ap '=' * 60

  jd_html = File.read(config[:jd_file])
  job_dir = "#{output_dir}/#{job_key}"
  FileUtils.mkdir_p(job_dir)

  # 10 pipeline runs
  all_runs = []
  10.times do |run_idx|
    run_num = run_idx + 1
    ap "\n--- #{job_key} Run #{run_num}/10 ---"

    retries = 0
    begin
      result = run_pipeline(
        jd_html: jd_html, openai: openai, gemini: gemini,
        call1_class: call1_class, call2_class: call2_class,
        judge_class: judge_class, decomp_class: decomp_class,
        soft_skills: soft_skills, t1_heading_words: t1_heading_words, t3_heading_words: t3_heading_words
      )
    rescue => e
      retries += 1
      if retries <= 2
        ap "  Run #{run_num} error, retry #{retries}: #{e.message[0..60]}"
        sleep 10
        retry
      end
      ap "  Run #{run_num} FAILED: #{e.message[0..60]}"
      next
    end

    tier_counts = { 'tier_1' => 0, 'tier_2' => 0, 'tier_3' => 0 }
    result[:final_criteria].each { |c| tier_counts[c['tier']] += 1 }

    ap "  #{result[:final_criteria].length} criteria | T1:#{tier_counts['tier_1']} T2:#{tier_counts['tier_2']} T3:#{tier_counts['tier_3']} | #{result[:flagged_count]} decomposed | #{result[:heading_overrides]} heading overrides"

    run_data = {
      'run' => run_num,
      'criteria_count' => result[:final_criteria].length,
      'tier_counts' => tier_counts,
      'flagged_count' => result[:flagged_count],
      'flagged_texts' => result[:flagged_texts],
      'heading_overrides' => result[:heading_overrides],
      'title_technology' => result[:title_technology],
      'criteria' => result[:final_criteria],
      'call1' => result[:call1],
      'call2_raw' => result[:call2],
      'judge' => result[:judge],
      'decomp' => result[:decomp]
    }

    File.write("#{job_dir}/run#{run_num}.json", JSON.pretty_generate(run_data))
    all_runs << run_data
    sleep 3
  end

  # Stability summary
  if all_runs.any?
    counts = all_runs.map { |r| r['criteria_count'] }
    t1_counts = all_runs.map { |r| r['tier_counts']['tier_1'] }
    flagged_counts = all_runs.map { |r| r['flagged_count'] }

    stability = {
      'criteria_range' => "#{counts.min}-#{counts.max}",
      'criteria_mean' => (counts.sum.to_f / counts.length).round(1),
      't1_range' => "#{t1_counts.min}-#{t1_counts.max}",
      'flagged_range' => "#{flagged_counts.min}-#{flagged_counts.max}",
      'per_run' => all_runs.map { |r| { 'run' => r['run'], 'count' => r['criteria_count'], 't1' => r['tier_counts']['tier_1'], 'flagged' => r['flagged_count'] } }
    }

    File.write("#{job_dir}/stability-summary.json", JSON.pretty_generate(stability))
    ap "\nStability: #{stability['criteria_range']} criteria, T1: #{stability['t1_range']}, flagged: #{stability['flagged_range']}"
  end

  # Score candidates using run 10
  last_run = all_runs.last
  next unless last_run

  criteria = last_run['criteria']
  max_score = criteria.sum { |c| tier_weights[c['tier']] * (c['contains_title_technology'] ? title_tech_multiplier : 1) }

  ap "\n--- Scoring #{config[:candidates].length} candidates using run 10 criteria (#{criteria.length} criteria) ---"

  config[:candidates].each do |cand_num|
    resume_file = "#{scoring_dir}/#{config[:resume_prefix]}-#{cand_num}.txt"
    unless File.exist?(resume_file)
      ap "  #{config[:resume_prefix]}-#{cand_num}: SKIPPED (no file)"
      next
    end
    resume = File.read(resume_file)

    retries = 0
    begin
      result = openai.chat(
        messages: scoring_class.messages(criteria: criteria, resume_text: resume),
        model: 'gpt-4o-mini',
        response_format: scoring_class.response_format
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

      ap "  #{config[:resume_prefix]}-#{cand_num}: #{pct}% | FM:#{fm} PM:#{pm} NF:#{nf}"

      File.write("#{job_dir}/score-#{config[:resume_prefix]}-#{cand_num}.json", JSON.pretty_generate(
        parsed.merge(
          'computed_score' => { 'points' => points, 'max' => max_score, 'percentage' => pct },
          'criteria_used' => criteria,
          'run_used' => 10,
          'model' => 'gpt-4o-mini'
        )
      ))
    rescue => e
      retries += 1
      if retries <= 2
        ap "  #{config[:resume_prefix]}-#{cand_num}: retry #{retries}: #{e.message[0..40]}"
        sleep 5
        retry
      end
      ap "  #{config[:resume_prefix]}-#{cand_num}: FAILED"
    end

    sleep 2
  end
end

ap "\n#{'=' * 60}"
ap "DONE. Results in #{output_dir}/"
ap '=' * 60
