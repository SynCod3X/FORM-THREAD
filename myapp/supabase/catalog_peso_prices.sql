-- Run once after the schema and whichever sample catalog scripts you used.
-- These are suggested Philippine retail prices for the 64 fixed-ID demo items,
-- not verified prices of the illustrative photos. No foreign-exchange conversion.
-- A row is changed only if its price and sale/original price still match the
-- original demo values, so a staff-edited price is not overwritten.
-- Existing order snapshots keep their old amount and are labelled USD;
-- new orders use PHP through the orders.currency default.

begin;

alter table public.orders add column if not exists currency text;
update public.orders set currency = 'USD' where currency is null;
alter table public.orders alter column currency set default 'PHP';
alter table public.orders alter column currency set not null;

create temporary table sample_peso_prices (
  id uuid primary key,
  old_price numeric(10,2) not null,
  old_original numeric(10,2),
  peso_price numeric(10,2) not null,
  peso_original numeric(10,2)
) on commit drop;

insert into sample_peso_prices values
('10000000-0000-4000-8000-000000000001',128,null,2490,null),
('10000000-0000-4000-8000-000000000002',74,null,1290,null),
('10000000-0000-4000-8000-000000000003',89,null,990,null),
('10000000-0000-4000-8000-000000000004',110,null,1490,null),
('10000000-0000-4000-8000-000000000005',155,null,3490,null),
('10000000-0000-4000-8000-000000000006',38,48,490,690),
('10000000-0000-4000-8000-000000000007',92,null,1690,null),
('10000000-0000-4000-8000-000000000008',32,null,390,null),
('10000000-0000-4000-8000-000000000009',86,null,1790,null),
('10000000-0000-4000-8000-000000000010',120,null,1990,null),
('10000000-0000-4000-8000-000000000011',45,null,790,null),
('10000000-0000-4000-8000-000000000012',68,null,1190,null),
('10000000-0000-4000-8000-000000000013',42,null,590,null),
('10000000-0000-4000-8000-000000000014',58,null,690,null),
('10000000-0000-4000-8000-000000000015',62,null,1190,null),
('10000000-0000-4000-8000-000000000016',98,null,1790,null),
('10000000-0000-4000-8000-000000000017',119,null,1990,null),
('10000000-0000-4000-8000-000000000018',79,null,1390,null),
('10000000-0000-4000-8000-000000000019',89,null,1790,null),
('10000000-0000-4000-8000-000000000020',149,null,2990,null),
('10000000-0000-4000-8000-000000000021',105,null,2490,null),
('10000000-0000-4000-8000-000000000022',39,49,690,890),
('10000000-0000-4000-8000-000000000023',54,null,590,null),
('10000000-0000-4000-8000-000000000024',48,null,790,null),
('10000000-0000-4000-8000-000000000025',46,null,590,null),
('10000000-0000-4000-8000-000000000026',72,null,1290,null),
('10000000-0000-4000-8000-000000000027',96,null,1790,null),
('10000000-0000-4000-8000-000000000028',68,null,1190,null),
('10000000-0000-4000-8000-000000000029',88,null,1590,null),
('10000000-0000-4000-8000-000000000030',158,null,3490,null),
('10000000-0000-4000-8000-000000000031',76,null,1290,null),
('10000000-0000-4000-8000-000000000032',34,null,490,null),
('10000000-0000-4000-8000-000000000033',82,105,1490,1890),
('10000000-0000-4000-8000-000000000034',69,null,1290,null),
('10000000-0000-4000-8000-000000000035',94,null,1990,null),
('10000000-0000-4000-8000-000000000036',112,null,1990,null),
('10000000-0000-4000-8000-000000000037',125,null,2290,null),
('10000000-0000-4000-8000-000000000038',52,null,890,null),
('10000000-0000-4000-8000-000000000039',72,null,1290,null),
('10000000-0000-4000-8000-000000000040',68,null,1390,null),
('10000000-0000-4000-8000-000000000041',138,null,2990,null),
('10000000-0000-4000-8000-000000000042',48,62,690,890),
('10000000-0000-4000-8000-000000000043',89,null,1790,null),
('10000000-0000-4000-8000-000000000044',132,null,2490,null),
('10000000-0000-4000-8000-000000000045',118,null,1990,null),
('10000000-0000-4000-8000-000000000046',74,null,1190,null),
('10000000-0000-4000-8000-000000000047',42,null,690,null),
('10000000-0000-4000-8000-000000000048',86,null,1390,null),
('10000000-0000-4000-8000-000000000049',142,null,2790,null),
('10000000-0000-4000-8000-000000000050',155,null,2490,null),
('10000000-0000-4000-8000-000000000051',65,null,990,null),
('10000000-0000-4000-8000-000000000052',78,null,1290,null),
('10000000-0000-4000-8000-000000000053',49,64,790,990),
('10000000-0000-4000-8000-000000000054',58,null,990,null),
('10000000-0000-4000-8000-000000000055',39,null,490,null),
('10000000-0000-4000-8000-000000000056',55,null,690,null),
('10000000-0000-4000-8000-000000000057',48,null,590,null),
('10000000-0000-4000-8000-000000000058',124,null,1990,null),
('10000000-0000-4000-8000-000000000059',44,null,690,null),
('10000000-0000-4000-8000-000000000060',36,null,490,null),
('10000000-0000-4000-8000-000000000061',18,null,190,null),
('10000000-0000-4000-8000-000000000062',58,null,690,null),
('10000000-0000-4000-8000-000000000063',52,68,790,990),
('10000000-0000-4000-8000-000000000064',64,null,890,null);

update public.products p
set price = v.peso_price,
    compare_at_price = v.peso_original,
    updated_at = now()
from sample_peso_prices v
where p.id = v.id
  and p.price = v.old_price
  and p.compare_at_price is not distinct from v.old_original;

-- Review these manually in Staff > Products: custom products and demo rows
-- whose prices had already been edited. Their currency cannot be inferred.
select p.id, p.name, p.category, p.price, p.compare_at_price,
       case when v.id is null then 'Custom product; verify PHP price'
            else 'Edited demo price; verify PHP price' end as review_reason
from public.products p
left join sample_peso_prices v on v.id = p.id
where v.id is null
   or p.price is distinct from v.peso_price
   or p.compare_at_price is distinct from v.peso_original
order by p.name;

commit;
