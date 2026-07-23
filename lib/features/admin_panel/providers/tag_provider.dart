import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/tag_model.dart';
import '../../../main.dart';

// Lắng nghe danh sách Thẻ (Dùng Model)
final tagsStreamProvider = StreamProvider<List<TagModel>>((ref) {
  return supabase
      .from('tags')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: true)
      .map((data) => data.map((json) => TagModel.fromSupabase(json)).toList());
});
