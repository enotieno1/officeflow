-- Performance indexes and RLS init-plan hardening
create index if not exists idx_automation_rules_created_by on public.automation_rules(created_by);
create index if not exists idx_automation_runs_request_step on public.automation_runs(request_step_id);
create index if not exists idx_automation_runs_rule on public.automation_runs(rule_id);
create index if not exists idx_departments_manager on public.departments(manager_id);
create index if not exists idx_departments_parent on public.departments(parent_id);
create index if not exists idx_email_outbox_org on public.email_outbox(organization_id);
create index if not exists idx_email_outbox_recipient on public.email_outbox(recipient_id);
create index if not exists idx_email_outbox_request on public.email_outbox(request_id);
create index if not exists idx_notifications_request on public.notifications(request_id);
create index if not exists idx_profiles_unit on public.profiles(unit_id);
create index if not exists idx_request_steps_unit on public.request_steps(unit_id);
create index if not exists idx_requests_origin_unit on public.requests(origin_unit_id);
create index if not exists idx_workflow_actions_org on public.workflow_actions(organization_id);
create index if not exists idx_workflow_steps_unit on public.workflow_steps(unit_id);

drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own on public.notifications for select to authenticated using ((recipient_id = (select auth.uid())) and (organization_id = (select fn_current_org())));

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own on public.notifications for update to authenticated using ((recipient_id = (select auth.uid())) and (organization_id = (select fn_current_org()))) with check ((recipient_id = (select auth.uid())) and (organization_id = (select fn_current_org())));

drop policy if exists automation_rules_select_authorized on public.automation_rules;
create policy automation_rules_select_authorized on public.automation_rules for select to authenticated using (
 organization_id = (select p.organization_id from public.profiles p where p.id = (select auth.uid()))
 and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=automation_rules.organization_id and p.role in ('administrator','auditor','super_admin'))
);

drop policy if exists automation_runs_select_authorized on public.automation_runs;
create policy automation_runs_select_authorized on public.automation_runs for select to authenticated using (
 organization_id = (select p.organization_id from public.profiles p where p.id = (select auth.uid()))
 and exists (select 1 from public.profiles p where p.id=(select auth.uid()) and p.organization_id=automation_runs.organization_id and p.role in ('administrator','auditor','super_admin'))
);