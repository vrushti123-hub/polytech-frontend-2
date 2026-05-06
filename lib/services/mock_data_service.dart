import '../models/models.dart';
import '../src/data/catalog_data.dart';

/// MockDataService — in-memory store that simulates the backend.
/// Replace individual methods with real HTTP calls when the API is ready.
class MockDataService {
  // ── Singleton ─────────────────────────────────────────────
  static final MockDataService _i = MockDataService._();
  factory MockDataService() => _i;
  MockDataService._();

  // ── Current User ─────────────────────────────────────────
  User? currentUser;

  final List<User> _users = [
    const User(id: 'u1', name: 'Sagar Mandhan',                 mobile: '9876500001', role: UserRole.owner,        username: 'owner',              password: 'owner123'),
    const User(id: 'u2', name: 'Wasim Khan',                    mobile: '9876500002', role: UserRole.dispatch,     username: 'dispatch',           password: 'dispatch123'),
    const User(id: 'u3', name: 'Ramesh Supervisor',             mobile: '9876500003', role: UserRole.supervisor,   username: 'supervisor',         password: 'super123'),
    const User(id: 'u4', name: 'Mixing Operator',               mobile: '9876500004', role: UserRole.operator,     username: 'operator',           password: 'oper123'),
    const User(id: 'd1', name: 'Ravi Enterprises - Nashik',     mobile: '9876501001', role: UserRole.distributor,  username: 'ravi.nashik',        password: 'dist123'),
    const User(id: 'd2', name: 'Shree Traders - Pune',          mobile: '9876501002', role: UserRole.distributor,  username: 'shree.pune',         password: 'dist123'),
    const User(id: 'd3', name: 'Ganesh Wholesale - Aurangabad', mobile: '9876501003', role: UserRole.distributor,  username: 'ganesh.aurangabad',  password: 'dist123'),
  ];

  User? login(String username, String password) {
    try {
      currentUser = _users.firstWhere(
            (u) => u.username == username.trim().toLowerCase() && u.password == password,
      );
      return currentUser;
    } catch (_) {
      return null;
    }
  }

  // ── Products ──────────────────────────────────────────────
  late final List<Product> _products = _buildProducts();

  List<Product> getProducts({String? category, String? brand}) {
    return _products.where((p) {
      if (category != null && p.category != category) return false;
      if (brand != null && p.brand != brand) return false;
      return p.isActive;
    }).toList();
  }

  List<String> getCategories() =>
      _products.map((p) => p.category).toSet().toList();

  // ── Inventory ─────────────────────────────────────────────
  late final List<InventoryItem> _inventory = _buildInventory();

  List<InventoryItem> getInventory() => List.from(_inventory);

  int getStock(String productId, String brand, String color) {
    try {
      final item = _inventory.firstWhere((i) =>
          i.productId == productId && i.brand == brand && i.color == color);
      return item.currentStock;
    } catch (_) {
      return 0;
    }
  }

  // ── Orders ────────────────────────────────────────────────
  late final List<Order> _orders = _buildInitialOrders();

  List<Order> getOrders({String? distributorId}) {
    if (distributorId != null) {
      return _orders.where((o) => o.distributorId == distributorId).toList();
    }
    return List.from(_orders);
  }

  void addOrder(Order order) => _orders.insert(0, order);

  String generateOrderId() => 'ORD-${(100 + _orders.length).toString().padLeft(3, '0')}';

  // ── Production Tasks ──────────────────────────────────────
  final List<ProductionTask> _tasks = [
    ProductionTask(id: 'T001', productId: 'p1', productName: 'Polo Chair', brand: 'Polish', color: 'Beige', requiredQty: 1000, status: 'pending'),
    ProductionTask(id: 'T002', productId: 'p5', productName: 'Kids Chair', brand: 'Polytech', color: 'Yellow', requiredQty: 500, assignedMachine: 7, status: 'in_progress'),
    ProductionTask(id: 'T003', productId: 'p10', productName: 'Center Table 3ft', brand: 'Polish', color: 'Black', requiredQty: 200, status: 'pending'),
    ProductionTask(id: 'T004', productId: 'p2', productName: 'Executive Chair', brand: 'Polytech', color: 'Beige', requiredQty: 800, status: 'pending'),
  ];

  List<ProductionTask> getTasks() => List.from(_tasks);

  void addTask(ProductionTask task) => _tasks.add(task);

