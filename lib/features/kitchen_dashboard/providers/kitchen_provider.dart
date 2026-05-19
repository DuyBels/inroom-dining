import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../../admin_panel/providers/menu_provider.dart';

// 0. Provider lắng nghe trạng thái đăng nhập để tự động refresh các provider khác
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

// 1. Lấy thông tin Trạm Bếp của tài khoản đang đăng nhập (Sử dụng autoDispose và watch Auth)
final currentStationProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  // Ép provider này phải chạy lại khi trạng thái đăng nhập thay đổi
  ref.watch(authStateProvider);
  
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  
  final data = await supabase
      .from('profiles')
      .select('station_id, kitchen_stations(name)')
      .eq('id', user.id)
      .single();
      
  return {
    'id': data['station_id'],
    'name': data['kitchen_stations']?['name'] ?? 'Không xác định',
  };
});

// Provider hỗ trợ lấy nhanh ID (Thêm autoDispose để đồng bộ)
final currentStationIdProvider = FutureProvider.autoDispose<String?>((ref) async {
  final station = await ref.watch(currentStationProvider.future);
  return station?['id'];
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
  final DateTime targetStartTime; // Thời gian tối ưu để bắt đầu nấu

  SmartTicket({
    required this.rawTicket,
    required this.itemName,
    required this.roomNumber,
    required this.prepTime,
    required this.delayMinutes,
    required this.targetStartTime,
  });
}

// 4. THUẬT TOÁN ĐỒNG BỘ THỜI GIAN (SMART PACING)
final smartKitchenTicketsProvider = Provider<List<SmartTicket>>((ref) {
  final ticketsAsync = ref.watch(activeTicketsStreamProvider);
  final menuAsync = ref.watch(menuItemsStreamProvider);
  final ordersAsync = ref.watch(activeOrdersStreamProvider);
  final myStationIdAsync = ref.watch(currentStationIdProvider);

  // Nếu dữ liệu chưa tải xong, trả về mảng rỗng
  if (ticketsAsync.value == null || menuAsync.value == null || 
      ordersAsync.value == null || myStationIdAsync.value == null) {
    return [];
  }

  final allTickets = ticketsAsync.value!;
  final menuItems = menuAsync.value!;
  final orders = ordersAsync.value!;
  final myStationId = myStationIdAsync.value;

  if (myStationId == null) return [];

  Map<String, DateTime> orderTargetFinishTimes = {};

  for (var ticket in allTickets) {
    final orderId = ticket['order_id'];
    final menuItem = menuItems.firstWhere((m) => m['id'] == ticket['item_id'], orElse: () => {'prep_time_minutes': 15});

    final int prepTime = menuItem['prep_time_minutes'] ?? 15;
    final int delay = ticket['delay_minutes'] ?? 0;
    final int totalMinutesNeeded = prepTime + delay;

    final createdAt = DateTime.parse(ticket['created_at']).toLocal();
    final expectedFinishTime = createdAt.add(Duration(minutes: totalMinutesNeeded));

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

    final int prepTime = menuItem['prep_time_minutes'] ?? 15;
    final int delay = ticket['delay_minutes'] ?? 0;

    final targetFinish = orderTargetFinishTimes[orderId]!;
    final targetStart = targetFinish.subtract(Duration(minutes: prepTime + delay));

    mySmartTickets.add(SmartTicket(
      rawTicket: ticket,
      itemName: menuItem['name'],
      roomNumber: order['room_number'],
      prepTime: prepTime,
      delayMinutes: delay,
      targetStartTime: targetStart,
    ));
  }

  mySmartTickets.sort((a, b) => a.targetStartTime.compareTo(b.targetStartTime));

  return mySmartTickets;
});
