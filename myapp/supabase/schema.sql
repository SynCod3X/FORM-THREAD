-- Run this script in the Supabase SQL Editor for this project.
-- Passwords are stored and managed by Supabase Auth, never in this table.

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  full_name text not null default '',
  contact_number text not null default '',
  address text not null default '',
  role text not null default 'customer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Keep a copy of the Auth email on the application profile. The column is not
-- client-editable; email changes continue to go through Supabase Auth.
alter table public.profiles
  add column if not exists email text not null default '';

update public.profiles as p
set email = u.email
from auth.users as u
where p.id = u.id
  and u.email is not null
  and p.email is distinct from u.email;

alter table public.profiles
  drop constraint if exists profiles_email_not_blank;
alter table public.profiles
  add constraint profiles_email_not_blank check (btrim(email) <> '');

-- Add the role field when upgrading an existing profiles table.
alter table public.profiles
  add column if not exists role text not null default 'customer';

alter table public.profiles
  drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check check (role in ('customer', 'staff'));

alter table public.profiles enable row level security;

drop policy if exists "Users can read their own profile" on public.profiles;
create policy "Users can read their own profile"
  on public.profiles for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "Users can update their own profile" on public.profiles;
create policy "Users can update their own profile"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (full_name, contact_number, address) on public.profiles to authenticated;

create or replace function public.set_profile_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_profile_updated_at();

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, contact_number, address)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'contact_number', ''),
    coalesce(new.raw_user_meta_data ->> 'address', '')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute function public.create_profile_for_new_user();

create or replace function public.sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set email = new.email
  where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_updated_profile on auth.users;
create trigger on_auth_user_email_updated_profile
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.sync_profile_email();

-- Create profiles for Auth accounts that existed before the trigger was installed.
insert into public.profiles (id, email, full_name, contact_number, address)
select
  u.id,
  u.email,
  coalesce(u.raw_user_meta_data ->> 'full_name', ''),
  coalesce(u.raw_user_meta_data ->> 'contact_number', ''),
  coalesce(u.raw_user_meta_data ->> 'address', '')
from auth.users as u
on conflict (id) do nothing;

-- Store products managed by staff. Product images are supplied as public URLs.
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null default '',
  image_url text not null,
  price numeric(10, 2) not null check (price > 0),
  quantity integer not null default 0 check (quantity >= 0),
  is_active boolean not null default true,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.products add column if not exists category text not null default 'Clothing';
alter table public.products add column if not exists compare_at_price numeric(10,2);
alter table public.products add column if not exists discount_percent numeric(5,2);
alter table public.products drop constraint if exists products_discount_percent_valid;
alter table public.products add constraint products_discount_percent_valid check (
  discount_percent is null or (
    discount_percent > 0 and discount_percent < 100
    and compare_at_price is not null
    and compare_at_price > price
    and price = round(compare_at_price * (1 - discount_percent / 100), 2)
  )
);
alter table public.products add column if not exists badge text not null default '';
alter table public.products add column if not exists available_sizes text[] not null default array['XS','S','M','L','XL'];
alter table public.products add column if not exists available_colors text[] not null default array['Natural','Black','Olive'];

alter table public.products enable row level security;
revoke all on public.products from anon, authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;

drop policy if exists "Anyone can view active products" on public.products;
create policy "Anyone can view active products"
  on public.products for select
  to anon, authenticated
  using (
    is_active
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'staff'
    )
  );

drop policy if exists "Staff can insert products" on public.products;
create policy "Staff can insert products"
  on public.products for insert
  to authenticated
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'staff'
    )
  );

drop policy if exists "Staff can update products" on public.products;
create policy "Staff can update products"
  on public.products for update
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'staff'
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'staff'
    )
  );

drop policy if exists "Staff can delete products" on public.products;
create policy "Staff can delete products"
  on public.products for delete
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'staff'
    )
  );

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users (id) on delete restrict,
  customer_email text not null default '',
  customer_name text not null default '',
  contact_number text not null default '',
  shipping_address text not null default '',
  items jsonb not null,
  total numeric(10, 2) not null check (total >= 0),
  currency text not null default 'PHP',
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'shipped', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.orders enable row level security;
revoke all on public.orders from anon, authenticated;
grant select on public.orders to authenticated;
grant update (status) on public.orders to authenticated;

