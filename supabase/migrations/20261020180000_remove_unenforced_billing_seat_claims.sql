-- Do not imply seat entitlements or module features that are not yet enforced.
update public.billing_plans
set description = case id
  when 'starter_monthly' then 'Core workflow requests and approvals, task tracking, private document storage and in-app notifications.'
  when 'professional_monthly' then 'Advanced workflow configuration, SLA escalation and workflow operations visibility.'
  else description
end,
updated_at = now()
where id in ('starter_monthly','professional_monthly');
