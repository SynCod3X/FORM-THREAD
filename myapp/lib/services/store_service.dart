import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase_config.dart';

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.quantity,
    required this.isActive,
    required this.category,
    required this.compareAtPrice,
    this.discountPercent,
    required this.badge,
    required this.availableSizes,
    required this.availableColors,
  });

  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final double price;
  final int quantity;
  final bool isActive;
  final String category;
  final double? compareAtPrice;
  final double? discountPercent;
  final String badge;
  final List<String> availableSizes;
  final List<String> availableColors;

  factory StoreProduct.fromMap(Map<String, dynamic> row) => StoreProduct(
    id: row['id'] as String,
    name: row['name'] as String,
    description: row['description'] as String? ?? '',
    imageUrl: row['image_url'] as String,
    price: (row['price'] as num).toDouble(),
    quantity: row['quantity'] as int,
    isActive: row['is_active'] as bool? ?? true,
    category: row['category'] as String? ?? 'Clothing',
    compareAtPrice: (row['compare_at_price'] as num?)?.toDouble(),
    discountPercent: (row['discount_percent'] as num?)?.toDouble(),
    badge: row['badge'] as String? ?? '',
    availableSizes:
        (row['available_sizes'] as List? ?? const ['XS', 'S', 'M', 'L', 'XL'])
            .cast<String>(),
    availableColors:
        (row['available_colors'] as List? ??
                const ['Natural', 'Black', 'Olive'])
            .cast<String>(),
  );
}

class StoreService {
  StoreService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<StoreProduct>> loadProducts({
    bool staffView = false,
  }) async {
    final rows = await _client
        .from('products')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((row) => StoreProduct.fromMap(Map<String, dynamic>.from(row)))
        .where((product) => staffView || product.isActive)
        .toList();
  }

  static Future<StoreProduct?> loadProduct(String id) async {
    final row = await _client
        .from('products')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return StoreProduct.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> saveProduct({
    String? id,
    required String name,
    required String description,
    required String imageUrl,
    required double price,
    required int quantity,
    required bool isActive,
    String category = 'Clothing',
    double? compareAtPrice,
    double? discountPercent,
    String badge = '',
    List<String> availableSizes = const ['XS', 'S', 'M', 'L', 'XL'],
    List<String> availableColors = const ['Natural', 'Black', 'Olive'],
  }) async {
    final values = {
      'name': name.trim(),
      'description': description.trim(),
      'image_url': imageUrl.trim(),
      'price': price,
      'quantity': quantity,
      'is_active': isActive,
      'category': category,
      'compare_at_price': compareAtPrice,
      'discount_percent': discountPercent,
      'badge': badge.trim(),
      'available_sizes': availableSizes,
      'available_colors': availableColors,
    };
    if (id == null) {
      await _client.from('products').insert({
        ...values,
        'created_by': _client.auth.currentUser!.id,
      });
    } else {
      final updated = await _client
          .from('products')
          .update(values)
          .eq('id', id)
          .select('id')
          .maybeSingle();
      if (updated == null) {
        throw StateError(
          'Product not found or you no longer have staff access.',
        );
      }
    }
  }

  static Future<void> deleteProduct(String id) async {
    await _client.from('products').delete().eq('id', id);
  }

  static Future<void> setProductVisibility(
    String id, {
    required bool isActive,
  }) async {
    final updated = await _client
        .from('products')
        .update({'is_active': isActive})
        .eq('id', id)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('Product not found or you no longer have staff access.');
    }
  }

