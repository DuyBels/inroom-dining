import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';

// Stream lấy các yêu cầu dịch vụ chưa hoàn thành (Dọn dẹp / Hỗ trợ)
final activeRoomServicesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('room_services')
      .stream(primaryKey: ['id'])
      .map((list) {
        // Lọc và sắp xếp trực tiếp bằng Dart để đảm bảo tính ổn định cao nhất
        final activeList = list.where((item) => item['status'] != 'COMPLETED').toList();
        activeList.sort((a, b) => (a['requested_at'] ?? '').compareTo(b['requested_at'] ?? ''));
        return activeList;
      });
});

// Stream lấy yêu cầu dịch vụ theo từng phòng (Dùng cho máy khách)
final roomServicesByRoomStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomNumber) {
  return supabase
      .from('room_services')
      .stream(primaryKey: ['id'])
      .eq('room_number', roomNumber)
      .map((list) {
        final activeList = list.where((item) => item['status'] != 'COMPLETED').toList();
        activeList.sort((a, b) => (b['requested_at'] ?? '').compareTo(a['requested_at'] ?? ''));
        return activeList;
      });
});
