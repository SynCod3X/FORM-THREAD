-- Run once in the Supabase SQL Editor after the earlier schema scripts.
-- Existing orders keep their snapshots; all new checkout lines use products.

-- Ensure customer support is installed for projects with only the first four tables.
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

create table if not exists public.saved_items (
  customer_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (customer_id, product_id)
);
alter table public.saved_items enable row level security;
revoke all on public.saved_items from anon, authenticated;
grant select, insert, update, delete on public.saved_items to authenticated;
drop policy if exists "Customers manage their saved items" on public.saved_items;
create policy "Customers manage their saved items" on public.saved_items
  for all to authenticated using (customer_id = (select auth.uid()))
  with check (customer_id = (select auth.uid()));

create table if not exists public.cart_items (
  customer_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  size text not null,
  color text not null,
  quantity integer not null check (quantity between 1 and 99),
  is_selected boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (customer_id, product_id, size, color)
);
alter table public.cart_items enable row level security;
revoke all on public.cart_items from anon, authenticated;
grant select, insert, update, delete on public.cart_items to authenticated;
drop policy if exists "Customers manage their cart" on public.cart_items;
create policy "Customers manage their cart" on public.cart_items
  for all to authenticated using (customer_id = (select auth.uid()))
  with check (customer_id = (select auth.uid()));

create table if not exists public.order_requests (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  customer_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('cancellation','return')),
  reason text not null check (char_length(btrim(reason)) between 1 and 1000),
  status text not null default 'pending' check (status in ('pending','approved','rejected','completed')),
  staff_note text not null default '',
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (order_id, type)
);
create index if not exists order_requests_customer_created_idx
  on public.order_requests(customer_id, created_at desc);
alter table public.order_requests enable row level security;
revoke all on public.order_requests from anon, authenticated;
grant select on public.order_requests to authenticated;
grant insert (order_id, customer_id, type, reason) on public.order_requests to authenticated;
grant update (status, staff_note) on public.order_requests to authenticated;
drop policy if exists "Customers and staff read order requests" on public.order_requests;
create policy "Customers and staff read order requests" on public.order_requests
  for select to authenticated using (
    customer_id = (select auth.uid()) or exists (
      select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'staff'
    )
  );
drop policy if exists "Customers create their order requests" on public.order_requests;
create policy "Customers create their order requests" on public.order_requests
  for insert to authenticated with check (
    customer_id = (select auth.uid()) and exists (
      select 1 from public.orders o where o.id = order_id and o.customer_id = (select auth.uid())
      and ((type = 'cancellation' and o.status in ('pending','processing'))
        or (type = 'return' and o.status = 'completed'))
    )
  );
drop policy if exists "Staff update order requests" on public.order_requests;
create policy "Staff update order requests" on public.order_requests
  for update to authenticated using (exists (
    select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'staff'
  )) with check (exists (
    select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'staff'
  ));

create or replace function public.validate_order_request_update()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_order_status text;
  v_item jsonb;
begin
  if new.order_id <> old.order_id or new.customer_id <> old.customer_id
     or new.type <> old.type or new.reason <> old.reason then
    raise exception 'Order request details cannot be changed.';
  end if;
  if new.status <> old.status and not (
    (old.status = 'pending' and new.status in ('approved','rejected'))
    or (old.status = 'approved' and new.status = 'completed' and new.type = 'return')
  ) then
    raise exception 'This request is already decided.';
  end if;
  if new.status = 'approved' and old.status = 'pending' and new.type = 'cancellation' then
    select status into v_order_status from public.orders where id = new.order_id for update;
    if v_order_status not in ('pending','processing') then
      raise exception 'This order can no longer be cancelled.';
    end if;
    update public.orders set status = 'cancelled' where id = new.order_id;
  end if;
  if new.status = 'approved' and old.status = 'pending' and new.type = 'return' then
    select status into v_order_status from public.orders where id = new.order_id for update;
    if v_order_status <> 'completed' then
      raise exception 'This order is not eligible for a return.';
    end if;
  end if;
  if new.status = 'completed' and old.status = 'approved' and new.type = 'return' then
    for v_item in select value from jsonb_array_elements(
      (select items from public.orders where id = new.order_id)) as x(value)
    loop
      if nullif(v_item ->> 'product_id','') is not null then
        update public.products set quantity = quantity + (v_item ->> 'quantity')::integer,
          updated_at = now() where id = (v_item ->> 'product_id')::uuid;
      end if;
    end loop;
  end if;
  if new.status <> old.status and new.status <> 'pending' then
    new.resolved_at = now();
  end if;
  return new;
