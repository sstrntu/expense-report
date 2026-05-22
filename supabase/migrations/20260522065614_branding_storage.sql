-- Public Storage bucket for branding assets (user avatars and workspace
-- logos). The iOS client uploads to:
--   users/<user_id>/<uuid>.<ext>          (avatars — owner writes only)
--   workspaces/<workspace_id>/<uuid>.<ext> (logos — workspace admins write)
-- and references the resulting public URL from public.users.avatar_url /
-- public.workspaces.logo_url, so the bucket is `public = true` for reads.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'branding',
  'branding',
  true,
  5242880, -- 5 MB
  array['image/jpeg', 'image/png', 'image/heic', 'image/webp']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Helpers: parse the second path segment as a uuid for each prefix.
create or replace function public.branding_user_segment(object_name text)
returns uuid
language plpgsql
immutable
set search_path = public
as $$
declare
  prefix text := split_part(object_name, '/', 1);
  segment text := split_part(object_name, '/', 2);
begin
  if prefix = 'users' and segment ~ '^[0-9a-fA-F-]{36}$' then
    return segment::uuid;
  end if;
  return null;
end;
$$;

create or replace function public.branding_workspace_segment(object_name text)
returns uuid
language plpgsql
immutable
set search_path = public
as $$
declare
  prefix text := split_part(object_name, '/', 1);
  segment text := split_part(object_name, '/', 2);
begin
  if prefix = 'workspaces' and segment ~ '^[0-9a-fA-F-]{36}$' then
    return segment::uuid;
  end if;
  return null;
end;
$$;

-- Reads: bucket is public so anonymous SELECT is already implicit via the
-- /storage/v1/object/public/branding/... path. No extra policy needed.

drop policy if exists "users can upload their own branding" on storage.objects;
create policy "users can upload their own branding" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'branding'
  and public.branding_user_segment(name) = auth.uid()
);

drop policy if exists "users can update their own branding" on storage.objects;
create policy "users can update their own branding" on storage.objects
for update to authenticated
using (
  bucket_id = 'branding'
  and public.branding_user_segment(name) = auth.uid()
)
with check (
  bucket_id = 'branding'
  and public.branding_user_segment(name) = auth.uid()
);

drop policy if exists "users can delete their own branding" on storage.objects;
create policy "users can delete their own branding" on storage.objects
for delete to authenticated
using (
  bucket_id = 'branding'
  and public.branding_user_segment(name) = auth.uid()
);

drop policy if exists "workspace admins can upload branding" on storage.objects;
create policy "workspace admins can upload branding" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'branding'
  and public.has_workspace_role(
    public.branding_workspace_segment(name),
    array['admin'::public.workspace_role]
  )
);

drop policy if exists "workspace admins can update branding" on storage.objects;
create policy "workspace admins can update branding" on storage.objects
for update to authenticated
using (
  bucket_id = 'branding'
  and public.has_workspace_role(
    public.branding_workspace_segment(name),
    array['admin'::public.workspace_role]
  )
)
with check (
  bucket_id = 'branding'
  and public.has_workspace_role(
    public.branding_workspace_segment(name),
    array['admin'::public.workspace_role]
  )
);

drop policy if exists "workspace admins can delete branding" on storage.objects;
create policy "workspace admins can delete branding" on storage.objects
for delete to authenticated
using (
  bucket_id = 'branding'
  and public.has_workspace_role(
    public.branding_workspace_segment(name),
    array['admin'::public.workspace_role]
  )
);
