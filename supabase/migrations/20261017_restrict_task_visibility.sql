-- CliniSys: visibility par rôle et suppression limitée aux tâches non démarrées.
drop policy if exists "Workspace members can read tasks" on public.clinisys_tasks;
drop policy if exists "Workspace members can insert tasks" on public.clinisys_tasks;
drop policy if exists "Workspace members can update tasks" on public.clinisys_tasks;
drop policy if exists "Admins can read unfinished tasks" on public.clinisys_tasks;
drop policy if exists "Members can read own unfinished tasks" on public.clinisys_tasks;
drop policy if exists "Admins can insert unfinished tasks" on public.clinisys_tasks;
drop policy if exists "Members can insert own unfinished tasks" on public.clinisys_tasks;
drop policy if exists "Admins can update tasks" on public.clinisys_tasks;
drop policy if exists "Members can update own tasks" on public.clinisys_tasks;
drop policy if exists "Admins can delete only unstarted tasks" on public.clinisys_tasks;
drop policy if exists "Members can delete only own unstarted tasks" on public.clinisys_tasks;

create policy "Admins can read all tasks" on public.clinisys_tasks for select to authenticated using (
  exists (select 1 from public.clinisys_workspace_members m where m.user_id = (select auth.uid()) and m.role = 'admin')
  and not deleted
);
create policy "Members can read own tasks" on public.clinisys_tasks for select to authenticated using (
  exists (select 1 from public.clinisys_workspace_members m where m.user_id = (select auth.uid()) and m.role = 'member')
  and not deleted
  and lower(coalesce(item->>'owner','')) = lower(coalesce((select p.display_name from public.clinisys_profiles p where p.user_id = (select auth.uid())), ''))
);
create policy "Admins can insert unfinished tasks" on public.clinisys_tasks for insert to authenticated with check (
  exists (select 1 from public.clinisys_workspace_members m where m.user_id = (select auth.uid()) and m.role = 'admin')
  and not deleted and coalesce(nullif(item->>'progress','')::numeric,0) < 100
);
create policy "Members can insert own unfinished tasks" on public.clinisys_tasks for insert to authenticated with check (
  exists (select 1 from public.clinisys_workspace_members m where m.user_id = (select auth.uid()) and m.role = 'member')
  and not deleted
  and lower(coalesce(item->>'owner','')) = lower(coalesce((select p.display_name from public.clinisys_profiles p where p.user_id = (select auth.uid())), ''))
);
create policy "Admins can update unfinished tasks" on public.clinisys_tasks for update to authenticated using (
  exists (select 1 from public.clinisys_workspace_members m where m.user_id = (select auth.uid()) and m.role = 'admin')
  and not deleted
) with check (not deleted and coalesce(nullif(item->>'progress','')::numeric,0) between 0 and 100);
create policy "Members can update own unfinished tasks" on public.clinisys_tasks for update to authenticated using (
  exists (select 1 from public.clinisys_workspace_members m where m.user_id = (select auth.uid()) and m.role = 'member')
  and not deleted and coalesce(nullif(item->>'progress','')::numeric,0) < 100
  and lower(coalesce(item->>'owner','')) = lower(coalesce((select p.display_name from public.clinisys_profiles p where p.user_id = (select auth.uid())), ''))
) with check (
  not deleted and coalesce(nullif(item->>'progress','')::numeric,0) between 0 and 100
  and lower(coalesce(item->>'owner','')) = lower(coalesce((select p.display_name from public.clinisys_profiles p where p.user_id = (select auth.uid())), ''))
);
create policy "Admins can delete only unstarted tasks" on public.clinisys_tasks for update to authenticated using (
  exists (select 1 from public.clinisys_workspace_members m where m.user_id = (select auth.uid()) and m.role = 'admin')
  and not deleted and coalesce(nullif(item->>'progress','')::numeric,0) = 0
) with check (deleted and item is null);
create policy "Members can delete only own unstarted tasks" on public.clinisys_tasks for update to authenticated using (
  exists (select 1 from public.clinisys_workspace_members m where m.user_id = (select auth.uid()) and m.role = 'member')
  and not deleted and coalesce(nullif(item->>'progress','')::numeric,0) = 0
  and lower(coalesce(item->>'owner','')) = lower(coalesce((select p.display_name from public.clinisys_profiles p where p.user_id = (select auth.uid())), ''))
) with check (deleted and item is null);

