def plato_excluded_organization_ids
  [8587, 8588, 8761, 8789, 8927, 8964, 9051, 9295, 9397, 9704, 9763, 9780, 9795, 9908, 10010, 10013, 10148, 10154, 10195, 10208, 10248, 10368, 10384, 10491, 10559, 10564, 10606, 10637, 10645, 10658, 10697, 10716, 10742, 10748, 10773, 10943, 10991, 10992, 10994, 11063, 11072, 11082, 11094, 11096, 11100, 11101, 11121, 11135, 11138, 12261, 12521, 12654, 12842, 12971, 12973, 12996, 13043, 13058, 13066, 13074, 13097]
end

def plato_contact_list_id
  'dfe4d198-c938-4dda-8274-b852ae90d3eb'
end

def plato_canceled_plan_organization_ids
  plan_keys = Organization.plans.keys.grep(/apollo|starter|growth|scale/)
  organization_ids = Organization.with_canceled_subscription.where(plan: plan_keys).where.not(id: plato_excluded_organization_ids).ids
  ap 'Canceled plan organizations', color: { string: :white }
  ap organization_ids.size, color: { integer: :purple }
  organization_ids
end

def plato_active_paid_organization_ids
  organization_ids = []
  Organization.find_each { |organization| organization_ids << organization.id if organization.active_paid_plan? }
  ap 'Active paid organizations', color: { string: :white }
  ap organization_ids.size, color: { integer: :purple }
  organization_ids
end

def plato_organization_ids
  organization_ids = (plato_active_paid_organization_ids + plato_canceled_plan_organization_ids).uniq
  ap 'Total distinct organizations', color: { string: :white }
  ap organization_ids.size, color: { integer: :purple }
  organization_ids
end

def plato_contact_for(organization_user)
  user = organization_user.user
  { email: user.email, first_name: user.first_name, last_name: user.last_name }
end

def plato_contacts(organization_ids)
  organization_users = OrganizationUser.kept.actives.atleast_org_user.where(organization_id: organization_ids).where(user_id: User.kept.actives).includes(:user)
  contacts = organization_users.map { |organization_user| plato_contact_for(organization_user) }.uniq { |contact| contact[:email] }
  ap 'Contacts', color: { string: :white }
  ap contacts.size, color: { integer: :purple }
  contacts
end

def plato_print_organization_ids(organization_ids)
  puts organization_ids.to_json
  ap 'Organization ids printed', color: { string: :white }
end

def plato_preview_contacts(organization_ids)
  json_string = JSON.pretty_generate(plato_contacts(organization_ids))
  puts json_string
  ap 'Contacts previewed, nothing sent', color: { string: :white }
end

def plato_upsert_contacts_to_sendgrid(organization_ids)
  contacts = plato_contacts(organization_ids)
  SendGridClient.new.upsert_contacts(contacts, plato_contact_list_id)
  ap 'Upserted to SendGrid list', color: { string: :white }
  ap plato_contact_list_id
end

def plato_credit_balances(organization_ids)
  Organization.where(id: organization_ids).includes(:organization_ai_credit_balance).each do |organization|
    organization_ai_credit_balance = organization.organization_ai_credit_balance
    puts "#{organization.id} | addon #{organization_ai_credit_balance&.addon_credits_remaining.inspect} | total #{organization_ai_credit_balance&.total_credits_remaining.inspect} | #{organization.name}"
  end
  ap 'Balances listed', color: { string: :white }
end

def plato_revoke_credits(organization_ids)
  Organization.where(id: organization_ids).includes(:organization_ai_credit_balance).each do |organization|
    organization_ai_credit_balance = organization.organization_ai_credit_balance
    next if organization_ai_credit_balance.nil?
    capped_amount = [100, organization_ai_credit_balance.addon_credits_remaining].min
    next if capped_amount.zero?
    organization_ai_credit_balance.update_columns(sent_low_notification_since_increase: true, sent_zero_notification_since_increase: true)
    ai_credit_balance_transaction = AiCreditBalanceTransaction.new(organization_ai_credit_balance: organization_ai_credit_balance, entry_type: :admin_debit, bucket: :addon, amount: -capped_amount, description: 'Plato open beta bonus revoked')
    puts "#{organization.id} | -#{capped_amount} | #{ai_credit_balance_transaction.save ? 'ok' : ai_credit_balance_transaction.errors.full_messages.join(', ')} | #{organization.name}"
  end
  ap 'Revoke complete', color: { string: :white }
end
