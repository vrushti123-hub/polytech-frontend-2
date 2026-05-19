import 'dart:convert';

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../utils/catalog_image_resolver.dart';
import '../../widgets/widgets.dart';
import '../dispatch/dispatch_home.dart';
import '../production/production_home.dart';
import '../rawmaterial/rm_home.dart';
import 'package:intl/intl.dart';

// ── Owner Dashboard ───────────────────────────────────────────
class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _tab = 0;
  int _refreshKey = 0;
  List<Order> _orders = [];
  List<InventoryItem> _inventory = [];
  List<RawMaterial> _rawMaterials = [];
  List<ProductionEntry> _entries = [];
  List<User> _distributors = [];
  List<Challan> _challans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.getOrders(),
      ApiService.getInventory(),
      ApiService.getRawMaterials(),
      ApiService.getProductionEntries(),
      ApiService.getDistributors(),
      ApiService.getChallans(),
    ]);
    if (mounted) {
      setState(() {
        _orders = results[0] as List<Order>;
        _inventory = results[1] as List<InventoryItem>;
        _rawMaterials = results[2] as List<RawMaterial>;
        _entries = results[3] as List<ProductionEntry>;
        _distributors = results[4] as List<User>;
        _challans = results[5] as List<Challan>;
        _loading = false;
        _refreshKey++;
      });
    }
  }

  List<RawMaterial> get _lowStock => _rawMaterials
      .where((m) => m.stockStatus != StockStatus.available)
      .toList();

  int get _pendingOrdersCount =>
      _orders.where((o) => o.status == OrderStatus.pending).length;

  List<Order> get _pendingOrders =>
      _orders.where((o) => o.status == OrderStatus.pending).toList();

  List<Challan> _challansForOrder(String orderId) =>
      _challans.where((challan) => challan.orderId == orderId).toList();

  void _showNotifications() {
    showNotificationSheet(
      context,
      title: 'Notifications',
      notifications: _pendingOrders
          .map(
            (order) => AppNotification(
              icon: Icons.receipt_long_outlined,
              title: 'Pending order ${order.id}',
              subtitle:
                  '${order.distributorName} • ${order.totalPieces} pcs waiting for approval',
              color: AppTheme.warningAmber,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _OwnerOrderDetail(
                    order: order,
                    challans: _challansForOrder(order.id),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  DashboardStats get _stats {
    final today = _entries.where((e) => e.date.day == DateTime.now().day);
    return DashboardStats(
      pendingOrders: _pendingOrdersCount,
      dispatchedToday: _orders
          .where((o) => o.status == OrderStatus.dispatched)
          .length,
      todayProduction: today.fold(0, (s, e) => s + e.netQty),
      activeMachines: today.map((e) => e.machineNumber).toSet().length,
      lowStockAlerts: _lowStock.length,
      totalDistributors: _distributors.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operations Dashboard'),
            Text(
              'Sagar Mandhan — Owner',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          if (!_loading)
            NotificationButton(
              count: _pendingOrdersCount,
              onTap: _showNotifications,
            ),
          const AppLogoutButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _tab,
              children: [
                _OverviewTab(
                  key: ValueKey(_refreshKey),
                  stats: _stats,
                  lowStock: _lowStock,
                  inventory: _inventory,
                  entries: _entries,
                  onRefresh: _loadAll,
                  onPendingOrdersTap: () => setState(() => _tab = 1),
                  onDispatchedTap: () => setState(() => _tab = 1),
                  onProductionTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProductionHome()),
                  ).then((_) => _loadAll()),
                  onMachinesTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProductionHome()),
                  ).then((_) => _loadAll()),
                ),
                _OrdersTab(
                  key: ValueKey(_refreshKey + 100),
                  orders: _orders,
                  challans: _challans,
                ),
                _InventoryTab(
                  key: ValueKey(_refreshKey + 200),
                  inventory: _inventory,
                  rawMaterials: _rawMaterials,
                  challans: _challans,
                  entries: _entries,
                  onRefresh: _loadAll,
                ),
                _DistributorsTab(
                  key: ValueKey(_refreshKey + 300),
                  distributors: _distributors,
                  orders: _orders,
                  challans: _challans,
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          _loadAll();
        },
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.chipBg,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryBlue),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppTheme.primaryBlue),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppTheme.primaryBlue),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_2_outlined),
            selectedIcon: Icon(Icons.groups_2, color: AppTheme.primaryBlue),
            label: 'Distributors',
          ),
        ],
      ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final DashboardStats stats;
  final List<RawMaterial> lowStock;
  final List<InventoryItem> inventory;
  final List<ProductionEntry> entries;
  final VoidCallback onRefresh;
  final VoidCallback onPendingOrdersTap;
  final VoidCallback onDispatchedTap;
  final VoidCallback onProductionTap;
  final VoidCallback onMachinesTap;

  const _OverviewTab({
    super.key,
    required this.stats,
    required this.lowStock,
    required this.inventory,
    required this.entries,
    required this.onRefresh,
    required this.onPendingOrdersTap,
    required this.onDispatchedTap,
    required this.onProductionTap,
    required this.onMachinesTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEEE, dd MMMM');
    final todayEntries = entries
        .where((e) => e.date.day == DateTime.now().day)
        .toList();

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryNavy, Color(0xFF1E4FC2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmt.format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'Live Operational Overview',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: AppTheme.successGreen,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Live',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const SectionHeader(title: 'Key Metrics'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                StatCard(
                  title: 'Pending Orders',
                  value: '${stats.pendingOrders}',
                  icon: Icons.pending_actions_rounded,
                  color: AppTheme.warningAmber,
                  bgColor: AppTheme.lightAmber,
                  onTap: onPendingOrdersTap,
                ),
                StatCard(
                  title: 'Dispatched Today',
                  value: '${stats.dispatchedToday}',
                  icon: Icons.local_shipping_rounded,
                  color: AppTheme.successGreen,
                  bgColor: AppTheme.lightGreen,
                  onTap: onDispatchedTap,
                ),
                StatCard(
                  title: "Today's Output",
                  value: '${stats.todayProduction}',
                  icon: Icons.precision_manufacturing,
                  color: AppTheme.primaryBlue,
                  bgColor: AppTheme.chipBg,
                  onTap: onProductionTap,
                ),
                StatCard(
                  title: 'Active Machines',
                  value: '${stats.activeMachines}',
                  icon: Icons.settings_rounded,
                  color: const Color(0xFF7C3AED),
                  bgColor: const Color(0xFFF3E8FF),
                  onTap: onMachinesTap,
                ),
              ],
            ),
            const SizedBox(height: 20),

            const SectionHeader(title: 'Quick Access'),
            const SizedBox(height: 12),
            Row(
              children: [
                _QuickAction(
                  icon: Icons.local_shipping_outlined,
                  label: 'Dispatch',
                  color: AppTheme.primaryBlue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DispatchHome()),
                  ).then((_) => onRefresh()),
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  icon: Icons.factory_outlined,
                  label: 'Production',
                  color: AppTheme.successGreen,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProductionHome()),
                  ).then((_) => onRefresh()),
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  icon: Icons.inventory_outlined,
                  label: 'Raw Material',
                  color: AppTheme.warningAmber,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RMHome()),
                  ).then((_) => onRefresh()),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (lowStock.isNotEmpty) ...[
              SectionHeader(
                title: 'Stock Alerts',
                subtitle: '${lowStock.length} materials need attention',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${lowStock.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...lowStock.take(5).map((m) => RawMaterialRow(material: m)),
              if (lowStock.length > 5)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RMHome()),
                  ).then((_) => onRefresh()),
                  child: Text('View all ${lowStock.length} alerts →'),
                ),
              const SizedBox(height: 12),
            ],

            const SectionHeader(title: 'Finished Goods Stock'),
            const SizedBox(height: 12),
            ...inventory.take(5).map((item) {
              final isLow = item.currentStock == 0;
              final imagePath = CatalogImageResolver.forInventoryItem(item);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLow ? AppTheme.lightRed : AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isLow
                        ? AppTheme.dangerRed.withOpacity(0.3)
                        : AppTheme.borderGrey,
                  ),
                ),
                child: Row(
                  children: [
                    _InventoryThumb(imagePath: imagePath, isLow: isLow),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${item.brand} • ${item.color}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.currentStock} pcs',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isLow
                            ? AppTheme.dangerRed
                            : AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            const SectionHeader(title: "Today's Production"),
            const SizedBox(height: 12),
            _ProductionSummaryCard(entries: todayEntries),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderGrey),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductionSummaryCard extends StatelessWidget {
  final List<ProductionEntry> entries;
  const _ProductionSummaryCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderGrey),
        ),
        child: const Text(
          'No production entries today',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        children: entries.map((e) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.chipBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'M${e.machineNumber}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.productName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${e.brand} • ${e.color}',
                            style: const TextStyle(
                              fontSize: 11,
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
                          '${e.netQty} pcs',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.successGreen,
                          ),
                        ),
                        if (e.rejectedQty > 0)
                          Text(
                            '${e.rejectedQty} rej',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.dangerRed,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (e != entries.last)
                const Divider(height: 1, color: AppTheme.borderGrey),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Orders Tab ────────────────────────────────────────────────
class _OrdersTab extends StatelessWidget {
  final List<Order> orders;
  final List<Challan> challans;

  const _OrdersTab({super.key, required this.orders, required this.challans});

  List<Challan> _challansForOrder(String orderId) =>
      challans.where((challan) => challan.orderId == orderId).toList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _StatusSummary(
              'Pending',
              orders.where((o) => o.status == OrderStatus.pending).length,
              AppTheme.warningAmber,
            ),
            const SizedBox(width: 8),
            _StatusSummary(
              'Approved',
              orders.where((o) => o.status == OrderStatus.approved).length,
              AppTheme.successGreen,
            ),
            const SizedBox(width: 8),
            _StatusSummary(
              'Dispatched',
              orders.where((o) => o.status == OrderStatus.dispatched).length,
              AppTheme.primaryBlue,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...orders.map(
          (o) => OrderCard(
            order: o,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _OwnerOrderDetail(
                  order: o,
                  challans: _challansForOrder(o.id),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnerOrderDetail extends StatelessWidget {
  final Order order;
  final List<Challan> challans;

  const _OwnerOrderDetail({required this.order, this.challans = const []});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final statusLabel =
        order.status.name.substring(0, 1).toUpperCase() +
        order.status.name.substring(1);

    return Scaffold(
      appBar: AppBar(title: Text(order.id), actions: const [AppLogoutButton()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryNavy, Color(0xFF1E4FC2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.store, color: Colors.white, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.distributorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${order.distributorCity} • ${fmt.format(order.orderDate)}',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(label: statusLabel),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (challans.isNotEmpty) ...[
            const SectionHeader(title: 'Dispatch Details'),
            const SizedBox(height: 10),
            ...challans.map((challan) => _TruckPhotoCard(challan: challan)),
            const SizedBox(height: 6),
          ],
          ...order.items.map((item) => _OwnerOrderItem(item: item)),
        ],
      ),
    );
  }
}

class _TruckPhotoCard extends StatelessWidget {
  final Challan challan;

  const _TruckPhotoCard({required this.challan});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final photoSource = (challan.truckPhotoUrl ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoSource.isNotEmpty)
            SizedBox(
              height: 210,
              width: double.infinity,
              child: _TruckPhotoImage(source: photoSource),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              color: AppTheme.chipBg,
              child: const Row(
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    color: AppTheme.textSecondary,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Truck photo not saved for this challan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.chipBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: AppTheme.primaryBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        challan.id,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${challan.totalPieces} pcs',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _OwnerDispatchDetailRow(
                  'Dispatch Date',
                  fmt.format(challan.dispatchDate),
                ),
                _OwnerDispatchDetailRow(
                  'Vehicle Number',
                  challan.vehicleNumber,
                ),
                _OwnerDispatchDetailRow('Driver Name', challan.driverName),
                _OwnerDispatchDetailRow('Driver Phone', challan.driverPhone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerDispatchDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _OwnerDispatchDetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            value.trim().isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TruckPhotoImage extends StatelessWidget {
  final String source;

  const _TruckPhotoImage({required this.source});

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('data:image')) {
      try {
        final base64Part = source.substring(source.indexOf(',') + 1);
        return Image.memory(
          base64Decode(base64Part),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const _TruckPhotoError(),
        );
      } catch (_) {
        return const _TruckPhotoError();
      }
    }

    return Image.network(
      source,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const _TruckPhotoError(),
    );
  }
}

class _TruckPhotoError extends StatelessWidget {
  const _TruckPhotoError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.chipBg,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppTheme.textSecondary,
          size: 36,
        ),
      ),
    );
  }
}

class _OwnerOrderItem extends StatelessWidget {
  final OrderItem item;
  const _OwnerOrderItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final imagePath = CatalogImageResolver.forOrderItem(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.chipBg,
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: imagePath == null
                ? const Icon(
                    Icons.inventory_2_outlined,
                    color: AppTheme.primaryBlue,
                    size: 28,
                  )
                : Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.inventory_2_outlined,
                      color: AppTheme.primaryBlue,
                      size: 28,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
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
                const SizedBox(height: 6),
                StockDot(available: item.stockAvailable),
              ],
            ),
          ),
          Text(
            '${item.quantity} pcs',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Distributors Tab ─────────────────────────────────────────
class _DistributorsTab extends StatelessWidget {
  final List<User> distributors;
  final List<Order> orders;
  final List<Challan> challans;

  const _DistributorsTab({
    super.key,
    required this.distributors,
    required this.orders,
    required this.challans,
  });

  @override
  Widget build(BuildContext context) {
    if (distributors.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_2_outlined,
        title: 'No Distributors',
        subtitle: 'No distributor users found',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionHeader(
          title: 'Distributors',
          subtitle: '${distributors.length} registered distributors',
        ),
        const SizedBox(height: 12),
        ...distributors.map((distributor) {
          final distributorOrders = orders
              .where((order) => order.distributorId == distributor.id)
              .toList();
          final pending = distributorOrders
              .where((order) => order.status == OrderStatus.pending)
              .length;
          final dispatched = distributorOrders
              .where((order) => order.status == OrderStatus.dispatched)
              .length;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderGrey),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.chipBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppTheme.primaryBlue,
                ),
              ),
              title: Text(
                distributor.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${distributor.mobile} • ${distributorOrders.length} orders • $pending pending • $dispatched dispatched',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppTheme.textLight,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _DistributorOrdersScreen(
                    distributor: distributor,
                    orders: distributorOrders,
                    challans: challans,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _DistributorOrdersScreen extends StatelessWidget {
  final User distributor;
  final List<Order> orders;
  final List<Challan> challans;

  const _DistributorOrdersScreen({
    required this.distributor,
    required this.orders,
    required this.challans,
  });

  List<Challan> _challansForOrder(String orderId) =>
      challans.where((challan) => challan.orderId == orderId).toList();

  @override
  Widget build(BuildContext context) {
    final totalPieces = orders.fold(0, (sum, order) => sum + order.totalPieces);
    final pending = orders
        .where((order) => order.status == OrderStatus.pending)
        .length;
    final approved = orders
        .where((order) => order.status == OrderStatus.approved)
        .length;
    final dispatched = orders
        .where((order) => order.status == OrderStatus.dispatched)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(distributor.name),
        actions: const [AppLogoutButton()],
      ),
      body: orders.isEmpty
          ? const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Orders',
              subtitle: 'This distributor has not placed any orders yet',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryNavy, Color(0xFF1E4FC2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        distributor.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${distributor.mobile} • ${orders.length} orders • $totalPieces pcs',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _MiniSummary('Pending', pending),
                          const SizedBox(width: 8),
                          _MiniSummary('Approved', approved),
                          const SizedBox(width: 8),
                          _MiniSummary('Dispatched', dispatched),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...orders.map(
                  (order) => _DistributorOrderPanel(
                    order: order,
                    challans: _challansForOrder(order.id),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MiniSummary extends StatelessWidget {
  final String label;
  final int count;

  const _MiniSummary(this.label, this.count);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributorOrderPanel extends StatelessWidget {
  final Order order;
  final List<Challan> challans;

  const _DistributorOrderPanel({required this.order, required this.challans});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final statusLabel =
        order.status.name.substring(0, 1).toUpperCase() +
        order.status.name.substring(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    _OwnerOrderDetail(order: order, challans: challans),
              ),
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.chipBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppTheme.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.id,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          '${fmt.format(order.orderDate)} • ${order.totalPieces} pcs',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(label: statusLabel),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderGrey),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ...order.items.map((item) => _OwnerOrderItem(item: item)),
                if (order.remarks != null && order.remarks!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Remarks: ${order.remarks}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSummary extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusSummary(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inventory Tab ─────────────────────────────────────────────
class _InventoryTab extends StatefulWidget {
  final List<InventoryItem> inventory;
  final List<RawMaterial> rawMaterials;
  final List<Challan> challans;
  final List<ProductionEntry> entries;
  final VoidCallback onRefresh;

  const _InventoryTab({
    super.key,
    required this.inventory,
    required this.rawMaterials,
    required this.challans,
    required this.entries,
    required this.onRefresh,
  });

  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  int _selected = 0; // 0 = Finished Goods, 1 = Raw Materials

  Map<String, int> get _todayDispatchByItem {
    final today = DateTime.now();
    final totals = <String, int>{};
    for (final challan in widget.challans) {
      final date = challan.dispatchDate;
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      if (!isToday) continue;

      for (final item in challan.items) {
        final key = _inventoryKey(item.productId, item.brand, item.color);
        totals[key] = (totals[key] ?? 0) + item.quantity;
      }
    }
    return totals;
  }

  Map<String, int> get _todayProductionByItem {
    final today = DateTime.now();
    final totals = <String, int>{};
    for (final entry in widget.entries) {
      final date = entry.date;
      final isToday =
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      if (!isToday || entry.netQty <= 0) continue;

      final key = _inventoryKey(entry.productId, entry.brand, entry.color);
      totals[key] = (totals[key] ?? 0) + entry.netQty;
    }
    return totals;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toggle Buttons ─────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selected = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selected == 0
                          ? AppTheme.lightGreen
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selected == 0
                            ? AppTheme.successGreen
                            : AppTheme.borderGrey,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          color: _selected == 0
                              ? AppTheme.successGreen
                              : AppTheme.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Finished Goods',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selected == 0
                                ? AppTheme.successGreen
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selected = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selected == 1
                          ? AppTheme.lightAmber
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selected == 1
                            ? AppTheme.warningAmber
                            : AppTheme.borderGrey,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          color: _selected == 1
                              ? AppTheme.warningAmber
                              : AppTheme.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Raw Materials',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selected == 1
                                ? AppTheme.warningAmber
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── List ───────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => widget.onRefresh(),
            child: _selected == 0
                ? _FinishedGoodsList(
                    inventory: widget.inventory,
                    todayDispatchByItem: _todayDispatchByItem,
                    todayProductionByItem: _todayProductionByItem,
                  )
                : _RawMaterialsList(rawMaterials: widget.rawMaterials),
          ),
        ),
      ],
    );
  }
}

String _inventoryKey(String productId, String brand, String color) =>
    '${productId.toLowerCase()}|${brand.toLowerCase()}|${color.toLowerCase()}';

class _FinishedGoodsList extends StatelessWidget {
  final List<InventoryItem> inventory;
  final Map<String, int> todayDispatchByItem;
  final Map<String, int> todayProductionByItem;

  const _FinishedGoodsList({
    required this.inventory,
    required this.todayDispatchByItem,
    required this.todayProductionByItem,
  });

  @override
  Widget build(BuildContext context) {
    if (inventory.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No Inventory',
        subtitle: 'No finished goods found',
      );
    }

    final sortedInventory = List<InventoryItem>.from(inventory)
      ..sort((a, b) {
        final aMinus =
            todayDispatchByItem[_inventoryKey(a.productId, a.brand, a.color)] ??
            0;
        final bMinus =
            todayDispatchByItem[_inventoryKey(b.productId, b.brand, b.color)] ??
            0;
        final aPlus =
            todayProductionByItem[_inventoryKey(
              a.productId,
              a.brand,
              a.color,
            )] ??
            0;
        final bPlus =
            todayProductionByItem[_inventoryKey(
              b.productId,
              b.brand,
              b.color,
            )] ??
            0;
        final aMovement = aMinus + aPlus;
        final bMovement = bMinus + bPlus;
        if (aMovement != bMovement) return bMovement.compareTo(aMovement);

        final productCompare = a.productName.toLowerCase().compareTo(
          b.productName.toLowerCase(),
        );
        if (productCompare != 0) return productCompare;

        final brandCompare = a.brand.toLowerCase().compareTo(
          b.brand.toLowerCase(),
        );
        if (brandCompare != 0) return brandCompare;

        return a.color.toLowerCase().compareTo(b.color.toLowerCase());
      });

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: sortedInventory.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) {
          final totalMinusToday = todayDispatchByItem.values.fold(
            0,
            (sum, qty) => sum + qty,
          );
          final totalPlusToday = todayProductionByItem.values.fold(
            0,
            (sum, qty) => sum + qty,
          );
          final netToday = totalPlusToday - totalMinusToday;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.lightRed,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dangerRed.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.remove_shopping_cart_outlined,
                    color: AppTheme.dangerRed,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Movement',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Production added and dispatch reduced',
                        style: TextStyle(
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
                      '+$totalPlusToday pcs',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.successGreen,
                      ),
                    ),
                    Text(
                      '-$totalMinusToday pcs',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.dangerRed,
                      ),
                    ),
                    Text(
                      '${netToday >= 0 ? '+' : ''}$netToday net',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        final item = sortedInventory[i - 1];
        final isLow = item.currentStock == 0;
        final imagePath = CatalogImageResolver.forInventoryItem(item);
        final minusToday =
            todayDispatchByItem[_inventoryKey(
              item.productId,
              item.brand,
              item.color,
            )] ??
            0;
        final plusToday =
            todayProductionByItem[_inventoryKey(
              item.productId,
              item.brand,
              item.color,
            )] ??
            0;
        final netToday = plusToday - minusToday;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isLow ? AppTheme.lightRed : AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isLow
                  ? AppTheme.dangerRed.withOpacity(0.3)
                  : AppTheme.borderGrey,
            ),
          ),
          child: Row(
            children: [
              _InventoryThumb(imagePath: imagePath, isLow: isLow),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${item.brand} • ${item.color}',
                      style: const TextStyle(
                        fontSize: 11,
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
                    '${item.currentStock}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isLow ? AppTheme.dangerRed : AppTheme.successGreen,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'pcs available',
                    style: TextStyle(fontSize: 10, color: AppTheme.textLight),
                  ),
                  if (plusToday > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.successGreen.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        '+$plusToday today',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ),
                  ],
                  if (minusToday > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.lightRed,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.dangerRed.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        '-$minusToday today',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.dangerRed,
                        ),
                      ),
                    ),
                  ],
                  if (plusToday > 0 || minusToday > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.chipBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderGrey),
                      ),
                      child: Text(
                        '${netToday >= 0 ? '+' : ''}$netToday net today',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InventoryThumb extends StatelessWidget {
  final String? imagePath;
  final bool isLow;

  const _InventoryThumb({required this.imagePath, required this.isLow});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppTheme.chipBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderGrey),
          ),
          clipBehavior: Clip.antiAlias,
          child: imagePath == null
              ? const Icon(
                  Icons.inventory_2_outlined,
                  color: AppTheme.primaryBlue,
                  size: 24,
                )
              : Image.asset(
                  imagePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.inventory_2_outlined,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
        ),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 5,
            decoration: BoxDecoration(
              color: isLow ? AppTheme.dangerRed : AppTheme.successGreen,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RawMaterialsList extends StatelessWidget {
  final List<RawMaterial> rawMaterials;
  const _RawMaterialsList({required this.rawMaterials});

  @override
  Widget build(BuildContext context) {
    if (rawMaterials.isEmpty) {
      return const EmptyState(
        icon: Icons.science_outlined,
        title: 'No Raw Materials',
        subtitle: 'No raw materials found',
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: rawMaterials.length,
      itemBuilder: (_, i) {
        final m = rawMaterials[i];
        final color = m.stockStatus == StockStatus.critical
            ? AppTheme.dangerRed
            : m.stockStatus == StockStatus.low
            ? AppTheme.warningAmber
            : AppTheme.successGreen;
        final bg = m.stockStatus == StockStatus.critical
            ? AppTheme.lightRed
            : m.stockStatus == StockStatus.low
            ? AppTheme.lightAmber
            : AppTheme.cardWhite;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      m.supplier,
                      style: const TextStyle(
                        fontSize: 11,
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
                    '${m.currentStockKg.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    m.stockStatus == StockStatus.critical
                        ? 'Critical'
                        : m.stockStatus == StockStatus.low
                        ? 'Low Stock'
                        : 'Available',
                    style: TextStyle(fontSize: 10, color: color),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
