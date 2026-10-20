-- Keep billing tables out of direct client/GraphQL reads; expose a scoped read RPC.
create or replace function public.fn_get_billing_overview()
returns jsonb
language plpgsql
security definer
set search_path = ''
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
    'id', s.id, 'status', s.status,
    'current_period_start', s.current_period_start,
    'current_period_end', s.current_period_end,
    'plan', jsonb_build_object('name', p.name, 'amount', p.amount,
      'currency', p.currency, 'interval_unit', p.interval_unit)
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
    'interval_count', p.interval_count, 'seat_limit', p.seat_limit
  ) order by p.amount), '[]'::jsonb) into v_plans
  from public.billing_plans p where p.is_active = true;

  return jsonb_build_object('subscription', v_subscription, 'payments', v_payments, 'plans', v_plans);
end;
$$;
revoke all on function public.fn_get_billing_overview() from public, anon, authenticated;
grant execute on function public.fn_get_billing_overview() to authenticated;

revoke select on public.billing_plans from anon, authenticated;
revoke select on public.billing_subscriptions from anon, authenticated;
revoke select on public.billing_payment_attempts from anon, authenticated;
