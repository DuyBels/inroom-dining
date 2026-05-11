import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';

// Lắng nghe danh sách Món ăn theo thời gian thực
final menuItemsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('menu_items')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false); // Mới tạo lên đầu
});