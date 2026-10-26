import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_items.dart';
import '../utils/money.dart';
import 'checkout_screen.dart';
import 'login_screen.dart';

const _ink = Color(0xFF25231F);
const _muted = Color(0xFF827D73);
const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(
      backgroundColor: _paper,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text(
        'YOUR BAG',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
      centerTitle: true,
    ),
    body: ValueListenableBuilder<List<CartLine>>(
      valueListenable: CartItems.items,
      builder: (context, lines, _) {
        if (lines.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  size: 48,
                  color: _olive,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Your bag is waiting.',
                  style: TextStyle(fontSize: 23),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add a few pieces you love to get started.',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _ink),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text(
                    'CONTINUE SHOPPING',
                    style: TextStyle(
                      fontFamily: 'Arial',
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final selectedLines = lines.where((line) => line.isSelected).toList();
        final total = selectedLines.fold<double>(
          0,
          (sum, line) => sum + line.total,
        );
        return Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                itemCount: lines.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 24, color: Color(0xFFE4E0D8)),
                itemBuilder: (context, index) => _CartRow(line: lines[index]),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE4E0D8))),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal (${selectedLines.length} selected)',
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            color: _muted,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          formatPeso(total),
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No shipping or tax charges are configured.',
                        style: TextStyle(
                          fontFamily: 'Arial',
                          color: _muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 49,
                      child: FilledButton(
                        onPressed: selectedLines.isEmpty || _isSubmitting
                            ? null
                            : () => _checkout(selectedLines),
                        style: FilledButton.styleFrom(
                          backgroundColor: _ink,
                          disabledBackgroundColor: const Color(0xFFB7B3AA),
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'REVIEW ORDER',
                                style: TextStyle(
                                  fontFamily: 'Arial',
                                  fontSize: 11,
                                  letterSpacing: 1.3,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Future<void> _checkout(List<CartLine> selectedLines) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      if (Supabase.instance.client.auth.currentUser == null) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
      if (!mounted) return;
      if (Supabase.instance.client.auth.currentUser == null) {
        _message('Sign in to place your order.');
        return;
      }
      await CartItems.ensureAvailable(selectedLines);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CheckoutScreen(lines: selectedLines)),
      );
    } catch (error) {
      if (mounted) _message('Could not open checkout: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text, style: const TextStyle(fontFamily: 'Arial')),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class _CartRow extends StatelessWidget {
  const _CartRow({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Checkbox(
        value: line.isSelected,
        onChanged: (selected) => _run(
          context,
          () => CartItems.toggleSelection(line, selected ?? false),
        ),
        activeColor: _olive,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          line.image,
          width: 92,
          height: 118,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 92,
            height: 118,
            color: const Color(0xFFE3E0D7),
            child: const Icon(Icons.checkroom_outlined, color: _olive),
          ),
        ),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 5),
            Text(
              line.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Arial',
                color: _muted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Size: ${line.size}  ·  Color: ${line.color}',
              style: const TextStyle(
                fontFamily: 'Arial',
                color: _muted,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                _QuantityButton(
                  icon: Icons.remove,
                  onTap: () =>
                      _run(context, () => CartItems.changeQuantity(line, -1)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${line.quantity}',
                    style: const TextStyle(fontFamily: 'Arial', fontSize: 12),
                  ),
                ),
                _QuantityButton(
                  icon: Icons.add,
                  onTap: () =>
                      _run(context, () => CartItems.changeQuantity(line, 1)),
                ),
                const Spacer(),
                Text(
                  formatPeso(line.total),
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update bag: $error')));
    }
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      width: 27,
      height: 27,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD9D5CC)),
      ),
      child: Icon(icon, size: 14, color: _ink),
    ),
  );
}
