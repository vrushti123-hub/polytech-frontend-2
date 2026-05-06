class OrderLine {
  final String productName;
  final String imagePath;
  final int quantity;

  const OrderLine({
    required this.productName,
    required this.imagePath,
    required this.quantity,
  });
}

class PlacedOrder {
  final String id;
  final String categoryName;
  final DateTime createdAt;
  final List<OrderLine> items;
  final String? notes;

  const PlacedOrder({
    required this.id,
    required this.categoryName,
    required this.createdAt,
    required this.items,
    this.notes,
  });

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}
