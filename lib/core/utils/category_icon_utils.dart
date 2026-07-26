import 'package:flutter/material.dart';

/// Helper tự động gợi ý và ánh xạ Google Material Icons cho Danh Mục Món Ăn
class CategoryIconUtils {
  /// Danh sách các icon Google Material phổ biến cho F&B
  static const Map<String, IconData> availableIcons = {
    'restaurant': Icons.restaurant,
    'restaurant_menu': Icons.restaurant_menu,
    'rice_bowl': Icons.rice_bowl,
    'soup_kitchen': Icons.soup_kitchen,
    'local_bar': Icons.local_bar,
    'local_drink': Icons.local_drink,
    'coffee': Icons.coffee,
    'emoji_food_beverage': Icons.emoji_food_beverage,
    'cake': Icons.cake,
    'icecream': Icons.icecream,
    'tapas': Icons.tapas,
    'wine_bar': Icons.wine_bar,
    'local_pizza': Icons.local_pizza,
    'lunch_dining': Icons.dining,
    'ramen_dining': Icons.ramen_dining,
    'set_meal': Icons.set_meal,
    'kebab_dining': Icons.kebab_dining,
    'bento': Icons.bento,
    'breakfast_dining': Icons.breakfast_dining,
    'bakery_dining': Icons.bakery_dining,
    'fastfood': Icons.fastfood,
    'eco': Icons.eco,
    'grass': Icons.grass,
    'local_fire_department': Icons.local_fire_department,
    'blender': Icons.blender,
    'cookie': Icons.cookie,
    'local_offer': Icons.local_offer,
    'category': Icons.category,
  };

  /// Tự động gợi ý tên Icon Google phù hợp dựa trên tên danh mục (Tiếng Việt hoặc Tiếng Anh)
  static String autoSuggestIconName(String categoryName) {
    final name = categoryName.toLowerCase().trim();
    if (name.isEmpty) return 'restaurant_menu';

    // Đồ uống & Cà phê & Rượu
    if (name.contains('nước') || name.contains('uống') || name.contains('drink') || name.contains('beverage') || name.contains('giải khát')) {
      if (name.contains('cà phê') || name.contains('coffee') || name.contains('cafe')) return 'coffee';
      if (name.contains('trà') || name.contains('tea')) return 'emoji_food_beverage';
      if (name.contains('rượu') || name.contains('bia') || name.contains('wine') || name.contains('beer') || name.contains('cocktail')) return 'wine_bar';
      if (name.contains('sinh tố') || name.contains('nước ép') || name.contains('juice') || name.contains('smoothie')) return 'blender';
      return 'local_bar';
    }
    if (name.contains('cà phê') || name.contains('coffee') || name.contains('cafe')) return 'coffee';
    if (name.contains('trà') || name.contains('tea')) return 'emoji_food_beverage';
    if (name.contains('rượu') || name.contains('bia') || name.contains('wine') || name.contains('beer') || name.contains('cocktail')) return 'wine_bar';

    // Súp, Lẩu, Canh
    if (name.contains('súp') || name.contains('canh') || name.contains('soup') || name.contains('lẩu') || name.contains('hotpot')) {
      return 'soup_kitchen';
    }

    // Cơm, Phở, Bún, Mỳ
    if (name.contains('cơm') || name.contains('rice') || name.contains('phở') || name.contains('bún') || name.contains('noodle') || name.contains('mỳ') || name.contains('mì')) {
      if (name.contains('mì') || name.contains('ramen') || name.contains('noodle') || name.contains('phở') || name.contains('bún')) return 'ramen_dining';
      return 'rice_bowl';
    }

    // Ăn nhẹ & Bakery & Bánh mỳ
    if (name.contains('ăn nhẹ') || name.contains('bakery') || name.contains('bánh mỳ') || name.contains('bread') || name.contains('light bite')) {
      return 'bakery_dining';
    }

    // Tráng miệng & Bánh ngọt & Kem
    if (name.contains('tráng miệng') || name.contains('dessert') || name.contains('cake') || name.contains('bánh ngọt') || name.contains('ngọt')) {
      if (name.contains('kem') || name.contains('ice cream')) return 'icecream';
      if (name.contains('bánh quy') || name.contains('cookie')) return 'cookie';
      return 'cake';
    }

    // Bánh chung
    if (name.contains('bánh')) {
      return 'cake';
    }

    // Khai vị & Tapas
    if (name.contains('khai vị') || name.contains('appetizer') || name.contains('starter') || name.contains('tapas')) {
      return 'tapas';
    }

    // Ăn vặt & Snack
    if (name.contains('ăn vặt') || name.contains('snack')) {
      return 'cookie';
    }

    // Hải sản
    if (name.contains('hải sản') || name.contains('cá') || name.contains('tôm') || name.contains('cua') || name.contains('seafood') || name.contains('fish')) {
      return 'set_meal';
    }

    // Nướng & BBQ & Xiên
    if (name.contains('nướng') || name.contains('bbq') || name.contains('grill') || name.contains('xiên') || name.contains('quay')) {
      return 'kebab_dining';
    }

    // Fast food & Pizza & Burger
    if (name.contains('pizza') || name.contains('burger') || name.contains('fast food') || name.contains('gà rán')) {
      if (name.contains('pizza')) return 'local_pizza';
      return 'fastfood';
    }

    // Ăn sáng
    if (name.contains('ăn sáng') || name.contains('breakfast') || name.contains('điểm tâm')) {
      return 'breakfast_dining';
    }

    // Đồ chay & Salad
    if (name.contains('chay') || name.contains('vegetables') || name.contains('salad') || name.contains('rau')) {
      return 'eco';
    }

    // Combo & Set
    if (name.contains('combo') || name.contains('set') || name.contains('phần') || name.contains('bento')) {
      return 'bento';
    }

    // Món chính
    if (name.contains('chính') || name.contains('main')) {
      return 'lunch_dining';
    }

    return 'restaurant_menu';
  }

  /// Lấy IconData từ tên Icon hoặc tự động phân tích tên danh mục
  static IconData getIconData(String? iconName, String? categoryName) {
    if (iconName != null && iconName.isNotEmpty && availableIcons.containsKey(iconName)) {
      return availableIcons[iconName]!;
    }
    final suggested = autoSuggestIconName(categoryName ?? '');
    return availableIcons[suggested] ?? Icons.restaurant_menu;
  }
}
