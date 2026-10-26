-- Platform-level administrator identity, separate from tenant profile roles.
create table if not exists public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  granted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  note text
);
alter table public.platform_admins enable row level security;
drop policy if exists platform_admins_select_self on public.platform_admins;
create policy platform_admins_select_self on public.platform_admins
  for select to authenticated using (user_id = (select auth.uid()));
revoke all on public.platform_admins from anon, authenticated;
grant select on public.platform_admins to authenticated;

create or replace function public.fn_is_platform_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.platform_admins pa where pa.user_id = (select auth.uid()));
$$;
revoke all on function public.fn_is_platform_admin() from public, anon;
grant execute on function public.fn_is_platform_admin() to authenticated;

create or replace function public.fn_platform_admin_overview()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare result jsonb;
begin
  if not public.fn_is_platform_admin() then
    raise exception 'Platform administrator access required' using errcode = '42501';
  end if;
  select jsonb_build_object(
    'organizations', (select count(*) from public.organizations),
    'profiles', (select count(*) from public.profiles),
    'subscriptions', (select count(*) from public.billing_subscriptions),
    'payment_attempts', (select count(*) from public.billing_payment_attempts),
    'generated_at', now()
  ) into result;
  return result;
end;
$$;
revoke all on function public.fn_platform_admin_overview() from public, anon;
grant execute on function public.fn_platform_admin_overview() to authenticated;
