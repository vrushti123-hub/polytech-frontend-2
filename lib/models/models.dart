// ============================================================
// MODELS — Polytech ERP
// ============================================================

enum UserRole { distributor, dispatch, supervisor, operator, owner }

enum OrderStatus { pending, approved, partial, dispatched }

enum StockStatus { available, low, critical }

// ── User ────────────────────────────────────────────────────
class User {
  final String id;
  final String name;
  final String mobile;
  final UserRole role;
  final String username;
  final String password;

  const User({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.username,
    required this.password,
  });

  String get roleLabel {
    switch (role) {
      case UserRole.distributor:
        return 'Distributor';
      case UserRole.dispatch:
        return 'Dispatch Manager';
      case UserRole.supervisor:
        return 'Production Supervisor';
      case UserRole.operator:
        return 'RM Operator';
      case UserRole.owner:
        return 'Owner';
    }
  }
}

// ── Product & Catalog ────────────────────────────────────────
class Product {
  final String id;
  final String name;
  final String category;
  final String brand;
  final List<String> colors;
  final Map<String, List<String>> brandOptions;
  final String imageUrl;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.colors,
    this.brandOptions = const {},
    this.imageUrl = '',
    this.isActive = true,
  });
}

// ── Inventory ────────────────────────────────────────────────
class InventoryItem {
  final String productId;
  final String productName;
  final String brand;
  final String color;
  final int totalProduced;
  final int totalDispatched;

  const InventoryItem({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.color,
    required this.totalProduced,
    required this.totalDispatched,
  });

  int get currentStock => totalProduced - totalDispatched;
  bool get isAvailable => currentStock > 0;
}

// ── Order ────────────────────────────────────────────────────
// ── Order ────────────────────────────────────────────────────
class OrderItem {
  final String productId;
  final String productName;
  final String brand;
  final String color;
  final int quantity;
  int dispatchedQty;
  bool stockAvailable;
  List<int> dispatchHistory;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.color,
    required this.quantity,
    this.dispatchedQty = 0,
    this.stockAvailable = false,
    List<int>? dispatchHistory,
  }) : dispatchHistory = dispatchHistory ?? [];

  int get pendingQty => quantity - dispatchedQty;
}

class Order {
  final String id;
  final String distributorId;
  final String distributorName;
  final String distributorCity;
  final DateTime orderDate;
  OrderStatus status;
  final List<OrderItem> items;
  final String? remarks;

  Order({
    required this.id,
    required this.distributorId,
    required this.distributorName,
    required this.distributorCity,
    required this.orderDate,
    required this.status,
    required this.items,
    this.remarks,
  });

  int get totalPieces => items.fold(0, (sum, i) => sum + i.quantity);
  int get pendingPieces => items.fold(0, (sum, i) => sum + i.pendingQty);
  bool get hasStockShortage => items.any((i) => !i.stockAvailable);
}

// ── Production ────────────────────────────────────────────────
class ProductionTask {
  final String id;
  final String productId;
  final String productName;
  final String brand;
  final String color;
  final int requiredQty;
  int? assignedMachine;
  bool isCompleted;
  String status;

  ProductionTask({
    required this.id,
    required this.productId,
    required this.productName,
    required this.brand,
    required this.color,
    required this.requiredQty,
    this.assignedMachine,
    this.isCompleted = false,
    this.status = 'pending',
  });
}

class ProductionEntry {
  final String id;
  final int machineNumber;
  final String productId;
  final String productName;
  final String brand;
  final String color;
  final int producedQty;
  final int rejectedQty;
  final int mixedColorQty;
  final DateTime date;

  const ProductionEntry({
    required this.id,
    required this.machineNumber,
    required this.productId,
    required this.productName,
    required this.brand,
    required this.color,
    required this.producedQty,
    required this.rejectedQty,
    required this.mixedColorQty,
    required this.date,
  });

  int get netQty => producedQty - rejectedQty - mixedColorQty;
}

// ── Raw Material ─────────────────────────────────────────────
class RawMaterial {
  final String id;
  final String name;
  final String supplier;
  double currentStockKg;
  final double minimumStockKg;

  RawMaterial({
    required this.id,
    required this.name,
    required this.supplier,
    required this.currentStockKg,
    required this.minimumStockKg,
  });

  StockStatus get stockStatus {
    if (currentStockKg <= 0) return StockStatus.critical;
    if (currentStockKg < minimumStockKg) return StockStatus.low;
    return StockStatus.available;
  }

  double get stockPercentage =>
      (currentStockKg / (minimumStockKg * 3)).clamp(0.0, 1.0);
}

class GRNEntry {
  final String id;
  final String materialId;
  final String materialName;
  final String supplier;
  final int numBags;
  final double weightPerBag;
  final DateTime date;

  const GRNEntry({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.supplier,
    required this.numBags,
    required this.weightPerBag,
    required this.date,
  });

  double get totalWeight => numBags * weightPerBag;
}

// ── Dispatch / Challan ────────────────────────────────────────
class Challan {
  final String id;
  final String orderId;
  final String distributorName;
  final String distributorCity;
  final String vehicleNumber;
  final String driverName;
  final String driverPhone;
  final List<OrderItem> items;
  final DateTime dispatchDate;
  String? truckPhotoUrl;

  Challan({
    required this.id,
    required this.orderId,
    required this.distributorName,
    required this.distributorCity,
    required this.vehicleNumber,
    required this.driverName,
    required this.driverPhone,
    required this.items,
    required this.dispatchDate,
    this.truckPhotoUrl,
  });

  int get totalPieces => items.fold(0, (s, i) => s + i.quantity);
}

// ── BOM ──────────────────────────────────────────────────────
class BomItem {
  final String materialId;
  final String materialName;
  final double qtyPerBatch;

  const BomItem({
    required this.materialId,
    required this.materialName,
    required this.qtyPerBatch,
  });
}

// ── Dashboard Stats ──────────────────────────────────────────
class DashboardStats {
  final int pendingOrders;
  final int dispatchedToday;
  final int todayProduction;
  final int activeMachines;
  final int lowStockAlerts;
  final int totalDistributors;

  const DashboardStats({
    required this.pendingOrders,
    required this.dispatchedToday,
    required this.todayProduction,
    required this.activeMachines,
    required this.lowStockAlerts,
    required this.totalDistributors,
  });
}
