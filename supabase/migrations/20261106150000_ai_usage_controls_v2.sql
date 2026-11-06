-- OfficeFlow AI usage controls v2
-- Forward-only migration. Apply to an isolated Supabase branch first.
-- Production migration history already contains 20261106103130_ai_foundation_usage_recommendations_timing.
-- This migration intentionally does not rewrite or replay that historical migration.

begin;

alter table public.ai_usage_log
  add column if not exists request_id uuid,
  add column if not exists provider text,
  add column if not exists prompt_tokens integer,
  add column if not exists completion_tokens integer,
  add column if not exists total_tokens integer,
  add column if not exists estimated_cost_usd numeric(14,8),
  add column if not exists latency_ms integer,
  add column if not exists error_code text,
  add column if not exists finalized_at timestamptz,
  add column if not exists reserved_tokens integer not null default 0;

alter table public.ai_usage_log
  drop constraint if exists ai_usage_log_status_check;

alter table public.ai_usage_log
  add constraint ai_usage_log_status_check
  check (status in (
    'ok','provider_error','blocked','not_configured','reserved',
    'quota_exceeded','rate_limited','timeout','invalid_response'
  )) not valid;

alter table public.ai_usage_log
  validate constraint ai_usage_log_status_check;

alter table public.ai_usage_log
  add constraint ai_usage_log_token_values_nonnegative
  check (
    coalesce(prompt_tokens,0) >= 0 and
    coalesce(completion_tokens,0) >= 0 and
    coalesce(total_tokens,0) >= 0 and
    reserved_tokens >= 0 and
    coalesce(latency_ms,0) >= 0 and
    coalesce(estimated_cost_usd,0) >= 0
  ) not valid;

alter table public.ai_usage_log
  validate constraint ai_usage_log_token_values_nonnegative;

create unique index if not exists ai_usage_log_request_id_uidx
  on public.ai_usage_log(request_id) where request_id is not null;

create index if not exists ai_usage_log_org_created_idx
  on public.ai_usage_log(organization_id, created_at desc);

create index if not exists ai_usage_log_user_created_idx
  on public.ai_usage_log(user_id, created_at desc);

create table if not exists public.ai_org_limits (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  daily_user_requests integer not null default 100,
  daily_org_requests integer not null default 1000,
  monthly_token_limit bigint not null default 1000000,
  max_request_tokens integer not null default 12000,
  monthly_cost_limit_usd numeric(14,4),
  updated_at timestamptz not null default now(),
  constraint ai_org_limits_daily_user_check check (daily_user_requests between 1 and 100000),
  constraint ai_org_limits_daily_org_check check (daily_org_requests between 1 and 1000000),
  constraint ai_org_limits_monthly_tokens_check check (monthly_token_limit between 1 and 1000000000),
  constraint ai_org_limits_request_tokens_check check (max_request_tokens between 1 and 200000)
);

alter table public.ai_org_limits enable row level security;
drop policy if exists ai_org_limits_admin_read on public.ai_org_limits;
create policy ai_org_limits_admin_read on public.ai_org_limits
for select to authenticated
using (
  organization_id = (select p.organization_id from public.profiles p where p.id = (select auth.uid()))
  and (select p.role from public.profiles p where p.id = (select auth.uid()))
      in ('administrator','super_admin','auditor')
);
revoke insert, update, delete, truncate on public.ai_org_limits from anon, authenticated;
grant select on public.ai_org_limits to authenticated;

