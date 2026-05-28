import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/mock_data_service.dart';
import '../../utils/catalog_image_resolver.dart';
import '../../widgets/widgets.dart';
import 'package:intl/intl.dart';

// ── Distributor Home ──────────────────────────────────────────
class DistributorHome extends StatefulWidget {
  final User user;
  const DistributorHome({super.key, required this.user});

  @override
  State<DistributorHome> createState() => _DistributorHomeState();
}

class _DistributorHomeState extends State<DistributorHome> {
  int _tab = 0;
  List<Order> _orders = [];
  bool _loadingNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadOrdersForNotifications();
  }

  Future<void> _loadOrdersForNotifications() async {
    final orders = await ApiService.getOrders(distributorId: widget.user.id);
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loadingNotifications = false;
    });
  }

  List<Order> get _approvedOrders =>
      _orders.where((o) => o.status == OrderStatus.approved).toList();

  Future<void> _showNotifications() async {
    await _loadOrdersForNotifications();
    if (!mounted) return;
    showNotificationSheet(
      context,
      title: 'Notifications',
      notifications: _approvedOrders
          .map(
            (order) => AppNotification(
              icon: Icons.check_circle_outline,
              title: 'Order approved ${order.id}',
              subtitle:
                  '${order.totalPieces} pcs approved and ready for dispatch',
              color: AppTheme.successGreen,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailScreen(order: order),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Swami Polytech'),
            Text(
              widget.user.name,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          NotificationButton(
            count: _loadingNotifications ? 0 : _approvedOrders.length,
            onTap: _showNotifications,
          ),
          const AppLogoutButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _CatalogTab(user: widget.user),
          _MyOrdersTab(user: widget.user, key: ValueKey(_tab)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          _loadOrdersForNotifications();
        },
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.chipBg,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.store_outlined),
            selectedIcon: Icon(Icons.store, color: AppTheme.primaryBlue),
            label: 'Catalog',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_outlined),
            selectedIcon: Icon(Icons.receipt, color: AppTheme.primaryBlue),
            label: 'My Orders',
          ),
        ],
      ),
    );
  }
}

// ── Catalog Tab — MockDataService se (images ke saath) ────────
class _CatalogTab extends StatefulWidget {
  final User user;
  const _CatalogTab({required this.user});

  @override
  State<_CatalogTab> createState() => _CatalogTabState();
}

class _CatalogTabState extends State<_CatalogTab> {
  String? _selectedCategory;
  final _searchCtrl = TextEditingController();
  final _svc = MockDataService(); // images ke liye mock fallback
  List<Product> _products = [];
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final backendProducts = await ApiService.getProducts();
    final products = backendProducts.isEmpty
        ? _svc.getProducts()
        : backendProducts.map(_withCatalogImage).toList();

