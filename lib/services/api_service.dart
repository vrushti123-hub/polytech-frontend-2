import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000/api',
  );
  static String? lastError;
  static final Map<String, OrderStatus> _localOrderStatuses = {};
  static final Map<String, Challan> _localChallans = {};
  // ── Token ─────────────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Auth ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> login(
    String username,
    String password,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (res.statusCode == 200) return jsonDecode(res.body);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<User>> getDistributors() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/distributors'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((u) => _parseUser(u)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Orders ────────────────────────────────────────────────
  static Future<List<Order>> getOrders({String? distributorId}) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/orders'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final orders = data.map((o) => _parseOrder(o)).toList();
        for (final order in orders) {
          final localStatus = _localOrderStatuses[order.id];
          if (localStatus != null) order.status = localStatus;
        }
        if (distributorId != null) {
          return orders.where((o) => o.distributorId == distributorId).toList();
        }
        return orders;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> createOrder(Order order) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: await _headers(),
        body: jsonEncode({
          'id': order.id,
          'distributor_id': order.distributorId,
          'distributor_name': order.distributorName,
          'distributor_city': order.distributorCity,
          'order_date': order.orderDate.toIso8601String(),
          'status': order.status.name,
          'remarks': order.remarks,
          'items': order.items
              .map(
                (i) => {
                  'product_id': i.productId,
                  'product_name': i.productName,
                  'brand': i.brand,
                  'color': i.color,
                  'quantity': i.quantity,
                  'dispatched_qty': i.dispatchedQty,
                  'stock_available': i.stockAvailable,
                  'dispatch_history': i.dispatchHistory,
                },
              )
              .toList(),
        }),
      );
      return res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateOrderStatus(String orderId, String status) async {
    final localStatus = _parseOrderStatus(status);
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/orders/$orderId/status'),
        headers: await _headers(),
        body: jsonEncode({'status': status}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _localOrderStatuses[orderId] = localStatus;
        return true;
      }
      if (status == 'dispatched') {
        _localOrderStatuses[orderId] = localStatus;
      }
      return false;
    } catch (e) {
      if (status == 'dispatched') {
        _localOrderStatuses[orderId] = localStatus;
      }
      return false;
    }
  }

  // ── Inventory ─────────────────────────────────────────────
  static Future<List<InventoryItem>> getInventory() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/inventory'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((i) => _parseInventoryItem(i)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ── Production ────────────────────────────────────────────
  static Future<List<ProductionTask>> getProductionTasks() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/production/tasks'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((t) => _parseProductionTask(t)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> createProductionTask(ProductionTask task) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/production/tasks'),
        headers: await _headers(),
        body: jsonEncode({
          'id': task.id,
          'product_id': task.productId,
          'product_name': task.productName,
          'brand': task.brand,
          'color': task.color,
          'required_qty': task.requiredQty,
          'assigned_machine': task.assignedMachine,
          'status': task.status,
        }),
      );
      return res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateProductionTask(
    String taskId, {
    String? status,
    int? assignedMachine,
    bool? isCompleted,
  }) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/production/tasks/$taskId'),
        headers: await _headers(),
        body: jsonEncode({
          'status': status,
          'assigned_machine': assignedMachine,
          'is_completed': isCompleted,
        }),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<ProductionEntry>> getProductionEntries() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/production/entries'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((e) => _parseProductionEntry(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> createProductionEntry(ProductionEntry entry) async {
    try {
      lastError = null;
      final res = await http.post(
        Uri.parse('$baseUrl/production/entries'),
        headers: await _headers(),
        body: jsonEncode(_productionEntryBody(entry)),
      );
      if (res.statusCode == 201) return true;

      try {
        final body = jsonDecode(res.body);
        lastError = body['error']?.toString() ?? 'Production entry failed';
      } catch (_) {
        lastError = 'Production entry failed (${res.statusCode})';
      }
      return false;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  static Future<bool> updateProductionEntry(ProductionEntry entry) async {
    try {
      lastError = null;
      final res = await http.patch(
        Uri.parse('$baseUrl/production/entries/${entry.id}'),
        headers: await _headers(),
        body: jsonEncode(_productionEntryBody(entry)),
      );
      if (res.statusCode == 200) return true;

      try {
        final body = jsonDecode(res.body);
        lastError =
            body['error']?.toString() ?? 'Production entry update failed';
      } catch (_) {
        lastError = 'Production entry update failed (${res.statusCode})';
      }
      return false;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  static Future<bool> deleteProductionEntry(String entryId) async {
    try {
      lastError = null;
      final res = await http.delete(
        Uri.parse('$baseUrl/production/entries/$entryId'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) return true;

      try {
        final body = jsonDecode(res.body);
        lastError =
            body['error']?.toString() ?? 'Production entry delete failed';
      } catch (_) {
        lastError = 'Production entry delete failed (${res.statusCode})';
      }
      return false;
    } catch (e) {
      lastError = e.toString();
      return false;
    }
  }

  static Map<String, dynamic> _productionEntryBody(ProductionEntry entry) {
    return {
      'id': entry.id,
      'machine_number': entry.machineNumber,
      'product_id': entry.productId,
      'product_name': entry.productName,
      'brand': entry.brand,
      'color': entry.color,
      'produced_qty': entry.producedQty,
      'rejected_qty': entry.rejectedQty,
      'mixed_color_qty': entry.mixedColorQty,
      'date': entry.date.toIso8601String(),
    };
  }

  static Future<RawMaterialCheckResult?> checkRawMaterialAvailability({
    required String brand,
    required String color,
  }) async {
    try {
      lastError = null;
      final uri = Uri.parse(
        '$baseUrl/production/raw-check',
      ).replace(queryParameters: {'brand': brand, 'color': color});
      final res = await http.get(uri, headers: await _headers());
      if (res.statusCode == 200) {
        return _parseRawMaterialCheck(jsonDecode(res.body));
      }

      try {
        final body = jsonDecode(res.body);
        lastError = body['error']?.toString() ?? 'Raw material check failed';
      } catch (_) {
        lastError = 'Raw material check failed (${res.statusCode})';
      }
      return null;
    } catch (e) {
      lastError = e.toString();
      return null;
    }
  }

  // ── Raw Material ──────────────────────────────────────────
  static Future<List<RawMaterial>> getRawMaterials() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/rawmaterial'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((m) => _parseRawMaterial(m)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<GRNEntry>> getGRNEntries() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/rawmaterial/grn'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((g) => _parseGRNEntry(g)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> createGRNEntry(GRNEntry entry) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/rawmaterial/grn'),
        headers: await _headers(),
        body: jsonEncode({
          'id': entry.id,
          'material_id': entry.materialId,
          'material_name': entry.materialName,
          'supplier': entry.supplier,
          'num_bags': entry.numBags,
          'weight_per_bag': entry.weightPerBag,
          'date': entry.date.toIso8601String(),
        }),
      );
      return res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateRawMaterialStock(
    String materialId,
    double currentStockKg,
  ) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/rawmaterial/$materialId'),
        headers: await _headers(),
        body: jsonEncode({'current_stock_kg': currentStockKg}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateInventoryProduced(
    String productId,
    int netQty,
    String color,
  ) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/inventory/$productId/produced'),
        headers: await _headers(),
        body: jsonEncode({'net_qty': netQty, 'color': color}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> checkOrderStock(String orderId) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/orders/$orderId/check-stock'),
        headers: await _headers(),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> createInventoryItem({
    required String productId,
    required String productName,
    required String brand,
    required String color,
    required int totalProduced,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/inventory'),
        headers: await _headers(),
        body: jsonEncode({
          'id':
              '${productId}_${color}_${DateTime.now().millisecondsSinceEpoch}',
          'product_id': productId,
          'product_name': productName,
          'brand': brand,
          'color': color,
          'total_produced': totalProduced,
          'total_dispatched': 0,
        }),
      );
      return res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Product>> getProducts() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/products'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((p) => _parseProduct(p)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Product _parseProduct(Map<String, dynamic> p) {
    final rawBrandOptions = p['brand_options'];
    final brandOptions = <String, List<String>>{};

    if (rawBrandOptions is Map) {
      rawBrandOptions.forEach((key, value) {
        if (value is List) {
          brandOptions[key.toString()] = value
              .map((color) => color.toString())
              .toList();
        }
      });
    }

    return Product(
      id: p['id'],
      name: p['name'],
      category: p['category'],
      brand: p['brand'],
      colors: List<String>.from(p['colors'] ?? []),
      brandOptions: brandOptions,
      imageUrl: p['image_url'] ?? '',
      isActive: p['is_active'] ?? true,
    );
  }

  static User _parseUser(Map<String, dynamic> u) {
    return User(
      id: u['id'],
      name: u['name'],
      mobile: u['mobile'] ?? '',
      role: _parseUserRole(u['role']),
      username: u['username'] ?? '',
      password: '',
    );
  }

  static UserRole _parseUserRole(String? role) {
    switch (role) {
      case 'owner':
        return UserRole.owner;
      case 'dispatch':
        return UserRole.dispatch;
      case 'supervisor':
        return UserRole.supervisor;
      case 'operator':
        return UserRole.operator;
      case 'distributor':
        return UserRole.distributor;
      default:
        return UserRole.operator;
    }
  }

  // ── Dispatch ──────────────────────────────────────────────
  static Future<List<Challan>> getChallans() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/dispatch'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final challansById = {
          for (final challan in data.map((c) => _parseChallan(c)))
            challan.id: challan,
        };
        challansById.addAll(_localChallans);
        return challansById.values.toList();
      }
      return _localChallans.values.toList();
    } catch (e) {
      return _localChallans.values.toList();
    }
  }

  static Future<bool> createChallan(Challan challan) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/dispatch'),
        headers: await _headers(),
        body: jsonEncode({
          'id': challan.id,
          'order_id': challan.orderId,
          'distributor_name': challan.distributorName,
          'distributor_city': challan.distributorCity,
          'vehicle_number': challan.vehicleNumber,
          'driver_name': challan.driverName,
          'driver_phone': challan.driverPhone,
          'dispatch_date': challan.dispatchDate.toIso8601String(),
          'truck_photo_url': challan.truckPhotoUrl,
          'items': challan.items
              .map(
                (i) => {
                  'product_id': i.productId,
                  'product_name': i.productName,
                  'brand': i.brand,
                  'color': i.color,
                  'quantity': i.quantity,
                  'dispatched_qty': i.quantity,
                },
              )
              .toList(),
        }),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _localChallans[challan.id] = challan;
        _localOrderStatuses[challan.orderId] = OrderStatus.dispatched;
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> updateChallanPhoto(
    String challanId,
    String truckPhotoUrl,
  ) async {
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/dispatch/$challanId/photo'),
        headers: await _headers(),
        body: jsonEncode({'truck_photo_url': truckPhotoUrl}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ── Parsers ───────────────────────────────────────────────
  static Order _parseOrder(Map<String, dynamic> o) {
    return Order(
      id: o['id'],
      distributorId: o['distributor_id'],
      distributorName: o['distributor_name'],
      distributorCity: o['distributor_city'],
      orderDate: DateTime.parse(o['order_date']),
      status: _parseOrderStatus(o['status']),
      remarks: o['remarks'],
      items: (o['items'] as List<dynamic>? ?? [])
          .map((i) => _parseOrderItem(i))
          .toList(),
    );
  }

  static OrderItem _parseOrderItem(Map<String, dynamic> i) {
    return OrderItem(
      productId: i['product_id'],
      productName: i['product_name'],
      brand: i['brand'],
      color: i['color'],
      quantity: i['quantity'],
      dispatchedQty: i['dispatched_qty'] ?? 0,
      stockAvailable: i['stock_available'] ?? false,
      dispatchHistory: List<int>.from(i['dispatch_history'] ?? []),
    );
  }

  static OrderStatus _parseOrderStatus(String s) {
    switch (s) {
      case 'approved':
        return OrderStatus.approved;
      case 'partial':
        return OrderStatus.partial;
      case 'dispatched':
        return OrderStatus.dispatched;
      default:
        return OrderStatus.pending;
    }
  }

  static InventoryItem _parseInventoryItem(Map<String, dynamic> i) {
    return InventoryItem(
      productId: i['product_id'],
      productName: i['product_name'],
      brand: i['brand'],
      color: i['color'],
      totalProduced: i['total_produced'] ?? 0,
      totalDispatched: i['total_dispatched'] ?? 0,
    );
  }

  static ProductionTask _parseProductionTask(Map<String, dynamic> t) {
    return ProductionTask(
      id: t['id'],
      productId: t['product_id'],
      productName: t['product_name'],
      brand: t['brand'],
      color: t['color'],
      requiredQty: t['required_qty'],
      assignedMachine: t['assigned_machine'],
      isCompleted: t['is_completed'] ?? false,
      status: t['status'] ?? 'pending',
    );
  }

  static ProductionEntry _parseProductionEntry(Map<String, dynamic> e) {
    return ProductionEntry(
      id: e['id'],
      machineNumber: e['machine_number'],
      productId: e['product_id'],
      productName: e['product_name'],
      brand: e['brand'],
      color: e['color'],
      producedQty: e['produced_qty'],
      rejectedQty: e['rejected_qty'] ?? 0,
      mixedColorQty: e['mixed_color_qty'] ?? 0,
      date: DateTime.parse(e['date']),
    );
  }

  static RawMaterial _parseRawMaterial(Map<String, dynamic> m) {
    return RawMaterial(
      id: m['id'],
      name: m['name'],
      supplier: m['supplier'],
      currentStockKg: (m['current_stock_kg'] as num).toDouble(),
      minimumStockKg: (m['minimum_stock_kg'] as num).toDouble(),
    );
  }

  static GRNEntry _parseGRNEntry(Map<String, dynamic> g) {
    return GRNEntry(
      id: g['id'],
      materialId: g['material_id'],
      materialName: g['material_name'],
      supplier: g['supplier'],
      numBags: g['num_bags'],
      weightPerBag: (g['weight_per_bag'] as num).toDouble(),
      date: DateTime.parse(g['date']),
    );
  }

  static RawMaterialCheckResult _parseRawMaterialCheck(
    Map<String, dynamic> data,
  ) {
    RawMaterialRequirement parseRequirement(dynamic value) {
      final m = value as Map<String, dynamic>;
      return RawMaterialRequirement(
        materialId: m['material_id']?.toString(),
        materialName: m['material_name']?.toString() ?? '',
        requiredQty: (m['required_qty'] as num? ?? 0).toDouble(),
        unit: m['unit']?.toString() ?? '',
        availableQty: (m['available_qty'] as num? ?? 0).toDouble(),
        isShort: m['is_short'] == true,
      );
    }

    final requirements = (data['requirements'] as List<dynamic>? ?? [])
        .map(parseRequirement)
        .toList();
    final shortages = (data['shortages'] as List<dynamic>? ?? [])
        .map(parseRequirement)
        .toList();

    return RawMaterialCheckResult(
      ok: data['ok'] == true,
      hasFormula: data['has_formula'] == true,
      formulaBrand: data['formula_brand']?.toString(),
      requirements: requirements,
      shortages: shortages,
    );
  }

  static Challan _parseChallan(Map<String, dynamic> c) {
    return Challan(
      id: c['id'],
      orderId: c['order_id'],
      distributorName: c['distributor_name'],
      distributorCity: c['distributor_city'],
      vehicleNumber: c['vehicle_number'],
      driverName: c['driver_name'],
      driverPhone: c['driver_phone'],
      dispatchDate: DateTime.parse(c['dispatch_date']),
      truckPhotoUrl: c['truck_photo_url'],
      items: (c['items'] as List<dynamic>? ?? [])
          .map((i) => _parseOrderItem(i))
          .toList(),
    );
  }
}
