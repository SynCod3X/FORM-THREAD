# Supabase setup

## Xendit demo payments (test mode only)

Run [`xendit_demo_payments.sql`](xendit_demo_payments.sql) in the Supabase SQL Editor **after** the schema/customer-flow SQL, and before using the updated checkout. The app now calls `place_order_with_payment`, so checkout needs this migration even for cash orders. Existing orders default to cash on delivery. This migration also adds `orders.currency` to older installations, defaults new orders to PHP, and backfills existing Xendit demo orders to PHP without guessing the currency of older cash orders.

Run [`customer_self_cancellation.sql`](customer_self_cancellation.sql) after the customer-flow and Xendit scripts to let a customer cancel their own `pending` order immediately. The database rejects cancellation once staff moves it to `processing`. An older pending cancellation request is resolved automatically; completed orders still use the staff-assisted return process.

In the Xendit dashboard, switch to **Test Mode**, create a **secret test API key** with Money-in write access, and copy the **test webhook verification token**. Never paste either value into Flutter or commit it to this repository. Add them as Supabase Edge Function secrets named `XENDIT_TEST_SECRET_KEY` and `XENDIT_WEBHOOK_TOKEN` in your project's Edge Functions settings. The create function rejects a key that does not begin with `xnd_development_` to prevent live transactions.

Deploy these functions to the **same Supabase project** as the app:

```sh
supabase functions deploy create-xendit-payment
supabase functions deploy xendit-webhook --no-verify-jwt
supabase functions deploy xendit-return --no-verify-jwt
```

In Xendit **Test Mode → Settings → Webhooks**, set **Payment Requests v3 – Payment Status** and **Payment Requests v3 – Payment Request Status** to `https://YOUR_PROJECT_REF.supabase.co/functions/v1/xendit-webhook`. Use the same test webhook token in Supabase secrets. Test a GCash payment and a bank transfer in Xendit's simulator, then refresh the order page. A payment is marked paid only by a verified Xendit callback. The return page itself does not confirm payment. GCash opens Xendit's test redirect; bank transfer displays the test virtual account. Cash on delivery bypasses Xendit.

After deploying `xendit-webhook`, click **Test and save** for each Payment Requests v3 webhook topic. Xendit's dashboard uses an IDR sample; the webhook acknowledges this authenticated non-PHP event without updating any order. A real payment is marked paid only when its verified PHP callback matches the saved order and payment request.

Online orders reserve stock while awaiting payment. A verified failed/expired callback cancels the order and returns stock. Staff cannot mark an unpaid online order processing. If a capture arrives after cancellation, the order is flagged `payment_review` and must be handled manually. Refunds are **not** automated; paid cancelled orders are flagged `refund_due`. Do not use this demo integration for live payments without reviewing reconciliation, retries, refund handling, and operational monitoring.

The `xendit-return` function redirects the mobile browser to `formandthread://payment-return?order_id=...`. Rebuild/reinstall the Android or iOS app after the deep-link configuration changes, and redeploy `xendit-return`. The app opens the order confirmation screen and checks for the verified webhook result for up to one minute. The return link is navigation only, never proof of payment. Some browsers may block automatic app opening; if so, return to the app manually, where the order can still be refreshed. A desktop browser without the mobile app cannot handle the custom scheme.

If a customer creates an online order but never starts Xendit's payment request, there is no expiry callback. The customer can cancel while it is still pending, or staff can cancel a stale order to release its stock. This demo does not include an automatic cleanup job.

1. Open the Supabase project whose URL is configured in `lib/supabase_config.dart`.
2. In **SQL Editor**, run `schema.sql`, then `customer_flow_upgrade.sql`. For a project already using the earlier four-table schema, run only `customer_flow_upgrade.sql`. The flow upgrade also creates `support_requests` if needed, plus saved items, carts, order requests, product options, a starter catalog, and server verified checkout.
   To add ten more sample products, run `catalog_additions.sql` after those scripts. Its fixed IDs prevent duplicate rows if rerun. The sample photos are illustrative; replace them with photos of your actual inventory before selling.
   For another 40 products (10 each in Clothing, Shoes, Bags, and Accessories), run `catalog_40_more.sql` after the schema/flow scripts. This batch uses different fixed IDs, so it can also be run after `catalog_additions.sql`.
   Finally, run `catalog_peso_prices.sql` after all catalog scripts. New seed rows already use suggested Philippine-peso prices; this migration updates older fixed-ID sample rows that still have the original demo prices. It leaves staff-edited and custom product prices unchanged for manual review. It also labels existing order snapshots as USD and new orders as PHP; it does not change historical totals.
   For the staff sale-percentage editor, run `product_discounts.sql` once on an existing project before using the updated app. It adds only `products.discount_percent` and validates newly percentage-priced sales; existing product prices are unchanged. New installations using the latest `schema.sql` or `customer_flow_upgrade.sql` already include this column and constraint.
3. To allow signup without an email code, open **Authentication → Sign In / Providers → Email** and turn off **Confirm email**. With confirmation disabled, Supabase returns an active session after signup and the app signs the user in. This setting is managed in the Supabase dashboard, not in `schema.sql`.
4. SMTP settings are only needed if you want Supabase to send authentication emails, such as password reset messages. Supabase's built-in sender is for testing and has strict delivery limits; configure custom SMTP for regular email delivery.
5. Run the Flutter app with `flutter run`.

The app uses the project URL and legacy anon key (a client key) from `lib/supabase_config.dart`. They can also be overridden at build time with `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` dart defines. Never put a service-role or secret key in the app.

Passwords are handled by Supabase Auth. Email confirmation is controlled by the Supabase Auth provider setting; there is no email-verification table or SQL command to remove from the database schema. The `profiles` table stores each user's name, contact number, address, role, and timestamps. Users can update their own profile details, but only a database administrator can change roles. Staff can manage products, read all orders, update order status, answer support requests, and decide cancellation/return requests. Approving a cancellation changes the order status and returns reserved stock. Staff mark an approved return received when the goods arrive; that restores stock once. Payment refunds are outside this app. Customers can read their own orders and status history, place orders, save products, maintain a cart, and submit support or order requests. Signed-in bags and saved products persist in the database. Guest bags and saved products stay in memory until sign-in, when they are merged into the customer's records. Every checkout line must be an active database product; its price and stock are checked on the server.

To promote a registered account, run this in the Supabase SQL Editor, replacing the email address:

```sql
update public.profiles
set role = 'staff', updated_at = now()
where id = (select id from auth.users where email = 'person@example.com');
```

To return the account to customer access, use the same query with `role = 'customer'`.
