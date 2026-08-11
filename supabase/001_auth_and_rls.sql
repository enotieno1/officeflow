-- OfficeFlow: real auth + row-level security migration
-- Run this once in the Supabase SQL Editor (Dashboard -> SQL Editor -> New query -> paste -> Run)
-- Safe to re-run: uses IF NOT EXISTS / OR REPLACE / DROP POLICY IF EXISTS throughout.

-- =========================================================
-- 1. PROFILES TABLE (one row per authenticated user)
-- =========================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role text not null default 'admin' check (role in ('admin','manager','viewer')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select using (id = auth.uid());

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update using (id = auth.uid());

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert with check (id = auth.uid());

-- Auto-create a profile row the moment someone signs up via Supabase Auth
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- =========================================================
-- 2. OWNER SCOPING on existing data tables
--    Each row is tied to the user who created it (owner_id).
--    New rows are auto-stamped via DEFAULT auth.uid() -- no app code changes needed.
-- =========================================================
alter table if exists public.employees    add column if not exists owner_id uuid not null default auth.uid() references auth.users(id);
alter table if exists public.transactions add column if not exists owner_id uuid not null default auth.uid() references auth.users(id);
alter table if exists public.tasks        add column if not exists owner_id uuid not null default auth.uid() references auth.users(id);
alter table if exists public.documents    add column if not exists owner_id uuid not null default auth.uid() references auth.users(id);

-- =========================================================
-- 3. ENABLE ROW LEVEL SECURITY + POLICIES
--    A user can only see/edit/delete their own rows.
-- =========================================================
alter table public.employees    enable row level security;
alter table public.transactions enable row level security;
alter table public.tasks        enable row level security;
alter table public.documents    enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['employees','transactions','tasks','documents']
  loop
    execute format('drop policy if exists "%1$s_select_own" on public.%1$I', t);
    execute format('create policy "%1$s_select_own" on public.%1$I for select using (owner_id = auth.uid())', t);

    execute format('drop policy if exists "%1$s_insert_own" on public.%1$I', t);
    execute format('create policy "%1$s_insert_own" on public.%1$I for insert with check (owner_id = auth.uid())', t);

    execute format('drop policy if exists "%1$s_update_own" on public.%1$I', t);
    execute format('create policy "%1$s_update_own" on public.%1$I for update using (owner_id = auth.uid())', t);

    execute format('drop policy if exists "%1$s_delete_own" on public.%1$I', t);
    execute format('create policy "%1$s_delete_own" on public.%1$I for delete using (owner_id = auth.uid())', t);
  end loop;
end $$;

-- =========================================================
-- 4. BACKFILL NOTE
-- =========================================================
-- Any rows created before this migration (owner_id was just added) will have
-- owner_id = NULL and become invisible under RLS. If you have real demo/seed
-- data you want to keep, run once, replacing <your-user-uuid> with your
-- actual auth.users id (find it in Authentication -> Users):
--
--   update public.employees    set owner_id = '<your-user-uuid>' where owner_id is null;
--   update public.transactions set owner_id = '<your-user-uuid>' where owner_id is null;
--   update public.tasks        set owner_id = '<your-user-uuid>' where owner_id is null;
--   update public.documents    set owner_id = '<your-user-uuid>' where owner_id is null;
--
-- Otherwise it's safe to just delete old demo rows and start clean.