    if (mounted) {
      setState(() {
        _products = products;
        _loading = false;
      });
    }
  }

  Product _withCatalogImage(Product product) {
    final imageUrl = _catalogImageFor(product);
    if (imageUrl.isEmpty) return product;

    return Product(
      id: product.id,
      name: product.name,
      category: product.category,
      brand: product.brand,
      colors: product.colors,
      brandOptions: product.brandOptions,
      imageUrl: imageUrl,
      isActive: product.isActive,
    );
  }

  String _catalogImageFor(Product product) {
    final mappedImage = CatalogImageResolver.forProduct(product);
    if (mappedImage != null) return mappedImage;

    final variants = _svc.getProducts();

    for (final variant in variants) {
      if (_norm(variant.name) == _norm(product.name)) {
        return variant.imageUrl;
      }
    }

    for (final variant in variants) {
      final variantColor = variant.colors.isEmpty ? '' : variant.colors.first;
      final colorMatches = product.colors.any(
        (color) => _norm(color) == _norm(variantColor),
      );
      if (_norm(_baseName(variant.name)) == _norm(product.name) &&
          colorMatches) {
        return variant.imageUrl;
      }
    }

    return '';
  }

  String _baseName(String value) {
    return value.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  }

  String _norm(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  bool _productMatchesSearch(Product product, String query) {
    final normalizedQuery = _norm(query);
    if (normalizedQuery.isEmpty) return true;

    final searchableValues = <String>[
      product.name,
      product.category,
      product.brand,
      ...product.colors,
      ...product.brandOptions.keys,
      ...product.brandOptions.values.expand((colors) => colors),
    ];

    return searchableValues.any(
      (value) => _norm(value).contains(normalizedQuery),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final categories = _products.map((p) => p.category).toSet().toList();
    final products = _products.where((p) {
      if (_selectedCategory != null && p.category != _selectedCategory) {
        return false;
      }
      if (!p.isActive) return false;
      if (_searchQuery.isEmpty) return true;
      return _productMatchesSearch(p, _searchQuery);
    }).toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search products',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                  ),
                  onChanged: (value) =>
                      setState(() => _searchQuery = value.trim()),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryChip(
                        label: 'All',
                        selected: _selectedCategory == null,
                        onTap: () => setState(() => _selectedCategory = null),
                      ),
                      ...categories.map(
                        (c) => _CategoryChip(
                          label: c,
                          selected: _selectedCategory == c,
                          onTap: () => setState(() => _selectedCategory = c),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (products.isEmpty) {
                return const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No Products',
                  subtitle: 'No products in this category',
                );
              }

              final compactGrid = constraints.maxWidth < 700;
              if (compactGrid) {
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 260,
                  ),
                  itemCount: products.length,
                  itemBuilder: (_, i) => _ProductCard(
                    product: products[i],
                    user: widget.user,
                    compact: true,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                itemBuilder: (_, i) =>
                    _ProductCard(product: products[i], user: widget.user),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryBlue : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryBlue : AppTheme.borderGrey,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Product product;
  final User user;
  final bool compact;
  const _ProductCard({
    required this.product,
    required this.user,
    this.compact = false,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard> {
  @override
  Widget build(BuildContext context) {
    return widget.compact ? _buildCompactCard() : _buildListCard();
  }

  void _openDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductDetailScreen(product: widget.product, user: widget.user),
      ),
    );
  }

  Map<String, List<String>> get _brandOptions {
    if (widget.product.brandOptions.isNotEmpty) {
      return widget.product.brandOptions;
    }
    return {widget.product.brand: widget.product.colors};
  }

  int get _totalColorCount =>
      _brandOptions.values.fold(0, (sum, colors) => sum + colors.length);

  Widget _buildListCard() {
    return InkWell(
      onTap: _openDetails,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderGrey),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _productImage(width: 104, height: 104, cover: true),
            const SizedBox(width: 14),
            Expanded(child: _productHeader()),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard() {
    return InkWell(
      onTap: _openDetails,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderGrey),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              width: double.infinity,
              child: _productImage(width: double.infinity, height: 150),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: _productHeader(compact: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productImage({
    required double width,
    required double height,
    bool cover = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.compact ? 0 : 10),
      child: Container(
        width: width,
        height: height,
        padding: cover ? EdgeInsets.zero : const EdgeInsets.all(8),
        color: Colors.white,
        child: widget.product.imageUrl.isNotEmpty
            ? Image.asset(
                widget.product.imageUrl,
                fit: cover ? BoxFit.cover : BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  _iconForCategory(widget.product.category),
                  size: 34,
                  color: AppTheme.primaryBlue.withValues(alpha: 0.6),
                ),
              )
            : Icon(
                _iconForCategory(widget.product.category),
                size: 34,
                color: AppTheme.primaryBlue.withValues(alpha: 0.6),
              ),
      ),
    );
  }

  Widget _productHeader({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.product.name,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.product.category,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _infoChip('${_brandOptions.length} brands', compact: compact),
            _infoChip(
              '$_totalColorCount color${_totalColorCount == 1 ? '' : 's'}',
              compact: compact,
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoChip(String label, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.chipBg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'Baby Products':
        return Icons.child_care_rounded;
      case 'Stools':
        return Icons.event_seat;
      case 'Center Tables':
        return Icons.table_bar;
      case 'Dining Tables':
        return Icons.dining;
      default:
        return Icons.chair;
    }
  }
}

// ── Product Detail / Order Screen ──────────────────────────────
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final User user;
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.user,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _selectedBrand;
  final Set<String> _selectedColors = {};
  final Map<String, TextEditingController> _qtyCtrls = {};
  final _remarksCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedBrand = _brandOptions.keys.first;
    _syncQuantityControllers();
  }

  Map<String, List<String>> get _brandOptions {
    if (widget.product.brandOptions.isNotEmpty) {
      return widget.product.brandOptions;
    }

    return {widget.product.brand: widget.product.colors};
  }

  List<String> get _availableColors {
    if (_selectedBrand == null) return const [];
    return _brandOptions[_selectedBrand] ?? const [];
  }

  @override
  void dispose() {
    for (final controller in _qtyCtrls.values) {
      controller.dispose();
    }
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _syncQuantityControllers() {
    final activeColors = _availableColors.toSet();
    for (final color in activeColors) {
      _qtyCtrls.putIfAbsent(color, () => TextEditingController());
    }

    final staleColors = _qtyCtrls.keys
        .where((color) => !activeColors.contains(color))
        .toList();
    for (final color in staleColors) {
      _qtyCtrls.remove(color)?.dispose();
      _selectedColors.remove(color);
    }
  }

  int _qtyForColor(String color) {
    return int.tryParse(_qtyCtrls[color]?.text.trim() ?? '') ?? 0;
  }

  int get _totalSelectedQty =>
      _selectedColors.fold(0, (sum, color) => sum + _qtyForColor(color));

  List<OrderItem> _selectedOrderItems() {
    final items = <OrderItem>[];
    for (final color in _availableColors) {
      if (!_selectedColors.contains(color)) continue;
      final qty = _qtyForColor(color);
      if (qty <= 0) continue;
      items.add(
        OrderItem(
          productId: widget.product.id,
          productName: widget.product.name,
          brand: _selectedBrand!,
          color: color,
          quantity: qty,
          stockAvailable: false,
        ),
      );
    }
    return items;
  }

  Future<void> _placeOrder() async {
    final items = _selectedOrderItems();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one color and enter quantity'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final user = widget.user;
    final orderId =
        'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final order = Order(
      id: orderId,
      distributorId: user.id,
      distributorName: user.name,
      distributorCity: 'Maharashtra',
      orderDate: DateTime.now(),
      status: OrderStatus.pending,
      items: items,
      remarks: _remarksCtrl.text.isEmpty ? null : _remarksCtrl.text,
    );

    final success = await ApiService.createOrder(order); // ✅ DB mein jaata hai

    setState(() => _saving = false);

    if (!mounted) return;

    if (success) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.lightGreen,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppTheme.successGreen,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Order Placed!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Order $orderId placed successfully',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order place karne mein error aaya. Try again.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Scaffold(
      appBar: AppBar(title: Text(p.name), actions: const [AppLogoutButton()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryNavy, AppTheme.primaryBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 84,
                      height: 84,
                      color: Colors.white.withValues(alpha: 0.12),
                      child: p.imageUrl.isNotEmpty
                          ? Image.asset(
                              p.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    _iconFor(p.category),
                                    color: Colors.white,
                                    size: 48,
                                  ),
                            )
                          : Icon(
                              _iconFor(p.category),
                              color: Colors.white,
                              size: 48,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          p.category,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _brandChipSelector(),
            const SizedBox(height: 16),

            _detailColorQuantitySelector(),
            const SizedBox(height: 16),

            FormFieldWrapper(
              label: 'Remarks (optional)',
              child: TextFormField(
                controller: _remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Any special instructions...',
                ),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _placeOrder,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.shopping_cart_checkout),
                label: const Text(
                  'Place Order',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String cat) {
    switch (cat) {
      case 'Baby Products':
        return Icons.child_care_rounded;
      case 'Stools':
        return Icons.event_seat;
      case 'Center Tables':
        return Icons.table_bar;
      case 'Dining Tables':
        return Icons.dining;
      default:
        return Icons.chair;
    }
  }

  Widget _brandChipSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Brand',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _brandOptions.keys.map((brand) {
            final selected = _selectedBrand == brand;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedBrand = brand;
                _selectedColors.clear();
                _syncQuantityControllers();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryBlue : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primaryBlue
                        : AppTheme.borderGrey,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  brand,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _detailColorQuantitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Colors & Quantity',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        ..._availableColors.map(_detailColorQuantityRow),
        const SizedBox(height: 4),
        Text(
          _totalSelectedQty > 0
              ? '${_selectedColors.length} color${_selectedColors.length == 1 ? '' : 's'} • $_totalSelectedQty pcs'
              : 'Select colors and enter quantity',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _totalSelectedQty > 0
                ? AppTheme.successGreen
                : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _detailColorQuantityRow(String color) {
    final selected = _selectedColors.contains(color);
    final controller = _qtyCtrls[color] ??= TextEditingController();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppTheme.chipBg : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppTheme.primaryBlue : AppTheme.borderGrey,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            visualDensity: VisualDensity.compact,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedColors.add(color);
                } else {
                  _selectedColors.remove(color);
                }
              });
            },
          ),
          _detailColorDot(color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              color,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: TextFormField(
              controller: controller,
              enabled: selected,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Qty',
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              onChanged: (value) {
                final qty = int.tryParse(value) ?? 0;
                setState(() {
                  if (qty > 0) {
                    _selectedColors.add(color);
                  } else {
                    _selectedColors.remove(color);
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailColorDot(String colorName) {
    final colorMap = {
      'BLACK': const Color(0xFF1A1A1A),
      'BEIGE': const Color(0xFFF5E6C8),
      'BISCUIT': const Color(0xFFD6B58A),
      'BLUE': const Color(0xFF2563EB),
      'BROWN': const Color(0xFF92400E),
      'COFFEE': const Color(0xFF6F4E37),
      'COPPER': const Color(0xFFB87333),
      'GREEN': const Color(0xFF16A34A),
      'GREY': const Color(0xFF9CA3AF),
      'LB': const Color(0xFF60A5FA),
      'METALIC': const Color(0xFF94A3B8),
      'ORANGE': const Color(0xFFF97316),
      'ORANGEWOOD': const Color(0xFFC26A2E),
      'PINK': const Color(0xFFEC4899),
      'RED': const Color(0xFFDC2626),
      'ROSEWOOD': const Color(0xFF7F1D1D),
      'SANDALWOOD': const Color(0xFFE7C79B),
      'SILVER': const Color(0xFFC0C0C0),
      'WHITE': const Color(0xFFF8FAFC),
      'YELLOW': const Color(0xFFD97706),
    };
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: colorMap[colorName.toUpperCase()] ?? AppTheme.textSecondary,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.borderGrey, width: 0.5),
      ),
    );
  }
}

// ── My Orders Tab — ApiService se (DB) ───────────────────────
class _MyOrdersTab extends StatefulWidget {
  final User user;
  const _MyOrdersTab({super.key, required this.user});

  @override
  State<_MyOrdersTab> createState() => _MyOrdersTabState();
}

class _MyOrdersTabState extends State<_MyOrdersTab> {
  List<Order> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final orders = await ApiService.getOrders(distributorId: widget.user.id);
    if (mounted) {
      setState(() {
        _orders = orders;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: _orders.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Orders Yet',
              subtitle: 'Your orders will appear here',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length,
              itemBuilder: (_, i) => OrderCard(
                order: _orders[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(order: _orders[i]),
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Order Detail Screen ───────────────────────────────────────
class OrderDetailScreen extends StatelessWidget {
  final Order order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final statusLabel =
        order.status.name.substring(0, 1).toUpperCase() +
        order.status.name.substring(1);

    return Scaffold(
      appBar: AppBar(title: Text(order.id), actions: const [AppLogoutButton()]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: getStatusBg(statusLabel),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: getStatusColor(statusLabel).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusIcon(order.status),
                    color: getStatusColor(statusLabel),
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: getStatusColor(statusLabel),
                        ),
                      ),
                      Text(
                        fmt.format(order.orderDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderGrey),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Text(
                      'Order Items',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.borderGrey),
                  ...order.items.map((item) => _OrderItemRow(item: item)),
                ],
              ),
            ),

            if (order.remarks != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remarks',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.remarks!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return Icons.hourglass_empty_rounded;
      case OrderStatus.approved:
        return Icons.thumb_up_rounded;
      case OrderStatus.partial:
        return Icons.hourglass_top_rounded;
      case OrderStatus.dispatched:
        return Icons.local_shipping_rounded;
    }
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItem item;
  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${item.brand} • ${item.color}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantity} pcs',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (item.dispatchedQty > 0)
                Text(
                  '${item.dispatchedQty} dispatched',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.successGreen,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
