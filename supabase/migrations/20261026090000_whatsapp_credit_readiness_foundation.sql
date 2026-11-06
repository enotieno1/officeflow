-- Secure foundation for WhatsApp webhook receipts, single-use flow tokens and consent-based readiness snapshots.
-- No client role can read or mutate these integration tables. Edge functions use the service role.
create table if not exists public.whatsapp_webhook_receipts (
  id uuid primary key default gen_random_uuid(),
  provider_event_key text not null unique,
  event_type text not null check (length(event_type) between 1 and 100),
  phone_number_id text,
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_status text not null default 'received'
    check (processing_status in ('received','processed','ignored','failed')),
  failure_code text,
  created_at timestamptz not null default now()
);

create table if not exists public.whatsapp_flow_tokens (
  id uuid primary key default gen_random_uuid(),
  token_digest text not null unique check (token_digest ~ '^[0-9a-f]{64}$'),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete cascade,
  allowed_action text not null check (allowed_action in ('task_acknowledge','read_summary','open_request')),
  entity_type text check (entity_type in ('task','request','summary')),
  entity_id text,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint whatsapp_flow_token_entity_consistent check (
    (allowed_action = 'task_acknowledge' and entity_type = 'task' and entity_id is not null)
    or (allowed_action = 'open_request' and entity_type = 'request' and entity_id is not null)
    or (allowed_action = 'read_summary' and entity_type = 'summary')
  ),
  constraint whatsapp_flow_token_expiry check (expires_at > created_at)
);

create index if not exists whatsapp_flow_tokens_actor_org_expiry_idx
  on public.whatsapp_flow_tokens (organization_id, actor_id, expires_at)
  where consumed_at is null and revoked_at is null;

create table if not exists public.credit_readiness_consents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  consented_by uuid not null references auth.users(id),
  purpose text not null check (purpose in ('internal_readiness','share_with_named_partner')),
  partner_name text,
  consent_version text not null,
  consented_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  constraint credit_readiness_partner_required check (
    (purpose = 'share_with_named_partner' and nullif(trim(partner_name),'') is not null)
    or purpose = 'internal_readiness'
  )
);

create index if not exists credit_readiness_active_consent_idx
  on public.credit_readiness_consents (organization_id, consented_at desc)
  where revoked_at is null;

create table if not exists public.credit_readiness_snapshots (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  generated_by uuid not null references auth.users(id),
  consent_id uuid not null references public.credit_readiness_consents(id),
  reporting_period_start date not null,
  reporting_period_end date not null,
  currency text not null default 'KES' check (currency = 'KES'),
  readiness_metrics jsonb not null default '{}'::jsonb,
  limitations jsonb not null default '[]'::jsonb,
  generated_at timestamptz not null default now(),
  constraint credit_readiness_period_valid check (reporting_period_end >= reporting_period_start),
  constraint credit_readiness_metrics_object check (jsonb_typeof(readiness_metrics) = 'object'),
  constraint credit_readiness_limitations_array check (jsonb_typeof(limitations) = 'array')
);

create index if not exists credit_readiness_snapshots_org_period_idx
  on public.credit_readiness_snapshots (organization_id, reporting_period_end desc);

alter table public.whatsapp_webhook_receipts enable row level security;
alter table public.whatsapp_flow_tokens enable row level security;
alter table public.credit_readiness_consents enable row level security;
alter table public.credit_readiness_snapshots enable row level security;

-- Deny access to anon/authenticated; service_role bypasses RLS for trusted edge functions.
revoke all on public.whatsapp_webhook_receipts from anon, authenticated;
revoke all on public.whatsapp_flow_tokens from anon, authenticated;
revoke all on public.credit_readiness_consents from anon, authenticated;
revoke all on public.credit_readiness_snapshots from anon, authenticated;
grant all on public.whatsapp_webhook_receipts to service_role;
grant all on public.whatsapp_flow_tokens to service_role;
grant all on public.credit_readiness_consents to service_role;
grant all on public.credit_readiness_snapshots to service_role;
