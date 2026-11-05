-- Organisation administrators may update only their own organisation identity.
-- Tenant boundary is enforced by fn_current_org() and the caller's profile role.
drop policy if exists organizations_admin_update_identity on public.organizations;
create policy organizations_admin_update_identity
on public.organizations
for update
to authenticated
using (
  id = (select fn_current_org())
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.organization_id = organizations.id
      and p.role in ('administrator', 'super_admin')
  )
)
with check (
  id = (select fn_current_org())
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.organization_id = organizations.id
      and p.role in ('administrator', 'super_admin')
  )
);
