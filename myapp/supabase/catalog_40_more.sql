-- Run after schema.sql and customer_flow_upgrade.sql.
-- Adds 10 NEW sample products to EACH shop category (40 total).
-- Photos are illustrative Unsplash images; replace with actual inventory photos.
-- Fixed UUIDs plus ON CONFLICT make this safe to rerun without duplicates.
-- Prices are suggested Philippine-peso (PHP) amounts.

begin;
-- Clothing (10 products)
insert into public.products
  (id, name, description, image_url, price, quantity, is_active,
   category, badge, compare_at_price, available_sizes, available_colors)
values
  ('10000000-0000-4000-8000-000000000025', 'Breton Stripe Tee', 'Black and white / Easy everyday style',
   'https://images.unsplash.com/photo-1569314310775-469add9953f4?auto=format&fit=crop&w=700&q=80', 590, 24, true,
   'Clothing', 'NEW', null, array['XS','S','M','L','XL'], array['Black and White']),
  ('10000000-0000-4000-8000-000000000026', 'Pleated Midi Skirt', 'Soft neutral / Flowing silhouette',
   'https://images.unsplash.com/photo-1497920261388-9c5866b65061?auto=format&fit=crop&w=700&q=80', 1290, 18, true,
   'Clothing', '', null, array['XS','S','M','L','XL'], array['Neutral']),
  ('10000000-0000-4000-8000-000000000027', 'Floral Wrap Dress', 'Floral / Relaxed wrap fit',
   'https://images.unsplash.com/photo-1759992878336-a5dd342ea245?auto=format&fit=crop&w=700&q=80', 1790, 16, true,
   'Clothing', 'NEW', null, array['XS','S','M','L','XL'], array['Floral']),
  ('10000000-0000-4000-8000-000000000028', 'Relaxed Linen Shirt', 'White / Light everyday layer',
   'https://images.unsplash.com/photo-1752825609278-f9696bc9d7bd?auto=format&fit=crop&w=700&q=80', 1190, 20, true,
   'Clothing', '', null, array['XS','S','M','L','XL'], array['White']),
  ('10000000-0000-4000-8000-000000000029', 'Blue Summer Dress', 'Light blue / Breezy day style',
   'https://images.unsplash.com/photo-1762342689302-e9d0e9078300?auto=format&fit=crop&w=700&q=80', 1590, 15, true,
   'Clothing', '', null, array['XS','S','M','L','XL'], array['Light Blue']),
  ('10000000-0000-4000-8000-000000000030', 'Beige Trench Coat', 'Beige / Classic outer layer',
   'https://images.unsplash.com/photo-1544997867-784de8a9918e?auto=format&fit=crop&w=700&q=80', 3490, 12, true,
   'Clothing', '', null, array['XS','S','M','L','XL'], array['Beige']),
  ('10000000-0000-4000-8000-000000000031', 'Open Front Cardigan', 'Black / Easy layering',
   'https://images.unsplash.com/photo-1608623643122-ba620a693c3b?auto=format&fit=crop&w=700&q=80', 1290, 20, true,
   'Clothing', '', null, array['XS','S','M','L','XL'], array['Black']),
  ('10000000-0000-4000-8000-000000000032', 'Essential White Tee', 'White / Clean everyday basic',
   'https://images.unsplash.com/photo-1722310752951-4d459d28c678?auto=format&fit=crop&w=700&q=80', 490, 30, true,
   'Clothing', '', null, array['XS','S','M','L','XL'], array['White']),
  ('10000000-0000-4000-8000-000000000033', 'Tropical Wide-Leg Trousers', 'Leaf print / Relaxed fit',
   'https://images.unsplash.com/photo-1789110520500-de902eeb2b16?auto=format&fit=crop&w=700&q=80', 1490, 17, true,
   'Clothing', 'SALE', 1890, array['XS','S','M','L','XL'], array['Tropical Print']),
  ('10000000-0000-4000-8000-000000000034', 'Everyday Grey Hoodie', 'Grey / Casual comfort',
   'https://images.unsplash.com/photo-1566184756292-ad763b7c526e?auto=format&fit=crop&w=700&q=80', 1290, 21, true,
   'Clothing', '', null, array['XS','S','M','L','XL'], array['Grey'])
on conflict (id) do nothing;

-- Shoes (10 products)
insert into public.products
  (id, name, description, image_url, price, quantity, is_active,
   category, badge, compare_at_price, available_sizes, available_colors)
