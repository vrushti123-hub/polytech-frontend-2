import 'package:flutter/foundation.dart';
import '../models/order_model.dart';

class OrderService {
  OrderService._();

  static final OrderService instance = OrderService._();

  final ValueNotifier<List<PlacedOrder>> orders =
      ValueNotifier<List<PlacedOrder>>(<PlacedOrder>[]);

  void addOrder(PlacedOrder order) {
    orders.value = [order, ...orders.value];
  }
}
