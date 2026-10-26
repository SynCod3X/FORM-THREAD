import 'package:flutter/material.dart';

import '../models/cart_items.dart';
import '../models/saved_items.dart';
import '../widgets/product_detail_sheet.dart';
import '../widgets/saved_button.dart';
import '../services/store_service.dart';
import '../utils/money.dart';
import 'cart_screen.dart';
import 'customer_dashboard.dart';
import 'saved_screen.dart';

const _ink = Color(0xFF25231F);
const _muted = Color(0xFF827D73);
const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);

class ShopScreen extends StatefulWidget {
  const ShopScreen({
    super.key,
    this.initialQuery = '',
    this.initialCategory = 'For you',
  });

  final String initialQuery;
  final String initialCategory;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _searchController = TextEditingController();
  final _categories = const [
    'For you',
    'Clothing',
    'Shoes',
    'Bags',
    'Accessories',
    'New in',
    'Sale',
  ];
  String _selectedCategory = 'For you';
  String _query = '';
  int _selectedNav = 1;
  List<_ShopItem> _managedItems = [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _searchController.text = _query;
    if (_categories.contains(widget.initialCategory)) {
      _selectedCategory = widget.initialCategory;
    }
    _loadManagedItems();
  }

  Future<void> _loadManagedItems() async {
    try {
      final products = await StoreService.loadProducts();
      if (!mounted) return;
      setState(() {
        _loadError = null;
        _managedItems = products
            .map(
              (product) => _ShopItem(
                name: product.name,
                detail: product.description,
                price: formatPeso(product.price),
                image: product.imageUrl,
                category: product.category,
                rating: '',
                productId: product.id,
                quantity: product.quantity,
                isNew: product.badge.toUpperCase() == 'NEW',
                badge:
                    product.compareAtPrice != null &&
                        product.compareAtPrice! > product.price
                    ? 'SALE'
                    : product.badge.isEmpty ||
                          product.badge.toUpperCase() == 'SALE'
                    ? null
                    : product.badge,
                oldPrice: product.compareAtPrice == null
                    ? null
                    : formatPeso(product.compareAtPrice!),
                isSale:
                    product.compareAtPrice != null &&
                    product.compareAtPrice! > product.price,
                sizes: product.availableSizes,
                colors: product.availableColors,
              ),
            )
            .toList();
      });
    } catch (_) {
      if (mounted)
        setState(
          () => _loadError = 'Could not load products. Pull down to retry.',
        );
    }
  }

