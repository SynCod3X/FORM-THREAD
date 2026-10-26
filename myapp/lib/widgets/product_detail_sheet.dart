import 'package:flutter/material.dart';

import '../models/cart_items.dart';
import '../screens/cart_screen.dart';

const _ink = Color(0xFF25231F);
const _muted = Color(0xFF827D73);
const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);

class ProductDetailSheet extends StatefulWidget {
  static bool _isShowing = false;

  const ProductDetailSheet({
    super.key,
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    this.productId,
    this.availableQuantity,
    this.sizes = const ['XS', 'S', 'M', 'L', 'XL'],
    this.colors = const ['Natural', 'Black', 'Olive'],
  });

  final String name;
  final String description;
  final String price;
  final String image;
  final String? productId;
  final int? availableQuantity;
  final List<String> sizes;
  final List<String> colors;

  static Future<void> show(
    BuildContext context, {
    required String name,
    required String description,
    required String price,
    required String image,
    String? productId,
    int? availableQuantity,
    List<String> sizes = const ['XS', 'S', 'M', 'L', 'XL'],
    List<String> colors = const ['Natural', 'Black', 'Olive'],
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      final added = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: _paper,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        builder: (_) => ProductDetailSheet(
          name: name,
          description: description,
          price: price,
          image: image,
          productId: productId,
          availableQuantity: availableQuantity,
          sizes: sizes,
          colors: colors,
        ),
      );

      if (added == true && context.mounted) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CartScreen()));
      }
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<ProductDetailSheet> {
  String? _selectedSize;
  String? _selectedColor;
  int _quantity = 1;
  bool _isAdding = false;

  int get _maxAdditionalQuantity {
    final productId = widget.productId;
    if (productId == null) return 0;
    final inCart = CartItems.items.value
        .where((line) => line.productId == productId)
        .fold<int>(0, (total, line) => total + line.quantity);
    final sameVariant = CartItems.items.value
        .where(
          (line) =>
              line.productId == productId &&
              line.size == _selectedSize &&
              line.color == _selectedColor,
        )
        .fold<int>(0, (total, line) => total + line.quantity);
    final stockRemaining = widget.availableQuantity == null
        ? 99
        : widget.availableQuantity! - inCart;
    final lineRemaining = 99 - sameVariant;
    return (stockRemaining < lineRemaining ? stockRemaining : lineRemaining)
        .clamp(0, 99);
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .88,
    minChildSize: .65,
    maxChildSize: .96,
    builder: (context, scrollController) => Column(
      children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6D2C9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.image,
                  height: 235,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 235,
                    color: const Color(0xFFE3E0D7),
                    child: const Icon(
                      Icons.checkroom_outlined,
                      color: _olive,
                      size: 55,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.name,
                      style: const TextStyle(fontSize: 24, height: 1.1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.price,
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.description,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  color: _muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              if (widget.availableQuantity != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.availableQuantity! > 0
                      ? '${widget.availableQuantity} available'
                      : 'Out of stock',
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    color: _muted,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _sectionLabel('CHOOSE SIZE'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.sizes.map((size) {
                  final selected = size == _selectedSize;
                  return ChoiceChip(
                    label: Text(size),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _selectedSize = size),
                    labelStyle: TextStyle(
                      fontFamily: 'Arial',
                      fontSize: 12,
                      color: selected ? Colors.white : _ink,
                    ),
                    selectedColor: _ink,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected ? _ink : const Color(0xFFD9D5CC),
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              _sectionLabel('CHOOSE COLOR'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.colors.map((color) {
                  final selected = color == _selectedColor;
                  return ChoiceChip(
                    label: Text(color),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _selectedColor = color),
                    labelStyle: TextStyle(
                      fontFamily: 'Arial',
                      fontSize: 12,
                      color: selected ? Colors.white : _ink,
                    ),
                    selectedColor: _olive,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: selected ? _olive : const Color(0xFFD9D5CC),
                    ),
                    shape: const StadiumBorder(),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              _sectionLabel('QUANTITY'),
              const SizedBox(height: 10),
              Row(
                children: [
                  _quantityControl(
                    icon: Icons.remove,
                    label: 'Decrease quantity',
                    onPressed: _quantity > 1 && !_isAdding
                        ? () => setState(() => _quantity--)
                        : null,
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$_quantity',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Arial',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _quantityControl(
                    icon: Icons.add,
                    label: 'Increase quantity',
                    onPressed: _quantity < _maxAdditionalQuantity && !_isAdding
                        ? () => setState(() => _quantity++)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _maxAdditionalQuantity == 0
                          ? 'No more available to add'
                          : 'Up to $_maxAdditionalQuantity more',
                      style: const TextStyle(
                        fontFamily: 'Arial',
                        color: _muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              color: _paper,
              border: Border(top: BorderSide(color: Color(0xFFE4E0D8))),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed:
                    _selectedSize == null ||
                        _selectedColor == null ||
                        widget.productId == null ||
                        _quantity > _maxAdditionalQuantity ||
                        _isAdding
                    ? null
                    : _addToCart,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  disabledBackgroundColor: const Color(0xFFB7B3AA),
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Text(
                  'ADD TO CART',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sectionLabel(String label) => Text(
    label,
    style: const TextStyle(
      fontFamily: 'Arial',
      color: _muted,
      fontSize: 9,
      letterSpacing: 1.5,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _quantityControl({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => SizedBox(
    width: 40,
    height: 40,
    child: IconButton.outlined(
      tooltip: label,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 18),
    ),
  );

  Future<void> _addToCart() async {
    if (_isAdding) return;
    setState(() => _isAdding = true);
    try {
      await CartItems.add(
        CartLine(
          name: widget.name,
          description: widget.description,
          price: widget.price,
          image: widget.image,
          size: _selectedSize!,
          color: _selectedColor!,
          productId: widget.productId,
          quantity: _quantity,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not add to bag: $error')));
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }
}
