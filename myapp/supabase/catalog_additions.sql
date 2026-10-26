-- Run in the Supabase SQL Editor after schema.sql/customer_flow_upgrade.sql.
-- Demo product photos are from Unsplash. Replace them with photos of your
-- actual inventory before selling these products.
-- Fixed UUIDs and ON CONFLICT make this safe to run again without duplicates.
-- Prices are suggested Philippine-peso (PHP) amounts.

insert into public.products (
  id, name, description, image_url, price, quantity, is_active,
  category, badge, compare_at_price, available_sizes, available_colors
) values
  (
    '10000000-0000-4000-8000-000000000015',
    'Pearl Collar Blouse', 'White / Polished everyday style',
    'https://images.unsplash.com/photo-1571044420976-94b71786bae8?auto=format&fit=crop&w=700&q=80',
    1190, 18, true, 'Clothing', 'NEW', null,
    array['XS','S','M','L','XL'], array['White']
  ),
  (
    '10000000-0000-4000-8000-000000000016',
    'Classic Denim Jacket', 'Blue / Casual layering piece',
    'https://images.unsplash.com/photo-1708523842501-1619478cea1f?auto=format&fit=crop&w=700&q=80',
    1790, 15, true, 'Clothing', 'NEW', null,
    array['XS','S','M','L','XL'], array['Blue']
  ),
  (
    '10000000-0000-4000-8000-000000000017',
    'Evening Black Dress', 'Black / Easy occasion dressing',
    'https://images.unsplash.com/photo-1568251188392-ae32f898cb3b?auto=format&fit=crop&w=700&q=80',
    1990, 12, true, 'Clothing', '', null,
    array['XS','S','M','L','XL'], array['Black']
  ),
  (
    '10000000-0000-4000-8000-000000000018',
    'Cozy Knit Sweater', 'Cream / Relaxed cool-weather layer',
    'https://images.unsplash.com/photo-1621705471214-b1e0a2b42bcd?auto=format&fit=crop&w=700&q=80',
    1390, 20, true, 'Clothing', '', null,
    array['XS','S','M','L','XL'], array['Cream']
  ),
  (
    '10000000-0000-4000-8000-000000000019',
    'Minimal White Sneakers', 'White / Everyday low-top style',
    'https://images.unsplash.com/photo-1553808373-92b0bcc3af65?auto=format&fit=crop&w=700&q=80',
    1790, 22, true, 'Shoes', '', null,
    array['6','7','8','9','10'], array['White']
  ),
  (
    '10000000-0000-4000-8000-000000000020',
    'Black Leather Boots', 'Black / Statement tall boots',
    'https://images.unsplash.com/photo-1763661300203-aa3e2702f510?auto=format&fit=crop&w=700&q=80',
    2990, 10, true, 'Shoes', 'NEW', null,
    array['6','7','8','9','10'], array['Black']
  ),
  (
    '10000000-0000-4000-8000-000000000021',
    'Heritage Leather Bag', 'Brown / Compact daily carry',
    'https://images.unsplash.com/photo-1657603498362-6188f4bcbf75?auto=format&fit=crop&w=700&q=80',
    2490, 14, true, 'Bags', '', null,
    array['One size'], array['Brown']
  ),
  (
    '10000000-0000-4000-8000-000000000022',
    'Canvas Market Tote', 'Beige / Roomy carryall',
    'https://images.unsplash.com/photo-1542957057-debadce4ce81?auto=format&fit=crop&w=700&q=80',
    690, 25, true, 'Bags', 'SALE', 890,
    array['One size'], array['Beige']
  ),
  (
    '10000000-0000-4000-8000-000000000023',
    'Gold Chain Necklace', 'Gold / Simple finishing touch',
    'https://images.unsplash.com/photo-1611107683227-e9060eccd846?auto=format&fit=crop&w=700&q=80',
    590, 16, true, 'Accessories', '', null,
    array['One size'], array['Gold']
  ),
  (
    '10000000-0000-4000-8000-000000000024',
    'Classic Sunglasses', 'Dark / Everyday sun style',
    'https://images.unsplash.com/photo-1711223499758-8aef018b720e?auto=format&fit=crop&w=700&q=80',
    790, 19, true, 'Accessories', 'NEW', null,
    array['One size'], array['Black']
  )
on conflict (id) do nothing;
