import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../widgets/widgets.dart';
import 'package:intl/intl.dart';

// ── Raw Material Home ─────────────────────────────────────────
class RMHome extends StatefulWidget {
  const RMHome({super.key});

  @override
  State<RMHome> createState() => _RMHomeState();
}

class _RMHomeState extends State<RMHome> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<RawMaterial> _materials = [];
  List<GRNEntry> _grnEntries = [];
  bool _loading = true;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    // Tab switch hone pe reload karo
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        _loadAll();
      }
    });
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.getRawMaterials(),
      ApiService.getGRNEntries(),
    ]);
    if (mounted) {
      setState(() {
        _materials = results[0] as List<RawMaterial>;
        _grnEntries = results[1] as List<GRNEntry>;
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
    final lowCount =
        _materials.where((m) => m.stockStatus != StockStatus.available).length;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWhite,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Raw Materials'),
            Text('Godown Operator',
                style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          NotificationButton(count: lowCount),
          const SizedBox(width: 4)
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF94A3B8),
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Stock View'),
            Tab(text: 'GRN Entry'),
            Tab(text: 'GRN History'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabCtrl,
        children: [
          _StockViewTab(
            key: ValueKey(_refreshKey),
            materials: _materials,
            onRefresh: _loadAll,
          ),
          _GRNEntryTab(
            materials: _materials,
            onSaved: () async {
              await _loadAll(); // ✅ GRN save hone ke baad reload
              // Stock View tab pe jaao automatically
              _tabCtrl.animateTo(2); // GRN History tab
            },
          ),
          _GRNHistoryTab(
            key: ValueKey(_refreshKey + 100),
            entries: _grnEntries,
            onRefresh: _loadAll,
          ),
        ],
      ),
    );
  }
}

// ── Stock View Tab ────────────────────────────────────────────
class _StockViewTab extends StatefulWidget {
  final List<RawMaterial> materials;
  final VoidCallback onRefresh;
  const _StockViewTab(
      {super.key, required this.materials, required this.onRefresh});

  @override
  State<_StockViewTab> createState() => _StockViewTabState();
}

class _StockViewTabState extends State<_StockViewTab> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final allMaterials = widget.materials;
    final materials = _filter == 'All'
        ? allMaterials
        : _filter == 'Low'
        ? allMaterials
        .where((m) => m.stockStatus != StockStatus.available)
        .toList()
        : allMaterials
        .where((m) => m.stockStatus == StockStatus.available)
        .toList();

    final criticalCount = allMaterials
        .where((m) => m.stockStatus == StockStatus.critical)
        .length;
    final lowCount =
        allMaterials.where((m) => m.stockStatus == StockStatus.low).length;

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (criticalCount + lowCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: criticalCount > 0
                      ? AppTheme.lightRed
                      : AppTheme.lightAmber,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: criticalCount > 0
                        ? AppTheme.dangerRed.withOpacity(0.3)
                        : AppTheme.warningAmber.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      criticalCount > 0
                          ? Icons.error_rounded
                          : Icons.warning_rounded,
                      color: criticalCount > 0
                          ? AppTheme.dangerRed
                          : AppTheme.warningAmber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        criticalCount > 0
                            ? '$criticalCount materials critically low! $lowCount below minimum.'
                            : '$lowCount materials below minimum stock level.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: criticalCount > 0
                              ? AppTheme.dangerRed
                              : AppTheme.warningAmber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            Row(
              children: [
                _FilterChip(
                    label: 'All',
                    count: allMaterials.length,
                    selected: _filter == 'All',
                    onTap: () => setState(() => _filter = 'All')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Low',
                    count: lowCount + criticalCount,
                    selected: _filter == 'Low',
                    onTap: () => setState(() => _filter = 'Low'),
                    color: AppTheme.dangerRed),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'OK',
                    count: allMaterials.length - lowCount - criticalCount,
                    selected: _filter == 'OK',
                    onTap: () => setState(() => _filter = 'OK'),
                    color: AppTheme.successGreen),
              ],
            ),
            const SizedBox(height: 14),

            ...materials.map((m) => _RMDetailCard(material: m)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip(
      {required this.label,
        required this.count,
        required this.selected,
        required this.onTap,
        this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryBlue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppTheme.borderGrey),
        ),
        child: Text('$label ($count)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppTheme.textSecondary)),
      ),
    );
  }
}

class _RMDetailCard extends StatelessWidget {
  final RawMaterial material;
  const _RMDetailCard({required this.material});

