-- Task editing is intentionally governed by the existing tasks_owner_or_admin RLS policy.
grant update on table public.tasks to authenticated;
