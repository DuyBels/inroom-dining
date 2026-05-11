import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';

// Lắng nghe danh sách Danh mục theo thời gian thực
final categoriesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('categories')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: true); // Hiển thị theo thứ tự tạo trước/sau
});