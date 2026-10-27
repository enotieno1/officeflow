-- OfficeFlow organisation-wide fraud intelligence expansion.
-- Keeps the existing finance rules and adds sensitive-change and privileged-action
-- monitoring across organisational roles. Alerts are indicators for human review.
begin;

alter function public.scan_fraud_risks() rename to scan_fraud_risks_finance_base;
revoke all on function public.scan_fraud_risks_finance_base() from public;
revoke all on function public.scan_fraud_risks_finance_base() from authenticated;

create or replace function public.scan_fraud_risks()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_uid uuid := auth.uid();
  v_org uuid;
  v_role text;
  v_base jsonb;
  v_extra integer := 0;
  v_rule_count integer := 5;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select p.organization_id, p.role
    into v_org, v_role
    from public.profiles p
   where p.id = v_uid;

  if v_org is null or v_role not in ('administrator','super_admin') then
    raise exception 'Risk scans are restricted to organization administrators and top leadership';
  end if;

  -- Preserve the existing duplicate-payment, split-purchase and high-value rules.
  v_base := public.scan_fraud_risks_finance_base();

  -- Rule 4: sensitive changes recorded in the append-only operational audit ledger.
  -- Actor level does not exempt the event; sensitive mutations by leaders are included.
  with sensitive as (
    select l.id, l.organization_id, l.entity_type, l.entity_id, l.action_type,
           l.actor_id, l.occurred_at, l.pre_state_payload, l.post_state_payload,
           l.device_fingerprint_hash, l.location_evidence
      from public.operational_audit_ledger l
     where l.organization_id = v_org
       and (
         lower(coalesce(l.entity_type,'')) ~ '(payroll|salary|employee|supplier|vendor|bank|payment|invoice|role|permission|access|approval|transaction|account)'
         or lower(coalesce(l.action_type,'')) ~ '(delete|update|change|override|approve|reject|export|role|permission|payroll|salary|bank|payment|supplier|vendor|account)'
         or coalesce(l.pre_state_payload,'{}'::jsonb) ?| array['salary','bank_account','account_number','supplier_bank_account','role','permissions','approval_status','amount','vendor_id']
         or coalesce(l.post_state_payload,'{}'::jsonb) ?| array['salary','bank_account','account_number','supplier_bank_account','role','permissions','approval_status','amount','vendor_id']
       )
  ), ins as (
    insert into public.fraud_alerts
      (organization_id, rule_key, severity, status, title, summary,
       source_table, source_record_id, fingerprint, evidence)
    select s.organization_id, 'sensitive_record_change',
           case
             when lower(coalesce(s.action_type,'')) ~ '(delete|override|role|permission|bank|payroll|salary)'
               or lower(coalesce(s.entity_type,'')) ~ '(role|permission|payroll|bank|payment)'
             then 'high' else 'medium'
           end,
           'open', 'Sensitive record or control change requires review',
           'A sensitive record or control-related action was recorded. Verify the actor, before/after values, approval trail and supporting evidence. This is a risk indicator, not a finding of misconduct.',
           'operational_audit_ledger', s.id::text,
           md5(concat_ws('|','sensitive_record_change',s.organization_id,s.id)),
           jsonb_build_object(
             'ledger_id',s.id,'entity_type',s.entity_type,'entity_id',s.entity_id,
             'action_type',s.action_type,'actor_id',s.actor_id,'occurred_at',s.occurred_at,
             'pre_state',coalesce(s.pre_state_payload,'{}'::jsonb),
             'post_state',coalesce(s.post_state_payload,'{}'::jsonb),
             'device_fingerprint_hash',s.device_fingerprint_hash,
             'location_evidence',s.location_evidence,'rule_version',2
           )
      from sensitive s
    on conflict (organization_id, fingerprint) do nothing
    returning 1
  )
  select count(*) into v_extra from ins;

  -- Rule 5: bursts of privileged/security-sensitive activity by one actor.
  -- This detects patterns across staff and leadership; it does not assume guilt.
  with bursts as (
    select e.organization_id, e.actor_id,
           date_trunc('minute', e.created_at) as window_minute,
           count(*) as event_count,
           min(e.created_at) as first_event,
           max(e.created_at) as last_event,
           array_agg(e.id order by e.created_at) as event_ids,
           array_agg(e.action order by e.created_at) as actions
      from public.audit_events e
     where e.organization_id = v_org
       and e.actor_id is not null
       and e.created_at >= now() - interval '24 hours'
       and lower(coalesce(e.action,'')) ~ '(role|permission|privilege|approve|override|delete|export|payroll|salary|bank|payment|supplier|vendor|access|security|impersonat)'
     group by e.organization_id, e.actor_id, date_trunc('minute', e.created_at)
    having count(*) >= 5
  ), ins as (
    insert into public.fraud_alerts
      (organization_id, rule_key, severity, status, title, summary,
       source_table, source_record_id, fingerprint, evidence)
    select b.organization_id, 'privileged_activity_burst',
           case when b.event_count >= 10 then 'critical' else 'high' end,
           'open', 'Unusual burst of sensitive actions',
           format('%s sensitive audit events by one actor were recorded within the same minute. Independently verify the session, business justification and approval trail.',
                  b.event_count),
           'audit_events', b.event_ids[1]::text,
           md5(concat_ws('|','privileged_activity_burst',b.organization_id,b.actor_id,b.window_minute)),
           jsonb_build_object('actor_id',b.actor_id,'event_count',b.event_count,
             'window_start',b.first_event,'window_end',b.last_event,
             'event_ids',b.event_ids,'actions',b.actions,'rule_version',2)
      from bursts b
    on conflict (organization_id, fingerprint) do nothing
    returning 1
  )
  select v_extra + count(*) into v_extra from ins;

  return jsonb_build_object(
    'success', true,
    'new_alerts', coalesce((v_base->>'new_alerts')::integer,0) + v_extra,
    'organization_id', v_org,
    'rules_run', v_rule_count,
    'message', 'Organisation-wide risk scan completed. Alerts require independent human review.',
    'coverage', jsonb_build_array(
      'duplicate transactions','possible split purchases','high-value transactions',
      'sensitive record and control changes','bursts of privileged/security-sensitive activity'
    )
  );
end;
$function$;

revoke all on function public.scan_fraud_risks() from public;
grant execute on function public.scan_fraud_risks() to authenticated;

comment on function public.scan_fraud_risks() is
'Organisation-scoped risk scanner: finance anomalies, sensitive audit-ledger changes, and bursts of privileged/security-sensitive activity. Alerts are leads for human review, not determinations of fraud.';

commit;
