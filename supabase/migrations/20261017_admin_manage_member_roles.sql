drop policy if exists "Admins can read all memberships" on public.clinisys_workspace_members;
drop policy if exists "Admins can update memberships" on public.clinisys_workspace_members;
create policy "Admins can read all memberships" on public.clinisys_workspace_members for select to authenticated using (
  exists (select 1 from public.clinisys_workspace_members me where me.user_id = (select auth.uid()) and me.role = 'admin')
);
create policy "Admins can update memberships" on public.clinisys_workspace_members for update to authenticated using (
  user_id <> (select auth.uid())
  and exists (select 1 from public.clinisys_workspace_members me where me.user_id = (select auth.uid()) and me.role = 'admin')
) with check (role in ('admin','member'));