values
  ('10000000-0000-4000-8000-000000000035', 'White Running Trainers', 'White / Active everyday style',
   'https://images.unsplash.com/photo-1553098248-de32bad54944?auto=format&fit=crop&w=700&q=80', 1990, 20, true,
   'Shoes', 'NEW', null, array['6','7','8','9','10'], array['White']),
  ('10000000-0000-4000-8000-000000000036', 'Brown Casual Loafers', 'Brown / Easy slip-on style',
   'https://images.unsplash.com/photo-1559334417-01b38aec66bd?auto=format&fit=crop&w=700&q=80', 1990, 15, true,
   'Shoes', '', null, array['6','7','8','9','10'], array['Brown']),
  ('10000000-0000-4000-8000-000000000037', 'Black Evening Heels', 'Black / Dress-up essential',
   'https://images.unsplash.com/photo-1770576568723-c557b096394b?auto=format&fit=crop&w=700&q=80', 2290, 12, true,
   'Shoes', '', null, array['6','7','8','9','10'], array['Black']),
  ('10000000-0000-4000-8000-000000000038', 'Beach Sandals', 'Natural / Easy warm-weather pair',
   'https://images.unsplash.com/photo-1644311823665-401351ac6851?auto=format&fit=crop&w=700&q=80', 890, 22, true,
   'Shoes', '', null, array['6','7','8','9','10'], array['Natural']),
  ('10000000-0000-4000-8000-000000000039', 'Red Canvas Sneakers', 'Red / Everyday lace-up',
   'https://images.unsplash.com/photo-1650320079970-b4ee8f0dae33?auto=format&fit=crop&w=700&q=80', 1290, 18, true,
   'Shoes', 'NEW', null, array['6','7','8','9','10'], array['Red']),
  ('10000000-0000-4000-8000-000000000040', 'Classic Ballet Flats', 'Neutral / Light everyday pair',
   'https://images.unsplash.com/photo-1773520945951-5321a377151a?auto=format&fit=crop&w=700&q=80', 1390, 17, true,
   'Shoes', '', null, array['6','7','8','9','10'], array['Neutral']),
  ('10000000-0000-4000-8000-000000000041', 'Trail Hiking Boots', 'Brown / Outdoor-ready style',
   'https://images.unsplash.com/photo-1766198198372-156e7a6cba36?auto=format&fit=crop&w=700&q=80', 2990, 13, true,
   'Shoes', '', null, array['6','7','8','9','10'], array['Brown']),
  ('10000000-0000-4000-8000-000000000042', 'Two-Tone Slide Sandals', 'White and brown / Easy slip-on',
   'https://images.unsplash.com/photo-1592151450183-908248f743e9?auto=format&fit=crop&w=700&q=80', 690, 24, true,
   'Shoes', 'SALE', 890, array['6','7','8','9','10'], array['White and Brown']),
  ('10000000-0000-4000-8000-000000000043', 'Black Street Sneakers', 'Black / Casual lace-up',
   'https://images.unsplash.com/photo-1752341695600-c52cc88ba60b?auto=format&fit=crop&w=700&q=80', 1790, 19, true,
   'Shoes', '', null, array['6','7','8','9','10'], array['Black']),
  ('10000000-0000-4000-8000-000000000044', 'Black Ankle Boots', 'Black / Everyday boot style',
   'https://images.unsplash.com/photo-1545921150-b45e7b7af76a?auto=format&fit=crop&w=700&q=80', 2490, 14, true,
   'Shoes', '', null, array['6','7','8','9','10'], array['Black'])
on conflict (id) do nothing;

-- Bags (10 products)
insert into public.products
  (id, name, description, image_url, price, quantity, is_active,
   category, badge, compare_at_price, available_sizes, available_colors)
values
  ('10000000-0000-4000-8000-000000000045', 'Black Structured Handbag', 'Black / Polished daily carry',
   'https://images.unsplash.com/photo-1702326626601-74d2e86922b4?auto=format&fit=crop&w=700&q=80', 1990, 14, true,
   'Bags', 'NEW', null, array['One size'], array['Black']),
  ('10000000-0000-4000-8000-000000000046', 'Pink Crossbody Bag', 'Pink / Hands-free style',
   'https://images.unsplash.com/photo-1566150905458-1bf1fc113f0d?auto=format&fit=crop&w=700&q=80', 1190, 18, true,
   'Bags', '', null, array['One size'], array['Pink']),
  ('10000000-0000-4000-8000-000000000047', 'Printed Canvas Tote', 'Natural / Lightweight carryall',
   'https://images.unsplash.com/photo-1772890753143-24991d807710?auto=format&fit=crop&w=700&q=80', 690, 26, true,
   'Bags', '', null, array['One size'], array['Natural']),
  ('10000000-0000-4000-8000-000000000048', 'Black Crossbody Bag', 'Black / Compact everyday bag',
   'https://images.unsplash.com/photo-1569313717948-f797bcbf00db?auto=format&fit=crop&w=700&q=80', 1390, 19, true,
   'Bags', '', null, array['One size'], array['Black']),
  ('10000000-0000-4000-8000-000000000049', 'Brown Leather Backpack', 'Brown / Roomy everyday bag',
   'https://images.unsplash.com/photo-1622560480605-d83c853bc5c3?auto=format&fit=crop&w=700&q=80', 2790, 12, true,
   'Bags', '', null, array['One size'], array['Brown']),
  ('10000000-0000-4000-8000-000000000050', 'Black Weekender Bag', 'Black / Easy overnight carry',
   'https://images.unsplash.com/photo-1758542988969-39a10168b2ce?auto=format&fit=crop&w=700&q=80', 2490, 11, true,
   'Bags', '', null, array['One size'], array['Black']),
  ('10000000-0000-4000-8000-000000000051', 'Everyday Clutch Bag', 'Tan / Compact hand carry',
   'https://images.unsplash.com/photo-1486308510493-aa64833637bc?auto=format&fit=crop&w=700&q=80', 990, 16, true,
   'Bags', '', null, array['One size'], array['Tan']),
  ('10000000-0000-4000-8000-000000000052', 'Red Crossbody Bag', 'Red / Bright statement carry',
   'https://images.unsplash.com/photo-1484527273420-c598cb0601f8?auto=format&fit=crop&w=700&q=80', 1290, 15, true,
   'Bags', 'NEW', null, array['One size'], array['Red']),
  ('10000000-0000-4000-8000-000000000053', 'Canvas Carryall', 'Brown / Simple daily tote',
   'https://images.unsplash.com/photo-1732963574895-f4b6af2dec06?auto=format&fit=crop&w=700&q=80', 790, 25, true,
   'Bags', 'SALE', 990, array['One size'], array['Brown']),
  ('10000000-0000-4000-8000-000000000054', 'Woven Straw Bag', 'Natural / Warm-weather carry',
   'https://images.unsplash.com/photo-1650226291607-b3a8124238c5?auto=format&fit=crop&w=700&q=80', 990, 20, true,
   'Bags', '', null, array['One size'], array['Natural'])
