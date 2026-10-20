-- Recurring card subscriptions via IntaSend, plus safe manual M-Pesa renewals.
alter table public.billing_subscriptions
  add column if not exists provider_customer_id text,
  add column if not exists provider_plan_id text,
  add column if not exists provider_setup_url text,
  add column if not exists provider_subscription_status text,
  add column if not exists next_billing_at date,
  add column if not exists provider_subscription_failure_reason text,
  add column if not exists completed_cycles integer not null default 0;

create unique index if not exists billing_subscriptions_provider_subscription_id_key
  on public.billing_subscriptions(provider_subscription_id)
  where provider_subscription_id is not null;

alter table public.billing_provider_events
  alter column provider_invoice_id drop not null,
  add column if not exists provider_subscription_id text;

create or replace function public.fn_get_billing_overview()
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_org uuid;
  v_role text;
  v_subscription jsonb;
  v_payments jsonb;
  v_plans jsonb;
begin
  if v_user is null then raise exception 'authentication required'; end if;
  select p.organization_id, p.role into v_org, v_role
    from public.profiles p where p.id = v_user;
  if not found or v_org is null then raise exception 'organization profile required'; end if;
  if v_role not in ('administrator','super_admin') then raise exception 'organization administrator required'; end if;

  select jsonb_build_object(
    'id', s.id, 'plan_id', s.plan_id, 'status', s.status,
    'payment_method', s.payment_method,
    'current_period_start', s.current_period_start,
    'current_period_end', s.current_period_end,
    'cancel_at_period_end', s.cancel_at_period_end,
    'provider_subscription_status', s.provider_subscription_status,
    'provider_setup_url', s.provider_setup_url,
    'provider_subscription_failure_reason', s.provider_subscription_failure_reason,
    'next_billing_at', s.next_billing_at,
    'completed_cycles', s.completed_cycles,
    'plan', jsonb_build_object('name', p.name, 'amount', p.amount,
      'currency', p.currency, 'interval_unit', p.interval_unit, 'interval_count', p.interval_count)
  ) into v_subscription
  from public.billing_subscriptions s
  join public.billing_plans p on p.id = s.plan_id
  where s.organization_id = v_org and s.status in ('pending','active','past_due')
  order by s.created_at desc limit 1;

  select coalesce(jsonb_agg(jsonb_build_object(
    'api_ref', x.api_ref, 'amount', x.amount, 'currency', x.currency,
    'payment_method', x.payment_method, 'status', x.status,
    'provider_state', x.provider_state, 'created_at', x.created_at
  ) order by x.created_at desc), '[]'::jsonb) into v_payments
  from (
    select a.api_ref, a.amount, a.currency, a.payment_method, a.status,
      a.provider_state, a.created_at
    from public.billing_payment_attempts a
    where a.organization_id = v_org
    order by a.created_at desc limit 10
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', p.id, 'name', p.name, 'description', p.description,
    'amount', p.amount, 'currency', p.currency, 'interval_unit', p.interval_unit,
    'interval_count', p.interval_count
  ) order by p.amount), '[]'::jsonb) into v_plans
  from public.billing_plans p where p.is_active = true;

  return jsonb_build_object('subscription', v_subscription, 'payments', v_payments, 'plans', v_plans);
end;
$$;
revoke all on function public.fn_get_billing_overview() from public, anon;
grant execute on function public.fn_get_billing_overview() to authenticated;

