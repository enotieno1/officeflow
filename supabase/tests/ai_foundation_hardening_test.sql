-- Run after 20261106150000_ai_usage_controls_v2.sql in an isolated database.
-- These assertions verify migration structure and ACLs; user/tenant behavioural tests
-- require authenticated test identities and are listed in the accompanying test plan.

do $test$
begin
  if to_regclass('public.ai_org_limits') is null then
    raise exception 'Missing ai_org_limits';
  end if;
  if to_regclass('public.ai_model_pricing') is null then
    raise exception 'Missing ai_model_pricing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='ai_usage_log' and column_name='request_id'
  ) then raise exception 'Missing ai_usage_log.request_id'; end if;

  if not exists (
    select 1 from pg_indexes
    where schemaname='public' and indexname='ai_usage_log_request_id_uidx'
  ) then raise exception 'Missing unique request id index'; end if;

  if has_function_privilege('authenticated',
    'public.fn_ai_reserve(uuid,uuid,uuid,text,integer,integer)', 'EXECUTE') then
    raise exception 'authenticated must not execute fn_ai_reserve';
  end if;
  if not has_function_privilege('service_role',
    'public.fn_ai_reserve(uuid,uuid,uuid,text,integer,integer)', 'EXECUTE') then
    raise exception 'service_role must execute fn_ai_reserve';
  end if;

  if has_function_privilege('authenticated',
    'public.fn_ai_finalize(uuid,uuid,uuid,text,text,integer,integer,integer,integer,text,text,text[])', 'EXECUTE') then
    raise exception 'authenticated must not execute fn_ai_finalize';
  end if;
  if not has_function_privilege('service_role',
    'public.fn_ai_finalize(uuid,uuid,uuid,text,text,integer,integer,integer,integer,text,text,text[])', 'EXECUTE') then
    raise exception 'service_role must execute fn_ai_finalize';
  end if;

  if has_function_privilege('authenticated',
    'public.fn_ai_record_recommendation_trusted(uuid,uuid,text,text,text,jsonb,text)', 'EXECUTE') then
    raise exception 'authenticated must not execute trusted recommendation recorder';
  end if;
  if not has_function_privilege('service_role',
    'public.fn_ai_record_recommendation_trusted(uuid,uuid,text,text,text,jsonb,text)', 'EXECUTE') then
    raise exception 'service_role must execute trusted recommendation recorder';
  end if;

  if exists (
    select 1 from public.ai_model_pricing
  ) then
    raise exception 'Pricing table must remain unseeded until current provider prices are verified';
  end if;

  if not (
    select relrowsecurity from pg_class where oid='public.ai_org_limits'::regclass
  ) then
    raise exception 'ai_org_limits must have row-level security enabled';
  end if;

  if has_table_privilege('authenticated','public.ai_org_limits','INSERT')
     or has_table_privilege('authenticated','public.ai_org_limits','UPDATE')
     or has_table_privilege('authenticated','public.ai_org_limits','DELETE') then
    raise exception 'Authenticated users must not modify AI organisation limits';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid='public.ai_usage_log'::regclass
      and conname='ai_usage_log_status_check'
  ) then
    raise exception 'Missing expanded usage status constraint';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='fn_ai_reserve'
      and p.prosecdef
      and pg_get_function_arguments(p.oid) like '%p_request_id uuid%'
  ) then
    raise exception 'Reservation function must exist as SECURITY DEFINER';
  end if;

  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='fn_ai_finalize'
      and p.prosecdef
  ) then
    raise exception 'Finalisation function must exist as SECURITY DEFINER';
  end if;
end;
$test$;

-- Required authenticated integration tests (run with real test JWTs):
-- 1. Tenant A user can reserve only against the organisation derived from their profile.
-- 2. Same request UUID cannot create a second reservation.
-- 3. Concurrent calls at a daily or monthly limit cannot exceed that limit.
-- 4. Provider failures and timeouts remain counted as requests.
-- 5. Cross-user and cross-tenant finalisation attempts are rejected.
-- 6. Re-finalisation of a completed reservation is rejected.
-- 7. Negative tokens/latency and unknown provider/status values are rejected.
-- 8. Manager cannot retrieve another unit's workflow analytics.
-- 9. Auditor can read permitted usage/recommendations but cannot decide recommendations.
-- 10. Recommendation decision rolls back if audit_events insertion fails.
-- 11. Direct authenticated calls to reserve/finalise/trusted recorder are denied.
