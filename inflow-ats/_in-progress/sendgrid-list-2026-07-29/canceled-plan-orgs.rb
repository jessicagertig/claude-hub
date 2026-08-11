def canceled_plan_organizations
  plan_keys = Organization.plans.keys.grep(/apollo|starter|growth|scale/)

  organizations = Organization
                  .with_canceled_subscription
                  .where(plan: plan_keys)
                  .includes(:users, :owner)
                  .order(:subscription_canceled_at)

  data = organizations.map do |organization|
    emails = (organization.users.map(&:email) + [organization.owner&.email]).compact.uniq

    next if emails.include?('jessica+blocked@polymer.co')
    next if organization.name.to_s.downcase.include?('ecosure')

    {
      id: organization.id,
      name: organization.name,
      plan: organization.plan,
      fraud_rating: organization.fraud_rating,
      subscription_canceled_at: organization.subscription_canceled_at,
      jobs_count: organization.jobs_count,
      published_jobs_count: organization.published_jobs_count,
      website_url: organization.website_url,
      emails: emails
    }
  end.compact

  json_string = JSON.pretty_generate(data)
  puts json_string

  distinct_emails_count = data.flat_map { |organization_data| organization_data[:emails] }.uniq.size

  ap 'Plans matched', color: { string: :white }
  ap plan_keys
  ap 'Organizations', color: { string: :white }
  ap data.size, color: { integer: data.size.positive? ? :purple : :white }
  ap 'Distinct emails', color: { string: :white }
  ap distinct_emails_count, color: { integer: distinct_emails_count.positive? ? :purple : :white }
end
