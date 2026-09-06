class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.label,
    required this.iconPath,
  });

  final String id;
  final String label;
  final String iconPath;
}

// Categories per store — keyed by store ID
const Map<String, List<CategoryModel>> storeCategoryMap =
    <String, List<CategoryModel>>{
  'zepto': <CategoryModel>[
    CategoryModel(id: 'all', label: 'All', iconPath: 'assets/3d_icons/all.webp'),
    CategoryModel(id: 'fruits', label: 'Fruits & Veg', iconPath: 'assets/3d_icons/Fruits.webp'),
    CategoryModel(id: 'dairy', label: 'Dairy', iconPath: 'assets/3d_icons/eggs.webp'),
    CategoryModel(id: 'snacks', label: 'Snacks', iconPath: 'assets/3d_icons/Snacks.webp'),
    CategoryModel(id: 'beverages', label: 'Beverages', iconPath: 'assets/3d_icons/beverage.webp'),
    CategoryModel(id: 'rice', label: 'Rice', iconPath: 'assets/3d_icons/Rice.webp'),
    CategoryModel(id: 'bread', label: 'Bread', iconPath: 'assets/3d_icons/Bread.webp'),
  ],
  'off_zone': <CategoryModel>[
    CategoryModel(id: 'all', label: 'All', iconPath: 'assets/3d_icons/all.webp'),
    CategoryModel(id: 'flash', label: 'Flash Sale', iconPath: 'assets/3d_icons/Snacks.webp'),
    CategoryModel(id: 'combos', label: 'Combos', iconPath: 'assets/3d_icons/Fruits.webp'),
    CategoryModel(id: 'clearance', label: 'Clearance', iconPath: 'assets/3d_icons/Rice.webp'),
    CategoryModel(id: 'bogo', label: 'Buy 1 Get 1', iconPath: 'assets/3d_icons/beverage.webp'),
    CategoryModel(id: 'bulk', label: 'Bulk Buy', iconPath: 'assets/3d_icons/Bread.webp'),
  ],
  'super_mall': <CategoryModel>[
    CategoryModel(id: 'all', label: 'All', iconPath: 'assets/3d_icons/all.webp'),
    CategoryModel(id: 'electronics', label: 'Electronics', iconPath: 'assets/3d_icons/beverage.webp'),
    CategoryModel(id: 'fashion', label: 'Fashion', iconPath: 'assets/3d_icons/Snacks.webp'),
    CategoryModel(id: 'home', label: 'Home', iconPath: 'assets/3d_icons/Bread.webp'),
    CategoryModel(id: 'beauty', label: 'Beauty', iconPath: 'assets/3d_icons/Fruits.webp'),
    CategoryModel(id: 'sports', label: 'Sports', iconPath: 'assets/3d_icons/Rice.webp'),
  ],
  'cafe': <CategoryModel>[
    CategoryModel(id: 'all', label: 'All', iconPath: 'assets/3d_icons/all.webp'),
    CategoryModel(id: 'coffee', label: 'Coffee', iconPath: 'assets/3d_icons/beverage.webp'),
    CategoryModel(id: 'tea', label: 'Tea', iconPath: 'assets/3d_icons/beverage.webp'),
    CategoryModel(id: 'snacks', label: 'Snacks', iconPath: 'assets/3d_icons/Snacks.webp'),
    CategoryModel(id: 'meals', label: 'Meals', iconPath: 'assets/3d_icons/Rice.webp'),
    CategoryModel(id: 'desserts', label: 'Desserts', iconPath: 'assets/3d_icons/Bread.webp'),
  ],
};
