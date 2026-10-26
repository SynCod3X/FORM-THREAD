import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/money.dart';

class CartLine {
  CartLine({
    required this.name,
    required this.description,
    required this.price,
    required this.image,
    required this.size,
    required this.color,
    this.productId,
    this.quantity = 1,
    this.isSelected = true,
  });

  final String name;
  final String description;
  final String price;
  final String image;
  final String size;
  final String color;
  final String? productId;
  int quantity;
  bool isSelected;

  double get unitPrice =>
      double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  double get total => unitPrice * quantity;

  bool matches(CartLine other) =>
      name == other.name &&
      size == other.size &&
      color == other.color &&
      productId == other.productId;
}

class StockException implements Exception {
  const StockException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CartItems {
  CartItems._();

  static final ValueNotifier<List<CartLine>> items =
      ValueNotifier<List<CartLine>>([]);
  static StreamSubscription<AuthState>? _authSubscription;
  static Future<void> _pending = Future.value();
  static String? _owner;

  static void initialize() {
    _authSubscription ??= Supabase.instance.client.auth.onAuthStateChange
        .listen((_) {
          unawaited(refresh().catchError((Object _) {}));
        });
    unawaited(refresh().catchError((Object _) {}));
  }

  static Future<void> refresh() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      if (_owner != null) items.value = [];
      _owner = null;
      return;
    }
    final previousOwner = _owner;
    final guestLines = previousOwner == null ? [...items.value] : <CartLine>[];
    if (previousOwner != null && previousOwner != userId) items.value = [];
    _owner = userId;
    try {
      await _pending;
      final existing = await client
          .from('cart_items')
          .select('product_id,size,color,quantity')
          .eq('customer_id', userId);
      for (final line in guestLines) {
        if (line.productId == null) continue;
        final match = (existing as List).where(
          (row) =>
              row['product_id'] == line.productId &&
              row['size'] == line.size &&
              row['color'] == line.color,
        );
        final mergedQuantity =
            (line.quantity +
                    (match.isEmpty ? 0 : match.first['quantity'] as int))
                .clamp(1, 99);
        await client.from('cart_items').upsert({
          ..._row(line, userId),
          'quantity': mergedQuantity,
        }, onConflict: 'customer_id,product_id,size,color');
      }
      final rows = await client
          .from('cart_items')
          .select(
            'product_id,size,color,quantity,is_selected,products!inner(id,name,description,price,image_url)',
          )
          .eq('customer_id', userId)
          .order('updated_at', ascending: false);
      if (client.auth.currentUser?.id != userId) return;
      items.value = (rows as List).map((row) {
        final product = Map<String, dynamic>.from(row['products'] as Map);
        return CartLine(
          productId: product['id'] as String,
          name: product['name'] as String,
          description: product['description'] as String? ?? '',
          price: formatPeso(product['price'] as num),
          image: product['image_url'] as String,
          size: row['size'] as String,
          color: row['color'] as String,
          quantity: row['quantity'] as int,
          isSelected: row['is_selected'] as bool? ?? true,
        );
      }).toList();
    } catch (_) {
      if (client.auth.currentUser?.id == userId && previousOwner == null) {
        _owner = null;
        items.value = guestLines;
      }
      rethrow;
    }
  }

  static Map<String, dynamic> _row(CartLine line, String userId) => {
    'customer_id': userId,
    'product_id': line.productId,
    'size': line.size,
    'color': line.color,
    'quantity': line.quantity,
    'is_selected': line.isSelected,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  static Future<void> _persist(CartLine line, {bool delete = false}) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || line.productId == null) return;
    final row = _row(line, userId);
    final productId = line.productId!;
    final size = line.size;
    final color = line.color;
    final operation = _pending.then((_) async {
      if (delete) {
        await Supabase.instance.client
            .from('cart_items')
            .delete()
            .eq('customer_id', userId)
            .eq('product_id', productId)
            .eq('size', size)
            .eq('color', color);
      } else {
        await Supabase.instance.client
            .from('cart_items')
            .upsert(row, onConflict: 'customer_id,product_id,size,color');
      }
    });
    _pending = operation.catchError((Object _) {});
    try {
      await operation;
    } catch (_) {
      await refresh();
      rethrow;
    }
  }

  static Future<void> add(CartLine line) async {
    if (line.quantity < 1) {
      throw const StockException('Choose at least one item.');
    }
    final updated = [...items.value];
    final existingIndex = updated.indexWhere((item) => item.matches(line));
    final mergedQuantity =
        line.quantity +
        (existingIndex == -1 ? 0 : updated[existingIndex].quantity);
    if (mergedQuantity > 99) {
      throw const StockException('You can add at most 99 of this item.');
    }
    final productTotal =
        line.quantity +
        updated
            .where((item) => item.productId == line.productId)
            .fold<int>(0, (total, item) => total + item.quantity);
    await _checkProductStock(line.productId, line.name, productTotal);
    if (existingIndex == -1) {
      updated.add(line);
    } else {
      updated[existingIndex].quantity = mergedQuantity;
    }
    items.value = List.unmodifiable(updated);
    await _persist(existingIndex == -1 ? line : updated[existingIndex]);
  }

  static Future<void> changeQuantity(CartLine line, int change) async {
    final updated = [...items.value];
    final index = updated.indexWhere((item) => item.matches(line));
    if (index == -1) return;
    final nextQuantity = updated[index].quantity + change;
    if (nextQuantity > 99) {
      throw const StockException('You can add at most 99 of this item.');
    }
    if (change > 0) {
      final productTotal =
          change +
          updated
              .where((item) => item.productId == line.productId)
              .fold<int>(0, (total, item) => total + item.quantity);
      await _checkProductStock(line.productId, line.name, productTotal);
    }
    updated[index].quantity += change;
    final removeLine = updated[index].quantity <= 0;
    if (removeLine) updated.removeAt(index);
    items.value = List.unmodifiable(updated);
    await _persist(line, delete: removeLine);
  }

  static Future<void> ensureAvailable(Iterable<CartLine> lines) async {
    final totals = <String, int>{};
    final names = <String, String>{};
    for (final line in lines) {
      final productId = line.productId;
      if (productId == null || line.quantity < 1 || line.quantity > 99) {
        throw const StockException(
          'An item has an invalid quantity. Update your bag.',
        );
      }
      totals[productId] = (totals[productId] ?? 0) + line.quantity;
      names[productId] = line.name;
    }
    for (final entry in totals.entries) {
      await _checkProductStock(entry.key, names[entry.key]!, entry.value);
    }
  }

  static Future<void> _checkProductStock(
    String? productId,
    String name,
    int requested,
  ) async {
    if (productId == null) {
      throw StockException('$name is no longer available.');
    }
    final product = await Supabase.instance.client
        .from('products')
        .select('quantity,is_active')
        .eq('id', productId)
        .maybeSingle();
    if (product == null || product['is_active'] != true) {
      throw StockException('$name is no longer available.');
    }
    final available = product['quantity'] as int;
    if (requested > available) {
      throw StockException(
        'Only $available of $name ${available == 1 ? 'is' : 'are'} available. Reduce the quantity to continue.',
      );
    }
  }

  static Future<void> remove(CartLine line) async {
    items.value = List.unmodifiable(
      items.value.where((item) => !item.matches(line)),
    );
    await _persist(line, delete: true);
  }

  static Future<void> toggleSelection(CartLine line, bool selected) async {
    final updated = [...items.value];
    final index = updated.indexWhere((item) => item.matches(line));
    if (index == -1) return;
    updated[index].isSelected = selected;
    items.value = List.unmodifiable(updated);
    await _persist(updated[index]);
  }

  static Future<void> clearSelected(Iterable<CartLine> selected) async {
    final selectedLines = selected.toSet();
    items.value = List.unmodifiable(
      items.value.where((line) => !selectedLines.contains(line)),
    );
    for (final line in selectedLines) {
      await _persist(line, delete: true);
    }
  }
}
