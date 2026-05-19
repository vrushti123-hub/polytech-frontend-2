import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/widgets.dart';
import '../production/production_home.dart';
import 'package:intl/intl.dart';

// ── Dispatch Home ─────────────────────────────────────────────
class DispatchHome extends StatefulWidget {
  const DispatchHome({super.key});

  @override
  State<DispatchHome> createState() => _DispatchHomeState();
}

class _DispatchHomeState extends State<DispatchHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Order> _orders = [];
  List<Challan> _challans = [];
  final Set<String> _completedOrderIds = {};
  bool _loading = true;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        _loadOrders();
      }
    });
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    final ordersFuture = ApiService.getOrders();
    final challansFuture = ApiService.getChallans();
    final orders = await ordersFuture;
    final challans = await challansFuture;
    if (mounted) {
      setState(() {
        for (final order in orders) {
          if (_completedOrderIds.contains(order.id)) {
            order.status = OrderStatus.dispatched;
          }
        }
        _orders = orders;
        _challans = challans;
        _loading = false;
        _refreshKey++;
      });
    }
  }

  List<Order> get _pendingNotifications => _orders
      .where(
        (o) =>
            !_isDone(o) &&
            (o.status == OrderStatus.pending ||
                o.status == OrderStatus.partial),
      )
      .toList();

  bool _isDone(Order order) {
    return _completedOrderIds.contains(order.id) ||
        order.status == OrderStatus.dispatched;
  }

  DateTime _doneSortDate(Order order) {
    final orderChallans = _challans
        .where((challan) => challan.orderId == order.id)
        .toList();
    if (orderChallans.isEmpty) return order.orderDate;
    return orderChallans
        .map((challan) => challan.dispatchDate)
        .reduce((latest, date) => date.isAfter(latest) ? date : latest);
  }

  void _handleDispatchComplete(Order order, Challan challan) {
    setState(() {
      if (order.status == OrderStatus.dispatched) {
        _completedOrderIds.add(order.id);
      } else {
        _completedOrderIds.remove(order.id);
      }
      final index = _orders.indexWhere((existing) => existing.id == order.id);
      order.status = OrderStatus.dispatched;
      if (index != -1) {
        _orders[index] = order;
      } else {
        _orders.add(order);
      }
      _challans.removeWhere((existing) => existing.id == challan.id);
      _challans.add(challan);
      _refreshKey++;
    });
    _tabCtrl.animateTo(order.status == OrderStatus.dispatched ? 2 : 1);
  }

  void _showNotifications() {
    showNotificationSheet(
      context,
      title: 'Notifications',
      notifications: _pendingNotifications
          .map(
            (order) => AppNotification(
              icon: Icons.local_shipping_outlined,
              title:
                  '${order.status == OrderStatus.partial ? 'Partial' : 'Pending'} order ${order.id}',
              subtitle:
                  '${order.distributorName} • ${order.totalPieces} pcs needs dispatch action',
              color: order.status == OrderStatus.partial
                  ? AppTheme.warningAmber
                  : AppTheme.primaryBlue,
              onTap: () async {
                final challan = await Navigator.push<Challan>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DispatchOrderDetail(
                      order: order,
                      onUpdate: _loadOrders,
                      onDispatchComplete: _handleDispatchComplete,
                    ),
                  ),
                );
                if (challan != null) _handleDispatchComplete(order, challan);
              },
            ),
          )
          .toList(),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        _orders.where((o) => o.status == OrderStatus.pending).toList()
          ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
    final approved = _orders
        .where(
          (o) =>
              !_isDone(o) &&
              (o.status == OrderStatus.approved ||
                  o.status == OrderStatus.partial),
        )
        .toList();
    final dispatched = _orders.where(_isDone).toList()
      ..sort((a, b) => _doneSortDate(b).compareTo(_doneSortDate(a)));

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dispatch Dashboard'),
            Text(
              'Wasim Khan',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: [
          NotificationButton(count: pending.length, onTap: _showNotifications),
          const AppLogoutButton(),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Pending (${pending.length})'),
            Tab(text: 'Ready (${approved.length})'),
            Tab(text: 'Done (${dispatched.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _PendingDistributorList(
                  key: ValueKey(_refreshKey),
                  orders: pending,
                  onRefresh: _loadOrders,
                  onDispatchComplete: _handleDispatchComplete,
                ),
                _OrderList(
                  key: ValueKey(_refreshKey + 100),
                  orders: approved,
                  showActions: true,
                  onRefresh: _loadOrders,
                  onDispatchComplete: _handleDispatchComplete,
                ),
                _OrderList(
                  key: ValueKey(_refreshKey + 200),
                  orders: dispatched,
                  challans: _challans,
                  showActions: false,
                  onRefresh: _loadOrders,
                  onDispatchComplete: _handleDispatchComplete,
                ),
              ],
            ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<Order> orders;
  final List<Challan> challans;
  final bool showActions;
  final VoidCallback onRefresh;
  final void Function(Order order, Challan challan)? onDispatchComplete;

  const _OrderList({
    super.key,
    required this.orders,
    this.challans = const [],
    required this.showActions,
    required this.onRefresh,
    this.onDispatchComplete,
  });

  List<Challan> _challansForOrder(String orderId) =>
      challans.where((challan) => challan.orderId == orderId).toList();

  int? _dispatchedPiecesFor(Order order) {
    final orderChallans = _challansForOrder(order.id);
    if (orderChallans.isEmpty) return null;
    return orderChallans.fold<int>(
      0,
      (sum, challan) => sum + challan.totalPieces,
    );
  }

  DateTime? _lastDispatchDateFor(Order order) {
    final orderChallans = _challansForOrder(order.id);
    if (orderChallans.isEmpty) return null;
    return orderChallans
        .map((challan) => challan.dispatchDate)
        .reduce((latest, date) => date.isAfter(latest) ? date : latest);
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_rounded,
        title: 'No Orders',
        subtitle: 'Orders will appear here',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (_, i) {
          final order = orders[i];
          return OrderCard(
            order: order,
            dispatchedPieces: _dispatchedPiecesFor(order),
            dispatchDate: _lastDispatchDateFor(order),
            onTap: () async {
              final challan = await Navigator.push<Challan>(
                context,
                MaterialPageRoute(
                  builder: (_) => DispatchOrderDetail(
                    order: order,
                    onUpdate: onRefresh,
                    onDispatchComplete: onDispatchComplete,
                  ),
                ),
              );
              if (challan != null) {
                onDispatchComplete?.call(order, challan);
              }
            },
          );
        },
      ),
    );
  }
}

