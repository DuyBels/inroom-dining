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

  // Đơn hàng chỉ hiển thị khi chưa hoàn tất giao (DELIVERED)
  final orders = ordersAsync.value!.where((o) => o['status'] != 'DELIVERED').toList();
  final tickets = ticketsAsync.value!;

  return orders.map((order) {
    // Lọc ra các vé thuộc về đơn hàng này
    final orderTickets = tickets.where((t) => t['order_id'] == order['id']).toList();

    // Kiểm tra: tất cả các món đều DONE hoặc REMAKED (đã được tách sang bill khác)
    final isFullyDone = orderTickets.isNotEmpty && orderTickets.every((t) => t['status'] == 'DONE' || t['status'] == 'REMAKED');

    return WaiterOrderModel(
      order: order,
      tickets: orderTickets,
      isFullyDone: isFullyDone,
    );
  }).toList();
});