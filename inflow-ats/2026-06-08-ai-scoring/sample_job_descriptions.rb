def sample_job_descriptions
  target_orgs = 100
  max_per_org = 2

  jobs = Job
    .where(status: :published)
    .where("job_applications_count > ?", 10)
    .where.not(description: [nil, ""])
    .order(published_at: :desc)
    .select(:id, :title, :description, :organization_id, :job_applications_count, :published_at)

  sampled = []
  org_counts = Hash.new(0)
  orgs_seen = Set.new

  jobs.find_each(batch_size: 500) do |job|
    break if orgs_seen.size >= target_orgs && org_counts.values.all? { |c| c >= max_per_org }

    next if org_counts[job.organization_id] >= max_per_org
    next if orgs_seen.size >= target_orgs && !orgs_seen.include?(job.organization_id)

    org_counts[job.organization_id] += 1
    orgs_seen.add(job.organization_id)

    sampled << {
      job_id: job.id,
      title: job.title,
      description: job.description,
      organization_id: job.organization_id,
      candidate_count: job.job_applications_count,
      published_at: job.published_at&.iso8601
    }
  end

  org_names = Organization.where(id: orgs_seen.to_a).pluck(:id, :name).to_h
  sampled.each { |j| j[:organization_name] = org_names[j[:organization_id]] }

  puts JSON.pretty_generate(sampled)
end
