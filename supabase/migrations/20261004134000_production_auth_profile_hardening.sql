-- Production auth/profile hardening
-- Fix recursive profiles RLS and provision a profile for every new Auth user.

create schema if not exists private;

create or replace function private.fn_profile_context()
returns table(role text, organization_id uuid)
language sql
security definer
set search_path = public, pg_temp
as $$
  select p.role, p.organization_id
  from public.profiles p
  where p.id = auth.uid()
  limit 1
$$;

revoke all on function private.fn_profile_context() from public;
grant execute on function private.fn_profile_context() to authenticated;

drop policy if exists profiles_select_self_or_org_admin on public.profiles;

create policy profiles_select_self
on public.profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy profiles_select_org_admin
on public.profiles
for select
to authenticated
using (
  exists (
    select 1
    from private.fn_profile_context() ctx
    where ctx.organization_id = profiles.organization_id
      and ctx.role = any (array['administrator','manager'])
  )
);

create or replace function private.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, role, organization_id)
  values (
    new.id,
    'employee',
    '00000000-0000-0000-0000-000000000001'::uuid
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function private.handle_new_auth_user() from public;

drop trigger if exists on_auth_user_created_officeflow on auth.users;

create trigger on_auth_user_created_officeflow
after insert on auth.users
for each row
execute function private.handle_new_auth_user();

revoke execute on function public.fn_cancel_request(uuid) from anon;
revoke execute on function public.fn_decide_request_step(uuid,text,text) from anon;
revoke execute on function public.fn_publish_workflow_version(uuid) from anon;
revoke execute on function public.fn_resubmit_request(uuid) from anon;
revoke execute on function public.fn_submit_request(uuid,text,jsonb,text) from anon;
revoke execute on function public.fn_update_profile_role(uuid,text) from anon;
