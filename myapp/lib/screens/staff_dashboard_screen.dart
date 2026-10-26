import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/store_service.dart';
import '../utils/money.dart';
import 'shop_screen.dart';
import 'staff_product_editor_dialog.dart';
import 'staff_support_screen.dart';
import 'staff_order_requests_screen.dart';

const _ink = Color(0xFF25231F);
const _muted = Color(0xFF827D73);
const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  final _productSearchController = TextEditingController();
  final _orderSearchController = TextEditingController();
  int _loadGeneration = 0;
  int _tab = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _orderFilter = 'active';
  String _productFilter = 'all';
  String _orderQuery = '';
  String _productQuery = '';
  Map<String, dynamic> _profile = {};
  List<StoreProduct> _products = [];
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _productSearchController.dispose();
    _orderSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await AuthService.loadMyProfile();
      if (profile['role'] != 'staff') {
        throw const AuthException('This account does not have staff access.');
      }
      final results = await Future.wait([
        StoreService.loadProducts(staffView: true),
        StoreService.loadOrders(),
      ]);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _profile = profile;
        _products = results[0] as List<StoreProduct>;
        _orders = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error is AuthException ? error.message : 'Could not load staff data. Run the latest Supabase schema and confirm this account role is staff.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(
      backgroundColor: _paper,
      title: const Text(
        'STAFF DASHBOARD',
        style: TextStyle(
          fontSize: 14,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ShopScreen())),
          icon: const Icon(Icons.storefront_outlined),
          label: const Text('SHOP'),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: _olive))
        : _error != null
        ? _errorView()
        : switch (_tab) {
            0 => _overviewView(),
            1 => _ordersView(),
            2 => _productsView(),
            _ => _accountView(),
          },
    bottomNavigationBar: _loading || _error != null
        ? null
        : NavigationBar(
            selectedIndex: _tab,
            height: 64,
            backgroundColor: _paper,
            indicatorColor: const Color(0xFFE8E6DE),
            onDestinationSelected: (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                label: 'Products',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                label: 'Account',
              ),
            ],
          ),
    floatingActionButton: !_loading && _error == null && _tab == 2
        ? FloatingActionButton.extended(
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            onPressed: () => _editProduct(),
            icon: const Icon(Icons.add),
            label: const Text('ADD PRODUCT'),
          )
        : null,
  );

  Widget _overviewView() {
    final pending = _orders
        .where((order) => order['status'] == 'pending')
        .length;
    final processing = _orders
        .where((order) => order['status'] == 'processing')
        .length;
    final lowStock = _products
        .where((product) => product.isActive && product.quantity <= 5)
        .toList();
    final active = _products.where((product) => product.isActive).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
        children: [
          const Text('Today in the shop', style: TextStyle(fontSize: 24)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Pending orders',
                  pending,
                  Icons.pending_actions_outlined,
                  () => setState(() {
                    _orderFilter = 'pending';
                    _tab = 1;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Processing',
                  processing,
                  Icons.inventory_outlined,
                  () => setState(() {
                    _orderFilter = 'processing';
                    _tab = 1;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Low stock',
                  lowStock.length,
                  Icons.warning_amber_outlined,
                  () => setState(() {
                    _productFilter = 'low';
                    _tab = 2;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Active products',
                  active,
                  Icons.storefront_outlined,
                  () => setState(() {
                    _productFilter = 'active';
                    _tab = 2;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _editProduct(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add product'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _orderFilter = 'active';
                    _tab = 1;
                  }),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('View orders'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Recent orders', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          if (_orders.isEmpty)
            const Text(
              'No customer orders yet.',
              style: TextStyle(fontFamily: 'Arial', color: _muted),
            ),
          ..._orders.take(3).map(_orderCard),
          if (lowStock.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Stock to review', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            ...lowStock
                .take(4)
                .map(
                  (product) => ListTile(
                    title: Text(product.name),
                    subtitle: Text('${product.quantity} left in stock'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editProduct(product),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _metricCard(
    String label,
    int count,
    IconData icon,
    VoidCallback onTap,
  ) => Card(
    color: Colors.white,
    elevation: 0,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _olive),
            const SizedBox(height: 10),
            Text('$count', style: const TextStyle(fontSize: 26)),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Arial',
                fontSize: 11,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 42, color: _olive),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Arial',
              color: _muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: _load, child: const Text('TRY AGAIN')),
        ],
      ),
    ),
  );

  Widget _productsView() {
    final products = _products.where((product) {
      final matchesQuery = product.name.toLowerCase().contains(
        _productQuery.toLowerCase(),
      );
      final matchesFilter = switch (_productFilter) {
        'active' => product.isActive,
        'hidden' => !product.isActive,
        'low' => product.isActive && product.quantity <= 5,
        'out' => product.isActive && product.quantity == 0,
        'sale' =>
          product.compareAtPrice != null &&
              product.compareAtPrice! > product.price,
        _ => true,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _productSearchController,
            onChanged: (query) => setState(() => _productQuery = query.trim()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search products',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        _filterChips(
          values: const {
            'all': 'All',
            'active': 'Active',
            'hidden': 'Hidden',
            'low': 'Low stock',
            'out': 'Out of stock',
            'sale': 'On sale',
          },
          selected: _productFilter,
          onSelected: (value) => setState(() => _productFilter = value),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: products.isEmpty ? 1 : products.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (products.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: Text('No matching products.')),
                  );
                }
                final product = products[index];
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: Image.network(
                            product.imageUrl,
                            width: 76,
                            height: 92,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 76,
                              height: 92,
                              color: const Color(0xFFEAE8DF),
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                product.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Arial',
                                  color: _muted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                '${formatPeso(product.price)}  ·  Stock ${product.quantity}',
                                style: const TextStyle(
                                  fontFamily: 'Arial',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              if (product.compareAtPrice != null &&
                                  product.compareAtPrice! > product.price)
                                Text(
                                  'Was ${formatPeso(product.compareAtPrice!)} · '
                                  '${(product.discountPercent ?? (1 - product.price / product.compareAtPrice!) * 100).toStringAsFixed(2)}% off',
                                  style: const TextStyle(
                                    fontFamily: 'Arial',
                                    color: _muted,
                                    fontSize: 11,
                                  ),
                                ),
                              if (!product.isActive)
                                const Text(
                                  'Hidden from shop',
                                  style: TextStyle(
                                    fontFamily: 'Arial',
                                    color: Colors.red,
                                    fontSize: 10,
                                  ),
                                ),
                              if (product.isActive && product.quantity <= 5)
                                Text(
                                  product.quantity == 0
                                      ? 'Out of stock'
                                      : 'Low stock',
                                  style: const TextStyle(
                                    fontFamily: 'Arial',
                                    color: Colors.deepOrange,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'edit') {
                              _editProduct(product);
                            } else if (action == 'visibility') {
                              _setProductVisibility(product);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit product'),
                            ),
                            PopupMenuItem(
                              value: 'visibility',
                              child: Text(
                                product.isActive
                                    ? 'Hide from shop'
                                    : 'Show in shop',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _ordersView() {
    final orders = _orders.where((order) {
      final status = order['status'] as String? ?? 'pending';
      final query = _orderQuery.toLowerCase();
      final matchesQuery =
          (order['customer_name'] as String? ?? '').toLowerCase().contains(
            query,
          ) ||
          (order['customer_email'] as String? ?? '').toLowerCase().contains(
            query,
          ) ||
          (order['id'] as String? ?? '').toLowerCase().contains(query);
      final matchesFilter =
          _orderFilter == 'all' ||
          (_orderFilter == 'active' &&
              (status == 'pending' ||
                  status == 'processing' ||
                  status == 'shipped')) ||
          _orderFilter == status;
      return matchesQuery && matchesFilter;
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _orderSearchController,
            onChanged: (query) => setState(() => _orderQuery = query.trim()),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search customer, email, or order ID',
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        _filterChips(
          values: const {
            'active': 'Active',
            'pending': 'Pending',
            'processing': 'Processing',
            'shipped': 'Shipped',
            'completed': 'Completed',
            'cancelled': 'Cancelled',
            'all': 'All',
          },
          selected: _orderFilter,
          onSelected: (value) => setState(() => _orderFilter = value),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: orders.isEmpty ? 1 : orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => orders.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: Text('No matching orders.')),
                    )
                  : _orderCard(orders[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChips({
    required Map<String, String> values,
    required String selected,
    required ValueChanged<String> onSelected,
  }) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: values.entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: selected == entry.key,
                onSelected: (_) => onSelected(entry.key),
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _orderCard(Map<String, dynamic> order) {
    final items = (order['items'] as List? ?? const []).cast<Map>();
    final status = order['status'] as String? ?? 'pending';
    final paymentMethod = order['payment_method'] as String? ?? 'cash';
    final paymentStatus = order['payment_status'] as String? ?? 'cash_due';
    final nextStatuses = _nextStatuses(status)
        .where(
          (next) =>
              next != 'processing' ||
              paymentMethod == 'cash' ||
              paymentStatus == 'paid',
        )
        .toList();
    final created = DateTime.tryParse(order['created_at'] as String? ?? '')
        ?.toLocal();
    return Card(
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (order['customer_name'] as String? ?? '').isEmpty
                            ? 'Customer order'
                            : order['customer_name'] as String,
                        style: const TextStyle(fontSize: 17),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        order['customer_email'] as String? ?? '',
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          color: _muted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Order ${(order['id'] as String? ?? '').split('-').first}',
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          color: _muted,
                          fontSize: 10,
                        ),
                      ),
                      if (created != null)
                        Text(
                          '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}  ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontFamily: 'Arial',
                            color: _muted,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  formatOrderMoney(order['total'] as num, order),
                  style: const TextStyle(
                    fontFamily: 'Arial',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...items.map((raw) {
              final item = Map<String, dynamic>.from(raw);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${item['quantity']} × ${item['name']}  ·  ${item['size']} / ${item['color']}',
                  style: const TextStyle(fontFamily: 'Arial', fontSize: 12),
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              'Deliver to: ${order['shipping_address'] ?? 'No address provided'}',
              style: const TextStyle(
                fontFamily: 'Arial',
                color: _muted,
                fontSize: 11,
              ),
            ),
            Text(
              'Contact: ${order['contact_number'] ?? 'Not provided'}',
              style: const TextStyle(
                fontFamily: 'Arial',
                color: _muted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Status: ${_statusLabel(status)}',
              style: const TextStyle(
                fontFamily: 'Arial',
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Payment: ${paymentMethod == 'cash'
                  ? 'Cash on delivery'
                  : paymentMethod == 'gcash'
                  ? 'GCash demo'
                  : 'Bank transfer demo'} · ${paymentStatus.replaceAll('_', ' ')}',
              style: const TextStyle(fontFamily: 'Arial', fontSize: 12),
            ),
            if (paymentStatus == 'payment_review' ||
                paymentStatus == 'refund_due')
              const Text(
                'Manual payment/refund review needed; do not fulfil automatically.',
                style: TextStyle(
                  fontFamily: 'Arial',
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 8),
            if (nextStatuses.isNotEmpty)
              Wrap(
                spacing: 8,
                children: nextStatuses
                    .map(
                      (next) => OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => _changeOrderStatus(
                                order['id'] as String,
                                status,
                                next,
                              ),
                        child: Text(
                          next == 'cancelled'
                              ? 'Cancel order'
                              : 'Mark ${_statusLabel(next).toLowerCase()}',
                        ),
                      ),
                    )
                    .toList(),
              ),
            TextButton.icon(
              onPressed: () => _showOrderHistory(order['id'] as String),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Status history'),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _nextStatuses(String status) => switch (status) {
    'pending' => const ['processing', 'cancelled'],
    'processing' => const ['shipped', 'cancelled'],
    'shipped' => const ['completed'],
    _ => const [],
  };

  String _statusLabel(String status) => status.isEmpty
      ? 'Unknown'
      : status[0].toUpperCase() + status.substring(1);

  Future<void> _showOrderHistory(String orderId) async {
    final historyFuture = StoreService.loadOrderHistory(orderId);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Order status history'),
        content: SizedBox(
          width: 420,
          height: 350,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: historyFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return snapshot.hasError
                    ? const Text(
                        'Could not load status history. Apply the latest Supabase schema.',
                      )
                    : const Center(child: CircularProgressIndicator());
              }
              final history = snapshot.data!;
              if (history.isEmpty) {
                return const Text('No status changes recorded.');
              }
              return ListView(
                shrinkWrap: true,
                children: history.map((entry) {
                  final from = entry['from_status'] as String?;
                  final to = entry['to_status'] as String? ?? '';
                  final changed = DateTime.tryParse(
                    entry['changed_at'] as String? ?? '',
                  )?.toLocal();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.check_circle_outline,
                      color: _olive,
                    ),
                    title: Text(
                      from == null
                          ? _statusLabel(to)
                          : '${_statusLabel(from)} → ${_statusLabel(to)}',
                    ),
                    subtitle: changed == null
                        ? null
                        : Text(changed.toString().split('.').first),
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _accountView() => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CircleAvatar(
          radius: 32,
          backgroundColor: _olive,
          child: Icon(Icons.person_outline, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            (_profile['full_name'] as String? ?? '').trim().isEmpty
                ? 'Staff account'
                : _profile['full_name'] as String,
            style: const TextStyle(fontSize: 22),
          ),
        ),
        const SizedBox(height: 5),
        Center(
          child: Text(
            (_profile['email'] as String? ??
                Supabase.instance.client.auth.currentUser?.email ??
                ''),
            style: const TextStyle(fontFamily: 'Arial', color: _muted),
          ),
        ),
        const SizedBox(height: 24),
        ListTile(
          leading: const Icon(Icons.storefront_outlined),
          title: const Text('View shop'),
          onTap: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ShopScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.refresh),
          title: const Text('Refresh dashboard'),
          onTap: _load,
        ),
        ListTile(
          leading: const Icon(Icons.support_agent_outlined),
          title: const Text('Support requests'),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const StaffSupportScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.assignment_outlined),
          title: const Text('Cancellation & return requests'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StaffOrderRequestsScreen()),
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign out'),
          onTap: _signOut,
        ),
      ],
    ),
  );

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (error) {
      if (mounted) _message('Could not sign out: $error');
    }
  }

  Future<void> _editProduct([StoreProduct? current]) async {
    final draft = await showDialog<StaffProductDraft>(
      context: context,
      builder: (_) => StaffProductEditorDialog(current: current),
    );
    if (!mounted || draft == null) return;

    try {
      await StoreService.saveProduct(
        id: current?.id,
        name: draft.name,
        description: draft.description,
        imageUrl: draft.imageUrl,
        price: draft.price,
        quantity: draft.quantity,
        isActive: current?.isActive ?? true,
        category: draft.category,
        compareAtPrice: draft.compareAtPrice,
        discountPercent: draft.discountPercent,
        badge: draft.badge,
        availableSizes: draft.availableSizes,
        availableColors: draft.availableColors,
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        _message(
          current == null ? 'Product added to the shop.' : 'Product updated.',
        );
      }
    } catch (error) {
      if (mounted) _message('Could not save product: $error');
    }
  }

  Future<void> _setProductVisibility(StoreProduct product) async {
    try {
      await StoreService.setProductVisibility(
        product.id,
        isActive: !product.isActive,
      );
      if (!mounted) return;
      await _load();
      if (mounted) {
        _message(
          product.isActive
              ? 'Product hidden from the shop.'
              : 'Product shown in the shop.',
        );
      }
    } catch (error) {
      if (mounted) _message('Could not change product visibility: $error');
    }
  }

  Future<void> _changeOrderStatus(
    String id,
    String currentStatus,
    String nextStatus,
  ) async {
    if (nextStatus == 'cancelled') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Cancel this order?'),
          content: const Text(
            'The customer order will be marked as cancelled.',
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
      if (!mounted || confirmed != true) return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await StoreService.updateOrderStatus(id, currentStatus, nextStatus);
      if (!mounted) return;
      await _load();
      if (mounted) {
        _message('Order marked ${_statusLabel(nextStatus).toLowerCase()}.');
      }
    } catch (error) {
      if (mounted) _message('Could not update order: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text, style: const TextStyle(fontFamily: 'Arial')),
    ),
  );
}