  // ── Production Entries ────────────────────────────────────
  final List<ProductionEntry> _entries = [
    ProductionEntry(id: 'PE001', machineNumber: 3, productId: 'p1', productName: 'Polo Chair', brand: 'Polish', color: 'Black', producedQty: 480, rejectedQty: 12, mixedColorQty: 0, date: DateTime.now()),
    ProductionEntry(id: 'PE002', machineNumber: 7, productId: 'p5', productName: 'Kids Chair', brand: 'Polytech', color: 'Yellow', producedQty: 250, rejectedQty: 8, mixedColorQty: 2, date: DateTime.now()),
    ProductionEntry(id: 'PE003', machineNumber: 14, productId: 'p3', productName: 'Budget Chair', brand: 'Shital', color: 'Black', producedQty: 610, rejectedQty: 18, mixedColorQty: 0, date: DateTime.now()),
    ProductionEntry(id: 'PE004', machineNumber: 22, productId: 'p12', productName: 'Folding Chair', brand: 'Polytech', color: 'Beige', producedQty: 420, rejectedQty: 15, mixedColorQty: 5, date: DateTime.now()),
  ];

  List<ProductionEntry> getEntries() => List.from(_entries);
  void addEntry(ProductionEntry e) => _entries.insert(0, e);

  int get todayProduction => _entries
      .where((e) => e.date.day == DateTime.now().day)
      .fold(0, (s, e) => s + e.netQty);

  // ── Raw Materials ─────────────────────────────────────────
  final List<RawMaterial> _rawMaterials = [
    RawMaterial(id: 'rm1', name: 'Rafia (Recycled Plastic)', supplier: 'Gupta Polymers', currentStockKg: 8200, minimumStockKg: 3000),
    RawMaterial(id: 'rm2', name: 'FC (Filler Component)', supplier: 'Shah Industries', currentStockKg: 1800, minimumStockKg: 2000),
    RawMaterial(id: 'rm3', name: 'FC Grade-2', supplier: 'Shah Industries', currentStockKg: 2200, minimumStockKg: 1500),
    RawMaterial(id: 'rm4', name: 'Moisture Absorber', supplier: 'Chem Solutions', currentStockKg: 380, minimumStockKg: 400),
    RawMaterial(id: 'rm5', name: 'Masterbatch Black', supplier: 'Colortech', currentStockKg: 120, minimumStockKg: 100),
    RawMaterial(id: 'rm6', name: 'Masterbatch Beige', supplier: 'Colortech', currentStockKg: 85, minimumStockKg: 100),
    RawMaterial(id: 'rm7', name: 'Masterbatch Red', supplier: 'Colortech', currentStockKg: 60, minimumStockKg: 100),
    RawMaterial(id: 'rm8', name: 'Masterbatch White', supplier: 'Colortech', currentStockKg: 110, minimumStockKg: 100),
    RawMaterial(id: 'rm9', name: 'Masterbatch Yellow', supplier: 'Colortech', currentStockKg: 45, minimumStockKg: 80),
    RawMaterial(id: 'rm10', name: 'Stabilizer UV', supplier: 'Chem Solutions', currentStockKg: 220, minimumStockKg: 200),
    RawMaterial(id: 'rm11', name: 'Antioxidant Additive', supplier: 'Chem Solutions', currentStockKg: 180, minimumStockKg: 150),
    RawMaterial(id: 'rm12', name: 'HDPE Granules', supplier: 'Reliance Polymers', currentStockKg: 5500, minimumStockKg: 2000),
    RawMaterial(id: 'rm13', name: 'PP Homopolymer', supplier: 'Reliance Polymers', currentStockKg: 3200, minimumStockKg: 1500),
    RawMaterial(id: 'rm14', name: 'Impact Modifier', supplier: 'Gupta Polymers', currentStockKg: 650, minimumStockKg: 500),
  ];

  List<RawMaterial> getRawMaterials() => List.from(_rawMaterials);

  List<RawMaterial> getLowStockMaterials() =>
      _rawMaterials.where((m) => m.stockStatus != StockStatus.available).toList();

  final List<GRNEntry> _grnEntries = [];
  List<GRNEntry> getGRNEntries() => List.from(_grnEntries);
  void addGRN(GRNEntry grn) {
    _grnEntries.insert(0, grn);
    final idx = _rawMaterials.indexWhere((m) => m.id == grn.materialId);
    if (idx >= 0) _rawMaterials[idx].currentStockKg += grn.totalWeight;
  }

  String get grnId => 'GRN-${(1000 + _grnEntries.length).toString()}';