end;
$$;
drop trigger if exists order_requests_validate_update on public.order_requests;
create trigger order_requests_validate_update before update on public.order_requests
  for each row execute function public.validate_order_request_update();

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

-- Starter catalog with suggested prices in Philippine pesos (PHP). Fixed IDs
-- make this safe to rerun, and staff can edit these rows after installation.
insert into public.products (id, name, description, image_url, price, quantity,
  category, badge, available_sizes, available_colors) values
('10000000-0000-4000-8000-000000000001','Linen Blend Blazer','Natural / Relaxed fit','https://images.unsplash.com/photo-1591047139829-d91aecb6caea?auto=format&fit=crop&w=700&q=80',2490,20,'Clothing','BESTSELLER',array['XS','S','M','L','XL'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000002','Everyday Knit','Oatmeal / Organic cotton','https://images.unsplash.com/photo-1620799140408-edc6dcb6d633?auto=format&fit=crop&w=700&q=80',1290,20,'Clothing','TRENDING',array['XS','S','M','L','XL'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000003','Weekend Shirt','Soft blue / Cotton poplin','https://images.unsplash.com/photo-1598033129183-c4f50c736f10?auto=format&fit=crop&w=700&q=80',990,20,'Clothing','',array['XS','S','M','L','XL'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000004','Tailored Trouser','Stone / Wide leg','https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?auto=format&fit=crop&w=700&q=80',1490,20,'Clothing','',array['XS','S','M','L','XL'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000005','Classic Trench Coat','Sand / Water resistant','https://images.unsplash.com/photo-1548126032-079a0fb0099d?auto=format&fit=crop&w=700&q=80',3490,20,'Clothing','NEW',array['XS','S','M','L','XL'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000006','Soft Cotton Tee','White / Everyday essential','https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=700&q=80',490,20,'Clothing','SALE',array['XS','S','M','L','XL'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000007','Relaxed Denim','Vintage blue / Straight leg','https://images.unsplash.com/photo-1541099649105-f69ad21f3246?auto=format&fit=crop&w=700&q=80',1690,20,'Clothing','',array['XS','S','M','L','XL'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000008','Ribbed Tank','Cream / Soft stretch','https://images.unsplash.com/photo-1503342217505-b0a15ec3261c?auto=format&fit=crop&w=700&q=80',390,20,'Clothing','',array['XS','S','M','L','XL'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000009','City Sneaker','White / Recycled canvas','https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=700&q=80',1790,20,'Shoes','POPULAR',array['6','7','8','9','10'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000010','Leather Loafer','Warm brown / Soft leather','https://images.unsplash.com/photo-1531310197839-ccf54634509e?auto=format&fit=crop&w=700&q=80',1990,20,'Shoes','',array['6','7','8','9','10'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000011','Everywhere Tote','Natural / Roomy canvas','https://images.unsplash.com/photo-1590874103328-eac38a683ce7?auto=format&fit=crop&w=700&q=80',790,20,'Bags','STAFF PICK',array['One size'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000012','Mini Shoulder Bag','Espresso / Vegan leather','https://images.unsplash.com/photo-1584917865442-de89df76afd3?auto=format&fit=crop&w=700&q=80',1190,20,'Bags','',array['One size'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000013','Everyday Belt','Tan / Genuine leather','https://images.unsplash.com/photo-1624222247344-550fb8d5d2b0?auto=format&fit=crop&w=700&q=80',590,20,'Accessories','',array['S','M','L'],array['Natural','Black','Olive']),
('10000000-0000-4000-8000-000000000014','Soft Wool Scarf','Moss / Merino blend','https://images.unsplash.com/photo-1601924994987-69e26d50dc26?auto=format&fit=crop&w=700&q=80',690,20,'Accessories','',array['One size'],array['Natural','Black','Olive'])
on conflict (id) do nothing;
  update public.products set compare_at_price = 690
  where id = '10000000-0000-4000-8000-000000000006'
    and compare_at_price is null;

-- Enable live order and request updates for the customer screens.
do $$
begin
  if not exists (select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'orders') then
    alter publication supabase_realtime add table public.orders;
  end if;
  if not exists (select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'support_requests') then
    alter publication supabase_realtime add table public.support_requests;
  end if;
  if not exists (select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'order_requests') then
    alter publication supabase_realtime add table public.order_requests;
  end if;
end;
$$;