on conflict (id) do nothing;

-- Accessories (10 products)
insert into public.products
  (id, name, description, image_url, price, quantity, is_active,
   category, badge, compare_at_price, available_sizes, available_colors)
values
  ('10000000-0000-4000-8000-000000000055', 'Gold Earrings', 'Gold / Everyday shine',
   'https://images.unsplash.com/photo-1708390071625-4096abb3af24?auto=format&fit=crop&w=700&q=80', 490, 25, true,
   'Accessories', 'NEW', null, array['One size'], array['Gold']),
  ('10000000-0000-4000-8000-000000000056', 'Silver Cuff Bracelet', 'Silver / Minimal finishing touch',
   'https://images.unsplash.com/photo-1681091639096-a7b2eb1d4990?auto=format&fit=crop&w=700&q=80', 690, 18, true,
   'Accessories', '', null, array['One size'], array['Silver']),
  ('10000000-0000-4000-8000-000000000057', 'Black Leather Belt', 'Black / Classic buckle detail',
   'https://images.unsplash.com/photo-1664286074176-5206ee5dc878?auto=format&fit=crop&w=700&q=80', 590, 22, true,
   'Accessories', '', null, array['S','M','L'], array['Black']),
  ('10000000-0000-4000-8000-000000000058', 'Gold Wristwatch', 'Gold / Polished timepiece',
   'https://images.unsplash.com/photo-1776370045971-f1a35e9fdeca?auto=format&fit=crop&w=700&q=80', 1990, 12, true,
   'Accessories', '', null, array['One size'], array['Gold']),
  ('10000000-0000-4000-8000-000000000059', 'Straw Sun Hat', 'Natural / Summer-ready style',
   'https://images.unsplash.com/photo-1560890531-5f937e988162?auto=format&fit=crop&w=700&q=80', 690, 19, true,
   'Accessories', '', null, array['One size'], array['Natural']),
  ('10000000-0000-4000-8000-000000000060', 'Silver Statement Ring', 'Silver / Standout detail',
   'https://images.unsplash.com/photo-1611146942956-d6be598e13cd?auto=format&fit=crop&w=700&q=80', 490, 24, true,
   'Accessories', '', null, array['6','7','8','9'], array['Silver']),
  ('10000000-0000-4000-8000-000000000061', 'Minimal Hair Clip', 'Neutral / Easy hair styling',
   'https://images.unsplash.com/photo-1748687060038-01162304e649?auto=format&fit=crop&w=700&q=80', 190, 30, true,
   'Accessories', '', null, array['One size'], array['Neutral']),
  ('10000000-0000-4000-8000-000000000062', 'Silver Pendant Necklace', 'Silver / Delicate everyday detail',
   'https://images.unsplash.com/photo-1631050165155-421c47e306f7?auto=format&fit=crop&w=700&q=80', 690, 20, true,
   'Accessories', 'NEW', null, array['One size'], array['Silver']),
  ('10000000-0000-4000-8000-000000000063', 'Colorful Silk Scarf', 'Multicolor / Versatile accent',
   'https://images.unsplash.com/photo-1684973470140-9eab1ab2ff4f?auto=format&fit=crop&w=700&q=80', 790, 17, true,
   'Accessories', 'SALE', 990, array['One size'], array['Multicolor']),
  ('10000000-0000-4000-8000-000000000064', 'Gold Aviator Sunglasses', 'Gold / Classic sun style',
   'https://images.unsplash.com/photo-1707101727273-100aba43fed7?auto=format&fit=crop&w=700&q=80', 890, 16, true,
   'Accessories', '', null, array['One size'], array['Gold'])
on conflict (id) do nothing;

commit;