  // ── Dashboard Stats ───────────────────────────────────────
  DashboardStats get dashboardStats => DashboardStats(
        pendingOrders: _orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.partial).length,
        dispatchedToday: _orders.where((o) => o.status == OrderStatus.dispatched).length,
        todayProduction: todayProduction,
        activeMachines: _entries.map((e) => e.machineNumber).toSet().length,
        lowStockAlerts: getLowStockMaterials().length,
        totalDistributors: 37,
      );

  // ── BOM ───────────────────────────────────────────────────
  Map<String, List<BomItem>> get bomFormulas => {
    'default_600kg': [
      const BomItem(materialId: 'rm1', materialName: 'Rafia (Recycled Plastic)', qtyPerBatch: 400),
      const BomItem(materialId: 'rm2', materialName: 'FC (Filler Component)', qtyPerBatch: 100),
      const BomItem(materialId: 'rm3', materialName: 'FC Grade-2', qtyPerBatch: 100),
      const BomItem(materialId: 'rm4', materialName: 'Moisture Absorber', qtyPerBatch: 12),
      const BomItem(materialId: 'rm5', materialName: 'Masterbatch Black', qtyPerBatch: 6),
    ],
  };

  List<Product> _buildProducts() {
    final products = <Product>[];
    var productCounter = 1;

    for (final category in catalogCategories) {
      for (final subProduct in category.subCategories) {
        products.add(
          Product(
            id: 'p${productCounter.toString().padLeft(3, '0')}',
            name: subProduct.name,
            category: category.name,
            brand: 'Polytech',
            colors: [_extractColor(subProduct.name)],
            imageUrl: subProduct.imagePath,
          ),
        );
        productCounter++;
      }
    }

    return products;
  }

  List<InventoryItem> _buildInventory() {
    final inventory = <InventoryItem>[];

    for (var i = 0; i < _products.length; i++) {
      final product = _products[i];
      final totalProduced = 600 + (i * 25);
      final totalDispatched = i.isEven ? 200 + (i * 10) : 120 + (i * 8);

      inventory.add(
        InventoryItem(
          productId: product.id,
          productName: product.name,
          brand: product.brand,
          color: product.colors.first,
          totalProduced: totalProduced,
          totalDispatched: totalDispatched > totalProduced
              ? totalProduced - 20
              : totalDispatched,
        ),
      );
    }

    return inventory;
  }

  String _extractColor(String productName) {
    final match = RegExp(r'\(([^)]+)\)').firstMatch(productName);
    return match?.group(1) ?? 'Standard';
  }

  List<Order> _buildInitialOrders() {
    if (_products.length < 4) {
      return <Order>[];
    }

    return [
      Order(
        id: 'ORD-001',
        distributorId: 'd1',
        distributorName: 'Ravi Enterprises',
        distributorCity: 'Nashik',
        orderDate: DateTime.now().subtract(const Duration(hours: 2)),
        status: OrderStatus.pending,
        items: [
          OrderItem(
            productId: _products[0].id,
            productName: _products[0].name,
            brand: _products[0].brand,
            color: _products[0].colors.first,
            quantity: 120,
            stockAvailable: true,
          ),
          OrderItem(
            productId: _products[1].id,
            productName: _products[1].name,
            brand: _products[1].brand,
            color: _products[1].colors.first,
            quantity: 80,
            stockAvailable: true,
          ),
        ],
      ),
      Order(
        id: 'ORD-002',
        distributorId: 'd2',
        distributorName: 'Shree Traders',
        distributorCity: 'Pune',
        orderDate: DateTime.now().subtract(const Duration(hours: 5)),
        status: OrderStatus.approved,
        items: [
          OrderItem(
            productId: _products[2].id,
            productName: _products[2].name,
            brand: _products[2].brand,
            color: _products[2].colors.first,
            quantity: 50,
            stockAvailable: true,
          ),
        ],
      ),
      Order(
        id: 'ORD-003',
        distributorId: 'd3',
        distributorName: 'Ganesh Wholesale',
        distributorCity: 'Aurangabad',
        orderDate: DateTime.now().subtract(const Duration(hours: 8)),
        status: OrderStatus.dispatched,
        items: [
          OrderItem(
            productId: _products[3].id,
            productName: _products[3].name,
            brand: _products[3].brand,
            color: _products[3].colors.first,
            quantity: 35,
            dispatchedQty: 35,
            stockAvailable: true,
          ),
        ],
      ),
    ];
  }
}