class _PendingDistributorList extends StatelessWidget {
  final List<Order> orders;
  final VoidCallback onRefresh;
  final void Function(Order order, Challan challan)? onDispatchComplete;

  const _PendingDistributorList({
    super.key,
    required this.orders,
    required this.onRefresh,
    this.onDispatchComplete,
  });

  List<_DistributorOrderGroup> get _groups {
    final grouped = <String, List<Order>>{};
    for (final order in orders) {
      grouped.putIfAbsent(order.distributorId, () => []).add(order);
    }

    final groups = grouped.entries.map((entry) {
      final distributorOrders = entry.value
        ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
      return _DistributorOrderGroup(
        distributorId: entry.key,
        distributorName: distributorOrders.first.distributorName,
        distributorCity: distributorOrders.first.distributorCity,
        orders: distributorOrders,
      );
    }).toList();

    groups.sort((a, b) => b.latestOrderDate.compareTo(a.latestOrderDate));
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_rounded,
        title: 'No Pending Orders',
        subtitle: 'Distributor orders will appear here',
      );
    }

    final groups = _groups;
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        itemBuilder: (_, i) => _DistributorGroupCard(
          group: groups[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _DistributorOrdersScreen(
                group: groups[i],
                onRefresh: onRefresh,
                onDispatchComplete: onDispatchComplete,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DistributorOrderGroup {
  final String distributorId;
  final String distributorName;
  final String distributorCity;
  final List<Order> orders;

  const _DistributorOrderGroup({
    required this.distributorId,
    required this.distributorName,
    required this.distributorCity,
    required this.orders,
  });

  DateTime get latestOrderDate => orders
      .map((order) => order.orderDate)
      .reduce((latest, date) => date.isAfter(latest) ? date : latest);

  int get totalPieces =>
      orders.fold(0, (sum, order) => sum + order.totalPieces);
  int get partialCount =>
      orders.where((order) => order.status == OrderStatus.partial).length;
}

class _DistributorGroupCard extends StatelessWidget {
  final _DistributorOrderGroup group;
  final VoidCallback onTap;

  const _DistributorGroupCard({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM, hh:mm a');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderGrey),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.chipBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.distributorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${group.distributorCity} • ${group.orders.length} orders • ${group.totalPieces} pcs',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Latest ${fmt.format(group.latestOrderDate)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ),
            if (group.partialCount > 0) ...[
              StatusBadge(label: '${group.partialCount} Partial'),
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributorOrdersScreen extends StatelessWidget {
  final _DistributorOrderGroup group;
  final VoidCallback onRefresh;
  final void Function(Order order, Challan challan)? onDispatchComplete;

  const _DistributorOrdersScreen({
    required this.group,
    required this.onRefresh,
    this.onDispatchComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.distributorName),
            Text(
              '${group.distributorCity} • ${group.orders.length} pending',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        actions: const [AppLogoutButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: group.orders.length,
          itemBuilder: (_, i) => OrderCard(
            order: group.orders[i],
            onTap: () async {
              final order = group.orders[i];
              final challan = await Navigator.push<Challan>(
                context,
                MaterialPageRoute(
                  builder: (_) => DispatchOrderDetail(
                    order: order,
                    onUpdate: onRefresh,
                    onDispatchComplete: onDispatchComplete,
                  ),
                ),
              );
              if (challan != null) {
                onDispatchComplete?.call(order, challan);
              }
            },
          ),
        ),
      ),
    );
  }
}

// ── Dispatch Order Detail ─────────────────────────────────────
class DispatchOrderDetail extends StatefulWidget {
  final Order order;
  final VoidCallback onUpdate;
  final void Function(Order order, Challan challan)? onDispatchComplete;

  const DispatchOrderDetail({
    super.key,
    required this.order,
    required this.onUpdate,
    this.onDispatchComplete,
  });

  @override
  State<DispatchOrderDetail> createState() => _DispatchOrderDetailState();
}

class _DispatchOrderDetailState extends State<DispatchOrderDetail> {
  bool _checkingStock = true;
  List<Challan> _orderChallans = [];
  final _detailImagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkStock();
  }

  Future<void> _checkStock() async {
    await ApiService.checkOrderStock(widget.order.id);
    final updatedOrdersFuture = ApiService.getOrders();
    final challansFuture = ApiService.getChallans();
    final updatedOrders = await updatedOrdersFuture;
    final challans = await challansFuture;
    final updatedOrder = updatedOrders
        .where((o) => o.id == widget.order.id)
        .firstOrNull;
    final orderChallans = challans
        .where((challan) => challan.orderId == widget.order.id)
        .toList();
    if (updatedOrder != null && mounted) {
      setState(() {
        for (int i = 0; i < widget.order.items.length; i++) {
          if (i < updatedOrder.items.length) {
            widget.order.items[i].stockAvailable =
                updatedOrder.items[i].stockAvailable;
          }
        }
        _orderChallans = orderChallans;
        _checkingStock = false;
      });
    } else {
      if (mounted) {
        setState(() {
          _orderChallans = orderChallans;
          _checkingStock = false;
        });
      }
    }
  }

  void _applyCompletedChallan(Challan challan) {
    setState(() {
      widget.order.status = OrderStatus.dispatched;
      _orderChallans.removeWhere((existing) => existing.id == challan.id);
      _orderChallans.add(challan);
    });
    widget.onDispatchComplete?.call(widget.order, challan);
  }

  Future<void> _generateChallan() async {
    final challan = await Navigator.push<Challan>(
      context,
      MaterialPageRoute(
        builder: (_) => ChallanScreen(
          order: widget.order,
          onCreated: (challan) {
            if (mounted) _applyCompletedChallan(challan);
          },
        ),
      ),
    );
    if (challan == null || !mounted) return;

    _applyCompletedChallan(challan);
    if (mounted) Navigator.pop(context, challan);
  }

  Future<void> _approveOrder() async {
    await ApiService.updateOrderStatus(widget.order.id, 'approved');
    setState(() => widget.order.status = OrderStatus.approved);
    widget.onUpdate();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order approved — ready for dispatch'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  Future<void> _uploadPhotoForChallan(Challan challan) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Upload From Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final picked = await _detailImagePicker.pickImage(
        source: source,
        maxWidth: 900,
        imageQuality: 45,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final photoDataUrl =
          'data:${_mimeTypeForFile(picked.name)};base64,${base64Encode(bytes)}';
      final saved = await ApiService.updateChallanPhoto(
        challan.id,
        photoDataUrl,
      );
      if (!mounted) return;

      if (saved) {
        setState(() => challan.truckPhotoUrl = photoDataUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Truck photo saved'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save truck photo'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not upload truck photo'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  String _mimeTypeForFile(String name) {
    final extension = name.split('.').last.toLowerCase();
    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    return 'image/jpeg';
  }

  bool _sameItem(OrderItem a, OrderItem b) {
    return a.productId == b.productId &&
        a.brand.toLowerCase() == b.brand.toLowerCase() &&
        a.color.toLowerCase() == b.color.toLowerCase();
  }

  List<_ItemDispatchEntry> _dispatchesForItem(OrderItem item) {
    final entries = <_ItemDispatchEntry>[];
    for (final challan in _orderChallans) {
      final qty = challan.items
          .where((challanItem) => _sameItem(challanItem, item))
          .fold(0, (sum, challanItem) => sum + challanItem.quantity);
      if (qty > 0) {
        entries.add(
          _ItemDispatchEntry(
            challanId: challan.id,
            quantity: qty,
            dispatchDate: challan.dispatchDate,
          ),
        );
      }
    }
    return entries;
  }

  int _dispatchedQtyFor(OrderItem item) {
    final challanQty = _dispatchesForItem(
      item,
    ).fold(0, (sum, entry) => sum + entry.quantity);
    return challanQty > 0 ? challanQty : item.dispatchedQty;
  }

  int get _totalDispatchedPieces {
    final challanQty = _orderChallans.fold(
      0,
      (sum, challan) => sum + challan.totalPieces,
    );
    if (challanQty > 0) return challanQty;
    return widget.order.items.fold(0, (sum, item) => sum + item.dispatchedQty);
  }

  DateTime? get _lastDispatchAt {
    if (_orderChallans.isEmpty) return null;
    return _orderChallans
        .map((challan) => challan.dispatchDate)
        .reduce((latest, date) => date.isAfter(latest) ? date : latest);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    String statusLabel;
    switch (o.status) {
      case OrderStatus.pending:
        statusLabel = "Pending";
        break;
      case OrderStatus.approved:
        statusLabel = "Approved";
        break;
      case OrderStatus.partial:
        statusLabel = "Partially Dispatched";
        break;
      case OrderStatus.dispatched:
        statusLabel = "Dispatched";
        break;
    }
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(title: Text(o.id), actions: const [AppLogoutButton()]),
      body: _checkingStock
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.store,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                o.distributorName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${o.distributorCity} • ${fmt.format(o.orderDate)}',
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

                  if (_orderChallans.isNotEmpty) ...[
                    const SectionHeader(title: 'Dispatch Details'),
                    const SizedBox(height: 10),
                    ..._orderChallans.map(
                      (challan) => _DispatchTruckPhotoCard(
                        challan: challan,
                        onUploadPhoto: () => _uploadPhotoForChallan(challan),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  ...o.items.map(
                    (item) => _DispatchItemCard(
                      item: item,
                      dispatchedQty: _dispatchedQtyFor(item),
                      dispatches: _dispatchesForItem(item),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderGrey),
                    ),
                    child: Column(
                      children: [
                        _SummaryRow('Order Received', '${o.totalPieces} pcs'),
                        const SizedBox(height: 6),
                        _SummaryRow(
                          'Final Dispatched',
                          '$_totalDispatchedPieces pcs',
                          valueColor: AppTheme.successGreen,
                        ),
                        if (_lastDispatchAt != null) ...[
                          const SizedBox(height: 6),
                          _SummaryRow(
                            'Last Dispatch',
                            fmt.format(_lastDispatchAt!),
                          ),
                        ],
                        const SizedBox(height: 6),
                        _SummaryRow(
                          'Stock Status',
                          o.hasStockShortage ? '⚠ Shortage' : '✓ Available',
                          valueColor: o.hasStockShortage
                              ? AppTheme.warningAmber
                              : AppTheme.successGreen,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Pending state ──────────────────────────────
                  if (o.status == OrderStatus.pending) ...[
                    if (o.hasStockShortage)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.lightAmber,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.warningAmber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.warningAmber,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Some items lack stock. Production tasks have been auto-queued.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.warningAmber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _approveOrder,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'Approve Order',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Approved / Partial state ───────────────────
                  if (o.status == OrderStatus.approved ||
                      o.status == OrderStatus.partial) ...[
                    if (o.hasStockShortage) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.lightAmber,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.warningAmber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.warningAmber,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Stock shortage detected. Please add production entries before dispatching.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.warningAmber,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProductionHome(),
                            ),
                          ).then((_) => _checkStock()),
                          icon: const Icon(Icons.factory_outlined),
                          label: const Text(
                            'Go to Production Entry',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _generateChallan,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successGreen,
                          ),
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: Text(
                            o.status == OrderStatus.partial
                                ? 'Continue Dispatch'
                                : 'Generate Challan & Dispatch',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  if (o.status == OrderStatus.partial)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.lightAmber,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: AppTheme.warningAmber,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Partially Dispatched',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warningAmber,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (o.status == OrderStatus.dispatched)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: AppTheme.successGreen,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Order Fully Dispatched',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.successGreen,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _DispatchItemCard extends StatelessWidget {
  final OrderItem item;
  final int dispatchedQty;
  final List<_ItemDispatchEntry> dispatches;

  const _DispatchItemCard({
    required this.item,
    required this.dispatchedQty,
    required this.dispatches,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final hasDispatch = dispatchedQty > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.stockAvailable
              ? AppTheme.successGreen.withValues(alpha: 0.3)
              : AppTheme.dangerRed.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 48,
            decoration: BoxDecoration(
              color: item.stockAvailable
                  ? AppTheme.successGreen
                  : AppTheme.dangerRed,
              borderRadius: BorderRadius.circular(3),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _VariantChip(
                      icon: Icons.sell_outlined,
                      label: item.brand,
                      color: AppTheme.primaryBlue,
                    ),
                    _VariantChip(
                      icon: Icons.palette_outlined,
                      label: item.color,
                      color: AppTheme.warningAmber,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  hasDispatch
                      ? 'Ordered: ${item.quantity} pcs • Final dispatched: $dispatchedQty pcs'
                      : 'Ordered: ${item.quantity} pcs',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: hasDispatch
                        ? AppTheme.warningAmber
                        : AppTheme.textSecondary,
                  ),
                ),
                if (dispatches.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(dispatches.length, (i) {
                      final dispatch = dispatches[i];
                      return Text(
                        '${dispatch.challanId} • ${fmt.format(dispatch.dispatchDate)} → ${dispatch.quantity} pcs',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasDispatch ? '$dispatchedQty pcs' : '${item.quantity} pcs',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              StockDot(available: item.stockAvailable),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemDispatchEntry {
  final String challanId;
  final int quantity;
  final DateTime dispatchDate;

  const _ItemDispatchEntry({
    required this.challanId,
    required this.quantity,
    required this.dispatchDate,
  });
}

class _DispatchTruckPhotoCard extends StatelessWidget {
  final Challan challan;
  final VoidCallback onUploadPhoto;

  const _DispatchTruckPhotoCard({
    required this.challan,
    required this.onUploadPhoto,
  });

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
              width: double.infinity,
              height: 210,
              child: _DispatchTruckPhotoImage(source: photoSource),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              color: AppTheme.chipBg,
              child: Row(
                children: [
                  const Icon(
                    Icons.image_not_supported_outlined,
                    color: AppTheme.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Truck photo not saved for this challan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onUploadPhoto,
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('Upload'),
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
                _DispatchDetailRow(
                  'Dispatch Date',
                  fmt.format(challan.dispatchDate),
                ),
                _DispatchDetailRow('Vehicle Number', challan.vehicleNumber),
                _DispatchDetailRow('Driver Name', challan.driverName),
                _DispatchDetailRow('Driver Phone', challan.driverPhone),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DispatchDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DispatchDetailRow(this.label, this.value);

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

class _DispatchTruckPhotoImage extends StatelessWidget {
  final String source;

  const _DispatchTruckPhotoImage({required this.source});

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('data:image')) {
      try {
        final base64Part = source.substring(source.indexOf(',') + 1);
        return Image.memory(
          base64Decode(base64Part),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const _DispatchTruckPhotoError(),
        );
      } catch (_) {
        return const _DispatchTruckPhotoError();
      }
    }

    return Image.network(
      source,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const _DispatchTruckPhotoError(),
    );
  }
}

class _DispatchTruckPhotoError extends StatelessWidget {
  const _DispatchTruckPhotoError();

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

class _VariantChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _VariantChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Challan Generation Screen ─────────────────────────────────
class ChallanScreen extends StatefulWidget {
  final Order order;
  final ValueChanged<Challan>? onCreated;

  const ChallanScreen({super.key, required this.order, this.onCreated});

  @override
  State<ChallanScreen> createState() => _ChallanScreenState();
}

class _ChallanScreenState extends State<ChallanScreen> {
  final _vehicleCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();
  final Map<OrderItem, TextEditingController> _qtyCtrls = {};
  final Map<OrderItem, bool> _selectedItems = {};
  Uint8List? _truckPhotoBytes;
  String? _truckPhotoDataUrl;
  String? _truckPhotoName;
  bool _saving = false;

  bool get _photoUploaded => _truckPhotoDataUrl != null;

  @override
  void initState() {
    super.initState();
    for (final item in widget.order.items) {
      final initialQty = item.pendingQty > 0 ? item.pendingQty : 0;
      _qtyCtrls[item] = TextEditingController(text: '$initialQty');
      _selectedItems[item] = initialQty > 0;
    }
  }

  @override
  void dispose() {
    for (final ctrl in _qtyCtrls.values) {
      ctrl.dispose();
    }
    _vehicleCtrl.dispose();
    _driverCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  int? _enteredQtyFor(OrderItem item) {
    final text = _qtyCtrls[item]?.text.trim() ?? '';
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  int get _challanTotal {
    var total = 0;
    for (final item in widget.order.items) {
      if (_selectedItems[item] != true) continue;
      final enteredQty = _enteredQtyFor(item);
      total += enteredQty ?? (item.pendingQty > 0 ? item.pendingQty : 0);
    }
    return total;
  }

  Future<void> _pickTruckPhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 900,
        imageQuality: 45,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final mimeType = _mimeTypeForFile(picked.name);
      setState(() {
        _truckPhotoBytes = bytes;
        _truckPhotoName = picked.name;
        _truckPhotoDataUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not upload truck photo'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  Future<void> _showPhotoSourcePicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Upload From Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source != null) await _pickTruckPhoto(source);
  }

  String _mimeTypeForFile(String name) {
    final extension = name.split('.').last.toLowerCase();
    if (extension == 'png') return 'image/png';
    if (extension == 'webp') return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _confirmDispatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_photoUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload truck photo'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    if (!_selectedItems.values.any((selected) => selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one product to dispatch'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    for (final item in widget.order.items) {
      if (_selectedItems[item] != true) continue;
      final enteredQty = _enteredQtyFor(item);
      if (enteredQty == null || enteredQty < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enter 0 or more pcs for ${item.productName}'),
            backgroundColor: AppTheme.warningAmber,
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    final challanItems = <OrderItem>[];

    for (final item in widget.order.items) {
      if (_selectedItems[item] != true) continue;
      final defaultQty = item.pendingQty > 0 ? item.pendingQty : 0;
      final dispatchQty = _enteredQtyFor(item) ?? defaultQty;
      if (dispatchQty == 0) continue;
      item.dispatchedQty += dispatchQty;
      item.dispatchHistory.add(dispatchQty);
      challanItems.add(
        OrderItem(
          productId: item.productId,
          productName: item.productName,
          brand: item.brand,
          color: item.color,
          quantity: dispatchQty,
          dispatchedQty: dispatchQty,
          stockAvailable: item.stockAvailable,
        ),
      );
    }

    if (challanItems.isEmpty) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pending quantity left to dispatch'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    final isFullyDispatched = widget.order.items.every(
      (item) => item.dispatchedQty >= item.quantity,
    );
    final newStatus = isFullyDispatched ? 'dispatched' : 'partial';
    widget.order.status = isFullyDispatched
        ? OrderStatus.dispatched
        : OrderStatus.partial;

    final challanId =
        'CHL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final challan = Challan(
      id: challanId,
      orderId: widget.order.id,
      distributorName: widget.order.distributorName,
      distributorCity: widget.order.distributorCity,
      vehicleNumber: _vehicleCtrl.text,
      driverName: _driverCtrl.text,
      driverPhone: _phoneCtrl.text,
      dispatchDate: DateTime.now(),
      items: challanItems,
      truckPhotoUrl: _truckPhotoDataUrl,
    );

    final challanCreated = await ApiService.createChallan(challan);
    if (!challanCreated) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save challan photo. Please try again.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final statusUpdated = await ApiService.updateOrderStatus(
      widget.order.id,
      newStatus,
    );
    if (!statusUpdated && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challan saved. Order will appear in Done.'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
    }
    widget.onCreated?.call(challan);

    setState(() => _saving = false);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                Icons.local_shipping,
                color: AppTheme.successGreen,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Dispatched!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Order marked as dispatched.\nChallan generated.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pop(context, challan);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final challanNo =
        'CHL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final fmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Challan'),
        actions: const [AppLogoutButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'DELIVERY CHALLAN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          challanNo,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.order.distributorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${widget.order.distributorCity} • ${fmt.format(DateTime.now())}',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
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
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Product',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            'QTY',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderGrey),
                    ...widget.order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _selectedItems[item] ?? false,
                              onChanged: (value) {
                                setState(() {
                                  _selectedItems[item] = value ?? false;
                                });
                              },
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
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
                            SizedBox(
                              width: 92,
                              child: TextFormField(
                                controller: _qtyCtrls[item],
                                enabled: _selectedItems[item] == true,
                                textAlign: TextAlign.right,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  suffixText: 'pcs',
                                  hintText: '0',
                                  helperText: 'Pending ${item.pendingQty}',
                                  helperMaxLines: 1,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderGrey),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$_challanTotal pcs',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              const SectionHeader(title: 'Transport Details'),
              const SizedBox(height: 14),
              FormFieldWrapper(
                label: 'Vehicle Number',
                child: TextFormField(
                  controller: _vehicleCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(hintText: 'MH-15 AB 1234'),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 14),
              FormFieldWrapper(
                label: 'Driver Name',
                child: TextFormField(
                  controller: _driverCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Enter driver name',
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
              ),
              const SizedBox(height: 14),
              FormFieldWrapper(
                label: 'Driver Phone',
                child: TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(hintText: '9876500000'),
                  validator: (v) =>
                      (v?.length ?? 0) < 10 ? 'Enter valid phone' : null,
                ),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: _showPhotoSourcePicker,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _photoUploaded
                        ? AppTheme.lightGreen
                        : AppTheme.chipBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _photoUploaded
                          ? AppTheme.successGreen
                          : AppTheme.borderGrey,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_truckPhotoBytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            _truckPhotoBytes!,
                            width: double.infinity,
                            height: 170,
                            fit: BoxFit.contain,
                          ),
                        )
                      else
                        Icon(
                          Icons.camera_alt_rounded,
                          size: 36,
                          color: _photoUploaded
                              ? AppTheme.successGreen
                              : AppTheme.primaryBlue,
                        ),
                      const SizedBox(height: 8),
                      Text(
                        _photoUploaded
                            ? 'Photo Uploaded'
                            : 'Upload Truck Photo',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _photoUploaded
                              ? AppTheme.successGreen
                              : AppTheme.primaryBlue,
                        ),
                      ),
                      if (_truckPhotoName != null)
                        Text(
                          _truckPhotoName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      if (!_photoUploaded)
                        const Text(
                          'Tap to capture loading photo',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _confirmDispatch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successGreen,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.local_shipping_rounded),
                  label: const Text(
                    'Confirm Dispatch',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