  @override
  Widget build(BuildContext context) {
    final isLow = material.stockStatus != StockStatus.available;
    final isCritical = material.stockStatus == StockStatus.critical;
    final color = isCritical
        ? AppTheme.dangerRed
        : isLow
        ? AppTheme.warningAmber
        : AppTheme.successGreen;
    final pct = material.stockPercentage;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCritical
              ? AppTheme.dangerRed.withOpacity(0.4)
              : isLow
              ? AppTheme.warningAmber.withOpacity(0.4)
              : AppTheme.borderGrey,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimary)),
                    Text(material.supplier,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${material.currentStockKg.toStringAsFixed(0)} kg',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: color,
                          letterSpacing: -0.5)),
                  Text('Min: ${material.minimumStockKg.toStringAsFixed(0)} kg',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.textLight)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppTheme.borderGrey,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── GRN Entry Tab ─────────────────────────────────────────────
class _GRNEntryTab extends StatefulWidget {
  final List<RawMaterial> materials;
  final VoidCallback onSaved;
  const _GRNEntryTab({required this.materials, required this.onSaved});

  @override
  State<_GRNEntryTab> createState() => _GRNEntryTabState();
}

class _GRNEntryTabState extends State<_GRNEntryTab> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMaterial;
  String? _selectedSupplier;
  final _bagsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  bool _saving = false;

  int get _bags => int.tryParse(_bagsCtrl.text) ?? 0;
  double get _weight => double.tryParse(_weightCtrl.text) ?? 0;
  double get _total => _bags * _weight;

  String get _grnId =>
      'GRN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

  Future<void> _saveGRN() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMaterial == null || _selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Select material and supplier'),
            backgroundColor: AppTheme.dangerRed),
      );
      return;
    }

    setState(() => _saving = true);

    final mat =
    widget.materials.firstWhere((m) => m.name == _selectedMaterial);

    final grn = GRNEntry(
      id: _grnId,
      materialId: mat.id,
      materialName: mat.name,
      supplier: _selectedSupplier!,
      numBags: _bags,
      weightPerBag: _weight,
      date: DateTime.now(),
    );

    final success = await ApiService.createGRNEntry(grn);
    setState(() => _saving = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'GRN saved: ${grn.totalWeight.toStringAsFixed(0)} kg added'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      setState(() {
        _selectedMaterial = null;
        _selectedSupplier = null;
        _bagsCtrl.clear();
        _weightCtrl.clear();
      });
      widget.onSaved(); // ✅ parent ko reload karo
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error saving GRN'),
            backgroundColor: AppTheme.dangerRed),
      );
    }
  }

  @override
  void dispose() {
    _bagsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialNames = widget.materials.map((m) => m.name).toList();
    const suppliers = [
      'Gupta Polymers',
      'Shah Industries',
      'Chem Solutions',
      'Colortech',
      'Reliance Polymers',
      'ABC Chemicals',
      'Global Additives',
      'Metro Plastics',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'GRN Entry',
              subtitle: 'Record inward raw material receipt',
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.chipBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt,
                      size: 16, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Text('GRN ID: $_grnId',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppTheme.primaryBlue)),
                  const Spacer(),
                  Text(DateFormat('dd MMM yyyy').format(DateTime.now()),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            AppDropdown(
              label: 'Material Type',
              value: _selectedMaterial,
              hint: 'Select raw material',
              items: materialNames,
              onChanged: (v) => setState(() {
                _selectedMaterial = v;
                if (v != null) {
                  final mat =
                  widget.materials.firstWhere((m) => m.name == v);
                  _selectedSupplier = mat.supplier;
                }
              }),
            ),
            const SizedBox(height: 14),

            AppDropdown(
              label: 'Supplier',
              value: _selectedSupplier,
              hint: 'Select supplier',
              items: suppliers,
              onChanged: (v) => setState(() => _selectedSupplier = v),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: FormFieldWrapper(
                    label: 'Number of Bags',
                    child: TextFormField(
                      controller: _bagsCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                      (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Required' : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FormFieldWrapper(
                    label: 'Weight / Bag (kg)',
                    child: TextFormField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                      validator: (v) =>
                      (double.tryParse(v ?? '') ?? 0) <= 0
                          ? 'Required'
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.successGreen.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Weight',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textSecondary)),
                  Text('${_total.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: AppTheme.successGreen,
                          letterSpacing: -0.5)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveGRN,
                icon: _saving
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_circle_outline),
                label: const Text('Save GRN',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── GRN History Tab ───────────────────────────────────────────
class _GRNHistoryTab extends StatelessWidget {
  final List<GRNEntry> entries;
  final VoidCallback onRefresh;
  const _GRNHistoryTab(
      {super.key, required this.entries, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');

    if (entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            EmptyState(
                icon: Icons.history,
                title: 'No GRN Records',
                subtitle: 'GRN entries will appear here'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: entries.length,
        itemBuilder: (_, i) {
          final g = entries[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderGrey),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.inventory_rounded,
                      color: AppTheme.successGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.materialName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.textPrimary)),
                      Text('${g.supplier} • ${fmt.format(g.date)}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${g.totalWeight.toStringAsFixed(0)} kg',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppTheme.successGreen)),
                    Text('${g.numBags} bags',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textLight)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