drop policy if exists "Customers and staff can read orders" on public.orders;
create policy "Customers and staff can read orders"
  on public.orders for select
  to authenticated
  using (
    customer_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'staff'
    )
  );

drop policy if exists "Staff can update order status" on public.orders;
create policy "Staff can update order status"
  on public.orders for update
  to authenticated
  using (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'staff'
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'staff'
    )
  );

-- Record order progress and enforce the same workflow for every client.
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
  -- Managed stock was reserved when the order was placed. Return it once if
  -- staff cancels before shipping; deleted products are simply skipped.
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

-- Give pre-existing orders a starting entry when applying this upgrade.
insert into public.order_status_history (order_id, to_status, changed_at)
select o.id, o.status, o.created_at
from public.orders o
where not exists (
  select 1 from public.order_status_history h where h.order_id = o.id
);

-- Customer help requests, visible to their owner and staff.
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

-- The server charges the database price and checks it against the price shown
-- to the customer. Every line must use an active product and valid options.
create or replace function public.place_order(p_items jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_item jsonb;
  v_product public.products%rowtype;
  v_product_id uuid;
  v_quantity integer;
  v_size text;
  v_color text;
  v_total numeric(10,2) := 0;
  v_items jsonb := '[]'::jsonb;
  v_profile public.profiles%rowtype;
  v_email text;
  v_order_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in before placing an order.';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0
     or jsonb_array_length(p_items) > 50 then
    raise exception 'Your order must contain between 1 and 50 items.';
  end if;
  for v_item in select value from jsonb_array_elements(p_items) as x(value) loop
    if jsonb_typeof(v_item) <> 'object' or nullif(v_item ->> 'product_id','') is null then
      raise exception 'Every item must be a shop product.';
    end if;
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_quantity := (v_item ->> 'quantity')::integer;
    v_size := coalesce(v_item ->> 'size','');
    v_color := coalesce(v_item ->> 'color','');
    if v_quantity is null or v_quantity not between 1 and 99 then
      raise exception 'Item quantity must be between 1 and 99.';
    end if;
    select * into v_product from public.products
      where id = v_product_id and is_active for update;
    if not found then raise exception 'A product is no longer available.'; end if;
    if (v_item ->> 'expected_price')::numeric is distinct from v_product.price then
      raise exception 'The price of % changed. Review your bag before ordering.', v_product.name;
    end if;
    if v_quantity > v_product.quantity then
      raise exception 'Not enough stock for %.', v_product.name;
    end if;
    if not (v_size = any(v_product.available_sizes))
       or not (v_color = any(v_product.available_colors)) then
      raise exception 'Choose an available size and color for %.', v_product.name;
    end if;
    update public.products set quantity = quantity - v_quantity, updated_at = now()
      where id = v_product_id;
    v_total := v_total + v_product.price * v_quantity;
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'product_id', v_product.id, 'name', v_product.name,
      'description', v_product.description, 'image', v_product.image_url,
      'unit_price', v_product.price, 'quantity', v_quantity,
      'size', v_size, 'color', v_color
    ));
  end loop;
  select * into v_profile from public.profiles where id = (select auth.uid());
  if not found or btrim(v_profile.full_name) = '' or btrim(v_profile.contact_number) = ''
     or btrim(v_profile.address) = '' then
    raise exception 'Complete your delivery details before ordering.';
  end if;
  select email into v_email from auth.users where id = (select auth.uid());
  insert into public.orders (customer_id, customer_email, customer_name,
    contact_number, shipping_address, items, total)
  values ((select auth.uid()), coalesce(v_email,''), v_profile.full_name,
    v_profile.contact_number, v_profile.address, v_items, v_total)
  returning id into v_order_id;
  return v_order_id;
end;
$$;
revoke all on function public.place_order(jsonb) from public, anon;
grant execute on function public.place_order(jsonb) to authenticated;
