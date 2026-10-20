-- OfficeFlow payroll records (KES). Schema only: statutory calculation and payment integrations must be separately validated.
create table if not exists public.payroll_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null,
  period_start date not null,
  period_end date not null,
  pay_date date,
  status text not null default 'draft' check (status in ('draft','in_review','approved','payment_recorded','void')),
  currency text not null default 'KES' check (currency = 'KES'),
  employee_count integer not null default 0 check (employee_count >= 0),
  gross_total numeric(14,2) not null default 0 check (gross_total >= 0),
  deductions_total numeric(14,2) not null default 0 check (deductions_total >= 0),
  net_total numeric(14,2) not null default 0 check (net_total >= 0),
  created_by uuid not null default auth.uid(),
  reviewed_by uuid,
  approved_by uuid,
  payment_reference text,
  payment_recorded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payroll_period_valid check (period_end >= period_start),
  constraint payroll_totals_valid check (net_total <= gross_total)
);
create table if not exists public.payroll_items (
  id uuid primary key default gen_random_uuid(),
  payroll_run_id uuid not null references public.payroll_runs(id) on delete cascade,
  organization_id uuid not null,
  employee_id bigint references public.employees(id) on delete set null,
  employee_name text not null,
  employee_email text,
  department text,
  position text,
  basic_pay numeric(14,2) not null default 0 check (basic_pay >= 0),
  allowances numeric(14,2) not null default 0 check (allowances >= 0),
  overtime numeric(14,2) not null default 0 check (overtime >= 0),
  bonus numeric(14,2) not null default 0 check (bonus >= 0),
  gross_pay numeric(14,2) not null default 0 check (gross_pay >= 0),
  pension_employee numeric(14,2) not null default 0 check (pension_employee >= 0),
  shif numeric(14,2) not null default 0 check (shif >= 0),
  housing_levy_employee numeric(14,2) not null default 0 check (housing_levy_employee >= 0),
  paye numeric(14,2) not null default 0 check (paye >= 0),
  other_deductions numeric(14,2) not null default 0 check (other_deductions >= 0),
  employer_contributions numeric(14,2) not null default 0 check (employer_contributions >= 0),
  net_pay numeric(14,2) not null default 0 check (net_pay >= 0),
  calculation_details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint payroll_item_math check (gross_pay = basic_pay + allowances + overtime + bonus),
  constraint payroll_net_math check (net_pay = gross_pay - pension_employee - shif - housing_levy_employee - paye - other_deductions),
  constraint payroll_employee_once unique (payroll_run_id, employee_id)
);
create table if not exists public.payroll_audit_events (
  id bigint generated always as identity primary key,
  organization_id uuid not null,
  payroll_run_id uuid not null references public.payroll_runs(id) on delete cascade,
  actor_id uuid not null default auth.uid(),
  event_type text not null,
  event_details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.payroll_runs enable row level security;
alter table public.payroll_items enable row level security;
alter table public.payroll_audit_events enable row level security;

create policy payroll_runs_org_read on public.payroll_runs for select to authenticated using (
  organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
  and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin','auditor')
);
create policy payroll_runs_admin_insert on public.payroll_runs for insert to authenticated with check (
  organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
  and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin')
  and created_by = auth.uid()
);
create policy payroll_runs_admin_update on public.payroll_runs for update to authenticated using (
  organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
  and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin')
) with check (
  organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
  and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin')
);
create policy payroll_items_org_read on public.payroll_items for select to authenticated using (
  organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
  and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin','auditor')
);
create policy payroll_items_admin_insert on public.payroll_items for insert to authenticated with check (
  organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
  and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin')
);
create policy payroll_items_admin_update on public.payroll_items for update to authenticated using (
  organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
  and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin')
) with check (
  organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
  and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin')
);
create policy payroll_audit_org_read on public.payroll_audit_events for select to authenticated using (
  organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
  and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin','auditor')
);
create policy payroll_audit_admin_insert on public.payroll_audit_events for insert to authenticated with check (
  organization_id = (select p.organization_id from public.profiles p where p.id = auth.uid())
  and actor_id = auth.uid()
  and (select p.role from public.profiles p where p.id = auth.uid()) in ('administrator','super_admin')
);
