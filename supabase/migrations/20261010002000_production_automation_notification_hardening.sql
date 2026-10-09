-- Production hardening: allow automation notifications and keep internal RLS helpers non-callable via REST.
alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    'approval_required','request_submitted','approved','rejected',
    'returned','completed','escalated','automation'
  ]));

revoke execute on function public.fn_has_decided_request(uuid) from authenticated;
revoke execute on function public.fn_is_current_step_approver(uuid) from authenticated;
revoke execute on function public.fn_is_request_submitter(uuid) from authenticated;
