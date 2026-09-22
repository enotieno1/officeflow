CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname='officeflow_escalate_overdue_steps';
SELECT cron.schedule('officeflow_escalate_overdue_steps','*/15 * * * *','SELECT public.fn_escalate_overdue_steps();');