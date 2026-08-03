import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';

// Định nghĩa các hằng số ID trạng thái để code dễ đọc
class ServiceStatus {
  static const int pending = 1;
  static const int processing = 2;
  static const int completed = 3;
}

// Stream lấy các yêu cầu dịch vụ chưa hoàn thành (status_id != 3)
final activeRoomServicesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('room_services')
      .stream(primaryKey: ['id'])
      .order('requested_at', ascending: true)
      .map((list) {
        // Lọc bỏ những yêu cầu đã hoàn tất (ID = 3)
        return list.where((item) => item['status_id'] != ServiceStatus.completed).toList();
      });
});

// Stream lấy yêu cầu dịch vụ theo từng phòng (Dùng cho máy khách)
final roomServicesByRoomStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomNumber) {
  return supabase
      .from('room_services')
      .stream(primaryKey: ['id'])
      .eq('room_number', roomNumber)
      .order('requested_at', ascending: false)
      .map((list) {
        return list.where((item) => item['status_id'] != ServiceStatus.completed && item['is_cleared_from_room'] != true).toList();
      });
});

// Stream lấy TOÀN BỘ yêu cầu dịch vụ của phòng (Dùng để bắt sự kiện hoàn thành)
final allRoomServicesStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomNumber) {
  return supabase
      .from('room_services')
      .stream(primaryKey: ['id'])
      .eq('room_number', roomNumber)
      .order('requested_at', ascending: false)
      .map((list) => list.where((item) => item['is_cleared_from_room'] != true).toList());
});
