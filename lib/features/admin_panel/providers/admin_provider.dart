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
  return supabase.from('kitchen_stations').stream(primaryKey: ['id']).order('name', ascending: true);
});

// 3. Hàm Xóa tài khoản (Chỉ xóa profile)
Future<void> deleteProfile(String id) async {
  await supabase.from('profiles').delete().eq('id', id);
}

// 4. Hàm Trả phòng (Ẩn lịch sử với khách mới, KHÔNG xóa dữ liệu)
Future<void> checkoutRoom(String roomNumber) async {
  if (roomNumber.isEmpty) {
    throw Exception("Room number cannot be empty for checkout");
  }
  
  print("DEBUG: Checking out room: $roomNumber");

  // Ẩn yêu cầu dịch vụ đã hoàn thành của phòng này khỏi khách mới
  await supabase
      .from('room_services')
      .update({'is_cleared_from_room': true})
      .eq('room_number', roomNumber);

  // Ẩn đơn hàng đã giao/hủy của phòng này khỏi khách mới
  // (Dữ liệu vẫn còn nguyên cho Admin, Bếp và Phục vụ xem)
  await supabase
      .from('orders')
      .update({'is_cleared_from_room': true})
      .eq('room_number', roomNumber);

  // Gửi tín hiệu Realtime Broadcast xuống Tablet phòng để xóa giỏ hàng cục bộ
  supabase.channel('room_$roomNumber').sendBroadcastMessage(
    event: 'clear_cart',
    payload: {'room_number': roomNumber},
  );
      
  print("DEBUG: Checkout successful for room: $roomNumber");
}
