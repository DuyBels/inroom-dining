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

// 4. Hàm Trả phòng (Xóa lịch sử của phòng đó)
Future<void> checkoutRoom(String roomNumber) async {
  if (roomNumber.isEmpty) {
    throw Exception("Room number cannot be empty for checkout");
  }
  
  print("DEBUG: Checking out room: $roomNumber");

  // Xóa yêu cầu dịch vụ của phòng này
  await supabase
      .from('room_services')
      .delete()
      .eq('room_number', roomNumber);

  // Xóa đơn hàng của phòng này
  // (Lưu ý: Tickets liên quan sẽ tự động bị xóa nhờ ON DELETE CASCADE trên DB)
  await supabase
      .from('orders')
      .delete()
      .eq('room_number', roomNumber);
      
  print("DEBUG: Checkout successful for room: $roomNumber");
}
