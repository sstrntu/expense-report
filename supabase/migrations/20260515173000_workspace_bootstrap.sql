create or replace function public.create_workspace_with_admin(
  workspace_name text,
  default_currency char(3) default 'USD'
)
returns public.workspaces
language plpgsql
security definer
set search_path = public
as $$
declare
  user_id uuid := auth.uid();
  clean_name text := nullif(trim(workspace_name), '');
  workspace_slug text;
  workspace_abbr text;
  created_workspace public.workspaces;
begin
  if user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if clean_name is null then
    raise exception 'Workspace name is required.';
  end if;

  insert into public.users (id, email, email_verified_at, display_name, avatar_url)
  select
    au.id,
    lower(coalesce(au.email, '')),
    au.email_confirmed_at,
    coalesce(nullif(au.raw_user_meta_data ->> 'display_name', ''), split_part(coalesce(au.email, ''), '@', 1), 'New user'),
    au.raw_user_meta_data ->> 'avatar_url'
  from auth.users au
  where au.id = user_id
  on conflict (id) do update set
    email = excluded.email,
    email_verified_at = excluded.email_verified_at,
    display_name = excluded.display_name,
    avatar_url = excluded.avatar_url,
    updated_at = now();

  workspace_slug := lower(regexp_replace(clean_name, '[^a-zA-Z0-9]+', '-', 'g'));
  workspace_slug := trim(both '-' from workspace_slug);
  if workspace_slug = '' then
    workspace_slug := 'workspace';
  end if;
  workspace_slug := workspace_slug || '-' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 6);
  workspace_abbr := upper(substr(regexp_replace(clean_name, '[^a-zA-Z0-9]+', '', 'g'), 1, 4));
  if workspace_abbr = '' then
    workspace_abbr := 'WS';
  end if;

  insert into public.workspaces (
    name,
    slug,
    abbr,
    brand_color,
    default_currency,
    created_by_user_id
  )
  values (
    clean_name,
    workspace_slug,
    workspace_abbr,
    '2F7D5C',
    upper(default_currency),
    user_id
  )
  returning * into created_workspace;

  insert into public.workspace_memberships (
    workspace_id,
    user_id,
    role,
    status
  )
  values (
    created_workspace.id,
    user_id,
    'admin',
    'active'
  );

  insert into public.categories (workspace_id, name, icon, is_active)
  values
    (created_workspace.id, 'Meals', 'fork.knife', true),
    (created_workspace.id, 'Travel', 'airplane', true),
    (created_workspace.id, 'Software', 'desktopcomputer', true),
    (created_workspace.id, 'Office', 'briefcase', true),
    (created_workspace.id, 'Other', 'tag', true);

  return created_workspace;
end;
$$;

grant execute on function public.create_workspace_with_admin(text, char) to authenticated;
