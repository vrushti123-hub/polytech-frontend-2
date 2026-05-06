import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final orders = await ApiService.getOrders();
    if (mounted) setState(() { _orders = orders; _loading = false; _refreshKey++; });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _orders.where((o) =>
    o.status == OrderStatus.pending || o.status == OrderStatus.partial).toList();
    final approved = _orders.where((o) => o.status == OrderStatus.approved).toList();
    final dispatched = _orders.where((o) => o.status == OrderStatus.dispatched).toList();

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dispatch Dashboard'),
            Text('Wasim Khan',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          NotificationButton(count: pending.length),
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
          _OrderList(key: ValueKey(_refreshKey), orders: pending, showActions: true, onRefresh: _loadOrders),
          _OrderList(key: ValueKey(_refreshKey + 100), orders: approved, showActions: true, onRefresh: _loadOrders),
          _OrderList(key: ValueKey(_refreshKey + 200), orders: dispatched, showActions: false, onRefresh: _loadOrders),
        ],
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final List<Order> orders;
  final bool showActions;
  final VoidCallback onRefresh;

  const _OrderList(
      {super.key,
        required this.orders,
        required this.showActions,
        required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const EmptyState(
          icon: Icons.inbox_rounded,
          title: 'No Orders',
          subtitle: 'Orders will appear here');
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (_, i) => OrderCard(
          order: orders[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => DispatchOrderDetail(
                    order: orders[i], onUpdate: onRefresh)),
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

  const DispatchOrderDetail(
      {super.key, required this.order, required this.onUpdate});

  @override
  State<DispatchOrderDetail> createState() => _DispatchOrderDetailState();
}

class _DispatchOrderDetailState extends State<DispatchOrderDetail> {
  bool _checkingStock = true;

  @override
  void initState() {
    super.initState();
    _checkStock();
  }

  Future<void> _checkStock() async {
    await ApiService.checkOrderStock(widget.order.id);
    // Reload order items from DB after stock check
    final updatedOrders = await ApiService.getOrders();
    final updatedOrder = updatedOrders.where((o) => o.id == widget.order.id).firstOrNull;
    if (updatedOrder != null && mounted) {
      // Update items stock_available
      for (int i = 0; i < widget.order.items.length; i++) {
        if (i < updatedOrder.items.length) {
          widget.order.items[i].stockAvailable = updatedOrder.items[i].stockAvailable;
        }
      }
    }
    if (mounted) setState(() => _checkingStock = false);
  }

  void _generateChallan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChallanScreen(
            order: widget.order,
            onDispatched: () {
              widget.onUpdate();
              Navigator.pop(context);
            }),
      ),
    );
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
      appBar: AppBar(title: Text(o.id)),
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
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.distributorName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        Text('${o.distributorCity} • ${fmt.format(o.orderDate)}',
                            style: const TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                  ),
                  StatusBadge(label: statusLabel),
                ],
              ),
            ),
            const SizedBox(height: 16),

            ...o.items.map((item) => _DispatchItemCard(item: item)),
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
                  _SummaryRow('Total Pieces', '${o.totalPieces} pcs'),
                  const SizedBox(height: 6),
                  _SummaryRow(
                      'Stock Status',
                      o.hasStockShortage ? '⚠ Shortage' : '✓ Available',
                      valueColor: o.hasStockShortage
                          ? AppTheme.warningAmber
                          : AppTheme.successGreen),
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
                        color: AppTheme.warningAmber.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppTheme.warningAmber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Some items lack stock. Production tasks have been auto-queued.',
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.warningAmber),
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
                  label: const Text('Approve Order',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
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
                        color: AppTheme.warningAmber.withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppTheme.warningAmber, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Stock shortage detected. Please add production entries before dispatching.',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.warningAmber,
                              fontWeight: FontWeight.w600),
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
                          builder: (_) => const ProductionHome()),
                    ).then((_) => _checkStock()),
                    icon: const Icon(Icons.factory_outlined),
                    label: const Text('Go to Production Entry',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _generateChallan,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: Text(
                      o.status == OrderStatus.partial
                          ? 'Continue Dispatch'
                          : 'Generate Challan & Dispatch',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
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
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warningAmber),
                    SizedBox(width: 8),
                    Text('Partially Dispatched',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.warningAmber,
                            fontSize: 15)),
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
                    Icon(Icons.check_circle, color: AppTheme.successGreen),
                    SizedBox(width: 8),
                    Text('Order Fully Dispatched',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.successGreen,
                            fontSize: 15)),
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
  const _DispatchItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.stockAvailable
              ? AppTheme.successGreen.withOpacity(0.3)
              : AppTheme.dangerRed.withOpacity(0.3),
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
                Text(item.productName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary)),
                Text(
                  item.dispatchedQty > 0
                      ? 'Dispatched: ${item.dispatchedQty} / ${item.quantity} pcs'
                      : '${item.quantity} pcs',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: item.dispatchedQty > 0
                        ? AppTheme.warningAmber
                        : AppTheme.textSecondary,
                  ),
                ),
                if (item.dispatchHistory.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(item.dispatchHistory.length, (i) {
                      return Text(
                        'Dispatch ${i + 1} → ${item.dispatchHistory[i]} pcs',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      );
                    }),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${item.quantity} pcs',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppTheme.textPrimary)),
              StockDot(available: item.stockAvailable),
            ],
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
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppTheme.textPrimary)),
      ],
    );
  }
}

