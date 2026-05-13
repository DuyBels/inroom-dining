import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../admin_panel/providers/menu_provider.dart';

// 1. Lấy station_id của tài khoản Bếp đang đăng nhập
final currentStationIdProvider = FutureProvider<String?>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;
  final profile = await supabase.from('profiles').select('station_id').eq('id', userId).single();
  return profile['station_id'] as String?;
});

// 2. Stream Lấy TẤT CẢ tickets đang chờ hoặc đang nấu (Để tính toán đồng bộ chéo giữa các Bếp)
final activeTicketsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('tickets')
      .stream(primaryKey: ['id'])
      .neq('status', 'DONE')
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
  final myStationId = myStationIdAsync.value!;

  // Bước A: Tính toán Tổng thời gian lâu nhất cho từng Đơn hàng (Order)
  // Để các bếp biết phải đợi nhau bao lâu
  Map<String, DateTime> orderTargetFinishTimes = {};

  for (var ticket in allTickets) {
    final orderId = ticket['order_id'];
    final menuItem = menuItems.firstWhere((m) => m['id'] == ticket['item_id'], orElse: () => {'prep_time_minutes': 15});

    final int prepTime = menuItem['prep_time_minutes'] ?? 15;
    final int delay = ticket['delay_minutes'] ?? 0;
    final int totalMinutesNeeded = prepTime + delay;

    final createdAt = DateTime.parse(ticket['created_at']).toLocal();
    final expectedFinishTime = createdAt.add(Duration(minutes: totalMinutesNeeded));

    // Tìm món có thời gian hoàn thành lâu nhất của đơn đó
    if (!orderTargetFinishTimes.containsKey(orderId) || expectedFinishTime.isAfter(orderTargetFinishTimes[orderId]!)) {
      orderTargetFinishTimes[orderId] = expectedFinishTime;
    }
  }

  // Bước B: Tạo danh sách SmartTicket cho Trạm bếp hiện tại
  List<SmartTicket> mySmartTickets = [];

  for (var ticket in allTickets) {
    // Chỉ lấy ticket của Trạm Bếp này
    if (ticket['station_id'] != myStationId) continue;

    final orderId = ticket['order_id'];
    final menuItem = menuItems.firstWhere((m) => m['id'] == ticket['item_id'], orElse: () => {'name': 'Unknown', 'prep_time_minutes': 15});
    final order = orders.firstWhere((o) => o['id'] == orderId, orElse: () => {'room_number': '?'});

    final int prepTime = menuItem['prep_time_minutes'] ?? 15;
    final int delay = ticket['delay_minutes'] ?? 0;

    // Tính toán lại: Thời gian bắt đầu = Thời gian xong của đơn - (Thời gian nấu món này + Delay)
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

  // Bước C: Sắp xếp. Món nào cần nấu gấp (targetStartTime nhỏ nhất) đưa lên đầu!
  mySmartTickets.sort((a, b) => a.targetStartTime.compareTo(b.targetStartTime));

  return mySmartTickets;
});