import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../../admin_panel/providers/menu_provider.dart';

// 0. Provider lắng nghe trạng thái đăng nhập
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

// 1. Provider lấy thông tin chi tiết của một Trạm Bếp dựa trên ID (Dùng cho URL State)
final stationDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, stationId) async {
  final data = await supabase
      .from('kitchen_stations')
      .select('id, name')
      .eq('id', stationId)
      .maybeSingle();
      
  return data;
});

// 2. Stream Lấy TẤT CẢ tickets (Để tính toán đồng bộ chéo giữa các Bếp)
final activeTicketsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('tickets')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: true);
});

// 3. Stream Lấy Đơn hàng (orders) để lấy số phòng
final activeOrdersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase.from('orders').stream(primaryKey: ['id']).neq('status', 'DELIVERED');
});

// MODEL ĐẠI DIỆN CHO TICKET ĐÃ TÍNH TOÁN SMART TIMING
class SmartTicket {
  final Map<String, dynamic> rawTicket;
  final String itemName;
  final String roomNumber;
  final int prepTime;
  final int delayMinutes;
  final DateTime targetStartTime;

  SmartTicket({
    required this.rawTicket,
    required this.itemName,
    required this.roomNumber,
    required this.prepTime,
    required this.delayMinutes,
    required this.targetStartTime,
  });
}

// 4. THUẬT TOÁN ĐỒNG BỘ THỜI GIAN - Bây giờ nhận stationId từ URL làm tham số
final smartKitchenTicketsProvider = Provider.family<List<SmartTicket>, String>((ref, myStationId) {
  final ticketsAsync = ref.watch(activeTicketsStreamProvider);
  final menuAsync = ref.watch(menuItemsStreamProvider);
  final ordersAsync = ref.watch(activeOrdersStreamProvider);

  if (ticketsAsync.value == null || menuAsync.value == null || ordersAsync.value == null) {
    return [];
  }

  final allTickets = ticketsAsync.value!;
  final menuItems = menuAsync.value!;
  final orders = ordersAsync.value!;

  Map<String, DateTime> orderTargetFinishTimes = {};

  for (var ticket in allTickets) {
    final orderId = ticket['order_id'];
    final menuItem = menuItems.firstWhere((m) => m['id'] == ticket['item_id'], orElse: () => {'prep_time_minutes': 15});
    final int prepTime = menuItem['prep_time_minutes'] ?? 15;
    final int delay = ticket['delay_minutes'] ?? 0;
    final createdAt = DateTime.parse(ticket['created_at']).toLocal();
    final expectedFinishTime = createdAt.add(Duration(minutes: prepTime + delay));

    if (!orderTargetFinishTimes.containsKey(orderId) || expectedFinishTime.isAfter(orderTargetFinishTimes[orderId]!)) {
      orderTargetFinishTimes[orderId] = expectedFinishTime;
    }
  }

  List<SmartTicket> mySmartTickets = [];

  for (var ticket in allTickets) {
    if (ticket['station_id'] != myStationId || ticket['status'] == 'DONE') continue;

    final orderId = ticket['order_id'];
    final menuItem = menuItems.firstWhere((m) => m['id'] == ticket['item_id'], orElse: () => {'name': 'Unknown', 'prep_time_minutes': 15});
    final order = orders.firstWhere((o) => o['id'] == orderId, orElse: () => {'room_number': '?'});

    final targetFinish = orderTargetFinishTimes[orderId]!;
    final targetStart = targetFinish.subtract(Duration(minutes: (menuItem['prep_time_minutes'] ?? 15) + (ticket['delay_minutes'] ?? 0)));

    mySmartTickets.add(SmartTicket(
      rawTicket: ticket,
      itemName: menuItem['name'],
      roomNumber: order['room_number'],
      prepTime: menuItem['prep_time_minutes'] ?? 15,
      delayMinutes: ticket['delay_minutes'] ?? 0,
      targetStartTime: targetStart,
    ));
  }

  mySmartTickets.sort((a, b) => a.targetStartTime.compareTo(b.targetStartTime));
  return mySmartTickets;
});

// 5. Provider lấy station_id mặc định của User (Chỉ dùng để redirect ban đầu)
final defaultStationIdProvider = FutureProvider<String?>((ref) async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  final data = await supabase.from('profiles').select('station_id').eq('id', user.id).maybeSingle();
  return data?['station_id'] as String?;
});
