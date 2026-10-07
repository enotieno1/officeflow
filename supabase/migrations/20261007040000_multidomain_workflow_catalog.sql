-- OfficeFlow multidomain workflow catalog
-- Applied to production project oghowrilrhummzvrljdt on 2026-10-07.
alter table public.workflow_definitions
  add column if not exists category text,
  add column if not exists description text,
  add column if not exists form_schema jsonb not null default '[]'::jsonb;

alter table public.workflow_definitions
  drop constraint if exists workflow_definitions_form_schema_object_chk;
alter table public.workflow_definitions
  add constraint workflow_definitions_form_schema_array_chk
  check (jsonb_typeof(form_schema) = 'array');

create index if not exists idx_workflow_definitions_org_category
  on public.workflow_definitions (organization_id, category);

-- The production seed for HR, Finance, IT, Administration and Documents
-- is intentionally represented by the same idempotent seed operation used
-- for the live migration. Existing Leave and Procurement workflows remain intact.