create table if not exists public.ai_model_pricing (
  provider text not null,
  model text not null,
  effective_from timestamptz not null,
  input_usd_per_million numeric(14,8) not null check (input_usd_per_million >= 0),
  output_usd_per_million numeric(14,8) not null check (output_usd_per_million >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (provider, model, effective_from)
);

alter table public.ai_model_pricing enable row level security;
revoke all on public.ai_model_pricing from anon, authenticated;
grant all on public.ai_model_pricing to service_role;

-- Reserve an AI request atomically before calling the provider.
create or replace function public.fn_ai_reserve(
  p_user_id uuid,
  p_organization_id uuid,
  p_request_id uuid,
  p_feature text,
  p_input_chars integer,
  p_reserved_tokens integer
)
returns table (
  usage_id uuid,
  reserved_tokens integer,
  daily_user_remaining integer,
  daily_org_remaining integer,
  monthly_tokens_remaining bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_role text;
  v_limits public.ai_org_limits%rowtype;
  v_existing public.ai_usage_log%rowtype;
  v_user_count integer;
  v_org_count integer;
  v_month_tokens bigint;
  v_id uuid;
begin
  if p_user_id is null or p_organization_id is null or p_request_id is null then
    raise exception 'AI reservation requires verified user, organisation and request identifiers';
  end if;
  if p_feature is null or length(p_feature) not between 1 and 60 then
    raise exception 'Invalid AI feature';
  end if;
  if coalesce(p_input_chars,0) < 0 or p_input_chars > 96000 then
    raise exception 'Invalid input size';
  end if;

  select role into v_role
  from public.profiles
  where id = p_user_id and organization_id = p_organization_id;

  if v_role is null then
    raise exception 'User does not belong to the requested organisation';
  end if;

  insert into public.ai_org_limits(organization_id)
  values (p_organization_id)
  on conflict (organization_id) do nothing;

  select * into v_limits
  from public.ai_org_limits
  where organization_id = p_organization_id
  for update;

  if p_reserved_tokens is null or p_reserved_tokens < 1
     or p_reserved_tokens > v_limits.max_request_tokens then
    raise exception 'Requested token reservation exceeds the organisation request limit';
  end if;

  -- Serialise reservations for this tenant; the row lock above serialises limit edits.
  perform pg_advisory_xact_lock(hashtextextended(p_organization_id::text, 17));

  select * into v_existing
  from public.ai_usage_log
  where request_id = p_request_id
  for update;

  if found then
    if v_existing.user_id = p_user_id
       and v_existing.organization_id = p_organization_id
       and v_existing.status = 'reserved' then
      return query
      select v_existing.id, v_existing.reserved_tokens,
        greatest(v_limits.daily_user_requests - (
          select count(*)::integer from public.ai_usage_log
          where user_id = p_user_id and created_at >= date_trunc('day', now())
        ),0),
        greatest(v_limits.daily_org_requests - (
          select count(*)::integer from public.ai_usage_log
          where organization_id = p_organization_id and created_at >= date_trunc('day', now())
        ),0),
        greatest(v_limits.monthly_token_limit - (
          select coalesce(sum(coalesce(total_tokens,0) + reserved_tokens),0)::bigint
          from public.ai_usage_log
          where organization_id = p_organization_id
            and created_at >= date_trunc('month', now())
        ),0);
      return;
    end if;
    raise exception 'Request identifier already exists or is no longer reservable';
  end if;

  select count(*)::integer into v_user_count
  from public.ai_usage_log
  where user_id = p_user_id and created_at >= date_trunc('day', now());

  select count(*)::integer into v_org_count
  from public.ai_usage_log
  where organization_id = p_organization_id and created_at >= date_trunc('day', now());

  select coalesce(sum(coalesce(total_tokens,0) + reserved_tokens),0)::bigint
  into v_month_tokens
  from public.ai_usage_log
  where organization_id = p_organization_id
    and created_at >= date_trunc('month', now());

  if v_user_count >= v_limits.daily_user_requests then
    raise exception 'AI daily user request quota exceeded' using errcode = 'P0001';
  end if;
  if v_org_count >= v_limits.daily_org_requests then
    raise exception 'AI daily organisation request quota exceeded' using errcode = 'P0001';
  end if;
  if v_month_tokens + p_reserved_tokens > v_limits.monthly_token_limit then
    raise exception 'AI monthly token quota exceeded' using errcode = 'P0001';
  end if;

  insert into public.ai_usage_log(
    organization_id,user_id,feature,input_chars,output_chars,status,
    grounded_sources,request_id,reserved_tokens,finalized_at
  ) values (
    p_organization_id,p_user_id,p_feature,p_input_chars,0,'reserved',
    '{}',p_request_id,p_reserved_tokens,null
  ) returning id into v_id;

  return query
  select v_id, p_reserved_tokens,
    greatest(v_limits.daily_user_requests - v_user_count - 1,0),
    greatest(v_limits.daily_org_requests - v_org_count - 1,0),
    greatest(v_limits.monthly_token_limit - v_month_tokens - p_reserved_tokens,0);
end;
$function$;

-- Finalise only the exact reservation. The caller is the trusted Edge Function.
create or replace function public.fn_ai_finalize(
  p_usage_id uuid,
  p_user_id uuid,
  p_organization_id uuid,
  p_provider text,
  p_model text,
  p_prompt_tokens integer,
  p_completion_tokens integer,
  p_latency_ms integer,
  p_status text,
  p_error_code text,
  p_sources text[]
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_row public.ai_usage_log%rowtype;
  v_cost numeric(14,8);
begin
  if p_usage_id is null or p_user_id is null or p_organization_id is null then
    raise exception 'Finalisation requires reservation, user and organisation identifiers';
  end if;
  if coalesce(p_prompt_tokens,0) < 0 or coalesce(p_completion_tokens,0) < 0
     or coalesce(p_latency_ms,0) < 0 then
    raise exception 'Token counts and latency must be non-negative';
  end if;
  if p_status not in ('ok','provider_error','not_configured','timeout','invalid_response','blocked') then
    raise exception 'Invalid final AI usage status';
  end if;
  if p_provider is not null and p_provider not in ('openai') then
    raise exception 'Unrecognised AI provider';
  end if;
  if p_model is not null and length(p_model) > 120 then
    raise exception 'Invalid model identifier';
  end if;

  select * into v_row
  from public.ai_usage_log
  where id = p_usage_id
  for update;

  if not found then raise exception 'AI reservation not found'; end if;
  if v_row.user_id <> p_user_id or v_row.organization_id <> p_organization_id then
    raise exception 'AI reservation ownership mismatch';
  end if;
  if v_row.status <> 'reserved' then
    raise exception 'AI reservation has already been finalised';
  end if;

  if p_provider is not null and p_model is not null then
    select (
      coalesce(p_prompt_tokens,0)::numeric * input_usd_per_million +
      coalesce(p_completion_tokens,0)::numeric * output_usd_per_million
    ) / 1000000
    into v_cost
    from public.ai_model_pricing
    where provider = p_provider and model = p_model
      and is_active and effective_from <= now()
    order by effective_from desc
    limit 1;
  end if;

  update public.ai_usage_log
  set provider = p_provider,
      model = p_model,
      prompt_tokens = coalesce(p_prompt_tokens,0),
      completion_tokens = coalesce(p_completion_tokens,0),
      total_tokens = coalesce(p_prompt_tokens,0) + coalesce(p_completion_tokens,0),
      estimated_cost_usd = v_cost,
      latency_ms = p_latency_ms,
      error_code = left(p_error_code,120),
      grounded_sources = coalesce(p_sources,'{}'),
      output_chars = 0,
      status = p_status,
      reserved_tokens = 0,
      finalized_at = now()
  where id = p_usage_id;
end;
$function$;

-- Trusted server-side recommendation recorder. Does not rely on auth.uid().
create or replace function public.fn_ai_record_recommendation_trusted(
  p_user_id uuid,
  p_organization_id uuid,
  p_feature text,
  p_title text,
  p_summary text,
  p_evidence jsonb,
  p_confidence text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_role text;
  v_id uuid;
begin
  select role into v_role
  from public.profiles
  where id = p_user_id and organization_id = p_organization_id;

  if v_role not in ('manager','administrator','super_admin') then
    raise exception 'User is not authorised to record recommendations';
  end if;
  if p_feature is null or length(p_feature) not between 1 and 60 then
    raise exception 'Invalid recommendation feature';
  end if;
  if p_title is null or length(p_title) not between 1 and 200 then
    raise exception 'Invalid recommendation title';
  end if;
  if p_summary is null or length(p_summary) > 4000 then
    raise exception 'Invalid recommendation summary';
  end if;
  if octet_length(coalesce(p_evidence,'{}'::jsonb)::text) > 20000 then
    raise exception 'Recommendation evidence exceeds 20 KB';
  end if;
  if coalesce(p_confidence,'low') not in ('low','medium','high') then
    raise exception 'Invalid recommendation confidence';
  end if;

  insert into public.ai_recommendations(
    organization_id,feature,title,summary,evidence,confidence,created_by
  ) values (
    p_organization_id,p_feature,p_title,p_summary,coalesce(p_evidence,'{}'::jsonb),
    coalesce(p_confidence,'low'),p_user_id
  ) returning id into v_id;

  return v_id;
end;
$function$;

-- Audit recommendation decisions in the same transaction as the state change.
create or replace function private.fn_ai_decide_recommendation(p_id uuid, p_decision text)
returns void
language plpgsql
security definer
set search_path = public, private, pg_temp
as $function$
declare
  v_org uuid;
  v_role text;
  v_title text;
  v_feature text;
  n integer;
begin
  select organization_id, role into v_org, v_role
  from public.profiles where id = auth.uid();

  if v_org is null or v_role not in ('administrator','super_admin') then
    raise exception 'Only administrators can decide AI recommendations';
  end if;
  if p_decision not in ('accepted','dismissed') then
    raise exception 'Invalid recommendation decision';
  end if;

  update public.ai_recommendations
  set status = p_decision, decided_by = auth.uid(), decided_at = now()
  where id = p_id and organization_id = v_org and status = 'proposed'
  returning title, feature into v_title, v_feature;

  get diagnostics n = row_count;
  if n = 0 then raise exception 'Recommendation not found or already decided'; end if;

  insert into public.audit_events(organization_id,actor_id,action,details)
  values (
    v_org,auth.uid(),'ai_recommendation_decided',
    jsonb_build_object('recommendation_id',p_id,'decision',p_decision,'title',v_title,'feature',v_feature)
  );
  -- Any audit insert failure aborts this transaction and rolls back the decision.
end;
$function$;

-- Only the server-side service role may reserve/finalise usage or create recommendations.
revoke all on function public.fn_ai_reserve(uuid,uuid,uuid,text,integer,integer) from public, anon, authenticated;
revoke all on function public.fn_ai_finalize(uuid,uuid,uuid,text,text,integer,integer,integer,text,text,text[]) from public, anon, authenticated;
revoke all on function public.fn_ai_record_recommendation_trusted(uuid,uuid,text,text,text,jsonb,text) from public, anon, authenticated;
grant execute on function public.fn_ai_reserve(uuid,uuid,uuid,text,integer,integer) to service_role;
grant execute on function public.fn_ai_finalize(uuid,uuid,uuid,text,text,integer,integer,integer,text,text,text[]) to service_role;
grant execute on function public.fn_ai_record_recommendation_trusted(uuid,uuid,text,text,text,jsonb,text) to service_role;

revoke all on function private.fn_ai_decide_recommendation(uuid,text) from public, anon;
grant execute on function private.fn_ai_decide_recommendation(uuid,text) to authenticated;

commit;
