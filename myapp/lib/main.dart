import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/cart_items.dart';
import 'screens/cart_screen.dart';
import 'models/saved_items.dart';
import 'screens/customer_dashboard.dart';
import 'screens/checkout_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/shop_screen.dart';
import 'widgets/saved_button.dart';
import 'widgets/product_detail_sheet.dart';
import 'supabase_config.dart';
import 'services/store_service.dart';
import 'utils/money.dart';
import 'utils/payment_return_link.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    SavedItems.initialize();
    CartItems.initialize();
  }
  runApp(const ThreadApp());
}

const ink = Color(0xFF25231F);
const muted = Color(0xFF827D73);
const paper = Color(0xFFF8F6F1);
const olive = Color(0xFF68715A);

class ThreadApp extends StatefulWidget {
  const ThreadApp({super.key});

  @override
  State<ThreadApp> createState() => _ThreadAppState();
}

class _ThreadAppState extends State<ThreadApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _paymentLinkSubscription;
  String? _lastPaymentLink;
  DateTime? _lastPaymentLinkAt;

  @override
  void initState() {
    super.initState();
    _paymentLinkSubscription = AppLinks().uriLinkStream.listen(
      _handlePaymentLink,
      onError: (_) {},
    );
  }

  void _handlePaymentLink(Uri uri) {
    final orderId = PaymentReturnLink.orderId(uri);
    if (orderId == null) return;
    final now = DateTime.now();
    if (_lastPaymentLink == orderId &&
        _lastPaymentLinkAt != null &&
        now.difference(_lastPaymentLinkAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastPaymentLink = orderId;
    _lastPaymentLinkAt = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => OrderConfirmationScreen(
            orderId: orderId,
            paymentMethod: 'gcash',
            autoCheckPayment: true,
          ),
        ),
        (route) => route.isFirst,
      );
    });
  }

  @override
  void dispose() {
    _paymentLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    debugShowCheckedModeBanner: false,
    title: 'FORM & THREAD',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: olive),
      fontFamily: 'Georgia',
    ),
    home: const Storefront(),
  );
}

class Storefront extends StatefulWidget {
  const Storefront({super.key});

  @override
  State<Storefront> createState() => _StorefrontState();
}

