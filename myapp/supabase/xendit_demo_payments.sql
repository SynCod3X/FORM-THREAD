-- Run after schema.sql / customer_flow_upgrade.sql. Xendit is TEST MODE only.
-- The existing place_order(jsonb) still handles stock and server-side prices.
-- Older installations may not have orders.currency. New orders default to PHP;
-- only Xendit demo orders are backfilled because older cash order currency
-- cannot be inferred safely from its amount.
alter table public.orders add column if not exists currency text;
alter table public.orders alter column currency set default 'PHP';

alter table public.orders
  add column if not exists payment_method text not null default 'cash',
  add column if not exists payment_status text not null default 'cash_due',
  add column if not exists xendit_request_id text,
  add column if not exists xendit_payment_id text,
  add column if not exists payment_action jsonb,
  add column if not exists payment_expires_at timestamptz;

update public.orders
set currency = 'PHP'
where currency is null and payment_method in ('gcash', 'bank_transfer');

alter table public.orders drop constraint if exists orders_payment_method_check;
alter table public.orders add constraint orders_payment_method_check
  check (payment_method in ('cash', 'gcash', 'bank_transfer'));
alter table public.orders drop constraint if exists orders_payment_status_check;
alter table public.orders add constraint orders_payment_status_check
  check (payment_status in ('cash_due', 'awaiting_payment', 'paid', 'failed', 'payment_review', 'refund_due'));
create unique index if not exists orders_xendit_request_id_key
  on public.orders (xendit_request_id) where xendit_request_id is not null;

-- Atomic wrapper: an order is not visible until its chosen method is saved.
create or replace function public.place_order_with_payment(p_items jsonb, p_payment_method text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if p_payment_method not in ('cash', 'gcash', 'bank_transfer') or p_payment_method is null then
    raise exception 'Choose a valid payment method.';
  end if;
  v_id := public.place_order(p_items);
  update public.orders set payment_method = p_payment_method,
    payment_status = case when p_payment_method = 'cash' then 'cash_due' else 'awaiting_payment' end
  where id = v_id and customer_id = (select auth.uid());
  return v_id;
end;
$$;
revoke all on function public.place_order_with_payment(jsonb,text) from public, anon;
grant execute on function public.place_order_with_payment(jsonb,text) to authenticated;

-- Only an Edge Function using service_role can attach Xendit's response.
create or replace function public.attach_xendit_payment(
  p_order_id uuid, p_request_id text, p_action jsonb, p_expires_at timestamptz default null
) returns void language plpgsql security definer set search_path = '' as $$
begin
  if nullif(p_request_id, '') is null or jsonb_typeof(p_action) <> 'object' then
    raise exception 'Invalid Xendit payment response.';
  end if;
  update public.orders set
    xendit_request_id = p_request_id,
    payment_action = p_action,
    payment_expires_at = p_expires_at,
    updated_at = now()
  where id = p_order_id and payment_method in ('gcash','bank_transfer')
    and (xendit_request_id is null or xendit_request_id = p_request_id);
  if not found then raise exception 'Payment request could not be attached.'; end if;
end;
$$;
revoke all on function public.attach_xendit_payment(uuid,text,jsonb,timestamptz) from public, anon, authenticated;
grant execute on function public.attach_xendit_payment(uuid,text,jsonb,timestamptz) to service_role;

-- Fulfilment is prohibited until a trusted callback records payment.
create or replace function public.validate_order_status_change()
returns trigger language plpgsql set search_path = '' as $$
declare v_item jsonb;
begin
  if new.status = old.status then return new; end if;
  if not (
    (old.status = 'pending' and new.status in ('processing', 'cancelled'))
    or (old.status = 'processing' and new.status in ('shipped', 'cancelled'))
    or (old.status = 'shipped' and new.status = 'completed')
  ) then
    raise exception 'Invalid order status change: % to %', old.status, new.status;
  end if;
  if new.status = 'processing' and old.payment_method <> 'cash'
     and old.payment_status <> 'paid' then
    raise exception 'Online payment has not been confirmed.';
  end if;
  if new.status = 'cancelled' then
    if old.payment_status = 'paid' then new.payment_status := 'refund_due'; end if;
    for v_item in select value from jsonb_array_elements(old.items) as x(value) loop
      if nullif(v_item ->> 'product_id', '') is not null then
        update public.products
        set quantity = quantity + (v_item ->> 'quantity')::integer,
            updated_at = now()
        where id = (v_item ->> 'product_id')::uuid;
      end if;
    end loop;
  end if;
  new.updated_at := now();
  return new;
end;
$$;

-- Token verification happens in xendit-webhook. This function also checks
-- request identity, amount, currency, and makes duplicate callbacks harmless.
create or replace function public.apply_xendit_event(
  p_order_id uuid, p_request_id text, p_event text, p_amount numeric,
  p_currency text, p_payment_id text default null
) returns void language plpgsql security definer set search_path = '' as $$
declare v_order public.orders%rowtype;
begin
  select * into v_order from public.orders where id = p_order_id for update;
  if not found or v_order.payment_method not in ('gcash','bank_transfer')
     or v_order.xendit_request_id is distinct from p_request_id
     or v_order.total is distinct from p_amount or p_currency <> 'PHP' then
    raise exception 'Payment event does not match the order.';
  end if;
  if p_event = 'payment.capture' then
    if v_order.payment_status = 'paid' then return; end if;
    if v_order.status = 'cancelled' or v_order.payment_status in ('failed','refund_due') then
      update public.orders set payment_status = 'payment_review',
        xendit_payment_id = p_payment_id, updated_at = now() where id = p_order_id;
    else
      update public.orders set payment_status = 'paid',
        xendit_payment_id = p_payment_id, updated_at = now() where id = p_order_id;
    end if;
  elsif p_event in ('payment.failure','payment_request.expiry') then
    if v_order.payment_status <> 'awaiting_payment' then return; end if;
    update public.orders set payment_status = 'failed', status = 'cancelled'
      where id = p_order_id;
  else
    raise exception 'Unsupported payment event.';
  end if;
end;
$$;
revoke all on function public.apply_xendit_event(uuid,text,text,numeric,text,text) from public, anon, authenticated;
grant execute on function public.apply_xendit_event(uuid,text,text,numeric,text,text) to service_role;
