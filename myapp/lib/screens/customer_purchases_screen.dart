import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/store_service.dart';
import '../utils/money.dart';
import 'customer_orders_screen.dart';

const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);
const _muted = Color(0xFF827D73);
const _ink = Color(0xFF25231F);

enum PurchaseTab { all, toPay, toShip, toReceive, completed, cancelled }

PurchaseTab purchaseTabFor(Map<String, dynamic> order) {
  final status = order['status'] as String? ?? 'pending';
  final paymentStatus = order['payment_status'] as String? ?? 'cash_due';
  if (status == 'cancelled' || paymentStatus == 'failed') {
    return PurchaseTab.cancelled;
  }
  if (status == 'completed') return PurchaseTab.completed;
  if (status == 'shipped') return PurchaseTab.toReceive;
  if (status == 'pending' &&
      order['payment_method'] != 'cash' &&
      paymentStatus == 'awaiting_payment') {
    return PurchaseTab.toPay;
  }
  return PurchaseTab.toShip;
}

String purchaseStatusLabel(Map<String, dynamic> order) {
  final status = order['status'] as String? ?? 'pending';
  if (status == 'cancelled' && order['payment_status'] == 'refund_due') {
    return 'Refund due';
  }
  return switch (purchaseTabFor(order)) {
    PurchaseTab.all => 'Order placed',
    PurchaseTab.toPay => 'To pay',
    PurchaseTab.toShip =>
      status == 'processing' ? 'Preparing to ship' : 'Awaiting confirmation',
    PurchaseTab.toReceive => 'On the way',
    PurchaseTab.completed => 'Completed',
    PurchaseTab.cancelled => 'Cancelled',
  };
}

class CustomerPurchasesScreen extends StatefulWidget {
  const CustomerPurchasesScreen({super.key, this.loadOrders});

  final Future<List<Map<String, dynamic>>> Function()? loadOrders;

  @override
  State<CustomerPurchasesScreen> createState() =>
      _CustomerPurchasesScreenState();
}

class _CustomerPurchasesScreenState extends State<CustomerPurchasesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  RealtimeChannel? _orderChannel;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: PurchaseTab.values.length, vsync: this);
    _refresh();
    final userId = widget.loadOrders == null
        ? Supabase.instance.client.auth.currentUser?.id
        : null;
    if (userId != null) {
      _orderChannel = Supabase.instance.client
          .channel('my-purchases-$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'customer_id',
              value: userId,
            ),
            callback: (_) {
              if (mounted) _refresh();
            },
          )
          .subscribe();
    }
  }

  @override
  void dispose() {
    if (_orderChannel != null) {
      Supabase.instance.client.removeChannel(_orderChannel!);
    }
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = (widget.loadOrders ?? StoreService.loadMyOrders)();
    setState(() {
      _ordersFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // The FutureBuilder displays the retry action.
    }
  }

  Future<void> _openOrder(Map<String, dynamic> order) async {
    final id = order['id'] as String?;
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerOrderDetailsScreen(orderId: id),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(
      backgroundColor: _paper,
      title: const Text('MY ORDERS'),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: _ink,
        unselectedLabelColor: _muted,
        indicatorColor: _olive,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'To Pay'),
          Tab(text: 'To Ship'),
          Tab(text: 'To Receive'),
          Tab(text: 'Completed'),
          Tab(text: 'Cancelled'),
        ],
      ),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _olive));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load your orders.'),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('TRY AGAIN'),
                ),
              ],
            ),
          );
        }
        final all = snapshot.data ?? const <Map<String, dynamic>>[];
        return TabBarView(
          controller: _tabs,
          children: [
            for (final tab in PurchaseTab.values)
              _orderList(
                tab == PurchaseTab.all
                    ? all
                    : all
                          .where((order) => purchaseTabFor(order) == tab)
                          .toList(),
                tab,
              ),
          ],
        );
      },
    ),
  );

  Widget _orderList(List<Map<String, dynamic>> orders, PurchaseTab tab) =>
      RefreshIndicator(
        onRefresh: _refresh,
        color: _olive,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            if (orders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: Column(
                  children: [
                    const Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: _olive,
                    ),
                    const SizedBox(height: 14),
                    Text(switch (tab) {
                      PurchaseTab.all => 'No orders yet',
                      PurchaseTab.toPay => 'No payments due',
                      PurchaseTab.toShip => 'No orders to ship',
                      PurchaseTab.toReceive => 'Nothing on the way',
                      PurchaseTab.completed => 'No completed orders',
                      PurchaseTab.cancelled => 'No cancelled orders',
                    }, style: const TextStyle(fontSize: 19, color: _ink)),
                    const SizedBox(height: 6),
                    const Text(
                      'Pull down to refresh your orders.',
                      style: TextStyle(fontFamily: 'Arial', color: _muted),
                    ),
                  ],
                ),
              ),
            for (final order in orders)
              _PurchaseCard(order: order, onOpen: () => _openOrder(order)),
          ],
        ),
      );
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.order, required this.onOpen});

  final Map<String, dynamic> order;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final items = order['items'] as List? ?? const [];
    final first = items.isNotEmpty && items.first is Map
        ? Map<String, dynamic>.from(items.first as Map)
        : <String, dynamic>{};
    final count = items.fold<int>(0, (total, raw) {
      final quantity = raw is Map ? raw['quantity'] : null;
      return total + (quantity is num ? quantity.toInt() : 0);
    });
    final image = first['image'] as String? ?? '';
    final tab = purchaseTabFor(order);
    final status = purchaseStatusLabel(order);
    final id = (order['id'] as String? ?? '').split('-').first.toUpperCase();
    final options = [
      first['size'],
      first['color'],
    ].whereType<String>().where((value) => value.isNotEmpty).join(' / ');
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ORDER #$id',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: _ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      status,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tab == PurchaseTab.cancelled ? _muted : _olive,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                customerOrderDate(order['created_at'] as String?),
                style: const TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 11,
                  color: _muted,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: image.isEmpty
                          ? const _ImageFallback()
                          : Image.network(
                              image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const _ImageFallback(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          first['name'] as String? ?? 'Order items',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, color: _ink),
                        ),
                        if (options.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            options,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Arial',
                              fontSize: 12,
                              color: _muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          'Qty ${first['quantity'] ?? 0}',
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            fontSize: 12,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          formatOrderMoney(
                            (first['unit_price'] as num?) ?? 0,
                            order,
                          ),
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (items.length > 1) ...[
                const SizedBox(height: 8),
                Text(
                  '+${items.length - 1} more ${items.length == 2 ? 'product' : 'products'}',
                  style: const TextStyle(fontFamily: 'Arial', color: _muted),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$count ${count == 1 ? 'item' : 'items'}  ·  Total',
                    style: const TextStyle(fontFamily: 'Arial', color: _muted),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      formatOrderMoney((order['total'] as num?) ?? 0, order),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: tab == PurchaseTab.toPay
                    ? FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: _olive),
                        onPressed: onOpen,
                        child: const Text('VIEW PAYMENT'),
                      )
                    : OutlinedButton(
                        onPressed: onOpen,
                        child: const Text('VIEW ORDER'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: _paper,
    child: Icon(Icons.checkroom_outlined, color: _olive),
  );
}
