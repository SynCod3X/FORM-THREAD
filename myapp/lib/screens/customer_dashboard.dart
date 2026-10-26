import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/store_service.dart';
import 'create_account_screen.dart';
import 'customer_purchases_screen.dart';
import 'customer_orders_screen.dart';
import 'customer_support_screen.dart';
import 'login_screen.dart';
import 'profile_details_screen.dart';
import 'saved_screen.dart';
import 'cart_screen.dart';
import 'staff_dashboard_screen.dart';

const _ink = Color(0xFF25231F);
const _muted = Color(0xFF827D73);
const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  late Future<Map<String, dynamic>> _profileFuture;
  late Future<List<Map<String, dynamic>>> _ordersFuture;
  RealtimeChannel? _orderChannel;
  String? _subscribedUser;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final signedIn = userId != null;
    if (_subscribedUser != userId) {
      if (_orderChannel != null) {
        Supabase.instance.client.removeChannel(_orderChannel!);
      }
      _orderChannel = null;
      _subscribedUser = userId;
      if (userId != null) {
        _orderChannel = Supabase.instance.client
            .channel('customer-orders-$userId')
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
    setState(() {
      _profileFuture = signedIn
          ? AuthService.loadMyProfile()
          : Future.value({});
      _ordersFuture = signedIn ? StoreService.loadMyOrders() : Future.value([]);
    });
  }

  @override
  void dispose() {
    if (_orderChannel != null) {
      Supabase.instance.client.removeChannel(_orderChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _paper,
        title: const Text(
          'MY ACCOUNT',
          style: TextStyle(
            fontSize: 14,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? _signedOutView()
          : FutureBuilder<Map<String, dynamic>>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _olive),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Could not load your account.'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('TRY AGAIN'),
                        ),
                      ],
                    ),
                  );
                }
                final profile = snapshot.data ?? <String, dynamic>{};
                final name = (profile['full_name'] as String? ?? '').trim();
                return RefreshIndicator(
                  onRefresh: () async {
                    _refresh();
                    try {
                      await _profileFuture;
                    } catch (_) {}
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAE8DF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: _olive,
                              child: Icon(
                                Icons.person_outline,
                                color: Colors.white,
                                size: 29,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isEmpty ? 'Welcome' : name,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email ?? '',
                                    style: const TextStyle(
                                      fontFamily: 'Arial',
                                      fontSize: 12,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _ordersFuture,
                        builder: (context, ordersSnapshot) {
                          if (ordersSnapshot.hasError) {
                            return ListTile(
                              title: const Text('My orders'),
                              subtitle: const Text(
                                'Could not load orders. Tap to retry.',
                              ),
                              onTap: _refresh,
                            );
                          }
                          final orders = ordersSnapshot.data ?? [];
                          final active = orders
                              .where(
                                (order) => const [
                                  'pending',
                                  'processing',
                                  'shipped',
                                ].contains(order['status']),
                              )
                              .toList();
                          if (active.isEmpty) return const SizedBox.shrink();
                          final latest = active.first;
                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            child: ListTile(
                              leading: const Icon(
                                Icons.local_shipping_outlined,
                                color: _olive,
                              ),
                              title: Text(
                                'Order ${((latest['id'] as String?) ?? '').split('-').first}',
                              ),
                              subtitle: Text(
                                'Status: ${customerOrderStatus(latest['status'] as String? ?? 'pending')}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          CustomerOrderDetailsScreen(
                                            orderId: latest['id'] as String,
                                          ),
                                    ),
                                  )
                                  .then((_) {
                                    if (mounted) _refresh();
                                  }),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      const _SectionLabel('YOUR SHOPPING'),
                      const SizedBox(height: 8),
                      _AccountTile(
                        icon: Icons.receipt_long_outlined,
                        title: 'My orders',
                        subtitle: 'Track current and past orders',
                        onTap: () => Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => const CustomerPurchasesScreen(),
                              ),
                            )
                            .then((_) {
                              if (mounted) _refresh();
                            }),
                      ),
                      _AccountTile(
                        icon: Icons.favorite_border,
                        title: 'Saved items',
                        subtitle: 'Pieces you have saved',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SavedScreen(),
                          ),
                        ),
                      ),
                      _AccountTile(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Shopping bag',
                        subtitle: 'Review pieces before checkout',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CartScreen()),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SectionLabel('YOUR DETAILS'),
                      const SizedBox(height: 8),
                      _AccountTile(
                        icon: Icons.person_outline,
                        title: 'Personal details',
                        subtitle: 'Name, contact number and delivery address',
                        onTap: () => _editProfile(profile),
                      ),
                      if ((profile['role'] as String? ?? 'customer') ==
                          'staff') ...[
                        const SizedBox(height: 20),
                        const _SectionLabel('STAFF TOOLS'),
                        const SizedBox(height: 8),
                        _AccountTile(
                          icon: Icons.dashboard_outlined,
                          title: 'Staff dashboard',
                          subtitle: 'Manage shop products and customer orders',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const StaffDashboardScreen(),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      const _SectionLabel('HELP'),
                      const SizedBox(height: 8),
                      _AccountTile(
                        icon: Icons.support_agent_outlined,
                        title: 'Help & support',
                        subtitle: 'Send a request and check its status',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CustomerSupportScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          'SIGN OUT',
                          style: TextStyle(
                            fontFamily: 'Arial',
                            letterSpacing: 1.2,
                            fontSize: 11,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink,
                          side: const BorderSide(color: _ink),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _signedOutView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_circle_outlined, size: 60, color: _olive),
          const SizedBox(height: 16),
          const Text(
            'Your account, your style.',
            style: TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to view your profile, settings, and support.',
            style: TextStyle(fontFamily: 'Arial', fontSize: 13, color: _muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                await Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
                if (mounted) _refresh();
              },
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
                padding: const EdgeInsets.all(15),
              ),
              child: const Text(
                'SIGN IN',
                style: TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateAccountScreen()),
              );
              if (mounted) _refresh();
            },
            child: const Text(
              'Create an account',
              style: TextStyle(color: _olive),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _editProfile(Map<String, dynamic> profile) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProfileDetailsScreen(profile: profile)),
    );
    if (saved == true && mounted) _refresh();
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) _refresh();
    } catch (error) {
      if (mounted) _message('Could not sign out: $error');
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontFamily: 'Arial',
      color: _muted,
      fontSize: 9,
      letterSpacing: 1.7,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
    leading: Icon(icon, color: _olive),
    title: Text(title, style: const TextStyle(fontSize: 16)),
    subtitle: Text(
      subtitle,
      style: const TextStyle(fontFamily: 'Arial', fontSize: 11, color: _muted),
    ),
    trailing: const Icon(Icons.chevron_right, color: _muted),
    onTap: onTap,
  );
}
