import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/store_service.dart';
import '../utils/money.dart';
import 'customer_support_screen.dart';
import '../widgets/xendit_payment_panel.dart';

const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);
const _muted = Color(0xFF827D73);

String customerOrderStatus(String status) {
  if (status.isEmpty) return 'Unknown';
  return status[0].toUpperCase() + status.substring(1).replaceAll('_', ' ');
}

String customerOrderRequestStatus(String type, String status) {
  if (type == 'cancellation' && status == 'approved') return 'Cancelled';
  return customerOrderStatus(status);
}

String customerOrderDate(String? raw) {
  final date = DateTime.tryParse(raw ?? '')?.toLocal();
  if (date == null) return '';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  bool _activeOnly = true;
  RealtimeChannel? _orderChannel;

  @override
  void initState() {
    super.initState();
    _refresh();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _orderChannel = Supabase.instance.client
          .channel('my-orders-$userId')
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
    if (_orderChannel != null)
      Supabase.instance.client.removeChannel(_orderChannel!);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = StoreService.loadMyOrders();
    setState(() {
      _ordersFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // The FutureBuilder shows the error and retry action.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(backgroundColor: _paper, title: const Text('MY ORDERS')),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _olive));
        }
        if (snapshot.hasError) {
          return _centerMessage(
            'Could not load your orders.',
            'Try again',
            _refresh,
          );
        }
        final all = snapshot.data ?? [];
        final orders = all.where((order) {
          final status = order['status'] as String? ?? 'pending';
          final active =
              status == 'pending' ||
              status == 'processing' ||
              status == 'shipped';
          return _activeOnly ? active : !active;
        }).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Active')),
                  ButtonSegment(value: false, label: Text('Past')),
                ],
                selected: {_activeOnly},
                onSelectionChanged: (value) =>
                    setState(() => _activeOnly = value.first),
              ),
              const SizedBox(height: 14),
              if (orders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 65),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        size: 44,
                        color: _olive,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _activeOnly ? 'No active orders' : 'No past orders',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                ),
              ...orders.map(
                (order) => Card(
                  color: Colors.white,
                  elevation: 0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    title: Text(
                      'Order ${(order['id'] as String? ?? '').split('-').first}',
                    ),
                    subtitle: Text(
                      '${customerOrderDate(order['created_at'] as String?)}\n${customerOrderStatus(order['status'] as String? ?? 'pending')} · ${_paymentLabel(order)}',
                      style: const TextStyle(
                        fontFamily: 'Arial',
                        color: _muted,
                      ),
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      formatOrderMoney((order['total'] as num?) ?? 0, order),
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomerOrderDetailsScreen(
                            orderId: order['id'] as String,
                          ),
                        ),
                      );
                      if (mounted) _refresh();
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Widget _centerMessage(
    String message,
    String action,
    VoidCallback onPressed,
  ) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onPressed, child: Text(action)),
      ],
    ),
  );
}

class CustomerOrderDetailsScreen extends StatefulWidget {
  const CustomerOrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<CustomerOrderDetailsScreen> createState() =>
      _CustomerOrderDetailsScreenState();
}

