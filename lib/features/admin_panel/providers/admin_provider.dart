import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart'; // Import biến supabase

// 1. Lắng nghe danh sách tài khoản theo thời gian thực
final profilesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);
});

// 2. Lắng nghe danh sách trạm bếp (để hiển thị trong Dropdown khi chọn role STATION)
final stationsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase.from('kitchen_stations').stream(primaryKey: ['id']);
});

// 3. Hàm Xóa tài khoản (Chỉ xóa profile)
Future<void> deleteProfile(String id) async {
  await supabase.from('profiles').delete().eq('id', id);
}