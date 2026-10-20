-- Avoid touching OLD on INSERT; preserve legacy assignee labels unless assignment identity changes.
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
  elsif tg_op = 'INSERT' then
    new.assigned_to := null;
  elsif old.assigned_to_user_id is not null then
    new.assigned_to := null;
  end if;
  return new;
end;
$$;
revoke all on function private.fn_validate_task_assignment() from public, anon, authenticated;
