class SubProduct {
  final String name;
  final String imagePath;

  const SubProduct({required this.name, required this.imagePath});
}

class Category {
  final int id;
  final String name;
  final List<SubProduct> subCategories;

  const Category({
    required this.id,
    required this.name,
    required this.subCategories,
  });
}
