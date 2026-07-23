import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/category_model.dart';
import '../../../main.dart';

// Lắng nghe danh sách Danh mục (Dùng Model)
final categoriesStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  return supabase
      .from('categories')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: true)
      .map((data) => data.map((json) => CategoryModel.fromSupabase(json)).toList());
});
