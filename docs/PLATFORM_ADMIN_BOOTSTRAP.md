# OOES Platform Admin bootstrap

## Included
- A platform-level membership table independent of tenant profile roles.
- A server-side membership check and aggregate-only overview RPC.
- A restricted workspace at /dashboard/platform-admin.html.

## Deployment and bootstrap
1. Review and apply supabase/migrations/20261026100000_platform_admin_workspace.sql to the intended production Supabase project.
2. Grant access only to the verified OOES operator account using the Supabase SQL editor. Replace the placeholder email:
   SQL:
   insert into public.platform_admins (user_id, granted_by, note)
   select id, auth.uid(), 'Initial OOES platform operator'
   from auth.users
   where lower(email) = lower('REPLACE-WITH-VERIFIED-ADMIN-EMAIL')
   on conflict (user_id) do nothing;
   In SQL Editor, auth.uid() may be null; this is acceptable for the initial bootstrap. Verify the inserted user ID and email.
3. Sign in at /dashboard/auth.html, then open /dashboard/platform-admin.html.
4. Verify a normal customer and a tenant super_admin without platform_admins membership are denied.
5. Verify the overview RPC rejects non-members with SQLSTATE 42501.

## Security boundaries
- Do not add a platform_admin value to tenant profile roles as a shortcut.
- Do not use localStorage flags or email-domain checks for authorization.
- The first release exposes aggregate counts only, not customer records, impersonation, subscription edits or payment actions.
- This is an initial foundation, not proof that billing, support workflows, or customer lifecycle operations are complete.
- Validate against the intended Supabase project before production rollout.
