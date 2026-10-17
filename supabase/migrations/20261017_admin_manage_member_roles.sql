create or replace function public.clinisys_is_admin(uid uuid default auth.uid()) returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.clinisys_workspace_members where user_id = uid and role = 'admin');
$$;
revoke all on function public.clinisys_is_admin(uuid) from public;
revoke execute on function public.clinisys_is_admin(uuid) from anon;
grant execute on function public.clinisys_is_admin(uuid) to authenticated;
drop policy if exists "Admins can read all memberships" on public.clinisys_workspace_members;
drop policy if exists "Admins can update memberships" on public.clinisys_workspace_members;
create policy "Admins can read all memberships" on public.clinisys_workspace_members for select to authenticated using (
  public.clinisys_is_admin()
);
create policy "Admins can update memberships" on public.clinisys_workspace_members for update to authenticated using (
  user_id <> (select auth.uid())
  and public.clinisys_is_admin()
) with check (role in ('admin','member'));

