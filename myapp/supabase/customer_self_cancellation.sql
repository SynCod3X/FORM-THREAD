-- Run after customer_flow_upgrade.sql and xendit_demo_payments.sql.
-- A customer may cancel only their own order while staff has not moved it
-- beyond pending. The existing order status trigger restores reserved stock
-- once and flags already-paid Xendit orders as refund_due.
create or replace function public.cancel_pending_order(p_order_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_customer_id uuid := (select auth.uid());
  v_request_id uuid;
  v_order_customer_id uuid;
  v_order_status text;
begin
  if v_customer_id is null then
    raise exception 'Please sign in to cancel an order.';
  end if;

  -- Lock an existing request before the order, matching the lock order used
  -- by the staff request trigger. This avoids racing a staff decision.
  select id into v_request_id
  from public.order_requests
  where order_id = p_order_id and customer_id = v_customer_id
    and type = 'cancellation' and status = 'pending'
  for update;

  select customer_id, status into v_order_customer_id, v_order_status
  from public.orders where id = p_order_id for update;
  if not found or v_order_customer_id is distinct from v_customer_id then
    raise exception 'Order not found for this customer.';
  end if;
  if v_order_status <> 'pending' then
    raise exception 'This order is already being processed or is closed. Ask staff for help.';
  end if;

  if v_request_id is not null then
    -- Approving the customer's older pending request also cancels the order
    -- through validate_order_request_update, all in this transaction.
    update public.order_requests set status = 'approved'
    where id = v_request_id;
  else
    update public.orders set status = 'cancelled' where id = p_order_id;
  end if;
end;
$$;
revoke all on function public.cancel_pending_order(uuid) from public, anon;
grant execute on function public.cancel_pending_order(uuid) to authenticated;
