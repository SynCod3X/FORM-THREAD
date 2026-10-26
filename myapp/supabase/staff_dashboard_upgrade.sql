-- Run in the Supabase SQL Editor after the base schema has been installed.
-- The dashboard's counts and filters use existing profiles, products, and orders.

create table if not exists public.order_status_history (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders (id) on delete cascade,
  from_status text,
  to_status text not null,
  changed_by uuid references auth.users (id) on delete set null,
  changed_at timestamptz not null default now()
);

create index if not exists order_status_history_order_id_changed_at_idx
  on public.order_status_history (order_id, changed_at);

alter table public.order_status_history enable row level security;
revoke all on public.order_status_history from anon, authenticated;
grant select on public.order_status_history to authenticated;

drop policy if exists "Customers and staff can read order history" on public.order_status_history;
create policy "Customers and staff can read order history"
  on public.order_status_history for select
  to authenticated
  using (exists (
    select 1 from public.orders o where o.id = order_id
  ));

create or replace function public.validate_order_status_change()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_item jsonb;
begin
  if new.status = old.status then
    return new;
  end if;
  if not (
    (old.status = 'pending' and new.status in ('processing', 'cancelled'))
    or (old.status = 'processing' and new.status in ('shipped', 'cancelled'))
    or (old.status = 'shipped' and new.status = 'completed')
  ) then
    raise exception 'Invalid order status change: % to %', old.status, new.status;
  end if;
  if new.status = 'cancelled' then
    for v_item in select value from jsonb_array_elements(old.items) as x(value)
    loop
      if nullif(v_item ->> 'product_id', '') is not null then
        update public.products
        set quantity = quantity + (v_item ->> 'quantity')::integer,
            updated_at = now()
        where id = (v_item ->> 'product_id')::uuid;
      end if;
    end loop;
  end if;
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists orders_validate_status_change on public.orders;
create trigger orders_validate_status_change
  before update of status on public.orders
  for each row execute function public.validate_order_status_change();

create or replace function public.record_order_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' or old.status is distinct from new.status then
    insert into public.order_status_history
      (order_id, from_status, to_status, changed_by, changed_at)
    values
      (new.id, case when tg_op = 'INSERT' then null else old.status end,
       new.status, auth.uid(), now());
  end if;
  return new;
end;
$$;

drop trigger if exists orders_record_status_change on public.orders;
create trigger orders_record_status_change
  after insert or update of status on public.orders
  for each row execute function public.record_order_status_change();

insert into public.order_status_history (order_id, to_status, changed_at)
select o.id, o.status, o.created_at
from public.orders o
where not exists (
  select 1 from public.order_status_history h where h.order_id = o.id
);
