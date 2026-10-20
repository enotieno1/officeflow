-- Atomic, idempotent server-side reconciliation of verified IntaSend payment states.
create or replace function public.fn_reconcile_intasend_payment(
  p_event_key text,
  p_topic text,
  p_invoice_id text,
  p_api_ref text,
  p_provider_state text,
  p_provider_reference text,
  p_amount numeric,
  p_currency text,
  p_failure_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt public.billing_payment_attempts%rowtype;
  v_plan public.billing_plans%rowtype;
  v_event_id bigint;
  v_processed_at timestamptz;
  v_state text := upper(coalesce(p_provider_state, ''));
  v_mapped text;
  v_now timestamptz := now();
  v_period_start timestamptz;
  v_period_end timestamptz;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'service_role required';
  end if;
  if p_topic <> 'collection_event' or coalesce(p_event_key, '') = ''
     or coalesce(p_invoice_id, '') = '' or coalesce(p_api_ref, '') = '' then
    raise exception 'invalid payment event';
  end if;
  if v_state = 'COMPLETE' then v_mapped := 'paid';
  elsif v_state = 'FAILED' then v_mapped := 'failed';
  elsif v_state in ('CANCELED','CANCELLED') then v_mapped := 'cancelled';
  elsif v_state in ('PENDING','PROCESSING','RETRY','PARTIAL') then v_mapped := 'processing';
  else raise exception 'unsupported verified provider state'; end if;

  select * into v_attempt
    from public.billing_payment_attempts
    where api_ref = p_api_ref
    for update;
  if not found then raise exception 'payment attempt not found'; end if;
  if v_attempt.provider_invoice_id is not null and v_attempt.provider_invoice_id <> p_invoice_id then
    raise exception 'provider invoice does not match payment attempt';
  end if;
  if v_attempt.amount <> p_amount or v_attempt.currency <> p_currency then
    raise exception 'provider amount or currency does not match payment attempt';
  end if;

  insert into public.billing_provider_events(event_key, topic, provider_invoice_id)
    values (p_event_key, p_topic, p_invoice_id)
    on conflict (event_key) do nothing
    returning id into v_event_id;

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
                              then coalesce(p_failure_reason, v_state)
                              else failure_reason end,
        verified_at = case when v_mapped = 'paid' then coalesce(verified_at, v_now) else verified_at end,
        updated_at = v_now
    where id = v_attempt.id;

  if v_mapped = 'paid' and v_attempt.status <> 'paid' then
    if v_attempt.subscription_id is null then
      raise exception 'payment attempt has no subscription';
    end if;
    select * into v_plan from public.billing_plans where id = v_attempt.plan_id;
    if not found then raise exception 'billing plan not found'; end if;

    v_period_start := case
      when v_attempt.subscription_id is not null and exists (
        select 1 from public.billing_subscriptions s
        where s.id = v_attempt.subscription_id and s.current_period_end > v_now
      ) then (select s.current_period_end from public.billing_subscriptions s where s.id = v_attempt.subscription_id)
      else v_now
    end;
    v_period_end := v_period_start + case
      when v_plan.interval_unit = 'year' then make_interval(months => 12 * v_plan.interval_count)
      else make_interval(months => v_plan.interval_count)
    end;

    update public.billing_subscriptions
      set status = 'active',
          current_period_start = v_period_start,
          current_period_end = v_period_end,
          cancel_at_period_end = false,
          updated_at = v_now
      where id = v_attempt.subscription_id;
    if not found then raise exception 'subscription not found'; end if;
  end if;

  update public.billing_provider_events
    set processed_at = v_now, processing_error = null
    where event_key = p_event_key;

  return jsonb_build_object('ok', true, 'duplicate', false,
    'status', case when v_attempt.status = 'paid' then 'paid' else v_mapped end);
end;
$$;

revoke all on function public.fn_reconcile_intasend_payment(text,text,text,text,text,text,numeric,text,text) from public, anon, authenticated;
grant execute on function public.fn_reconcile_intasend_payment(text,text,text,text,text,text,numeric,text,text) to service_role;
