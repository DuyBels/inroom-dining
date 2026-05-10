import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';

// Lắng nghe danh sách Thẻ theo thời gian thực
final tagsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('tags')
      .stream(primaryKey: ['id'])
      .order('tag_type', ascending: true) // Nhóm theo loại thẻ cho dễ nhìn
      .order('created_at', ascending: false);
});