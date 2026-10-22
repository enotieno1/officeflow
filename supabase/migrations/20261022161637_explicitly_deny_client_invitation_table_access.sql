-- Explicit deny-all policy documents the intended client access boundary.
-- The table grants remain revoked for anon/authenticated; service_role handles server-side invitation work.
CREATE POLICY organization_invitations_deny_client_access
ON public.organization_invitations
FOR ALL
TO anon, authenticated
USING (false)
WITH CHECK (false);
