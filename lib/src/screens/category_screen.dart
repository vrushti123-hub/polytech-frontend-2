import 'package:flutter/material.dart';
import '../data/catalog_data.dart';
import '../models/category_model.dart';
import '../theme/app_theme.dart';
import 'my_orders_screen.dart';
import 'sub_category_screen.dart';

class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key});

  static const List<Category> categories = catalogCategories;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SWAMI POLYTECH - CATEGORIES"),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyOrdersScreen(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'My Orders',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final item = categories[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: ListTile(
              title: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${item.subCategories.length} products'),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textLight,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubCategoryScreen(category: item),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MyOrdersScreen(),
            ),
          );
        },
        icon: const Icon(Icons.shopping_bag_outlined),
        label: const Text('My Orders'),
      ),
    );
  }
}
