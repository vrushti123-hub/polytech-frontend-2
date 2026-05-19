import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/widgets.dart';
import '../rawmaterial/rm_home.dart';

// ── Production Home ───────────────────────────────────────────
class ProductionHome extends StatefulWidget {
  const ProductionHome({super.key});

  @override
  State<ProductionHome> createState() => _ProductionHomeState();
}

class _ProductionHomeState extends State<ProductionHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<ProductionEntry> _entries = [];
  List<ProductionTask> _tasks = [];
  List<InventoryItem> _inventory = [];
  List<Product> _products = [];
  bool _loading = true;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _loadAll();
    });
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.getProductionEntries(),
      ApiService.getProductionTasks(),
      ApiService.getInventory(),
      ApiService.getProducts(),
    ]);
    if (mounted) {
      setState(() {
        _entries = results[0] as List<ProductionEntry>;
        _tasks = results[1] as List<ProductionTask>;
        _inventory = results[2] as List<InventoryItem>;
        _products = results[3] as List<Product>;
        _loading = false;
        _refreshKey++;
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _entries
        .where((e) => e.date.day == DateTime.now().day)
        .toList();
    final todayNet = today.fold(0, (s, e) => s + e.netQty);
    final pendingTasks = _tasks
        .where(
          (task) => task.status == 'pending' || task.status == 'in_progress',
        )
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Production'),
            Text(
              'Supervisor View',
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
              count: pendingTasks.length,
              onTap: () => showNotificationSheet(
                context,
                title: 'Notifications',
                notifications: pendingTasks
                    .map(
                      (task) => AppNotification(
                        icon: Icons.precision_manufacturing_outlined,
                        title: task.productName,
                        subtitle:
                            '${task.requiredQty} pcs • ${task.color} • ${task.status.replaceAll('_', ' ')}',
                        color: task.status == 'in_progress'
                            ? AppTheme.primaryBlue
                            : AppTheme.warningAmber,
                        onTap: () => _tabCtrl.animateTo(0),
                      ),
                    )
                    .toList(),
              ),
            ),
          const AppLogoutButton(),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Task Board'),
            Tab(text: 'Log Entry'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: AppTheme.primaryNavy,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      _MiniStat(
                        'Today',
                        '$todayNet pcs',
                        Icons.trending_up,
                        AppTheme.accentBlue,
                      ),
                      const SizedBox(width: 12),
                      _MiniStat(
                        'Tasks',
                        '${_tasks.length}',
                        Icons.assignment_outlined,
                        const Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 12),
                      _MiniStat(
                        'Machines',
                        '${today.map((e) => e.machineNumber).toSet().length}',
                        Icons.precision_manufacturing,
                        AppTheme.successGreen,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _TaskBoardTab(
                        key: ValueKey(_refreshKey),
                        tasks: _tasks,
                        products: _products,
                        onRefresh: _loadAll,
                      ),
                      _ProductionEntryTab(
                        key: ValueKey(_refreshKey + 100),
                        entries: _entries,
                        inventory: _inventory,
                        products: _products,
                        onSaved: _loadAll,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Task Board Tab ────────────────────────────────────────────
class _TaskBoardTab extends StatefulWidget {
  final List<ProductionTask> tasks;
  final List<Product> products;
  final VoidCallback onRefresh;
  const _TaskBoardTab({
    super.key,
    required this.tasks,
    required this.products,
    required this.onRefresh,
  });

  @override
  State<_TaskBoardTab> createState() => _TaskBoardTabState();
}

class _TaskBoardTabState extends State<_TaskBoardTab> {
  Set<int> get _activeMachines => widget.tasks
      .where((task) => task.status == 'in_progress')
      .map((task) => task.assignedMachine)
      .whereType<int>()
      .toSet();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: SectionHeader(
                  title: 'Task Board',
                  subtitle: 'Assign machines and track active production',
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showCreateTaskDialog,
                icon: const Icon(Icons.add_task_outlined, size: 18),
                label: const Text('Add Task'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: EmptyState(
                icon: Icons.task_alt,
                title: 'No Tasks',
                subtitle: 'All production tasks completed',
              ),
            )
          else
            ...widget.tasks.map(
              (task) => _TaskCard(
                task: task,
                unavailableMachines: _activeMachines,
                onAssign: (machine) async {
                  await ApiService.updateProductionTask(
                    task.id,
                    status: 'in_progress',
                    assignedMachine: machine,
                    isCompleted: false,
                  );
                  widget.onRefresh();
                },
                onComplete: () async {
                  await ApiService.updateProductionTask(
                    task.id,
                    status: 'completed',
                    assignedMachine: task.assignedMachine,
                    isCompleted: true,
                  );
                  widget.onRefresh();
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCreateTaskDialog() async {
    Product? selectedProduct;
    String? selectedBrand;
    String? selectedColor;
    final qtyCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final sortedProducts = List<Product>.from(widget.products)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    Map<String, List<String>> brandOptionsFor(Product product) {
      if (product.brandOptions.isNotEmpty) return product.brandOptions;
      return {product.brand: product.colors};
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDState) {
          final brandOptions = selectedProduct == null
              ? <String, List<String>>{}
              : brandOptionsFor(selectedProduct!);
          final availableColors = selectedBrand == null
              ? const <String>[]
              : brandOptions[selectedBrand] ?? const <String>[];

          return AlertDialog(
            title: const Text('Add Production Task'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<Product>(
                      value: selectedProduct,
                      hint: const Text('Select product'),
                      items: sortedProducts
                          .map(
                            (product) => DropdownMenuItem(
                              value: product,
                              child: Text(
                                '${product.name} (${product.brand})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (product) => setDState(() {
                        selectedProduct = product;
                        selectedBrand = product?.brandOptions.isNotEmpty == true
                            ? product!.brandOptions.keys.first
                            : product?.brand;
                        selectedColor = null;
                      }),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedBrand,
                      hint: const Text('Select brand'),
                      items: brandOptions.keys
                          .map(
                            (brand) => DropdownMenuItem(
                              value: brand,
                              child: Text(brand),
                            ),
                          )
                          .toList(),
                      onChanged: selectedProduct == null
                          ? null
                          : (brand) => setDState(() {
                              selectedBrand = brand;
                              selectedColor = null;
                            }),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedColor,
                      hint: const Text('Select color'),
                      items: availableColors
                          .map(
                            (color) => DropdownMenuItem(
                              value: color,
                              child: Text(color),
                            ),
                          )
                          .toList(),
                      onChanged: selectedBrand == null
                          ? null
                          : (color) => setDState(() => selectedColor = color),
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Required quantity',
                        prefixIcon: Icon(Icons.numbers_outlined),
                      ),
                      validator: (value) {
                        final qty = int.tryParse(value ?? '');
                        if (qty == null || qty <= 0) return 'Enter quantity';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final product = selectedProduct!;
                  final created = await ApiService.createProductionTask(
                    ProductionTask(
                      id: 'T${DateTime.now().millisecondsSinceEpoch}',
                      productId: product.id,
                      productName: product.name,
                      brand: selectedBrand!,
                      color: selectedColor!,
                      requiredQty: int.parse(qtyCtrl.text),
                      status: 'pending',
                    ),
                  );
                  if (!mounted) return;
                  Navigator.of(context, rootNavigator: true).pop();
                  widget.onRefresh();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        created
                            ? 'Production task added'
                            : 'Could not add production task',
                      ),
                      backgroundColor: created
                          ? AppTheme.successGreen
                          : AppTheme.dangerRed,
                    ),
                  );
                },
                child: const Text('Create Task'),
              ),
            ],
          );
        },
      ),
    );

    qtyCtrl.dispose();
  }
}

class _TaskCard extends StatelessWidget {
  final ProductionTask task;
  final Set<int> unavailableMachines;
  final ValueChanged<int> onAssign;
  final VoidCallback onComplete;

  const _TaskCard({
    required this.task,
    required this.unavailableMachines,
    required this.onAssign,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    Color statusBg;
    switch (task.status) {
      case 'in_progress':
        statusColor = AppTheme.successGreen;
        statusBg = AppTheme.lightGreen;
      case 'completed':
        statusColor = AppTheme.primaryBlue;
        statusBg = AppTheme.chipBg;
      default:
        statusColor = AppTheme.warningAmber;
        statusBg = AppTheme.lightAmber;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.precision_manufacturing,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${task.brand} • ${task.color}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    task.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Required',
                      style: TextStyle(fontSize: 10, color: AppTheme.textLight),
                    ),
                    Text(
                      '${task.requiredQty} pcs',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                if (task.assignedMachine != null) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Machine',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textLight,
                        ),
                      ),
                      Text(
                        'M-${task.assignedMachine}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppTheme.successGreen,
                        ),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                if (task.status == 'pending')
                  TextButton.icon(
                    onPressed: () => _showAssignDialog(context),
                    icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                    label: const Text('Assign Machine'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (task.status == 'in_progress')
                  TextButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Mark Complete'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.successGreen,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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

  void _showAssignDialog(BuildContext context) {
    int? selected;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Assign Machine'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select machine for: ${task.productName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(20, (i) {
                  final m = i + 1;
                  final busy = unavailableMachines.contains(m);
                  return GestureDetector(
                    onTap: busy ? null : () => setDState(() => selected = m),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected == m
                            ? AppTheme.primaryBlue
                            : busy
                            ? AppTheme.borderGrey
                            : AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected == m
                              ? AppTheme.primaryBlue
                              : busy
                              ? AppTheme.textLight
                              : AppTheme.borderGrey,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$m',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: selected == m
                                    ? Colors.white
                                    : busy
                                    ? AppTheme.textSecondary
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            if (busy)
                              const Text(
                                'Busy',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selected != null
                  ? () {
                      Navigator.pop(context);
                      onAssign(selected!);
                    }
                  : null,
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Production Entry Tab ──────────────────────────────────────
class _ProductionEntryTab extends StatefulWidget {
  final List<ProductionEntry> entries;
  final List<InventoryItem> inventory;
  final List<Product> products;
  final VoidCallback onSaved;

  const _ProductionEntryTab({
    super.key,
    required this.entries,
    required this.inventory,
    required this.products,
    required this.onSaved,
  });

  @override
  State<_ProductionEntryTab> createState() => _ProductionEntryTabState();
}

class _ProductionEntryTabState extends State<_ProductionEntryTab> {
  final _formKey = GlobalKey<FormState>();
  Product? _selectedProduct;
  String? _selectedBrand;
  String? _selectedColor;
  int? _machine;
  final _producedCtrl = TextEditingController();
  final _rejectedCtrl = TextEditingController(text: '0');
  final _mixedCtrl = TextEditingController(text: '0');
  bool _saving = false;

  int get _produced => int.tryParse(_producedCtrl.text) ?? 0;
  int get _rejected => int.tryParse(_rejectedCtrl.text) ?? 0;
  int get _mixed => int.tryParse(_mixedCtrl.text) ?? 0;
  int get _net => (_produced - _rejected - _mixed).clamp(0, 99999);

  Map<String, List<String>> get _brandOptions {
    final product = _selectedProduct;
    if (product == null) return const {};
    if (product.brandOptions.isNotEmpty) return product.brandOptions;
    return {product.brand: product.colors};
  }

  List<String> get _availableColors {
    if (_selectedBrand == null) return const [];
    return _brandOptions[_selectedBrand] ?? const [];
  }

  Map<String, List<String>> _brandOptionsFor(Product product) {
    if (product.brandOptions.isNotEmpty) return product.brandOptions;
    return {product.brand: product.colors};
  }

  Product? _productForEntry(ProductionEntry entry) {
    for (final product in widget.products) {
      if (product.id == entry.productId) return product;
    }
    for (final product in widget.products) {
      if (product.name.toLowerCase() == entry.productName.toLowerCase()) {
        return product;
      }
    }
    return null;
  }

  String _qtyLabel(double value, String unit) {
    final qty = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$qty $unit'.trim();
  }

  Future<bool> _ensureRawMaterialAvailable() async {
    final check = await ApiService.checkRawMaterialAvailability(
      brand: _selectedBrand!,
      color: _selectedColor!,
    );

    if (!mounted) return false;
    if (check == null) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.lastError ?? 'Raw material check failed'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return false;
    }

    if (check.ok) return true;

    setState(() => _saving = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Raw Material Shortage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add these materials in GRN before production entry:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ...check.shortages.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppTheme.warningAmber,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${item.materialName}: need ${_qtyLabel(item.requiredQty, item.unit)}, available ${item.availableQty.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RMHome(
                    initialTab: 1,
                    initialColor: _selectedColor,
                    initialRequirements: check.requirements,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Go to GRN'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_machine == null ||
        _selectedProduct == null ||
        _selectedBrand == null ||
        _selectedColor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill all fields'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }
    if (_net <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Net production must be greater than 0'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final rawMaterialOk = await _ensureRawMaterialAvailable();
    if (!rawMaterialOk) return;

    final entry = ProductionEntry(
      id: 'PE${DateTime.now().millisecondsSinceEpoch}',
      machineNumber: _machine!,
      productId: _selectedProduct!.id,
      productName: _selectedProduct!.name,
      brand: _selectedBrand!,
      color: _selectedColor!,
      producedQty: _produced,
      rejectedQty: _rejected,
      mixedColorQty: _mixed,
      date: DateTime.now(),
    );

    final saved = await ApiService.createProductionEntry(entry);

    if (!saved) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.lastError ??
                'Production entry failed. Inventory not updated.',
          ),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    setState(() => _saving = false);
    widget.onSaved();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Production logged: $_net net pieces — Inventory updated!',
          ),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      setState(() {
        _selectedProduct = null;
        _selectedBrand = null;
        _selectedColor = null;
        _machine = null;
        _producedCtrl.clear();
        _rejectedCtrl.text = '0';
        _mixedCtrl.text = '0';
      });
    }
  }

  Future<void> _showEditEntryDialog(ProductionEntry entry) async {
    final formKey = GlobalKey<FormState>();
    final products = List<Product>.from(widget.products)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    Product? selectedProduct = _productForEntry(entry);
    String? selectedBrand = entry.brand;
    String? selectedColor = entry.color;
    int? machine = entry.machineNumber;
    final producedCtrl = TextEditingController(
      text: entry.producedQty.toString(),
    );
    final rejectedCtrl = TextEditingController(
      text: entry.rejectedQty.toString(),
    );
    final mixedCtrl = TextEditingController(
      text: entry.mixedColorQty.toString(),
    );
    bool saving = false;

    int netQty() {
      final produced = int.tryParse(producedCtrl.text) ?? 0;
      final rejected = int.tryParse(rejectedCtrl.text) ?? 0;
      final mixed = int.tryParse(mixedCtrl.text) ?? 0;
      return produced - rejected - mixed;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDState) {
          final brandOptions = selectedProduct == null
              ? <String, List<String>>{}
              : _brandOptionsFor(selectedProduct!);
          final colors = selectedBrand == null
              ? const <String>[]
              : brandOptions[selectedBrand] ?? const <String>[];

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: const Text('Edit Production Entry'),
            content: SizedBox(
              width: 430,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: machine,
                        decoration: const InputDecoration(
                          labelText: 'Machine',
                          prefixIcon: Icon(Icons.precision_manufacturing),
                        ),
                        items: List.generate(
                          15,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text('Machine ${i + 1}'),
                          ),
                        ),
                        onChanged: saving
                            ? null
                            : (v) => setDState(() => machine = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Product>(
                        value: selectedProduct,
                        decoration: const InputDecoration(
                          labelText: 'Product',
                          prefixIcon: Icon(Icons.chair_outlined),
                        ),
                        items: products
                            .map(
                              (product) => DropdownMenuItem(
                                value: product,
                                child: Text(
                                  product.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (product) => setDState(() {
                                selectedProduct = product;
                                final options = product == null
                                    ? <String, List<String>>{}
                                    : _brandOptionsFor(product);
                                selectedBrand = options.keys.isEmpty
                                    ? null
                                    : options.keys.first;
                                selectedColor = null;
                              }),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: brandOptions.containsKey(selectedBrand)
                            ? selectedBrand
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Brand',
                          prefixIcon: Icon(Icons.local_offer_outlined),
                        ),
                        items: brandOptions.keys
                            .map(
                              (brand) => DropdownMenuItem(
                                value: brand,
                                child: Text(brand),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (brand) => setDState(() {
                                selectedBrand = brand;
                                selectedColor = null;
                              }),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: colors.contains(selectedColor)
                            ? selectedColor
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Color',
                          prefixIcon: Icon(Icons.palette_outlined),
                        ),
                        items: colors
                            .map(
                              (color) => DropdownMenuItem(
                                value: color,
                                child: Text(color),
                              ),
                            )
                            .toList(),
                        onChanged: saving
                            ? null
                            : (color) => setDState(() => selectedColor = color),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: producedCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Produced',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => setDState(() {}),
                              validator: (v) =>
                                  (int.tryParse(v ?? '') ?? 0) <= 0
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: rejectedCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Rejected',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => setDState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: mixedCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Mixed',
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (_) => setDState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGreen,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.successGreen),
                        ),
                        child: Text(
                          '${netQty()} net pcs',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (netQty() <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Net production must be greater than 0',
                              ),
                              backgroundColor: AppTheme.warningAmber,
                            ),
                          );
                          return;
                        }
                        setDState(() => saving = true);
                        final product = selectedProduct!;
                        final updated = ProductionEntry(
                          id: entry.id,
                          machineNumber: machine!,
                          productId: product.id,
                          productName: product.name,
                          brand: selectedBrand!,
                          color: selectedColor!,
                          producedQty: int.parse(producedCtrl.text),
                          rejectedQty: int.tryParse(rejectedCtrl.text) ?? 0,
                          mixedColorQty: int.tryParse(mixedCtrl.text) ?? 0,
                          date: entry.date,
                        );
                        final ok = await ApiService.updateProductionEntry(
                          updated,
                        );
                        if (!mounted ||
                            !context.mounted ||
                            !dialogContext.mounted) {
                          return;
                        }
                        if (ok) {
                          Navigator.pop(dialogContext);
                          widget.onSaved();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Production entry updated. Inventory refreshed.',
                              ),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                        } else {
                          setDState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ApiService.lastError ??
                                    'Production entry update failed',
                              ),
                              backgroundColor: AppTheme.dangerRed,
                            ),
                          );
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );

    producedCtrl.dispose();
    rejectedCtrl.dispose();
    mixedCtrl.dispose();
  }

  Future<void> _deleteEntry(ProductionEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Production Entry?'),
        content: Text(
          '${entry.productName} ${entry.brand} ${entry.color} ka ${entry.netQty} net pcs entry delete hoga. Inventory and raw material stock reverse ho jayega.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final ok = await ApiService.deleteProductionEntry(entry.id);
    if (!mounted) return;
    if (ok) {
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Production entry deleted. Inventory refreshed.'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.lastError ?? 'Production entry delete failed',
          ),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  void dispose() {
    _producedCtrl.dispose();
    _rejectedCtrl.dispose();
    _mixedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedProducts = List<Product>.from(widget.products)
      ..sort((a, b) {
        final nameCompare = a.name.toLowerCase().compareTo(
          b.name.toLowerCase(),
        );
        if (nameCompare != 0) return nameCompare;
        return a.brand.toLowerCase().compareTo(b.brand.toLowerCase());
      });

    final allEntries = List<ProductionEntry>.from(widget.entries)
      ..sort((a, b) => b.date.compareTo(a.date));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Production Entry',
              subtitle: 'Log output for a production run',
            ),
            const SizedBox(height: 16),

            // Machine Number
            FormFieldWrapper(
              label: 'Machine Number',
              child: DropdownButtonFormField<int>(
                value: _machine,
                hint: const Text('Select machine'),
                items: List.generate(
                  15,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text('Machine ${i + 1}'),
                  ),
                ),
                onChanged: (v) => setState(() => _machine = v),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.borderGrey),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.borderGrey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryBlue,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 14),

            // Product Dropdown — catalog se saare products
            const Text(
              'Product',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<Product>(
              value: _selectedProduct,
              hint: const Text('Select product'),
              items: sortedProducts.map((p) {
                return DropdownMenuItem<Product>(
                  value: p,
                  child: Text(
                    '${p.name} (${p.brand})',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() {
                _selectedProduct = v;
                _selectedBrand = v?.brandOptions.isNotEmpty == true
                    ? v!.brandOptions.keys.first
                    : v?.brand;
                _selectedColor = null;
              }),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.borderGrey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.borderGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryBlue,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 14),

            // Color Selection — product ke colors
            if (_selectedProduct != null) ...[
              const Text(
                'Brand',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _brandOptions.keys.map((brand) {
                  final sel = _selectedBrand == brand;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedBrand = brand;
                      _selectedColor = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primaryBlue : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel
                              ? AppTheme.primaryBlue
                              : AppTheme.borderGrey,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        brand,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              const Text(
                'Color',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableColors.map((c) {
                  final sel = _selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? AppTheme.primaryBlue : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel
                              ? AppTheme.primaryBlue
                              : AppTheme.borderGrey,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Auto-filled info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.chipBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Brand',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            _selectedBrand!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Category',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            _selectedProduct!.category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_selectedColor != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Color',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              _selectedColor!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppTheme.successGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Quantities
            const Text(
              'Quantities',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: FormFieldWrapper(
                    label: 'Produced',
                    child: TextFormField(
                      controller: _producedCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                          (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Required' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FormFieldWrapper(
                    label: 'Rejected',
                    child: TextFormField(
                      controller: _rejectedCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FormFieldWrapper(
                    label: 'Mixed Color',
                    child: TextFormField(
                      controller: _mixedCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Net Production
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.successGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Net Production',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Produced − Rejected − Mixed',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$_net pcs',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.successGreen,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text(
                  'Save Production Entry',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),

            const SizedBox(height: 28),
            const SectionHeader(
              title: 'All Entries',
              subtitle: 'Edit or delete wrong production logs',
            ),
            const SizedBox(height: 12),
            if (allEntries.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No Production Entries',
                subtitle: 'Production logs will appear here',
              )
            else
              ...allEntries.map(
                (entry) => _EntryRow(
                  entry: entry,
                  onEdit: () => _showEditEntryDialog(entry),
                  onDelete: () => _deleteEntry(entry),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final ProductionEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _EntryRow({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM, hh:mm a');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderGrey),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.chipBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'M${entry.machineNumber}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  '${entry.brand} • ${entry.color}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  fmt.format(entry.date),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.netQty} net',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppTheme.successGreen,
                ),
              ),
              Text(
                '${entry.producedQty} − ${entry.rejectedQty} − ${entry.mixedColorQty}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
              ),
            ],
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppTheme.dangerRed,
                    ),
                    SizedBox(width: 8),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
