-- Remove the older permissive policy (policies are OR-combined).
DROP POLICY IF EXISTS employees_owner_or_admin ON public.employees;
DROP POLICY IF EXISTS documents_owner_or_admin ON public.documents;
CREATE POLICY documents_owner_or_admin ON public.documents FOR ALL TO authenticated
USING (organization_id=(SELECT public.fn_current_org()) AND (
 (lower(coalesce(folder,'')) !~ '(human[ _-]?resources?|(^|[^a-z])hr([^a-z]|$)|personnel|payroll|recruitment|disciplin|employee records)'
 AND lower(coalesce(name,'')) !~ '(human[ _-]?resources?|(^|[^a-z])hr([^a-z]|$)|personnel|payroll|recruitment|disciplin|employee records)'
 AND lower(coalesce(type,'')) !~ '(human[ _-]?resources?|(^|[^a-z])hr([^a-z]|$)|personnel|payroll|recruitment|disciplin|employee records)'
 AND (owner_id=(SELECT auth.uid()) OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid())
 AND p.organization_id=documents.organization_id AND p.role IN ('administrator','manager','super_admin'))))
 OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.organization_id=documents.organization_id
 AND p.role IN ('administrator','super_admin'))))
WITH CHECK (organization_id=(SELECT public.fn_current_org()) AND (
 (lower(coalesce(folder,'')) !~ '(human[ _-]?resources?|(^|[^a-z])hr([^a-z]|$)|personnel|payroll|recruitment|disciplin|employee records)'
 AND lower(coalesce(name,'')) !~ '(human[ _-]?resources?|(^|[^a-z])hr([^a-z]|$)|personnel|payroll|recruitment|disciplin|employee records)'
 AND lower(coalesce(type,'')) !~ '(human[ _-]?resources?|(^|[^a-z])hr([^a-z]|$)|personnel|payroll|recruitment|disciplin|employee records)'
 AND (owner_id=(SELECT auth.uid()) OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid())
 AND p.organization_id=documents.organization_id AND p.role IN ('administrator','manager','super_admin'))))
 OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=(SELECT auth.uid()) AND p.organization_id=documents.organization_id
 AND p.role IN ('administrator','super_admin'))));
