import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/widgets.dart';

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
  final VoidCallback onRefresh;
  const _TaskBoardTab({
    super.key,
    required this.tasks,
    required this.onRefresh,
  });

  @override
  State<_TaskBoardTab> createState() => _TaskBoardTabState();
}

class _TaskBoardTabState extends State<_TaskBoardTab> {
  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt,
        title: 'No Tasks',
        subtitle: 'All production tasks completed',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.tasks.length,
        itemBuilder: (_, i) => _TaskCard(
          task: widget.tasks[i],
          onAssign: (machine) async {
            await ApiService.updateProductionTask(
              widget.tasks[i].id,
              status: 'in_progress',
              assignedMachine: machine,
              isCompleted: false,
            );
            widget.onRefresh();
          },
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final ProductionTask task;
  final ValueChanged<int> onAssign;

  const _TaskCard({required this.task, required this.onAssign});

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
                  return GestureDetector(
                    onTap: () => setDState(() => selected = m),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected == m
                            ? AppTheme.primaryBlue
                            : AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected == m
                              ? AppTheme.primaryBlue
                              : AppTheme.borderGrey,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$m',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: selected == m
                                ? Colors.white
                                : AppTheme.textPrimary,
                          ),
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

    setState(() => _saving = true);

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

    await ApiService.createProductionEntry(entry);

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

    final todayEntries = widget.entries
        .where((e) => e.date.day == DateTime.now().day)
        .toList();

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
            const SectionHeader(title: "Today's Entries"),
            const SizedBox(height: 12),
            ...todayEntries.map((e) => _EntryRow(entry: e)),
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final ProductionEntry entry;
  const _EntryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
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
                '${entry.producedQty} − ${entry.rejectedQty}',
                style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
