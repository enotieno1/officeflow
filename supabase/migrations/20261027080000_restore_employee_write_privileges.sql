-- Restore the missing table privileges required by employees_admin_only RLS.
-- RLS continues to restrict writes to administrators/super_admins in the caller's organization.
GRANT INSERT, UPDATE ON TABLE public.employees TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.employees_id_seq TO authenticated;
