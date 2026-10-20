-- Real task assignment identity, tenant validation and least-privilege policies.
alter table public.tasks
  add column if not exists assigned_to_user_id uuid references auth.users(id) on delete set null;

drop policy if exists tasks_owner_or_admin on public.tasks;
drop policy if exists tasks_read_owner_assignee_or_admin on public.tasks;
drop policy if exists tasks_insert_owner_or_admin on public.tasks;
drop policy if exists tasks_update_owner_assignee_or_admin on public.tasks;
drop policy if exists tasks_delete_owner_or_admin on public.tasks;

create policy tasks_read_owner_assignee_or_admin on public.tasks
for select to authenticated
using (
  organization_id = (select public.fn_current_org())
  and (
    owner_id = (select auth.uid())
    or assigned_to_user_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.organization_id = tasks.organization_id
        and p.role in ('administrator','manager','super_admin')
    )
  )
);

create policy tasks_insert_owner_or_admin on public.tasks
for insert to authenticated
with check (
  organization_id = (select public.fn_current_org())
  and (
    owner_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.organization_id = tasks.organization_id
        and p.role in ('administrator','manager','super_admin')
    )
  )
);

create policy tasks_update_owner_assignee_or_admin on public.tasks
for update to authenticated
using (
  organization_id = (select public.fn_current_org())
  and (
    owner_id = (select auth.uid())
    or assigned_to_user_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.organization_id = tasks.organization_id
        and p.role in ('administrator','manager','super_admin')
    )
  )
)
with check (
  organization_id = (select public.fn_current_org())
  and (
    owner_id = (select auth.uid())
    or assigned_to_user_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.organization_id = tasks.organization_id
        and p.role in ('administrator','manager','super_admin')
    )
  )
);

create policy tasks_delete_owner_or_admin on public.tasks
for delete to authenticated
using (
  organization_id = (select public.fn_current_org())
  and (
    owner_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid())
        and p.organization_id = tasks.organization_id
        and p.role in ('administrator','manager','super_admin')
    )
  )
);

create or replace function private.fn_validate_task_assignment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_org uuid;
  v_actor_role text;
  v_target_org uuid;
  v_target_name text;
begin
  if coalesce(auth.role(), '') = 'service_role' then return new; end if;

  select p.organization_id, p.role into v_actor_org, v_actor_role
  from public.profiles p where p.id = auth.uid();

  if v_actor_org is null or new.organization_id is distinct from v_actor_org then
    raise exception 'task must belong to the current organization';
  end if;

  if tg_op = 'INSERT' then
    if new.owner_id is distinct from auth.uid()
       and v_actor_role not in ('administrator','super_admin') then
      raise exception 'only an administrator can create a task for another owner';
    end if;
    if new.assigned_to_user_id is not null
       and new.assigned_to_user_id <> auth.uid()
       and v_actor_role not in ('administrator','manager','super_admin') then
      raise exception 'only managers or administrators can assign tasks to another user';
    end if;
  else
    if new.organization_id is distinct from old.organization_id then
      raise exception 'task organization cannot be changed';
    end if;
    if new.owner_id is distinct from old.owner_id
       and v_actor_role not in ('administrator','super_admin') then
      raise exception 'only an administrator can change task ownership';
    end if;
    if new.assigned_to_user_id is distinct from old.assigned_to_user_id
       and new.assigned_to_user_id is not null
       and new.assigned_to_user_id <> auth.uid()
       and v_actor_role not in ('administrator','manager','super_admin') then
      raise exception 'only managers or administrators can assign tasks to another user';
    end if;
  end if;

  if new.assigned_to_user_id is not null then
    select p.organization_id into v_target_org
    from public.profiles p where p.id = new.assigned_to_user_id;
    if v_target_org is distinct from v_actor_org then
      raise exception 'assignee must belong to the same organization';
    end if;
    select coalesce(nullif(trim(u.raw_user_meta_data->>'full_name'),''), u.email)
      into v_target_name from auth.users u where u.id = new.assigned_to_user_id;
    new.assigned_to := v_target_name;
  elsif tg_op = 'INSERT' or old.assigned_to_user_id is not null then
    new.assigned_to := null;
  end if;

  return new;
end;
$$;

revoke all on function private.fn_validate_task_assignment() from public, anon, authenticated;
drop trigger if exists tasks_validate_assignment on public.tasks;
create trigger tasks_validate_assignment
before insert or update on public.tasks
for each row execute function private.fn_validate_task_assignment();

create or replace function public.fn_list_task_assignees()
returns table(user_id uuid, email text, display_name text, role text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_org uuid;
  v_role text;
begin
  if v_user is null then raise exception 'authentication required'; end if;
  select p.organization_id, p.role into v_org, v_role
  from public.profiles p where p.id = v_user;
  if not found or v_org is null then raise exception 'organization profile required'; end if;
  if v_role not in ('administrator','manager','super_admin') then
    raise exception 'only managers and administrators can list task assignees';
  end if;
  return query
    select p.id, u.email::text,
      coalesce(nullif(trim(u.raw_user_meta_data->>'full_name'),''), u.email)::text,
      p.role
    from public.profiles p
    join auth.users u on u.id = p.id
    where p.organization_id = v_org
    order by coalesce(nullif(trim(u.raw_user_meta_data->>'full_name'),''), u.email);
end;
$$;
revoke all on function public.fn_list_task_assignees() from public, anon, authenticated;
grant execute on function public.fn_list_task_assignees() to authenticated;

create index if not exists tasks_assigned_to_user_idx
  on public.tasks(organization_id, assigned_to_user_id, due_date);
