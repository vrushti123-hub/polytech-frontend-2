import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import 'my_orders_screen.dart';

class SubCategoryScreen extends StatefulWidget {
  const SubCategoryScreen({super.key, required this.category});

  final Category category;

  @override
  State<SubCategoryScreen> createState() => _SubCategoryScreenState();
}

class _SubCategoryScreenState extends State<SubCategoryScreen> {
  late final List<int> quantities;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    quantities = List<int>.filled(widget.category.subCategories.length, 0);
  }

  void _updateQuantity(int index, int change) {
    setState(() {
      final updatedValue = quantities[index] + change;
      quantities[index] = updatedValue < 0 ? 0 : updatedValue;
    });
  }

  void _placeOrder() {
    final orderedItems = <OrderLine>[];

    for (var i = 0; i < widget.category.subCategories.length; i++) {
      if (quantities[i] > 0) {
        orderedItems.add(
          OrderLine(
            productName: widget.category.subCategories[i].name,
            imagePath: widget.category.subCategories[i].imagePath,
            quantity: quantities[i],
          ),
        );
      }
    }

    if (orderedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add quantity before ordering.")),
      );
      return;
    }

    final order = PlacedOrder(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
      categoryName: widget.category.name,
      createdAt: DateTime.now(),
      items: orderedItems,
      notes: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    OrderService.instance.addOrder(order);

    for (var i = 0; i < quantities.length; i++) {
      quantities[i] = 0;
    }
    _noteController.clear();

    setState(() {});

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Order placed'),
        content: Text('${order.id} has been added to My Orders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay Here'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyOrdersScreen(),
                ),
              );
            },
            child: const Text('View Orders'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = quantities.fold<int>(0, (sum, item) => sum + item);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.category.subCategories.length,
              itemBuilder: (context, index) {
                final subProduct = widget.category.subCategories[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  elevation: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            subProduct.imagePath,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 90,
                                height: 90,
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subProduct.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Add quantity to place order",
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => _updateQuantity(index, -1),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text(
                              quantities[index].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _updateQuantity(index, 1),
                              icon: const Icon(Icons.add_circle),
                              color: AppTheme.primaryBlue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total items: $totalItems",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteController,
                        decoration: const InputDecoration(
                          hintText: 'Add order notes (optional)',
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  child: const Text("Place Order"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