class _StorefrontState extends State<Storefront> {
  int selectedNav = 0;
  final _searchController = TextEditingController();
  List<StoreProduct> _featuredProducts = [];
  String? _productError;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openShop({String category = 'For you'}) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShopScreen(
          initialQuery: _searchController.text.trim(),
          initialCategory: category,
        ),
      ),
    );
  }

  Future<void> _showFilters() async {
    const categories = [
      'For you',
      'Clothing',
      'Shoes',
      'Bags',
      'Accessories',
      'New in',
      'Sale',
    ];
    var selected = 'For you';
    final category = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: paper,
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FILTER PRODUCTS',
                  style: TextStyle(fontSize: 17, letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a category to browse.',
                  style: TextStyle(fontFamily: 'Arial', color: muted),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in categories)
                      ChoiceChip(
                        label: Text(option),
                        selected: selected == option,
                        onSelected: (_) =>
                            setSheetState(() => selected = option),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, selected),
                    child: const Text('SHOW PRODUCTS'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted && category != null) _openShop(category: category);
  }

  Future<void> _loadProducts() async {
    try {
      final products = await StoreService.loadProducts();
      if (mounted) {
        setState(() {
          _featuredProducts = products.take(4).toList();
          _productError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _productError = 'Could not load products.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _topBar()),
            SliverToBoxAdapter(child: _searchBar()),
            SliverToBoxAdapter(child: _serviceHighlights()),
            SliverToBoxAdapter(child: _hero()),
            SliverToBoxAdapter(child: _quickCategories()),
            SliverToBoxAdapter(child: _sectionHeading()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _productCard(_featuredProducts[index]),
                  childCount: _featuredProducts.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 22,
                  childAspectRatio: .66,
                ),
              ),
            ),
            if (_productError != null)
              SliverToBoxAdapter(
                child: Center(
                  child: TextButton(
                    onPressed: _loadProducts,
                    child: Text('$_productError Tap to retry.'),
                  ),
                ),
              ),
            SliverToBoxAdapter(child: _newsletter()),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
      bottomNavigationBar: _bottomNav(),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
    child: Row(
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'FORM & THREAD',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.1,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'YOUR EVERYDAY STYLE, DELIVERED',
              style: TextStyle(
                fontFamily: 'Arial',
                fontSize: 8,
                letterSpacing: 1.2,
                color: muted,
              ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const CartScreen())),
          icon: ValueListenableBuilder<List<CartLine>>(
            valueListenable: CartItems.items,
            builder: (context, lines, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 23),
                if (lines.isNotEmpty)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: olive,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${lines.fold<int>(0, (count, line) => count + line.quantity)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontFamily: 'Arial',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          tooltip: 'Shopping bag',
        ),
      ],
    ),
  );

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _openShop(),
      decoration: InputDecoration(
        hintText: 'Search clothes, styles, and more',
        hintStyle: const TextStyle(
          fontFamily: 'Arial',
          fontSize: 12,
          color: muted,
        ),
        prefixIcon: const Icon(Icons.search, color: muted, size: 20),
        suffixIcon: IconButton(
          onPressed: _showFilters,
          icon: const Icon(Icons.tune, color: olive, size: 19),
          tooltip: 'Filters',
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFE2DED5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: olive),
        ),
      ),
    ),
  );

  Widget _serviceHighlights() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 2, 20, 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        _ServiceHighlight(
          icon: Icons.local_shipping_outlined,
          text: 'Free delivery',
        ),
        _ServiceHighlight(icon: Icons.autorenew, text: 'Easy returns'),
        _ServiceHighlight(
          icon: Icons.verified_outlined,
          text: 'Quality pieces',
        ),
      ],
    ),
  );

  Widget _hero() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 265,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _FashionImage(
              url: 'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?auto=format&fit=crop&w=1200&q=85',
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: .48),
                    Colors.transparent,
                  ],
                  stops: const [0, .82],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 27, 24, 27),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'THE NEW SEASON',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      letterSpacing: 2.2,
                      fontFamily: 'Arial',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Wear what\nmoves you.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      height: 1.05,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 13),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: paper,
                      foregroundColor: ink,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 11,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () =>
                        _notice('New season collection coming soon.'),
                    child: const Text(
                      'EXPLORE THE EDIT',
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Positioned(
              top: 20,
              right: 20,
              child: Text(
                '01 / 03',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _quickCategories() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SHOP BY CATEGORY',
          style: TextStyle(
            fontFamily: 'Arial',
            color: muted,
            fontSize: 9,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            _CategoryTile(
              icon: Icons.checkroom_outlined,
              title: 'Clothing',
              onTap: () => _openShop(category: 'Clothing'),
            ),
            const SizedBox(width: 10),
            _CategoryTile(
              icon: Icons.fiber_new_outlined,
              title: 'New in',
              onTap: () => _openShop(category: 'New in'),
            ),
            const SizedBox(width: 10),
            _CategoryTile(
              icon: Icons.shopping_bag_outlined,
              title: 'Accessories',
              onTap: () => _openShop(category: 'Accessories'),
            ),
            const SizedBox(width: 10),
            _CategoryTile(
              icon: Icons.sell_outlined,
              title: 'Sale',
              onTap: () => _openShop(category: 'Sale'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _sectionHeading() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 9, 20, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'HANDPICKED FOR YOU',
                style: TextStyle(
                  fontFamily: 'Arial',
                  color: muted,
                  fontSize: 9,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Popular right now',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => _notice('You’re viewing all new arrivals.'),
          child: const Text(
            'VIEW ALL  →',
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: 9,
              letterSpacing: 1,
              color: ink,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _productCard(StoreProduct product) => InkWell(
    onTap: () => ProductDetailSheet.show(
      context,
      name: product.name,
      description: product.description,
      price: formatPeso(product.price),
      image: product.imageUrl,
      productId: product.id,
      availableQuantity: product.quantity,
      sizes: product.availableSizes,
      colors: product.availableColors,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _FashionImage(url: product.imageUrl),
                if (product.badge.isNotEmpty)
                  Positioned(
                    top: 10,
                    left: 9,
                    child: Container(
                      color: paper,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: Text(
                        product.badge,
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 8,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 9,
                  top: 9,
                  child: SavedButton(
                    item: SavedItem(
                      productId: product.id,
                      name: product.name,
                      detail: product.description,
                      price: formatPeso(product.price),
                      image: product.imageUrl,
                    ),
                  ),
                ),
                Positioned(
                  right: 9,
                  bottom: 9,
                  child: _CircleAction(
                    icon: Icons.add,
                    onTap: () => ProductDetailSheet.show(
                      context,
                      name: product.name,
                      description: product.description,
                      price: formatPeso(product.price),
                      image: product.imageUrl,
                      productId: product.id,
                      availableQuantity: product.quantity,
                      sizes: product.availableSizes,
                      colors: product.availableColors,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          product.description,
          style: const TextStyle(
            fontFamily: 'Arial',
            fontSize: 10,
            color: muted,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          formatPeso(product.price),
          style: const TextStyle(
            fontFamily: 'Arial',
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  Widget _newsletter() => Container(
    margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
    color: const Color(0xFFEAE8DF),
    child: Column(
      children: [
        const Text(
          'A LITTLE NOTE FROM US',
          style: TextStyle(
            fontFamily: 'Arial',
            color: muted,
            fontSize: 9,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Good things, in your inbox.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22),
        ),
        const SizedBox(height: 8),
        const Text(
          'New arrivals, thoughtful stories, and 10% off your first order.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Arial', color: muted, fontSize: 11),
        ),
        const SizedBox(height: 15),
        OutlinedButton(
          onPressed: () =>
              _notice('Thanks for your interest! Sign-up is coming soon.'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            side: const BorderSide(color: ink),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: const Text(
            'JOIN THE LIST',
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _bottomNav() => NavigationBar(
    selectedIndex: selectedNav,
    onDestinationSelected: (index) {
      setState(() => selectedNav = index);
      if (index == 3) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CustomerDashboard()));
      } else if (index == 2) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SavedScreen()));
      } else if (index == 1) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ShopScreen()));
      }
    },
    height: 64,
    backgroundColor: paper,
    indicatorColor: const Color(0xFFE8E6DE),
    destinations: const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        label: 'Shop',
      ),
      NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Saved'),
      NavigationDestination(icon: Icon(Icons.person_outline), label: 'Account'),
    ],
  );

  void _notice(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: const TextStyle(fontFamily: 'Arial')),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

class _ServiceHighlight extends StatelessWidget {
  const _ServiceHighlight({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: olive),
      const SizedBox(width: 5),
      Text(
        text,
        style: const TextStyle(fontFamily: 'Arial', color: muted, fontSize: 9),
      ),
    ],
  );
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFEAE8DF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Icon(icon, color: olive, size: 21),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Arial',
                color: ink,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: paper.withValues(alpha: .94),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(icon, size: 16, color: ink),
      ),
    ),
  );
}

class _FashionImage extends StatelessWidget {
  const _FashionImage({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stack) => Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD8D2C6), Color(0xFF9A9789)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.checkroom_outlined,
          size: 48,
          color: Color(0xFFF2F0E9),
        ),
      ),
    ),
    loadingBuilder: (context, child, progress) => progress == null
        ? child
        : Container(
            color: const Color(0xFFE8E5DC),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: olive,
                ),
              ),
            ),
          ),
  );
}
