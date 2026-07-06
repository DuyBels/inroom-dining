import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../../admin_panel/providers/menu_provider.dart';
import '../../auth/providers/auth_provider.dart';

// 1. Provider lấy thông tin chi tiết của một Trạm Bếp dựa trên ID
final stationDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, stationId) async {
  final data = await supabase
      .from('kitchen_stations')
      .select('id, name')
      .eq('id', stationId)
      .maybeSingle();
  return data;
});

// 2. Stream Lấy TẤT CẢ tickets để tính toán Dynamic Pacing
final activeTicketsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('tickets')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: true);
});

// 3. Stream Lấy Đơn hàng để lấy số phòng
final activeOrdersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase.from('orders').stream(primaryKey: ['id']).neq('status', 'DELIVERED');
});

// Model đại diện cho Ticket đã tính toán Dynamic Smart Timing
class SmartTicket {
  final Map<String, dynamic> rawTicket;
  final String itemName;
  final String roomNumber;
  final int prepTime;
  final int delayMinutes;
  final double basePrice; // Thêm giá gốc
  final DateTime targetStartTime;
  final bool isOrderStarted;
  final bool isInitialAnchor;

  SmartTicket({
    required this.rawTicket,
    required this.itemName,
    required this.roomNumber,
    required this.prepTime,
    required this.delayMinutes,
    required this.basePrice,
    required this.targetStartTime,
    this.isOrderStarted = false,
    this.isInitialAnchor = false,
  });
}

// 4. THUẬT TOÁN ĐỒNG BỘ THỜI GIAN ĐỘNG (DYNAMIC PACING)
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

  // BƯỚC A: XÁC ĐỊNH TRẠNG THÁI "KÍCH HOẠT" VÀ MỐC THỜI GIAN CHUẨN (ANCHOR)
  Map<String, DateTime> orderTargetFinishTimes = {};
  Map<String, bool> orderHasStarted = {};

  // 1. Tìm tất cả các Đơn hàng đã bắt đầu nấu (Có ít nhất 1 món status là COOKING)
  for (var t in allTickets) {
    if (t['status'] == 'COOKING') {
      orderHasStarted[t['order_id'].toString()] = true;
    }
  }

  // 2. Tính toán "Thời điểm hoàn thành mục tiêu" cho từng đơn hàng một cách biệt lập
  for (var ticket in allTickets) {
    if (ticket['status'] == 'DONE') continue;
    
    final String orderId = ticket['order_id'].toString();
    final bool isStarted = orderHasStarted[orderId] ?? false;

    final menuItem = menuItems.firstWhere((m) => m['id'] == ticket['item_id'], orElse: () => {'prep_time_minutes': 15});
    final int prepTime = menuItem['prep_time_minutes'] ?? 15;
    final int delay = ticket['delay_minutes'] ?? 0;
    
    DateTime refTime;
    if (isStarted) {
      // NẾU ĐƠN ĐÃ BẮT ĐẦU: Chỉ dùng mốc thời gian của những món đang COOKING để làm chuẩn
      if (ticket['status'] == 'COOKING') {
        refTime = DateTime.parse(ticket['updated_at']).toLocal();
      } else {
        // Món PENDING trong đơn đã bắt đầu sẽ không tự tạo mốc, mà sẽ "ăn theo" mốc của món COOKING
        continue; 
      }
    } else {
      // NẾU ĐƠN CHƯA BẮT ĐẦU: Dùng thời gian tạo đơn làm mốc dự kiến
      refTime = DateTime.parse(ticket['created_at']).toLocal();
    }

    final finishTime = refTime.add(Duration(minutes: prepTime + delay));

    // Lấy món có thời gian kết thúc muộn nhất làm mốc Anchor cho ĐÚNG đơn hàng đó
    if (!orderTargetFinishTimes.containsKey(orderId) || finishTime.isAfter(orderTargetFinishTimes[orderId]!)) {
      orderTargetFinishTimes[orderId] = finishTime;
    }
  }

  // BƯỚC B: Tính ngược mốc bắt đầu cho từng món của trạm hiện tại
  List<SmartTicket> mySmartTickets = [];

  for (var ticket in allTickets) {
    if (ticket['station_id'] != myStationId || ticket['status'] == 'DONE') continue;

    final orderId = ticket['order_id'];
    if (!orderTargetFinishTimes.containsKey(orderId)) continue;

    final menuItem = menuItems.firstWhere((m) => m['id'] == ticket['item_id'], orElse: () => {'name': 'Unknown', 'prep_time_minutes': 15});
    final order = orders.firstWhere((o) => o['id'] == orderId, orElse: () => {'room_number': '?'});

    final targetFinish = orderTargetFinishTimes[orderId]!;
    final targetStart = targetFinish.subtract(Duration(minutes: (menuItem['prep_time_minutes'] ?? 15) + (ticket['delay_minutes'] ?? 0)));

    // KIỂM TRA XEM ĐÂY CÓ PHẢI MÓN CẦN NẤU ĐẦU TIÊN KHÔNG (Anchor)
    // Món Anchor là món có targetStartTime sớm nhất trong toàn bộ Order
    final orderTickets = allTickets.where((t) => t['order_id'] == orderId && t['status'] != 'DONE');
    DateTime earliestInOrder = targetStart;
    for(var ot in orderTickets) {
       final m = menuItems.firstWhere((mi) => mi['id'] == ot['item_id'], orElse: () => {'prep_time_minutes': 15});
       final otStart = targetFinish.subtract(Duration(minutes: (m['prep_time_minutes'] ?? 15) + (ot['delay_minutes'] ?? 0)));
       if (otStart.isBefore(earliestInOrder)) earliestInOrder = otStart;
    }

    mySmartTickets.add(SmartTicket(
      rawTicket: ticket,
      itemName: menuItem['name'],
      roomNumber: order['room_number'],
      prepTime: menuItem['prep_time_minutes'] ?? 15,
      delayMinutes: ticket['delay_minutes'] ?? 0,
      basePrice: num.tryParse(menuItem['price'].toString())?.toDouble() ?? 0.0,
      targetStartTime: targetStart,
      isOrderStarted: orderHasStarted[orderId] ?? false,
      isInitialAnchor: targetStart.isAtSameMomentAs(earliestInOrder),
    ));
  }

  mySmartTickets.sort((a, b) => a.targetStartTime.compareTo(b.targetStartTime));
  return mySmartTickets;
});

// 5. Provider lấy station_id mặc định của User
final defaultStationIdProvider = Provider<AsyncValue<String?>>((ref) {
  return ref.watch(userProfileProvider).whenData((profile) => profile?['station_id'] as String?);
});
