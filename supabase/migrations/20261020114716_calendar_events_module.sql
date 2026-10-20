-- Organization-scoped calendar events for OfficeFlow.
-- RLS is the security boundary; UI visibility is only a convenience.

CREATE TABLE IF NOT EXISTS public.calendar_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  unit_id uuid NULL,
  title text NOT NULL CHECK (length(btrim(title)) BETWEEN 1 AND 200),
  description text NULL CHECK (description IS NULL OR length(description) <= 10000),
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  timezone text NOT NULL DEFAULT 'Africa/Nairobi',
  visibility text NOT NULL DEFAULT 'private' CHECK (visibility IN ('private','department','organization')),
  status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','cancelled')),
  recurrence_rule text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT calendar_events_valid_interval CHECK (end_at > start_at)
);

CREATE INDEX IF NOT EXISTS calendar_events_org_start_idx
  ON public.calendar_events (organization_id, start_at);
CREATE INDEX IF NOT EXISTS calendar_events_unit_start_idx
  ON public.calendar_events (organization_id, unit_id, start_at);
CREATE INDEX IF NOT EXISTS calendar_events_creator_start_idx
  ON public.calendar_events (created_by, start_at);

ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.calendar_events FROM anon, PUBLIC;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.calendar_events TO authenticated;

DROP POLICY IF EXISTS calendar_events_read_scope ON public.calendar_events;
CREATE POLICY calendar_events_read_scope
ON public.calendar_events FOR SELECT TO authenticated
USING (
  organization_id = (SELECT public.fn_current_org())
  AND (
    created_by = (SELECT auth.uid())
    OR visibility = 'organization'
    OR (
      visibility = 'department'
      AND unit_id IS NOT NULL
      AND unit_id = (
        SELECT p.unit_id FROM public.profiles p
        WHERE p.id = (SELECT auth.uid())
          AND p.organization_id = calendar_events.organization_id
      )
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.organization_id = calendar_events.organization_id
        AND p.role IN ('administrator','super_admin')
    )
  )
);

DROP POLICY IF EXISTS calendar_events_insert_scope ON public.calendar_events;
CREATE POLICY calendar_events_insert_scope
ON public.calendar_events FOR INSERT TO authenticated
WITH CHECK (
  organization_id = (SELECT public.fn_current_org())
  AND created_by = (SELECT auth.uid())
  AND (
    visibility = 'private'
    OR (
      visibility = 'department'
      AND unit_id IS NOT NULL
      AND unit_id = (
        SELECT p.unit_id FROM public.profiles p
        WHERE p.id = (SELECT auth.uid())
          AND p.organization_id = calendar_events.organization_id
      )
    )
    OR (
      visibility = 'organization'
      AND EXISTS (
        SELECT 1 FROM public.profiles p
        WHERE p.id = (SELECT auth.uid())
          AND p.organization_id = calendar_events.organization_id
          AND p.role IN ('manager','administrator','super_admin')
      )
    )
  )
);

DROP POLICY IF EXISTS calendar_events_update_scope ON public.calendar_events;
CREATE POLICY calendar_events_update_scope
ON public.calendar_events FOR UPDATE TO authenticated
USING (
  organization_id = (SELECT public.fn_current_org())
  AND (
    created_by = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.organization_id = calendar_events.organization_id
        AND p.role IN ('administrator','super_admin')
    )
  )
)
WITH CHECK (
  organization_id = (SELECT public.fn_current_org())
  AND (
    created_by = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.organization_id = calendar_events.organization_id
        AND p.role IN ('administrator','super_admin')
    )
  )
);

DROP POLICY IF EXISTS calendar_events_delete_scope ON public.calendar_events;
CREATE POLICY calendar_events_delete_scope
ON public.calendar_events FOR DELETE TO authenticated
USING (
  organization_id = (SELECT public.fn_current_org())
  AND (
    created_by = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (SELECT auth.uid())
        AND p.organization_id = calendar_events.organization_id
        AND p.role IN ('administrator','super_admin')
    )
  )
);

COMMENT ON TABLE public.calendar_events IS
  'Tenant-scoped calendar events. Row access is enforced by RLS; visibility may be private, department, or organization.';
