-- Production auth profile provisioning and grant hardening
create or replace function public.fn_provision_profile_on_signup()
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

revoke all on function public.fn_provision_profile_on_signup() from public, anon, authenticated;
grant execute on function public.fn_provision_profile_on_signup() to supabase_auth_admin;

drop trigger if exists trg_provision_profile_on_signup on auth.users;
create trigger trg_provision_profile_on_signup
  after insert on auth.users
  for each row execute function public.fn_provision_profile_on_signup();

revoke trigger, references on all tables in schema public from anon, authenticated;

alter default privileges for role postgres in schema public
  revoke trigger, references on tables from anon, authenticated;

alter default privileges for role postgres in schema public
  revoke execute on functions from anon, authenticated;

alter default privileges for role postgres in schema public
  revoke usage, select on sequences from anon, authenticated;
