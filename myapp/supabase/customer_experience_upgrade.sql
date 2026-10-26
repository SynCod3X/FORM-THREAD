-- Run after the existing schema.sql or the previously supplied full schema.
-- Orders and order_status_history already support customer order tracking.

create table if not exists public.support_requests (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users (id) on delete cascade,
  customer_email text not null default '',
  order_id uuid references public.orders (id) on delete set null,
  subject text not null check (char_length(btrim(subject)) between 1 and 120),
  message text not null check (char_length(btrim(message)) between 1 and 4000),
  staff_reply text not null default '' check (char_length(staff_reply) <= 4000),
  responded_at timestamptz,
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'resolved')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.support_requests
  add column if not exists staff_reply text not null default '';
alter table public.support_requests
  add column if not exists responded_at timestamptz;

create index if not exists support_requests_customer_created_idx
  on public.support_requests (customer_id, created_at desc);

alter table public.support_requests enable row level security;
revoke all on public.support_requests from anon, authenticated;
grant select on public.support_requests to authenticated;
grant insert (customer_id, order_id, subject, message)
  on public.support_requests to authenticated;
grant update (status, staff_reply) on public.support_requests to authenticated;

drop policy if exists "Customers and staff can read support requests" on public.support_requests;
create policy "Customers and staff can read support requests"
  on public.support_requests for select to authenticated
  using (
    customer_id = (select auth.uid())
    or exists (select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'staff')
  );

drop policy if exists "Customers can create support requests" on public.support_requests;
create policy "Customers can create support requests"
  on public.support_requests for insert to authenticated
  with check (
    customer_id = (select auth.uid())
    and (order_id is null or exists (
      select 1 from public.orders o
      where o.id = order_id and o.customer_id = (select auth.uid())
    ))
  );

drop policy if exists "Staff can update support requests" on public.support_requests;
create policy "Staff can update support requests"
  on public.support_requests for update to authenticated
  using (exists (select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'staff'))
  with check (exists (select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'staff'));

create or replace function public.set_support_request_details()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.customer_email := coalesce((
      select u.email from auth.users u where u.id = new.customer_id
    ), '');
  else
    new.updated_at = now();
    if new.staff_reply is distinct from old.staff_reply
       and btrim(new.staff_reply) <> '' then
      new.responded_at = now();
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists support_requests_set_details on public.support_requests;
create trigger support_requests_set_details
  before insert or update on public.support_requests
  for each row execute function public.set_support_request_details();
