-- Private Storage bucket for receipt / proof attachments.
-- Objects are keyed as "<workspace_id>/<expense_id>/<uuid>-<file_name>".

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'receipts',
  'receipts',
  false,
  20971520, -- 20 MB
  array['image/jpeg', 'image/png', 'image/heic', 'image/webp', 'application/pdf']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Helper: the workspace segment of a receipts object key, as uuid (or null).
create or replace function public.receipts_object_workspace(object_name text)
returns uuid
language plpgsql
immutable
set search_path = public
as $$
declare
  segment text := split_part(object_name, '/', 1);
begin
  if segment ~ '^[0-9a-fA-F-]{36}$' then
    return segment::uuid;
  end if;
  return null;
end;
$$;

drop policy if exists "workspace members can read receipts" on storage.objects;
create policy "workspace members can read receipts" on storage.objects
for select to authenticated
using (
  bucket_id = 'receipts'
  and public.is_workspace_member(public.receipts_object_workspace(name))
);

drop policy if exists "workspace members can upload receipts" on storage.objects;
create policy "workspace members can upload receipts" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'receipts'
  and public.is_workspace_member(public.receipts_object_workspace(name))
);

drop policy if exists "workspace members can update receipts" on storage.objects;
create policy "workspace members can update receipts" on storage.objects
for update to authenticated
using (
  bucket_id = 'receipts'
  and public.is_workspace_member(public.receipts_object_workspace(name))
)
with check (
  bucket_id = 'receipts'
  and public.is_workspace_member(public.receipts_object_workspace(name))
);

drop policy if exists "admins can delete receipts" on storage.objects;
create policy "admins can delete receipts" on storage.objects
for delete to authenticated
using (
  bucket_id = 'receipts'
  and public.has_workspace_role(
    public.receipts_object_workspace(name),
    array['admin'::public.workspace_role]
  )
);
