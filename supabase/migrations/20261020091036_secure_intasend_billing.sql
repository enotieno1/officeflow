-- OfficeFlow secure SaaS billing foundation.
-- No payment is marked successful by a browser redirect; only verified provider status may activate a subscription.

create table if not exists public.billing_plans (
  id text primary key,
  name text not null,
  description text,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'KES' check (currency = 'KES'),
  interval_unit text not null default 'month' check (interval_unit in ('month','year')),
  interval_count integer not null default 1 check (interval_count > 0),
  seat_limit integer check (seat_limit is null or seat_limit > 0),
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.billing_subscriptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  plan_id text not null references public.billing_plans(id) on delete restrict,
  status text not null default 'pending' check (status in ('pending','active','past_due','cancelled','expired')),
  payment_method text check (payment_method in ('mpesa','card')),
  provider text not null default 'intasend' check (provider = 'intasend'),
  provider_subscription_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  cancel_at_period_end boolean not null default false,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists billing_one_live_subscription_per_org
  on public.billing_subscriptions (organization_id)
  where status in ('pending','active','past_due');

create index if not exists billing_subscriptions_org_status_idx
  on public.billing_subscriptions (organization_id, status);

create table if not exists public.billing_payment_attempts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  subscription_id uuid references public.billing_subscriptions(id) on delete restrict,
  plan_id text not null references public.billing_plans(id) on delete restrict,
  initiated_by uuid references auth.users(id) on delete set null,
  provider text not null default 'intasend' check (provider = 'intasend'),
  payment_method text not null check (payment_method in ('mpesa','card')),
  api_ref text not null unique,
  provider_invoice_id text unique,
  provider_reference text,
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'KES' check (currency = 'KES'),
  status text not null default 'pending' check (status in ('pending','processing','paid','failed','cancelled')),
  provider_state text,
  checkout_url text,
  failure_reason text,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists billing_payment_attempts_org_created_idx
  on public.billing_payment_attempts (organization_id, created_at desc);

create table if not exists public.billing_provider_events (
  id bigint generated always as identity primary key,
  provider text not null default 'intasend' check (provider = 'intasend'),
  event_key text not null unique,
  topic text not null,
  provider_invoice_id text,
  received_at timestamptz not null default now(),
  processed_at timestamptz,
  processing_error text
);

alter table public.billing_plans enable row level security;
alter table public.billing_subscriptions enable row level security;
alter table public.billing_payment_attempts enable row level security;
alter table public.billing_provider_events enable row level security;

drop policy if exists billing_plans_read_active on public.billing_plans;
create policy billing_plans_read_active on public.billing_plans
  for select to authenticated using (is_active = true);

drop policy if exists billing_subscriptions_read_org_admin on public.billing_subscriptions;
create policy billing_subscriptions_read_org_admin on public.billing_subscriptions
  for select to authenticated using (
    organization_id = (select p.organization_id from public.profiles p where p.id = (select auth.uid()))
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.organization_id = billing_subscriptions.organization_id
        and p.role in ('administrator','super_admin')
    )
  );

drop policy if exists billing_payment_attempts_read_org_admin on public.billing_payment_attempts;
create policy billing_payment_attempts_read_org_admin on public.billing_payment_attempts
  for select to authenticated using (
    organization_id = (select p.organization_id from public.profiles p where p.id = (select auth.uid()))
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.organization_id = billing_payment_attempts.organization_id
        and p.role in ('administrator','super_admin')
    )
  );

revoke all on public.billing_plans from anon, authenticated;
revoke all on public.billing_subscriptions from anon, authenticated;
revoke all on public.billing_payment_attempts from anon, authenticated;
revoke all on public.billing_provider_events from anon, authenticated;
grant select on public.billing_plans to authenticated;
grant select on public.billing_subscriptions to authenticated;
grant select on public.billing_payment_attempts to authenticated;
revoke all on sequence public.billing_provider_events_id_seq from anon, authenticated;

comment on table public.billing_plans is 'Admin-managed OfficeFlow subscription price catalog; active plans are visible to signed-in users.';
comment on table public.billing_subscriptions is 'Authoritative tenant subscription state; writes only from trusted server-side billing functions.';
comment on table public.billing_payment_attempts is 'Payment attempts with provider identifiers and verified states; never stores card numbers or CVV.';
comment on table public.billing_provider_events is 'Server-side webhook idempotency and processing audit log; inaccessible to client roles.';