  static Future<List<Map<String, dynamic>>> loadOrders() async {
    final rows = await _client
        .from('orders')
        .select()
        .order('created_at', ascending: false);
    return (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<List<Map<String, dynamic>>> loadMyOrders() async {
    final user = _client.auth.currentUser;
    if (user == null)
      throw const AuthException('Please sign in to view your orders.');
    final rows = await _client
        .from('orders')
        .select()
        .eq('customer_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<Map<String, dynamic>> loadMyOrder(String id) async {
    final user = _client.auth.currentUser;
    if (user == null)
      throw const AuthException('Please sign in to view your order.');
    final row = await _client
        .from('orders')
        .select()
        .eq('id', id)
        .eq('customer_id', user.id)
        .maybeSingle();
    if (row == null) throw StateError('Order not found.');
    return Map<String, dynamic>.from(row);
  }

  static Future<List<Map<String, dynamic>>> loadMySupportRequests() async {
    final user = _client.auth.currentUser;
    if (user == null)
      throw const AuthException('Please sign in to view support requests.');
    final rows = await _client
        .from('support_requests')
        .select()
        .eq('customer_id', user.id)
        .order('created_at', ascending: false);
    return (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> submitSupportRequest({
    required String subject,
    required String message,
    String? orderId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null)
      throw const AuthException('Please sign in to contact support.');
    await _client.from('support_requests').insert({
      'customer_id': user.id,
      'subject': subject.trim(),
      'message': message.trim(),
      'order_id': orderId,
    });
  }

  static Future<List<Map<String, dynamic>>> loadSupportRequests() async {
    final rows = await _client
        .from('support_requests')
        .select()
        .order('created_at', ascending: false);
    return (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> updateSupportRequestStatus(
    String id,
    String status,
  ) async {
    final row = await _client
        .from('support_requests')
        .update({'status': status})
        .eq('id', id)
        .select('id')
        .maybeSingle();
    if (row == null) throw StateError('Could not update this support request.');
  }

  static Future<void> replyToSupportRequest(String id, String reply) async {
    final row = await _client
        .from('support_requests')
        .update({'staff_reply': reply.trim(), 'status': 'in_progress'})
        .eq('id', id)
        .select('id')
        .maybeSingle();
    if (row == null) throw StateError('Could not send this reply.');
  }

  static Future<List<Map<String, dynamic>>> loadOrderHistory(
    String orderId,
  ) async {
    final rows = await _client
        .from('order_status_history')
        .select('from_status, to_status, changed_at')
        .eq('order_id', orderId)
        .order('changed_at');
    return (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> updateOrderStatus(
    String id,
    String currentStatus,
    String nextStatus,
  ) async {
    final updated = await _client
        .from('orders')
        .update({'status': nextStatus})
        .eq('id', id)
        .eq('status', currentStatus)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('This order changed. Refresh it and try again.');
    }
  }

  static Future<String> placeOrder(
    List<Map<String, dynamic>> items, {
    String paymentMethod = 'cash',
  }) async {
    final result = await _client.rpc(
      'place_order_with_payment',
      params: {'p_items': items, 'p_payment_method': paymentMethod},
    );
    return result as String;
  }

  static Future<Map<String, dynamic>> startXenditTestPayment(
    String orderId,
  ) async {
    late final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'create-xendit-payment',
        body: {'order_id': orderId, 'project_url': SupabaseConfig.url},
      );
    } on FunctionException catch (error) {
      throw StateError(_paymentFunctionError(error));
    }
    if (response.status != 200 || response.data is! Map) {
      throw StateError('Could not start the Xendit test payment.');
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['action'] is! Map) {
      throw StateError(
        data['error']?.toString() ?? 'No payment instructions were returned.',
      );
    }
    return Map<String, dynamic>.from(data['action'] as Map);
  }

  static Future<void> ensureXenditTestReady() async {
    try {
      final response = await _client.functions.invoke(
        'create-xendit-payment',
        body: {'health_check': true, 'project_url': SupabaseConfig.url},
      );
      if (response.status != 200 ||
          response.data is! Map ||
          (response.data as Map)['ready'] != true) {
        throw StateError('Xendit test mode is not configured.');
      }
    } on FunctionException catch (error) {
      throw StateError(_paymentFunctionError(error));
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError(
        'Xendit test mode is not ready. Choose cash or ask staff to configure demo payments.',
      );
    }
  }

  static String _paymentFunctionError(FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return 'Xendit test payment is unavailable (HTTP ${error.status}). Check the deployed function and its logs.';
  }

  static Future<List<Map<String, dynamic>>> loadMyOrderRequests(
    String orderId,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Please sign in.');
    final rows = await _client
        .from('order_requests')
        .select()
        .eq('customer_id', user.id)
        .eq('order_id', orderId)
        .order('created_at', ascending: false);
    return (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> submitOrderRequest({
    required String orderId,
    required String type,
    required String reason,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Please sign in.');
    await _client.from('order_requests').insert({
      'order_id': orderId,
      'customer_id': user.id,
      'type': type,
      'reason': reason.trim(),
    });
  }

  static Future<void> cancelPendingOrder(String orderId) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Please sign in.');
    await _client.rpc('cancel_pending_order', params: {'p_order_id': orderId});
  }

  static Future<List<Map<String, dynamic>>> loadOrderRequests() async {
    final rows = await _client
        .from('order_requests')
        .select()
        .order('created_at', ascending: false);
    return (rows as List).map((row) => Map<String, dynamic>.from(row)).toList();
  }

  static Future<void> decideOrderRequest(
    String id,
    String currentStatus,
    String status,
    String note,
  ) async {
    final row = await _client
        .from('order_requests')
        .update({'status': status, 'staff_note': note.trim()})
        .eq('id', id)
        .eq('status', currentStatus)
        .select('id')
        .maybeSingle();
    if (row == null)
      throw StateError(
        'This request has already changed. Refresh and try again.',
      );
  }
}