class _CustomerOrderDetailsScreenState
    extends State<CustomerOrderDetailsScreen> {
  late Future<_OrderDetails> _detailsFuture;
  RealtimeChannel? _orderChannel;
  RealtimeChannel? _requestChannel;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _orderChannel = Supabase.instance.client
        .channel('order-${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.orderId,
          ),
          callback: (_) {
            if (mounted) _refresh();
          },
        )
        .subscribe();
    _requestChannel = Supabase.instance.client
        .channel('order-requests-${widget.orderId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'order_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: widget.orderId,
          ),
          callback: (_) {
            if (mounted) _refresh();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_orderChannel != null)
      Supabase.instance.client.removeChannel(_orderChannel!);
    if (_requestChannel != null)
      Supabase.instance.client.removeChannel(_requestChannel!);
    super.dispose();
  }

  Future<void> _refresh() async {
    final future = _loadDetails();
    setState(() {
      _detailsFuture = future;
    });
    try {
      await future;
    } catch (_) {
      // The FutureBuilder shows the error and retry action.
    }
  }

  Future<_OrderDetails> _loadDetails() async {
    final order = await StoreService.loadMyOrder(widget.orderId);
    final history = await StoreService.loadOrderHistory(widget.orderId);
    final requests = await StoreService.loadMyOrderRequests(widget.orderId);
    return _OrderDetails(order, history, requests);
  }

  Future<void> _cancelPendingOrder(Map<String, dynamic> order) async {
    if (_cancelling) return;
    final paymentStatus = order['payment_status'] as String? ?? 'cash_due';
    final warning = paymentStatus == 'paid'
        ? 'Your payment will need a staff-arranged refund after cancellation.'
        : order['payment_method'] != 'cash'
        ? 'Do not complete the Xendit checkout after cancelling. If a payment arrives later, staff will review it.'
        : 'You will not owe anything for this order.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'This order has not been processed by staff. It will be cancelled immediately and reserved stock will be released.\n\n$warning',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('KEEP ORDER'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('CANCEL ORDER'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await StoreService.cancelPendingOrder(widget.orderId);
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not cancel order: $error')));
      _refresh();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _requestAction(String type) async {
    final reason = TextEditingController();
    final key = GlobalKey<FormState>();
    final send = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          type == 'return' ? 'Request a return' : 'Request cancellation',
        ),
        content: Form(
          key: key,
          child: TextFormField(
            controller: reason,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
            validator: (value) => (value?.trim().isEmpty ?? true)
                ? 'Please enter a reason.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CLOSE'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate())
                Navigator.pop(dialogContext, true);
            },
            child: const Text('SEND REQUEST'),
          ),
        ],
      ),
    );
    if (send == true) {
      try {
        await StoreService.submitOrderRequest(
          orderId: widget.orderId,
          type: type,
          reason: reason.text,
        );
        if (mounted) {
          _refresh();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request sent to staff.')),
          );
        }
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not send request: $error')),
          );
      }
    }
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(backgroundColor: _paper, title: const Text('ORDER DETAILS')),
    body: FutureBuilder<_OrderDetails>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _olive));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load this order.'),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('TRY AGAIN'),
                ),
              ],
            ),
          );
        }
        final order = snapshot.data!.order;
        final history = snapshot.data!.history;
        final requests = snapshot.data!.requests;
        final items = (order['items'] as List? ?? const []).cast<Map>();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            children: [
              Text(
                'Order ${(order['id'] as String? ?? '').split('-').first}',
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 4),
              Text(
                customerOrderDate(order['created_at'] as String?),
                style: const TextStyle(fontFamily: 'Arial', color: _muted),
              ),
              const SizedBox(height: 18),
              const Text('Payment', style: TextStyle(fontSize: 19)),
              const SizedBox(height: 8),
              XenditPaymentPanel(
                orderId: widget.orderId,
                paymentMethod: order['payment_method'] as String? ?? 'cash',
                paymentStatus: order['payment_status'] as String? ?? 'cash_due',
                orderStatus: order['status'] as String? ?? 'pending',
                action: order['payment_action'] is Map
                    ? Map<String, dynamic>.from(order['payment_action'] as Map)
                    : null,
                onPaymentStarted: _refresh,
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.white,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current status',
                        style: TextStyle(fontFamily: 'Arial', color: _muted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customerOrderStatus(
                          order['status'] as String? ?? 'pending',
                        ),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Progress', style: TextStyle(fontSize: 19)),
              if (history.isEmpty) const Text('No status updates yet.'),
              ...history.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: _olive,
                  ),
                  title: Text(
                    customerOrderStatus(entry['to_status'] as String? ?? ''),
                  ),
                  subtitle: Text(
                    customerOrderDate(entry['changed_at'] as String?),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Items', style: TextStyle(fontSize: 19)),
              ...items.map((raw) {
                final item = Map<String, dynamic>.from(raw);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item['name'] as String? ?? 'Item'),
                  subtitle: Text(
                    'Qty ${item['quantity']}  •  ${item['size'] ?? ''} / ${item['color'] ?? ''}',
                  ),
                  trailing: Text(
                    formatOrderMoney((item['unit_price'] as num?) ?? 0, order),
                  ),
                );
              }),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Total'),
                trailing: Text(
                  formatOrderMoney((order['total'] as num?) ?? 0, order),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Delivery details', style: TextStyle(fontSize: 19)),
              const SizedBox(height: 8),
              Text(order['customer_name'] as String? ?? ''),
              Text(order['shipping_address'] as String? ?? ''),
              Text(order['contact_number'] as String? ?? ''),
              Text(order['customer_email'] as String? ?? ''),
              const SizedBox(height: 20),
              if (requests.isNotEmpty) ...[
                const Text('Your requests', style: TextStyle(fontSize: 19)),
                ...requests.map(
                  (request) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${customerOrderStatus(request['type'] as String? ?? '')} · ${customerOrderRequestStatus(request['type'] as String? ?? '', request['status'] as String? ?? '')}',
                    ),
                    subtitle: Text(
                      '${request['reason'] ?? ''}${(request['staff_note'] as String? ?? '').isEmpty ? '' : '\nStaff: ${request['staff_note']}'}',
                    ),
                  ),
                ),
              ],
              if (order['status'] == 'pending') ...[
                OutlinedButton(
                  onPressed: _cancelling
                      ? null
                      : () => _cancelPendingOrder(order),
                  child: Text(_cancelling ? 'CANCELLING...' : 'CANCEL ORDER'),
                ),
                if (requests.any(
                  (request) =>
                      request['type'] == 'cancellation' &&
                      request['status'] == 'pending',
                ))
                  const Text('You can cancel now without waiting for staff.'),
              ] else if (order['status'] == 'processing' &&
                  !requests.any((request) => request['type'] == 'cancellation'))
                OutlinedButton(
                  onPressed: () => _requestAction('cancellation'),
                  child: const Text('REQUEST CANCELLATION'),
                ),
              if (!requests.any((request) => request['type'] == 'return') &&
                  order['status'] == 'completed')
                OutlinedButton(
                  onPressed: () => _requestAction('return'),
                  child: const Text('REQUEST RETURN'),
                ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CustomerSupportScreen(orderId: widget.orderId),
                  ),
                ),
                icon: const Icon(Icons.support_agent_outlined),
                label: const Text('GET HELP WITH THIS ORDER'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

String _paymentLabel(Map<String, dynamic> order) {
  final method = switch (order['payment_method']) {
    'gcash' => 'GCash',
    'bank_transfer' => 'Bank transfer',
    _ => 'Cash on delivery',
  };
  if (order['status'] == 'cancelled') {
    if (order['payment_status'] == 'refund_due') return '$method · refund due';
    if (order['payment_status'] == 'payment_review') {
      return '$method · payment review';
    }
    return '$method · cancelled';
  }
  final status = switch (order['payment_status']) {
    'paid' => 'paid',
    'awaiting_payment' => 'awaiting payment',
    'failed' => 'failed',
    'payment_review' => 'review needed',
    'refund_due' => 'refund due',
    _ => 'due on delivery',
  };
  return '$method · $status';
}

class _OrderDetails {
  const _OrderDetails(this.order, this.history, this.requests);
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> requests;
}