  List<_ShopItem> get _visibleItems {
    return _managedItems.where((item) {
      final matchesCategory =
          _selectedCategory == 'For you' ||
          _selectedCategory == 'New in' && item.isNew ||
          _selectedCategory == 'Sale' && item.isSale ||
          item.category == _selectedCategory;
      final matchesQuery =
          _query.isEmpty ||
          item.name.toLowerCase().contains(_query.toLowerCase()) ||
          item.detail.toLowerCase().contains(_query.toLowerCase()) ||
          item.category.toLowerCase().contains(_query.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    appBar: AppBar(
      backgroundColor: _paper,
      titleSpacing: 20,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DISCOVER',
            style: TextStyle(
              fontSize: 16,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Find your next favorite.',
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: 10,
              color: _muted,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const CartScreen())),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_bag_outlined),
              if (CartItems.items.value.isNotEmpty)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: _olive,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${CartItems.items.value.length}',
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
          tooltip: 'Shopping bag',
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _loadManagedItems,
      child: CustomScrollView(
        slivers: [
          if (_loadError != null)
            SliverToBoxAdapter(child: Center(child: Text(_loadError!))),
          SliverToBoxAdapter(child: _searchBar()),
          SliverToBoxAdapter(child: _trendBanner()),
          SliverToBoxAdapter(child: _categoryPicker()),
          SliverToBoxAdapter(child: _resultsHeader()),
          if (_visibleItems.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No pieces found. Try another search.',
                  style: TextStyle(fontFamily: 'Arial', color: _muted),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _productCard(_visibleItems[index]),
                  childCount: _visibleItems.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 17,
                  childAspectRatio: .61,
                ),
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedNav,
      height: 64,
      backgroundColor: _paper,
      indicatorColor: const Color(0xFFE8E6DE),
      onDestinationSelected: _navigate,
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
        NavigationDestination(
          icon: Icon(Icons.favorite_border),
          label: 'Saved',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Account',
        ),
      ],
    ),
  );

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 5, 16, 12),
    child: TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value.trim()),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search clothes, styles, and more',
        hintStyle: const TextStyle(
          fontFamily: 'Arial',
          fontSize: 12,
          color: _muted,
        ),
        prefixIcon: const Icon(Icons.search, color: _muted, size: 20),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close, color: _muted, size: 19),
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
          borderSide: const BorderSide(color: _olive),
        ),
      ),
    ),
  );

  Widget _trendBanner() => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 15),
    height: 104,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(7),
      gradient: const LinearGradient(
        colors: [Color(0xFF68715A), Color(0xFF9B9C83)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'THE EVERYDAY EDIT',
                  style: TextStyle(
                    fontFamily: 'Arial',
                    color: Colors.white,
                    fontSize: 9,
                    letterSpacing: 1.7,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Good style,\nmade easy.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.checkroom_outlined,
            color: Color(0xFFECEADF),
            size: 57,
          ),
        ],
      ),
    ),
  );

  Widget _categoryPicker() => SizedBox(
    height: 48,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      scrollDirection: Axis.horizontal,
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final category = _categories[index];
        final selected = category == _selectedCategory;
        return ChoiceChip(
          label: Text(category),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _selectedCategory = category),
          labelStyle: TextStyle(
            fontFamily: 'Arial',
            fontSize: 11,
            color: selected ? Colors.white : _ink,
          ),
          selectedColor: _ink,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: selected ? _ink : const Color(0xFFD9D5CC)),
          shape: const StadiumBorder(),
        );
      },
    ),
  );

  Widget _resultsHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 13, 18, 0),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A FRESH TAKE ON YOUR FEED',
                style: TextStyle(
                  fontFamily: 'Arial',
                  color: _muted,
                  fontSize: 8,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _selectedCategory == 'For you'
                    ? 'Discover pieces'
                    : _selectedCategory,
                style: const TextStyle(fontSize: 23),
              ),
            ],
          ),
        ),
        Text(
          '${_visibleItems.length} pieces',
          style: const TextStyle(
            fontFamily: 'Arial',
            color: _muted,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );

  Widget _productCard(_ShopItem item) => InkWell(
    onTap: () => ProductDetailSheet.show(
      context,
      name: item.name,
      description: item.detail,
      price: item.price,
      image: item.image,
      productId: item.productId,
      availableQuantity: item.quantity,
      sizes: item.sizes,
      colors: item.colors,
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
                Image.network(
                  item.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE3E0D7),
                    child: const Center(
                      child: Icon(
                        Icons.checkroom_outlined,
                        color: _olive,
                        size: 40,
                      ),
                    ),
                  ),
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : Container(
                          color: const Color(0xFFE8E5DC),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: _olive,
                            ),
                          ),
                        ),
                ),
                if (item.badge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      color: _paper,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 5,
                      ),
                      child: Text(
                        item.badge!,
                        style: const TextStyle(
                          fontFamily: 'Arial',
                          fontSize: 8,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: SavedButton(
                    size: 30,
                    item: SavedItem(
                      productId: item.productId!,
                      name: item.name,
                      detail: item.detail,
                      price: item.price,
                      image: item.image,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: _roundAction(
                    Icons.add,
                    () => ProductDetailSheet.show(
                      context,
                      name: item.name,
                      description: item.detail,
                      price: item.price,
                      image: item.image,
                      productId: item.productId,
                      availableQuantity: item.quantity,
                      sizes: item.sizes,
                      colors: item.colors,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 3),
        Text(
          item.detail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Arial',
            fontSize: 9,
            color: _muted,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Text(
              item.price,
              style: const TextStyle(
                fontFamily: 'Arial',
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (item.oldPrice != null) ...[
              const SizedBox(width: 6),
              Text(
                item.oldPrice!,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 9,
                  color: _muted,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
            const Spacer(),
            if (item.rating.isNotEmpty) ...[
              const Icon(Icons.star, size: 12, color: Color(0xFFB28B4A)),
              Text(
                item.rating,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 9,
                  color: _muted,
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _roundAction(IconData icon, VoidCallback onTap) => Material(
    color: _paper.withValues(alpha: .94),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Icon(icon, size: 15, color: _ink),
      ),
    ),
  );

  void _navigate(int index) {
    setState(() => _selectedNav = index);
    if (index == 0) {
      Navigator.pop(context);
    } else if (index == 2) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const SavedScreen()));
    } else if (index == 3) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CustomerDashboard()));
    }
  }
}

class _ShopItem {
  const _ShopItem({
    required this.name,
    required this.detail,
    required this.price,
    required this.image,
    required this.category,
    required this.rating,
    this.badge,
    this.oldPrice,
    this.isSale = false,
    this.isNew = false,
    this.productId,
    this.quantity,
    this.sizes = const ['XS', 'S', 'M', 'L', 'XL'],
    this.colors = const ['Natural', 'Black', 'Olive'],
  });

  final String name;
  final String detail;
  final String price;
  final String image;
  final String category;
  final String rating;
  final String? badge;
  final String? oldPrice;
  final bool isSale;
  final bool isNew;
  final String? productId;
  final int? quantity;
  final List<String> sizes;
  final List<String> colors;
}
