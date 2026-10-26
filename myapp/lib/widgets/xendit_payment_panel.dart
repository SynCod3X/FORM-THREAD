import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/store_service.dart';

class XenditPaymentPanel extends StatefulWidget {
  const XenditPaymentPanel({
    super.key,
    required this.orderId,
    required this.paymentMethod,
    required this.paymentStatus,
    this.orderStatus = 'pending',
    this.action,
    this.onPaymentStarted,
  });

  final String orderId;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final Map<String, dynamic>? action;
  final VoidCallback? onPaymentStarted;

  @override
  State<XenditPaymentPanel> createState() => _XenditPaymentPanelState();
}

class _XenditPaymentPanelState extends State<XenditPaymentPanel> {
  Map<String, dynamic>? _action;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _action = widget.action;
  }

  @override
  void didUpdateWidget(covariant XenditPaymentPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.action != null) _action = widget.action;
  }

  Future<void> _openGcash(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https') {
      if (mounted) {
        setState(() => _error = 'Could not open GCash checkout.');
      }
      return;
    }
    bool opened;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (opened) {
      widget.onPaymentStarted?.call();
    } else if (mounted) {
      setState(() => _error = 'Could not open GCash checkout.');
    }
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final action = await StoreService.startXenditTestPayment(widget.orderId);
      if (!mounted) return;
      setState(() => _action = action);
      widget.onPaymentStarted?.call();
      if (widget.paymentMethod == 'gcash') {
        await _openGcash(action['value'] as String);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not start payment: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.paymentMethod == 'cash') {
      return Text(
        widget.orderStatus == 'cancelled'
            ? 'Order cancelled. No cash payment is due.'
            : 'Cash on delivery · Pay when your order arrives.',
      );
    }
    final status = widget.paymentStatus;
    final value = _action?['value'] as String?;
    final isGcash = widget.paymentMethod == 'gcash';
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFFF0F1E9),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isGcash
                      ? Icons.account_balance_wallet_outlined
                      : Icons.account_balance_outlined,
                  size: 20,
                  color: const Color(0xFF4E682D),
                ),
                const SizedBox(width: 8),
                Text(
                  isGcash ? 'GCash' : 'Bank transfer',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(switch (status) {
              'paid' => 'Payment confirmed.',
              'failed' =>
                'Payment failed or expired. This order was cancelled.',
              'payment_review' =>
                'Payment needs staff review. Do not pay again.',
              'refund_due' =>
                'This paid order was cancelled. Staff must arrange a refund.',
              _ when widget.orderStatus == 'cancelled' => 'Order cancelled. Do not complete this payment. Contact staff if you already paid.',
              _ => 'Payment pending. Your order updates after payment is confirmed.',
            }),
            if (status == 'awaiting_payment' &&
                widget.orderStatus != 'cancelled') ...[
              const SizedBox(height: 12),
              if (widget.paymentMethod == 'bank_transfer' && value != null) ...[
                const Text('Asia United Bank (AUB) virtual account'),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text('Test account — do not send real funds.'),
              ] else if (widget.paymentMethod == 'gcash' && value != null)
                FilledButton.icon(
                  onPressed: () => _openGcash(value),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4E682D),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('OPEN GCASH CHECKOUT'),
                )
              else
                FilledButton(
                  onPressed: _busy ? null : _start,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4E682D),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(
                    _busy
                        ? 'CONNECTING…'
                        : isGcash
                        ? 'CONTINUE TO GCASH'
                        : 'GET BANK DETAILS',
                  ),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
