-- Task categories used by the live Task Management form.
ALTER TABLE public.tasks
  ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'operations';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.tasks'::regclass
      AND conname = 'tasks_category_check'
  ) THEN
    ALTER TABLE public.tasks
      ADD CONSTRAINT tasks_category_check
      CHECK (category IN ('operations','finance','hr','administration','it','other')) NOT VALID;
  END IF;
END
$$;

ALTER TABLE public.tasks VALIDATE CONSTRAINT tasks_category_check;