create or replace function public.fn_reconcile_intasend_payment(
  p_event_key text, p_topic text, p_invoice_id text, p_api_ref text,
  p_provider_state text, p_provider_reference text, p_amount numeric,
  p_currency text, p_failure_reason text default null
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_attempt public.billing_payment_attempts%rowtype;
  v_plan public.billing_plans%rowtype;
  v_sub public.billing_subscriptions%rowtype;
  v_event_id bigint;
  v_processed_at timestamptz;
  v_state text := upper(coalesce(p_provider_state, ''));
  v_mapped text;
  v_now timestamptz := now();
  v_period_start timestamptz;
  v_period_end timestamptz;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'service_role required'; end if;
  if p_topic not in ('collection_event','subscription_event') or coalesce(p_event_key, '') = ''
     or coalesce(p_invoice_id, '') = '' or coalesce(p_api_ref, '') = '' then
    raise exception 'invalid payment event';
  end if;
  if v_state = 'COMPLETE' then v_mapped := 'paid';
  elsif v_state = 'FAILED' then v_mapped := 'failed';
  elsif v_state in ('CANCELED','CANCELLED') then v_mapped := 'cancelled';
  elsif v_state in ('PENDING','PROCESSING','RETRY','PARTIAL') then v_mapped := 'processing';
  else raise exception 'unsupported verified provider state'; end if;
  select * into v_attempt from public.billing_payment_attempts where api_ref = p_api_ref for update;
  if not found then raise exception 'payment attempt not found'; end if;
  if v_attempt.provider_invoice_id is not null and v_attempt.provider_invoice_id <> p_invoice_id then
    raise exception 'provider invoice does not match payment attempt';
  end if;
  if v_attempt.amount <> p_amount or v_attempt.currency <> p_currency then
    raise exception 'provider amount or currency does not match payment attempt';
  end if;
  if p_topic = 'subscription_event' then
    select * into v_sub from public.billing_subscriptions where id = v_attempt.subscription_id for update;
    if not found or v_sub.provider_subscription_id is null then
      raise exception 'provider subscription mapping not found';
    end if;
  end if;
  insert into public.billing_provider_events(event_key, topic, provider_invoice_id,
      provider_subscription_id)
    values (p_event_key, p_topic, p_invoice_id,
      case when p_topic = 'subscription_event' then v_sub.provider_subscription_id else null end)
    on conflict (event_key) do nothing returning id into v_event_id;
  if v_event_id is null then
    select id, processed_at into v_event_id, v_processed_at
      from public.billing_provider_events where event_key = p_event_key;
    if v_processed_at is not null then
      return jsonb_build_object('ok', true, 'duplicate', true, 'status', v_attempt.status);
    end if;
  end if;
  update public.billing_payment_attempts
    set provider_invoice_id = coalesce(provider_invoice_id, p_invoice_id),
        provider_state = v_state,
        provider_reference = coalesce(p_provider_reference, provider_reference),
        status = case when status = 'paid' then 'paid' else v_mapped end,
        failure_reason = case when v_mapped in ('failed','cancelled') and status <> 'paid'
                              then coalesce(p_failure_reason, v_state) else failure_reason end,
        verified_at = case when v_mapped = 'paid' then coalesce(verified_at, v_now) else verified_at end,
        updated_at = v_now
    where id = v_attempt.id;
  if v_mapped = 'paid' and v_attempt.status <> 'paid' then
    if v_attempt.subscription_id is null then raise exception 'payment attempt has no subscription'; end if;
    select * into v_plan from public.billing_plans where id = v_attempt.plan_id;
    if not found then raise exception 'billing plan not found'; end if;
    select * into v_sub from public.billing_subscriptions where id = v_attempt.subscription_id for update;
    if not found then raise exception 'subscription not found'; end if;
    if v_sub.status = 'cancelled' then
      update public.billing_provider_events set processed_at = v_now, processing_error = 'paid invoice received after subscription cancellation'
        where event_key = p_event_key;
      return jsonb_build_object('ok', true, 'duplicate', false, 'status', 'cancelled', 'requires_review', true);
    end if;
    select case when s.current_period_end > v_now then s.current_period_end else v_now end
      into v_period_start from public.billing_subscriptions s where s.id = v_attempt.subscription_id;
    v_period_end := v_period_start + case
      when v_plan.interval_unit = 'year' then make_interval(months => 12 * v_plan.interval_count)
      else make_interval(months => v_plan.interval_count) end;
    update public.billing_subscriptions
      set status = 'active', current_period_start = v_period_start,
          current_period_end = v_period_end, cancel_at_period_end = false, updated_at = v_now
      where id = v_attempt.subscription_id;
    if not found then raise exception 'subscription activation failed'; end if;
  end if;
  update public.billing_provider_events set processed_at = v_now, processing_error = null where event_key = p_event_key;
  return jsonb_build_object('ok', true, 'duplicate', false,
    'status', case when v_attempt.status = 'paid' then 'paid' else v_mapped end);
end;
$$;
revoke all on function public.fn_reconcile_intasend_payment(text,text,text,text,text,text,numeric,text,text) from public, anon, authenticated;
grant execute on function public.fn_reconcile_intasend_payment(text,text,text,text,text,text,numeric,text,text) to service_role;

create or replace function public.fn_sync_intasend_subscription_status(
  p_event_key text, p_provider_subscription_id text, p_reference text,
  p_provider_status text, p_next_date date, p_completed_cycles integer,
  p_fail_reason text default null
)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
  v_sub public.billing_subscriptions%rowtype;
  v_event_id bigint;
  v_processed_at timestamptz;
  v_state text := upper(coalesce(p_provider_status,''));
  v_now timestamptz := now();
  v_status text;
begin
  if coalesce(auth.role(),'') <> 'service_role' then raise exception 'service_role required'; end if;
  if coalesce(p_event_key,'') = '' or coalesce(p_provider_subscription_id,'') = ''
     or coalesce(p_reference,'') = '' then raise exception 'invalid subscription event'; end if;
  if v_state not in ('PENDING','ACTIVE','CANCELED','COMPLETE','FAILED') then raise exception 'unsupported subscription state'; end if;

  select * into v_sub from public.billing_subscriptions
    where id::text = p_reference for update;
  if not found or v_sub.payment_method <> 'card' then raise exception 'OfficeFlow card subscription not found'; end if;
  if v_sub.provider_subscription_id is not null and v_sub.provider_subscription_id <> p_provider_subscription_id then
    raise exception 'provider subscription ID mismatch';
  end if;

  insert into public.billing_provider_events(event_key,topic,provider_invoice_id,provider_subscription_id)
    values(p_event_key,'subscription_event',null,p_provider_subscription_id)
    on conflict(event_key) do nothing returning id into v_event_id;
  if v_event_id is null then
    select id,processed_at into v_event_id,v_processed_at from public.billing_provider_events where event_key=p_event_key;
    if v_processed_at is not null then return jsonb_build_object('ok',true,'duplicate',true,'status',v_sub.status); end if;
  end if;

  v_status := case
    when v_state in ('CANCELED','COMPLETE') then 'cancelled'
    when v_state = 'FAILED' then 'past_due'
    when v_state = 'ACTIVE' and exists (
      select 1 from public.billing_payment_attempts a
      where a.subscription_id=v_sub.id and a.status='paid'
    ) then 'active'
    when v_state='PENDING' and v_sub.status='pending' then 'pending'
    else v_sub.status
  end;

  update public.billing_subscriptions
    set provider_subscription_id = coalesce(provider_subscription_id,p_provider_subscription_id),
        provider_subscription_status = v_state,
        next_billing_at = coalesce(p_next_date,next_billing_at),
        completed_cycles = greatest(completed_cycles,coalesce(p_completed_cycles,0)),
        provider_subscription_failure_reason = case when v_state='FAILED' then coalesce(p_fail_reason,v_state) else null end,
        status = v_status,
        current_period_end = case
          when v_status='active' and p_next_date is not null then p_next_date::timestamptz
          else current_period_end end,
        updated_at = v_now
    where id=v_sub.id;

  update public.billing_provider_events set processed_at=v_now,processing_error=null where event_key=p_event_key;
  return jsonb_build_object('ok',true,'duplicate',false,'status',v_status);
end;
$$;
revoke all on function public.fn_sync_intasend_subscription_status(text,text,text,text,date,integer,text) from public, anon, authenticated;
grant execute on function public.fn_sync_intasend_subscription_status(text,text,text,text,date,integer,text) to service_role;
