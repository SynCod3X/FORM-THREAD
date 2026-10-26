import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/money.dart';

class SavedItem {
  const SavedItem({
    required this.productId,
    required this.name,
    required this.detail,
    required this.price,
    required this.image,
  });

  final String productId;
  final String name;
  final String detail;
  final String price;
  final String image;

  @override
  bool operator ==(Object other) =>
      other is SavedItem && other.productId == productId;

  @override
  int get hashCode => productId.hashCode;
}

class SavedItems {
  SavedItems._();

  static final ValueNotifier<List<SavedItem>> items =
      ValueNotifier<List<SavedItem>>([]);
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
    final guestItems = previousOwner == null ? [...items.value] : <SavedItem>[];
    if (previousOwner != null && previousOwner != userId) items.value = [];
    _owner = userId;
    try {
      await _pending;
      for (final item in guestItems) {
        await client.from('saved_items').upsert({
          'customer_id': userId,
          'product_id': item.productId,
        });
      }
      final rows = await client
          .from('saved_items')
          .select(
            'product_id, products!inner(id,name,description,price,image_url)',
          )
          .eq('customer_id', userId)
          .order('created_at', ascending: false);
      if (client.auth.currentUser?.id != userId) return;
      items.value = (rows as List).map((row) {
        final product = Map<String, dynamic>.from(row['products'] as Map);
        return SavedItem(
          productId: product['id'] as String,
          name: product['name'] as String,
          detail: product['description'] as String? ?? '',
          price: formatPeso(product['price'] as num),
          image: product['image_url'] as String,
        );
      }).toList();
    } catch (_) {
      if (client.auth.currentUser?.id == userId && previousOwner == null) {
        _owner = null;
        items.value = guestItems;
      }
      rethrow;
    }
  }

  static bool contains(SavedItem item) => items.value.contains(item);

  static Future<void> toggle(SavedItem item) async {
    final updated = [...items.value];
    final hadItem = updated.contains(item);
    if (hadItem) {
      updated.remove(item);
    } else {
      updated.insert(0, item);
    }
    items.value = List.unmodifiable(updated);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final operation = _pending.then((_) async {
      if (hadItem) {
        await Supabase.instance.client
            .from('saved_items')
            .delete()
            .eq('customer_id', userId)
            .eq('product_id', item.productId);
      } else {
        await Supabase.instance.client.from('saved_items').upsert({
          'customer_id': userId,
          'product_id': item.productId,
        });
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

  static Future<void> remove(SavedItem item) => toggle(item);
}
