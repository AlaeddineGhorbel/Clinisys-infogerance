-- CliniSys Infogérance: stockage partagé, accès réservé aux membres Auth.
-- Exécuter après création du projet Supabase, dans SQL Editor.

create table if not exists public.clinisys_workspace_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

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
alter table public.clinisys_tasks enable row level security;

drop policy if exists "Members can read their own membership" on public.clinisys_workspace_members;
create policy "Members can read their own membership"
on public.clinisys_workspace_members for select to authenticated
using ((select auth.uid()) = user_id);

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
revoke all on public.clinisys_tasks from anon, authenticated;
revoke all on public.clinisys_tasks from public;
grant select, insert, update on public.clinisys_tasks to authenticated;
revoke all on function public.clinisys_touch_updated_at() from public, anon, authenticated;

-- Après avoir créé les utilisateurs dans Authentication > Users,
-- autoriser chacun explicitement en exécutant une instruction par UUID:
-- insert into public.clinisys_workspace_members (user_id)
-- values ('UUID_COPIÉ_DE_AUTHENTICATION_USERS');
-- Ne pas activer les inscriptions publiques. N'exposer jamais service_role.

