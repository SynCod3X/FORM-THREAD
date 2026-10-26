import 'package:flutter/material.dart';

import '../models/saved_items.dart';
import '../services/store_service.dart';
import '../utils/money.dart';
import '../widgets/product_detail_sheet.dart';
import 'shop_screen.dart';
import 'customer_dashboard.dart';

const _ink = Color(0xFF25231F);
const _muted = Color(0xFF827D73);
const _paper = Color(0xFFF8F6F1);
const _olive = Color(0xFF68715A);

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  void _navigate(int index) {
    if (index == 2) return;
    if (index == 0) {
      Navigator.pop(context);
    } else if (index == 1) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ShopScreen()));
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CustomerDashboard()));
    }
  }

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
        'SAVED PIECES',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.8,
        ),
      ),
      centerTitle: true,
    ),
    body: RefreshIndicator(
      onRefresh: SavedItems.refresh,
      child: ValueListenableBuilder<List<SavedItem>>(
        valueListenable: SavedItems.items,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return ListView(
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * .2),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_border,
                          size: 44,
                          color: _olive,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your saved pieces will live here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap the heart on anything you love and find it again here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Arial',
                            fontSize: 12,
                            color: _muted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: () => Navigator.of(context)
                              .pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const ShopScreen(),
                                ),
                              ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink,
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                          child: const Text(
                            'EXPLORE THE SHOP',
                            style: TextStyle(
                              fontFamily: 'Arial',
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  child: Text(
                    '${items.length} ${items.length == 1 ? 'piece' : 'pieces'} saved for later',
                    style: const TextStyle(
                      fontFamily: 'Arial',
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _SavedProductCard(item: items[index]),
                    childCount: items.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 18,
                    childAspectRatio: .64,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 2,
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
          selectedIcon: Icon(Icons.favorite),
          label: 'Saved',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Account',
        ),
      ],
    ),
  );
}

class _SavedProductCard extends StatefulWidget {
  const _SavedProductCard({required this.item});

  final SavedItem item;

  @override
  State<_SavedProductCard> createState() => _SavedProductCardState();
}

class _SavedProductCardState extends State<_SavedProductCard> {
  bool _isOpening = false;

  Future<void> _openProduct() async {
    if (_isOpening) return;
    _isOpening = true;
    try {
      final product = await StoreService.loadProduct(widget.item.productId);
      if (!mounted) return;
      if (product == null || !product.isActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This product is no longer available.')),
        );
        return;
      }
      await ProductDetailSheet.show(
        context,
        name: product.name,
        description: product.description,
        price: formatPeso(product.price),
        image: product.imageUrl,
        productId: product.id,
        availableQuantity: product.quantity,
        sizes: product.availableSizes,
        colors: product.availableColors,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open product: $error')),
        );
      }
    } finally {
      _isOpening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                InkWell(
                  onTap: _openProduct,
                  child: Image.network(
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
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: _paper,
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: () async {
                        try {
                          await SavedItems.remove(item);
                        } catch (error) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Could not update saved items: $error',
                                ),
                              ),
                            );
                        }
                      },
                      icon: const Icon(Icons.favorite, color: _olive, size: 18),
                      tooltip: 'Remove from saved',
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                      padding: EdgeInsets.zero,
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
        Text(
          item.price,
          style: const TextStyle(
            fontFamily: 'Arial',
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
