import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../admin_panel/providers/menu_provider.dart';

// 1. Lấy danh sách các Đơn hàng (Realtime)
final activeOrdersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('orders')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: true);
});

// 2. Lấy danh sách toàn bộ Phiếu in (Tickets) của các đơn hàng đó
final activeTicketsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('tickets')
      .stream(primaryKey: ['id']);
});

// 3. Model gom nhóm Đơn hàng và các Món ăn bên trong
class WaiterOrderModel {
  final Map<String, dynamic> order;
  final List<Map<String, dynamic>> tickets;
  final bool isFullyDone; // Cờ kiểm tra xem toàn bộ các món trong đơn đã nấu xong chưa

  WaiterOrderModel({
    required this.order,
    required this.tickets,
    required this.isFullyDone,
  });
}

// 4. Provider tổng hợp dữ liệu để Giao diện dễ dàng hiển thị
final waiterOrdersProvider = Provider<List<WaiterOrderModel>>((ref) {
  final ordersAsync = ref.watch(activeOrdersStreamProvider);
  final ticketsAsync = ref.watch(activeTicketsStreamProvider);

  if (ordersAsync.value == null || ticketsAsync.value == null) return [];

  // Đơn hàng chỉ hiển thị khi chưa hoàn tất giao (DELIVERED) và không bị hủy
  final orders = ordersAsync.value!.where((o) => o['status'] != 'DELIVERED' && o['status'] != 'CANCELLED').toList();
  final tickets = ticketsAsync.value!;

  final List<WaiterOrderModel> result = [];
  for (var order in orders) {
    // Lọc ra các vé thuộc về đơn hàng này và BỎ QUA các vé đã hủy hoặc đã nấu lại
    final orderTickets = tickets.where((t) => t['order_id'] == order['id'] && t['status'] != 'CANCELLED' && t['status'] != 'REMAKED').toList();

    // Bỏ qua nếu đơn hàng không có món nào (đã bị khách hủy hết)
    if (orderTickets.isEmpty) continue;

    // Kiểm tra: tất cả các món đều DONE hoặc REMAKED (đã được tách sang bill khác)
    final isFullyDone = orderTickets.every((t) => t['status'] == 'DONE' || t['status'] == 'REMAKED');

    result.add(WaiterOrderModel(
      order: order,
      tickets: orderTickets,
      isFullyDone: isFullyDone,
    ));
  }
  return result;
});