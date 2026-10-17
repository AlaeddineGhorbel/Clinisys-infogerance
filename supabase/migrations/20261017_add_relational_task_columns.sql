-- Migration additive: l'ancien champ item reste conservé pour retour arrière.
alter table public.clinisys_tasks
  add column if not exists task_number bigint,
  add column if not exists issue text,
  add column if not exists client text,
  add column if not exists owner text,
  add column if not exists created_date date,
  add column if not exists due_date date,
  add column if not exists progress numeric(5,2),
  add column if not exists notes text,
  add column if not exists closed boolean,
  add column if not exists closed_at date;

update public.clinisys_tasks t
set task_number = coalesce(t.task_number, n.row_number_value), issue = coalesce(t.issue, nullif(t.item->>'issue','')), client = coalesce(t.client, nullif(t.item->>'client','')), owner = coalesce(t.owner, nullif(t.item->>'owner','')), created_date = coalesce(t.created_date, nullif(t.item->>'date','')::date), due_date = coalesce(t.due_date, nullif(t.item->>'due','')::date), progress = coalesce(t.progress, greatest(0, least(100, coalesce(nullif(t.item->>'progress','')::numeric,0)))), notes = coalesce(t.notes, t.item->>'notes'), closed = coalesce(t.closed, coalesce((t.item->>'closed')::boolean, t.item ? 'closedAt', false)), closed_at = coalesce(t.closed_at, nullif(t.item->>'closedAt','')::date)
from (select id, row_number() over(order by updated_at, id) as row_number_value from public.clinisys_tasks) n
where t.id = n.id;

alter table public.clinisys_tasks alter column progress set default 0;
alter table public.clinisys_tasks alter column closed set default false;
alter table public.clinisys_tasks add constraint clinisys_tasks_progress_range check (progress is null or (progress >= 0 and progress <= 100));
create index if not exists clinisys_tasks_owner_idx on public.clinisys_tasks(owner);
create index if not exists clinisys_tasks_closed_idx on public.clinisys_tasks(closed);
create index if not exists clinisys_tasks_due_date_idx on public.clinisys_tasks(due_date);

create or replace function public.clinisys_sync_task_columns_from_item() returns trigger language plpgsql as $$
begin
  if new.item is not null then
    new.issue := coalesce(new.issue, nullif(new.item->>'issue',''));
    new.client := coalesce(new.client, nullif(new.item->>'client',''));
    new.owner := coalesce(new.owner, nullif(new.item->>'owner',''));
    new.created_date := coalesce(new.created_date, nullif(new.item->>'date','')::date);
    new.due_date := coalesce(new.due_date, nullif(new.item->>'due','')::date);
    new.progress := coalesce(new.progress, greatest(0, least(100, coalesce(nullif(new.item->>'progress','')::numeric,0))));
    new.notes := coalesce(new.notes, new.item->>'notes');
    new.closed := coalesce(new.closed, coalesce((new.item->>'closed')::boolean, new.item ? 'closedAt', false));
    new.closed_at := coalesce(new.closed_at, nullif(new.item->>'closedAt','')::date);
  end if;
  return new;
end; $$;
drop trigger if exists clinisys_sync_task_columns_from_item on public.clinisys_tasks;
create trigger clinisys_sync_task_columns_from_item before insert or update on public.clinisys_tasks for each row execute function public.clinisys_sync_task_columns_from_item();

