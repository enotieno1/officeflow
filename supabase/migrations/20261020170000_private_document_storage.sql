-- Private organization-scoped document storage and metadata writes.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values (
  'officeflow-documents','officeflow-documents',false,10485760,
  array[
    'application/pdf','image/jpeg','image/png','image/webp','text/plain',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  ]
)
on conflict (id) do update set
  public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists officeflow_documents_read_scoped on storage.objects;
create policy officeflow_documents_read_scoped on storage.objects
for select to authenticated
using (
  bucket_id='officeflow-documents'
  and (storage.foldername(name))[1]=(select public.fn_current_org()::text)
  and (
    (storage.foldername(name))[2]=(select auth.uid()::text)
    or exists(select 1 from public.profiles p where p.id=(select auth.uid())
      and p.organization_id=(select public.fn_current_org())
      and p.role in ('administrator','super_admin'))
  )
);

drop policy if exists officeflow_documents_insert_owner on storage.objects;
create policy officeflow_documents_insert_owner on storage.objects
for insert to authenticated
with check (
  bucket_id='officeflow-documents'
  and (storage.foldername(name))[1]=(select public.fn_current_org()::text)
  and (storage.foldername(name))[2]=(select auth.uid()::text)
);

drop policy if exists officeflow_documents_delete_scoped on storage.objects;
create policy officeflow_documents_delete_scoped on storage.objects
for delete to authenticated
using (
  bucket_id='officeflow-documents'
  and (storage.foldername(name))[1]=(select public.fn_current_org()::text)
  and (
    (storage.foldername(name))[2]=(select auth.uid()::text)
    or exists(select 1 from public.profiles p where p.id=(select auth.uid())
      and p.organization_id=(select public.fn_current_org())
      and p.role in ('administrator','super_admin'))
  )
);

drop policy if exists documents_insert_owner on public.documents;
create policy documents_insert_owner on public.documents
for insert to authenticated
with check (
  organization_id=(select public.fn_current_org())
  and owner_id=(select auth.uid())
);

drop policy if exists documents_delete_owner_or_admin on public.documents;
create policy documents_delete_owner_or_admin on public.documents
for delete to authenticated
using (
  organization_id=(select public.fn_current_org())
  and (
    owner_id=(select auth.uid())
    or exists(select 1 from public.profiles p where p.id=(select auth.uid())
      and p.organization_id=documents.organization_id
      and p.role in ('administrator','super_admin'))
  )
);

grant insert,delete on public.documents to authenticated;
grant usage,select on sequence public.documents_id_seq to authenticated;
