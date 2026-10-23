-- OfficeFlow payroll provider integration foundation.
-- No provider credentials or live transfers are created by this migration.
create table if not exists public.payroll_provider_accounts (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  provider text not null check (provider in ('safaricom_mpesa_b2c','bank_bulk')),
  account_label text not null,
  environment text not null default 'sandbox' check (environment in ('sandbox','production')),
  status text not null default 'not_configured' check (status in ('not_configured','pending_verification','active','suspended')),
  credential_secret_name text,
  business_shortcode text,
  callback_url text,
  created_by uuid not null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, provider, account_label)
);
create table if not exists public.payroll_payment_batches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  payroll_run_id uuid not null references public.payroll_runs(id) on delete restrict,
  provider_account_id uuid not null references public.payroll_provider_accounts(id) on delete restrict,
  provider text not null check (provider in ('safaricom_mpesa_b2c','bank_bulk')),
  currency text not null default 'KES' check (currency = 'KES'),
  total_amount numeric(14,2) not null check (total_amount > 0),
  item_count integer not null check (item_count > 0),
  status text not null default 'draft' check (status in ('draft','pending_approval','approved','submitting','processing','completed','partially_failed','failed','cancelled')),
  created_by uuid not null default auth.uid(),
  approved_by uuid,
  approved_at timestamptz,
  provider_batch_reference text,
  idempotency_key text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (organization_id, idempotency_key),
  constraint payroll_batch_separation_of_duties check (approved_by is null or approved_by <> created_by)
);
create table if not exists public.payroll_payment_transactions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  batch_id uuid not null references public.payroll_payment_batches(id) on delete restrict,
  payroll_item_id uuid not null references public.payroll_items(id) on delete restrict,
  provider text not null check (provider in ('safaricom_mpesa_b2c','bank_bulk')),
  amount numeric(14,2) not null check (amount > 0),
  currency text not null default 'KES' check (currency = 'KES'),
  destination_token text,
  provider_transaction_reference text,
  status text not null default 'queued' check (status in ('queued','submitted','processing','succeeded','failed','reversed','unknown')),
  failure_reason text,
  submitted_at timestamptz,
  confirmed_at timestamptz,
  last_provider_check_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (batch_id, payroll_item_id)
);
create table if not exists public.payroll_provider_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  provider text not null,
  event_key text not null,
  batch_id uuid references public.payroll_payment_batches(id) on delete set null,
  transaction_id uuid references public.payroll_payment_transactions(id) on delete set null,
  verified boolean not null default false,
  event_type text not null,
  event_payload jsonb not null default '{}'::jsonb,
  received_at timestamptz not null default now(),
  unique (provider, event_key)
);
create index if not exists payroll_payment_batches_org_status_idx on public.payroll_payment_batches (organization_id, status, created_at desc);
create index if not exists payroll_payment_transactions_org_status_idx on public.payroll_payment_transactions (organization_id, status, created_at desc);
create index if not exists payroll_provider_events_batch_idx on public.payroll_provider_events (batch_id, received_at desc);

alter table public.payroll_provider_accounts enable row level security;
alter table public.payroll_payment_batches enable row level security;
alter table public.payroll_payment_transactions enable row level security;
alter table public.payroll_provider_events enable row level security;

drop policy if exists payroll_provider_accounts_read_admin on public.payroll_provider_accounts;
create policy payroll_provider_accounts_read_admin on public.payroll_provider_accounts
for select to authenticated using (
 organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
 and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin','auditor')
);
drop policy if exists payroll_payment_batches_read_admin on public.payroll_payment_batches;
create policy payroll_payment_batches_read_admin on public.payroll_payment_batches
for select to authenticated using (
 organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
 and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin','auditor')
);
drop policy if exists payroll_payment_transactions_read_admin on public.payroll_payment_transactions;
create policy payroll_payment_transactions_read_admin on public.payroll_payment_transactions
for select to authenticated using (
 organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
 and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin','auditor')
);
drop policy if exists payroll_provider_events_read_admin on public.payroll_provider_events;
create policy payroll_provider_events_read_admin on public.payroll_provider_events
for select to authenticated using (
 organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
 and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin','auditor')
);
-- All writes go through authenticated, server-side functions after approval and provider verification.
revoke insert, update, delete, truncate on public.payroll_provider_accounts from anon, authenticated;
revoke insert, update, delete, truncate on public.payroll_payment_batches from anon, authenticated;
revoke insert, update, delete, truncate on public.payroll_payment_transactions from anon, authenticated;
revoke insert, update, delete, truncate on public.payroll_provider_events from anon, authenticated;
grant select on public.payroll_provider_accounts, public.payroll_payment_batches, public.payroll_payment_transactions, public.payroll_provider_events to authenticated;
