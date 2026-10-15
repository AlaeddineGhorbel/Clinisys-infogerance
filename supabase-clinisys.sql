-- CliniSys Infogérance: stockage partagé, accès réservé aux membres Auth.
-- Exécuter après création du projet Supabase, dans SQL Editor.

create table if not exists public.clinisys_workspace_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('admin','member')),
  created_at timestamptz not null default now()
);
alter table public.clinisys_workspace_members add column if not exists role text not null default 'member';
do $$ begin
  alter table public.clinisys_workspace_members add constraint clinisys_member_role_check check (role in ('admin','member'));
exception when duplicate_object then null;
end $$;

create table if not exists public.clinisys_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 120),
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.clinisys_invitations (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  display_name text not null check (char_length(trim(display_name)) between 1 and 120),
  token_hash text not null unique,
  created_by uuid not null references auth.users(id) on delete restrict,
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists clinisys_invitations_created_by_idx on public.clinisys_invitations(created_by);

create table if not exists public.clinisys_tasks (
  id text primary key,
  item jsonb,
  deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  constraint clinisys_task_payload_check check (
    (deleted and item is null) or (not deleted and item is not null and jsonb_typeof(item) = 'object')
  )
);

create or replace function public.clinisys_touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := pg_catalog.clock_timestamp();
  return new;
end;
$$;

drop trigger if exists clinisys_tasks_touch_updated_at on public.clinisys_tasks;
create trigger clinisys_tasks_touch_updated_at
before update on public.clinisys_tasks
for each row execute function public.clinisys_touch_updated_at();

alter table public.clinisys_workspace_members enable row level security;
alter table public.clinisys_profiles enable row level security;
alter table public.clinisys_invitations enable row level security;
alter table public.clinisys_tasks enable row level security;

drop policy if exists "Members can read their own membership" on public.clinisys_workspace_members;
create policy "Members can read their own membership"
on public.clinisys_workspace_members for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "Workspace members can read profiles" on public.clinisys_profiles;
create policy "Workspace members can read profiles"
on public.clinisys_profiles for select to authenticated
using (exists (select 1 from public.clinisys_workspace_members m where m.user_id = (select auth.uid())));

drop policy if exists "Users can create own profile" on public.clinisys_profiles;
create policy "Users can create own profile"
on public.clinisys_profiles for insert to authenticated
with check (user_id = (select auth.uid()));

drop policy if exists "Users can update own profile" on public.clinisys_profiles;
create policy "Users can update own profile"
on public.clinisys_profiles for update to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists "Admins can read invitations" on public.clinisys_invitations;
create policy "Admins can read invitations"
on public.clinisys_invitations for select to authenticated
using (exists (select 1 from public.clinisys_workspace_members m where m.user_id = (select auth.uid()) and m.role = 'admin'));

drop policy if exists "Admins can create invitations" on public.clinisys_invitations;
create policy "Admins can create invitations"
on public.clinisys_invitations for insert to authenticated
with check (created_by = (select auth.uid()) and exists (select 1 from public.clinisys_workspace_members m where m.user_id = (select auth.uid()) and m.role = 'admin'));

drop policy if exists "Workspace members can read tasks" on public.clinisys_tasks;
create policy "Workspace members can read tasks"
on public.clinisys_tasks for select to authenticated
using (exists (
  select 1 from public.clinisys_workspace_members m
  where m.user_id = (select auth.uid())
));

drop policy if exists "Workspace members can insert tasks" on public.clinisys_tasks;
create policy "Workspace members can insert tasks"
on public.clinisys_tasks for insert to authenticated
with check (exists (
  select 1 from public.clinisys_workspace_members m
  where m.user_id = (select auth.uid())
));

drop policy if exists "Workspace members can update tasks" on public.clinisys_tasks;
create policy "Workspace members can update tasks"
on public.clinisys_tasks for update to authenticated
using (exists (
  select 1 from public.clinisys_workspace_members m
  where m.user_id = (select auth.uid())
))
with check (exists (
  select 1 from public.clinisys_workspace_members m
  where m.user_id = (select auth.uid())
));

-- Aucune policy anon, aucun accès anonyme, et aucun droit DELETE physique.
revoke all on public.clinisys_workspace_members from anon, authenticated;
revoke all on public.clinisys_workspace_members from public;
grant select on public.clinisys_workspace_members to authenticated;
revoke all on public.clinisys_profiles from anon, authenticated;
revoke all on public.clinisys_profiles from public;
grant select, insert, update on public.clinisys_profiles to authenticated;
revoke all on public.clinisys_invitations from anon, authenticated;
revoke all on public.clinisys_invitations from public;
grant select, insert on public.clinisys_invitations to authenticated;
revoke all on public.clinisys_tasks from anon, authenticated;
revoke all on public.clinisys_tasks from public;
grant select, insert, update on public.clinisys_tasks to authenticated;
revoke all on function public.clinisys_touch_updated_at() from public, anon, authenticated;

-- Le premier administrateur doit être créé dans Authentication > Users puis autorisé ainsi:
-- insert into public.clinisys_workspace_members (user_id, role)
-- values ('UUID_COPIÉ_DE_AUTHENTICATION_USERS', 'admin');
-- Les autres comptes sont créés uniquement par invitation. Ne pas activer les inscriptions publiques.
-- N'exposez jamais service_role dans le HTML; la fonction Edge l'utilise côté serveur.

