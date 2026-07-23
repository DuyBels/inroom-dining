import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../main.dart';

// Lắng nghe danh sách Món ăn theo thời gian thực (Dùng Model)
final menuItemsStreamProvider = StreamProvider<List<MenuItemModel>>((ref) {
  return supabase
      .from('menu_items')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .map((data) => data.map((json) => MenuItemModel.fromSupabase(json)).toList());
});
