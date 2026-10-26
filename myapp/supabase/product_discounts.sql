-- Run once in the Supabase SQL Editor for an existing project.
-- Existing product prices and discounts are not changed.
-- A null discount_percent keeps older manually priced sales intact.
begin;

alter table public.products
  add column if not exists discount_percent numeric(5,2);

alter table public.products
  drop constraint if exists products_discount_percent_valid;

alter table public.products
  add constraint products_discount_percent_valid check (
    discount_percent is null or (
      discount_percent > 0 and discount_percent < 100
      and compare_at_price is not null
      and compare_at_price > price
      and price = round(compare_at_price * (1 - discount_percent / 100), 2)
    )
  );

commit;
