import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_items.dart';
import '../services/auth_service.dart';
import '../services/store_service.dart';
import '../utils/money.dart';
import 'customer_orders_screen.dart';
import '../widgets/xendit_payment_panel.dart';

const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);
const _muted = Color(0xFF827D73);
const _ink = Color(0xFF25231F);

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.lines});

  final List<CartLine> lines;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _loading = true;
  bool _placing = false;
  String _paymentMethod = 'cash';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await AuthService.loadMyProfile();
      if (!mounted) return;
      _name.text = profile['full_name'] as String? ?? '';
      _phone.text = profile['contact_number'] as String? ?? '';
      _address.text = profile['address'] as String? ?? '';
      setState(() => _loading = false);
    } catch (error) {
      try {
        await CartItems.refresh();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load delivery details. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.lines.fold<double>(0, (sum, line) => sum + line.total);
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        title: const Text('REVIEW ORDER'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _olive))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  OutlinedButton(
                    onPressed: _loadProfile,
                    child: const Text('TRY AGAIN'),
                  ),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  const Text(
                    'Delivery details',
                    style: TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Review these details before placing your order. Changes are saved to your profile.',
                    style: TextStyle(fontFamily: 'Arial', color: _muted),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter your name.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact number',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) =>
                        (value ?? '').replaceAll(RegExp(r'[^0-9]'), '').length <
                            7
                        ? 'Enter a valid contact number.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Delivery address',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? 'Enter your delivery address.'
                        : null,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Email: ${Supabase.instance.client.auth.currentUser?.email ?? ''}',
                    style: const TextStyle(fontFamily: 'Arial', color: _muted),
                  ),
                  const SizedBox(height: 24),
                  const Text('Your items', style: TextStyle(fontSize: 20)),
                  ...widget.lines.map(
                    (line) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.name),
                      subtitle: Text(
                        'Qty ${line.quantity}  •  ${line.size} / ${line.color}',
                      ),
                      trailing: Text(formatPeso(line.total)),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Estimated total'),
                    trailing: Text(formatPeso(total)),
                  ),
                  const Text(
                    'No shipping or tax charges are added.',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      color: _muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('Payment method', style: TextStyle(fontSize: 20)),
                  RadioGroup<String>(
                    groupValue: _paymentMethod,
                    onChanged: (value) =>
                        setState(() => _paymentMethod = value!),
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          title: Text('Cash on delivery'),
                          subtitle: Text('Pay when your order arrives.'),
                          value: 'cash',
                        ),
                        RadioListTile<String>(
                          title: Text('GCash'),
                          subtitle: Text(
                            'Open a test payment page. No real money moves.',
                          ),
                          value: 'gcash',
                        ),
                        RadioListTile<String>(
                          title: Text('Bank transfer'),
                          subtitle: Text(
                            'Receive a test virtual account number.',
                          ),
                          value: 'bank_transfer',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: _placing ? null : _placeOrder,
                  child: _placing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _paymentMethod == 'cash'
                              ? 'PLACE ORDER'
                              : 'PLACE ORDER & CONTINUE',
                        ),
                ),
              ),
            ),
    );
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.lines.isEmpty) return;
    setState(() => _placing = true);
    try {
      await CartItems.ensureAvailable(widget.lines);
      if (_paymentMethod != 'cash') await StoreService.ensureXenditTestReady();
      await AuthService.updateMyProfile(
        name: _name.text,
        contactNumber: _phone.text,
        address: _address.text,
      );
      final items = widget.lines
          .map(
            (line) => {
              'product_id': line.productId,
              'expected_price': line.unitPrice,
              'quantity': line.quantity,
              'size': line.size,
              'color': line.color,
            },
          )
          .toList();
      final orderId = await StoreService.placeOrder(
        items,
        paymentMethod: _paymentMethod,
      );
      try {
        await CartItems.clearSelected(widget.lines);
      } catch (_) {
        // The order already succeeded. The bag can be refreshed separately.
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderConfirmationScreen(
            orderId: orderId,
            paymentMethod: _paymentMethod,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not place order: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }
}

class OrderConfirmationScreen extends StatefulWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    this.paymentMethod = 'cash',
    this.loadOrder,
    this.autoCheckPayment = false,
  });

  final String orderId;
  final String paymentMethod;
  final Future<Map<String, dynamic>> Function(String)? loadOrder;
  final bool autoCheckPayment;

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _order;
  bool _refreshing = false;
  String? _loadError;
  Timer? _paymentCheckTimer;
  int _paymentCheckCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshOrder();
    if (widget.autoCheckPayment) _startPaymentChecks();
  }

  void _startPaymentChecks() {
    if (_paymentCheckTimer?.isActive ?? false) return;
    _paymentCheckCount = 0;
    _paymentCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted || ++_paymentCheckCount > 30) {
        timer.cancel();
        return;
      }
      if (!_refreshing) _refreshOrder();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOrder();
      if (widget.paymentMethod != 'cash') _startPaymentChecks();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _paymentCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshOrder() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final order = await (widget.loadOrder ?? StoreService.loadMyOrder)(
        widget.orderId,
      );
      if (!mounted) return;
      setState(() {
        _order = order;
        _loadError = null;
      });
      if (order['payment_status'] != 'awaiting_payment' ||
          order['status'] == 'cancelled') {
        _paymentCheckTimer?.cancel();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not check your payment status.');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentStatus = _order?['payment_status'] as String?;
    final paymentMethod =
        _order?['payment_method'] as String? ?? widget.paymentMethod;
    final orderStatus = _order?['status'] as String? ?? 'pending';
    final title = orderStatus == 'cancelled'
        ? 'ORDER CANCELLED'
        : paymentMethod == 'cash'
        ? 'ORDER PLACED'
        : switch (paymentStatus) {
            'paid' => 'PAYMENT CONFIRMED',
            'failed' => 'PAYMENT FAILED',
            'payment_review' => 'PAYMENT REVIEW',
            'refund_due' => 'REFUND DUE',
            _ when _loadError != null && _order == null =>
              'PAYMENT STATUS UNAVAILABLE',
            _ => 'PAYMENT PENDING',
          };
    final headline = orderStatus == 'cancelled'
        ? 'Your order has been cancelled'
        : paymentMethod == 'cash'
        ? 'Your order is placed'
        : switch (paymentStatus) {
            'paid' => 'Payment confirmed',
            'failed' => 'Payment failed or expired',
            'payment_review' => 'Your payment needs staff review',
            'refund_due' => 'Staff will arrange your refund',
            _ when _loadError != null && _order == null =>
              'Payment status is unavailable',
            _ => 'Complete your payment',
          };
    final supportingText = orderStatus == 'cancelled'
        ? 'Your order will not be processed. View the order for details.'
        : paymentMethod == 'cash'
        ? 'You can pay when your order arrives.'
        : switch (paymentStatus) {
            'paid' => 'We have received confirmation for this order.',
            'failed' =>
              'This order could not be paid. View the order for details.',
            'payment_review' => 'Please wait for staff to review this payment.',
            'refund_due' => 'Staff will contact you about the next step.',
            _ when _loadError != null && _order == null =>
              'Pull down to try checking the order again.',
            _ => 'Choose the payment action below. Your order will update after confirmation.',
          };
    final statusLabel = orderStatus == 'cancelled'
        ? 'CANCELLED'
        : paymentMethod == 'cash'
        ? 'ORDER PLACED'
        : switch (paymentStatus) {
            'paid' => 'PAID',
            'failed' => 'PAYMENT FAILED',
            'payment_review' => 'UNDER REVIEW',
            'refund_due' => 'REFUND DUE',
            _ => 'AWAITING PAYMENT',
          };
    final paymentMethodLabel = switch (paymentMethod) {
      'gcash' => 'GCash',
      'bank_transfer' => 'Bank transfer',
      _ => 'Cash on delivery',
    };
    final completed = paymentMethod == 'cash' || paymentStatus == 'paid';
    final statusColor = orderStatus == 'cancelled' || paymentStatus == 'failed'
        ? const Color(0xFF9B4C40)
        : _olive;
    final amount = _order?['total'];

    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        automaticallyImplyLeading: false,
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('SHOP'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refreshOrder,
          color: _olive,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              orderStatus == 'cancelled'
                                  ? Icons.close_rounded
                                  : completed
                                  ? Icons.check_rounded
                                  : Icons.schedule_rounded,
                              color: statusColor,
                              size: 28,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontFamily: 'Arial',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.7,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        headline,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        supportingText,
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 13,
                          height: 1.4,
                          color: _muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          const Text(
                            'Order number',
                            style: TextStyle(
                              fontFamily: 'Arial',
                              color: _muted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '#${widget.orderId.split('-').first.toUpperCase()}',
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Arial',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            orderStatus == 'cancelled'
                                ? 'Order total'
                                : 'Total',
                            style: const TextStyle(
                              fontFamily: 'Arial',
                              color: _muted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            amount is num
                                ? formatOrderMoney(amount, _order!)
                                : '—',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _ink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Text(
                            'Payment method',
                            style: TextStyle(
                              fontFamily: 'Arial',
                              color: _muted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            paymentMethodLabel,
                            style: const TextStyle(
                              fontFamily: 'Arial',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (paymentMethod != 'cash' &&
                  paymentStatus == 'awaiting_payment' &&
                  orderStatus == 'pending') ...[
                const SizedBox(height: 18),
                const Text(
                  'Complete payment',
                  style: TextStyle(fontSize: 20, color: _ink),
                ),
                const SizedBox(height: 8),
                if (_order != null)
                  XenditPaymentPanel(
                    orderId: widget.orderId,
                    paymentMethod: paymentMethod,
                    paymentStatus: paymentStatus ?? 'awaiting_payment',
                    orderStatus: orderStatus,
                    action: _order!['payment_action'] is Map
                        ? Map<String, dynamic>.from(
                            _order!['payment_action'] as Map,
                          )
                        : null,
                    onPaymentStarted: () {
                      _refreshOrder();
                      _startPaymentChecks();
                    },
                  )
                else if (_refreshing)
                  const Center(child: CircularProgressIndicator(color: _olive)),
                if (_loadError != null) ...[
                  const SizedBox(height: 8),
                  Text(_loadError!, style: const TextStyle(color: Colors.red)),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _refreshing ? null : _refreshOrder,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('CHECK PAYMENT STATUS'),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerOrderDetailsScreen(orderId: widget.orderId),
                      ),
                    );
                    if (mounted) _refreshOrder();
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('VIEW ORDER DETAILS'),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('CONTINUE SHOPPING'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