// ── Challan Generation Screen ─────────────────────────────────
class ChallanScreen extends StatefulWidget {
  final Order order;
  final VoidCallback onDispatched;

  const ChallanScreen(
      {super.key, required this.order, required this.onDispatched});

  @override
  State<ChallanScreen> createState() => _ChallanScreenState();
}

class _ChallanScreenState extends State<ChallanScreen> {
  final _partialQtyCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _driverCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _photoUploaded = false;
  bool _saving = false;

  Future<void> _confirmDispatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_photoUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload truck photo'),
            backgroundColor: AppTheme.warningAmber),
      );
      return;
    }

    setState(() => _saving = true);

    int? partialQty = int.tryParse(_partialQtyCtrl.text);
    bool isPartial = false;

    for (final item in widget.order.items) {
      int remaining = item.quantity - item.dispatchedQty;
      if (partialQty != null && partialQty > 0 && partialQty <= remaining) {
        item.dispatchedQty += partialQty;
        item.dispatchHistory.add(partialQty);
      } else {
        item.dispatchedQty = item.quantity;
        item.dispatchHistory.add(item.quantity);
      }
      if (item.dispatchedQty < item.quantity) isPartial = true;
    }

    final newStatus = isPartial ? 'partial' : 'dispatched';
    widget.order.status =
    isPartial ? OrderStatus.partial : OrderStatus.dispatched;

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
      items: widget.order.items,
    );

    await ApiService.createChallan(challan);
    await ApiService.updateOrderStatus(widget.order.id, newStatus);

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
              child: const Icon(Icons.local_shipping,
                  color: AppTheme.successGreen, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Dispatched!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
              Navigator.pop(context);
              widget.onDispatched();
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
      appBar: AppBar(title: const Text('Generate Challan')),
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
                        const Text('DELIVERY CHALLAN',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5)),
                        Text(challanNo,
                            style: const TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(widget.order.distributorName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    Text(
                        '${widget.order.distributorCity} • ${fmt.format(DateTime.now())}',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 12)),
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
                              child: Text('Product',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppTheme.textSecondary))),
                          Text('QTY',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.borderGrey),
                    ...widget.order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text('${item.brand} • ${item.color}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          Text('${item.quantity}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14)),
                        ],
                      ),
                    )),
                    const Divider(height: 1, color: AppTheme.borderGrey),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14)),
                          Text('${widget.order.totalPieces} pcs',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppTheme.primaryBlue)),
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
                  decoration:
                  const InputDecoration(hintText: 'Enter driver name'),
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
              const SizedBox(height: 14),
              FormFieldWrapper(
                label: 'Dispatch Quantity (Optional)',
                child: TextFormField(
                  controller: _partialQtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      hintText: 'Leave empty for full dispatch'),
                ),
              ),
              const SizedBox(height: 20),

              GestureDetector(
                onTap: () => setState(() => _photoUploaded = true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _photoUploaded ? AppTheme.lightGreen : AppTheme.chipBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _photoUploaded
                          ? AppTheme.successGreen
                          : AppTheme.borderGrey,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _photoUploaded
                            ? Icons.check_circle
                            : Icons.camera_alt_rounded,
                        size: 36,
                        color: _photoUploaded
                            ? AppTheme.successGreen
                            : AppTheme.primaryBlue,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _photoUploaded
                            ? 'Photo Uploaded ✓'
                            : 'Upload Truck Photo',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _photoUploaded
                                ? AppTheme.successGreen
                                : AppTheme.primaryBlue),
                      ),
                      if (!_photoUploaded)
                        const Text('Tap to capture loading photo',
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
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
                      backgroundColor: AppTheme.successGreen),
                  icon: _saving
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.local_shipping_rounded),
                  label: const Text('Confirm Dispatch',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
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