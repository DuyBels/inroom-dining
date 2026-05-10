import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// 1. Lắng nghe các phiếu món (tickets) đã được Bếp báo XONG
final readyToDeliverProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('tickets')
      .stream(primaryKey: ['id'])
      .eq('status', 'DONE') // Chỉ lấy những món Bếp đã nấu xong
      .order('updated_at', ascending: false) // Món nào xong trước hiển thị trước
      .map((data) => data);
});

// 2. Hàm để nhân viên xác nhận "Đã giao lên phòng thành công"
Future<void> markAsDelivered(String ticketId, String orderId) async {
  // Cập nhật trạng thái của Ticket (Ví dụ: Chuyển sang DELIVERED để biến mất khỏi màn hình phục vụ)
  await supabase
      .from('tickets')
      .update({'status': 'DELIVERED'})
      .eq('id', ticketId);

  // Mở rộng: Ở đây bạn có thể viết thêm logic kiểm tra xem
  // TOÀN BỘ tickets của cái orderId này đã DELIVERED hết chưa.
  // Nếu hết rồi thì cập nhật luôn bảng `orders` thành DELIVERED.
}