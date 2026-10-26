import 'package:flutter/material.dart';

import '../services/store_service.dart';
import '../utils/money.dart';
import '../utils/sale_pricing.dart';

const _paper = Color(0xFFF8F6F1);
const _productCategories = ['Clothing', 'Shoes', 'Bags', 'Accessories'];

class StaffProductDraft {
  const StaffProductDraft({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.quantity,
    required this.category,
    required this.compareAtPrice,
    required this.discountPercent,
    required this.badge,
    required this.availableSizes,
    required this.availableColors,
  });

  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final int quantity;
  final String category;
  final double? compareAtPrice;
  final double? discountPercent;
  final String badge;
  final List<String> availableSizes;
  final List<String> availableColors;
}

class StaffProductEditorDialog extends StatefulWidget {
  const StaffProductEditorDialog({super.key, this.current});

  final StoreProduct? current;

  @override
  State<StaffProductEditorDialog> createState() =>
      _StaffProductEditorDialogState();
}

class _StaffProductEditorDialogState extends State<StaffProductEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _image;
  late final TextEditingController _price;
  late final TextEditingController _quantity;
  String? _category;
  late final TextEditingController _discountPercent;
  bool _isOnSale = false;
  bool _saleEdited = false;
  late final TextEditingController _badge;
  late final TextEditingController _sizes;
  late final TextEditingController _colors;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _name = TextEditingController(text: current?.name ?? '');
    _description = TextEditingController(text: current?.description ?? '');
    _image = TextEditingController(text: current?.imageUrl ?? '');
    _isOnSale =
        current?.compareAtPrice != null &&
        current!.compareAtPrice! > current.price;
    _price = TextEditingController(
      text:
          (_isOnSale ? current!.compareAtPrice : current?.price)
              ?.toStringAsFixed(2) ??
          '',
    );
    _quantity = TextEditingController(
      text: current?.quantity.toString() ?? '0',
    );
    _category = current == null
        ? 'Clothing'
        : _productCategories.contains(current.category)
        ? current.category
        : null;
    _discountPercent = TextEditingController(
      text: !_isOnSale
          ? ''
          : current?.discountPercent?.toStringAsFixed(2) ??
                ((1 - current!.price / current.compareAtPrice!) * 100)
                    .toStringAsFixed(2),
    );
    _badge = TextEditingController(
      text: current?.badge.toUpperCase() == 'SALE' ? '' : current?.badge ?? '',
    );
    _sizes = TextEditingController(
      text: current?.availableSizes.join(', ') ?? 'XS, S, M, L, XL',
    );
    _colors = TextEditingController(
      text: current?.availableColors.join(', ') ?? 'Natural, Black, Olive',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _image.dispose();
    _price.dispose();
    _quantity.dispose();
    _discountPercent.dispose();
    _badge.dispose();
    _sizes.dispose();
    _colors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _paper,
    title: Text(widget.current == null ? 'Add product' : 'Edit product'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_name, 'Product name'),
              _field(_description, 'Description', maxLines: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                  ),
                  items: _productCategories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _category = value),
                  validator: (value) =>
                      value == null ? 'Select a product category.' : null,
                ),
              ),
              _field(
                _badge,
                'Other badge (optional)',
                validator: (value) => value?.trim().toUpperCase() == 'SALE'
                    ? 'SALE badge is set automatically.'
                    : null,
              ),
              _field(
                _sizes,
                'Sizes (comma separated)',
                validator: (value) =>
                    _options(value).isEmpty ? 'Enter at least one size.' : null,
              ),
              _field(
                _colors,
                'Colors (comma separated)',
                validator: (value) => _options(value).isEmpty
                    ? 'Enter at least one color.'
                    : null,
              ),
              _field(
                _image,
                'Image URL',
                keyboardType: TextInputType.url,
                validator: _validImageUrl,
              ),
              _field(
                _price,
                _isOnSale ? 'Regular price (PHP)' : 'Price (PHP)',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() => _saleEdited = true),
                validator: (value) {
                  final price = double.tryParse(value?.trim() ?? '');
                  if (price == null || !price.isFinite || price <= 0) {
                    return 'Enter a price greater than zero.';
                  }
                  if (!hasAtMostTwoDecimals(price)) {
                    return 'Use no more than two decimal places.';
                  }
                  return null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('On sale'),
                subtitle: const Text('Set a discount from the regular price'),
                value: _isOnSale,
                onChanged: (value) => setState(() {
                  _isOnSale = value;
                  _saleEdited = true;
                }),
              ),
              if (_isOnSale) ...[
                _field(
                  _discountPercent,
                  'Discount (%)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() => _saleEdited = true),
                  validator: (value) {
                    if (!_saleEdited &&
                        widget.current?.discountPercent == null &&
                        widget.current?.compareAtPrice != null) {
                      return null;
                    }
                    final percent = double.tryParse(value?.trim() ?? '');
                    if (percent == null ||
                        !percent.isFinite ||
                        percent <= 0 ||
                        percent >= 100) {
                      return 'Enter a discount greater than 0% and below 100%.';
                    }
                    if (!hasAtMostTwoDecimals(percent)) {
                      return 'Use no more than two decimal places.';
                    }
                    final regular = double.tryParse(_price.text.trim());
                    if (regular != null &&
                        calculateSalePrice(regular, percent) == null) {
                      return 'Discount must leave a price above zero.';
                    }
                    return null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _previewSalePrice == null
                          ? 'Final sale price: enter a valid price and discount'
                          : 'Final sale price: ${formatPeso(_previewSalePrice!)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
              _field(
                _quantity,
                'Quantity in stock',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final quantity = int.tryParse(value?.trim() ?? '');
                  return quantity == null || quantity < 0
                      ? 'Enter zero or a positive whole number.'
                      : null;
                },
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('CANCEL'),
      ),
      FilledButton(onPressed: _save, child: const Text('SAVE')),
    ],
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final regularPrice = double.parse(_price.text.trim());
    final percent = _isOnSale
        ? double.parse(_discountPercent.text.trim())
        : null;
    final preserveLegacySale =
        _isOnSale &&
        !_saleEdited &&
        widget.current?.discountPercent == null &&
        widget.current?.compareAtPrice != null;
    Navigator.pop(
      context,
      StaffProductDraft(
        name: _name.text.trim(),
        description: _description.text.trim(),
        imageUrl: _image.text.trim(),
        price: _isOnSale
            ? preserveLegacySale
                  ? widget.current!.price
                  : calculateSalePrice(regularPrice, percent!)!
            : regularPrice,
        quantity: int.parse(_quantity.text.trim()),
        category: _category!,
        compareAtPrice: _isOnSale ? regularPrice : null,
        discountPercent: preserveLegacySale ? null : percent,
        badge: _badge.text.trim(),
        availableSizes: _options(_sizes.text),
        availableColors: _options(_colors.text),
      ),
    );
  }

  List<String> _options(String? value) => (value ?? '')
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet()
      .toList();

  double? get _previewSalePrice {
    final regular = double.tryParse(_price.text.trim());
    final percent = double.tryParse(_discountPercent.text.trim());
    if (regular == null || percent == null) return null;
    if (!_saleEdited && widget.current?.discountPercent == null) {
      return widget.current?.price;
    }
    return calculateSalePrice(regular, percent);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      validator:
          validator ??
          (value) =>
              value == null || value.trim().isEmpty ? 'Enter $label.' : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
      ),
    ),
  );

  String? _validImageUrl(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return 'Enter a valid http or https image URL.';
    }
    return null;
  }
}
