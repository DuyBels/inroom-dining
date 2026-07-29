import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/l10n_utils.dart';
import '../../../core/models/menu_item_model.dart';
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
  final double basePrice;
  final DateTime targetStartTime;
  final bool isOrderStarted;
  final bool isInitialAnchor;
  final bool isRemake;

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
    this.isRemake = false,
  });
}

// 4. THUẬT TOÁN ĐỒNG BỘ THỜI GIAN ĐỘNG (DYNAMIC PACING)
final smartKitchenTicketsProvider = Provider.family<List<SmartTicket>, String>((ref, myStationId) {
  final locale = ref.watch(localeProvider);
  final ticketsAsync = ref.watch(activeTicketsStreamProvider);
  final menuAsync = ref.watch(menuItemsStreamProvider);
  final ordersAsync = ref.watch(activeOrdersStreamProvider);

  if (ticketsAsync.value == null || menuAsync.value == null || ordersAsync.value == null) {
    return [];
  }

  final allTickets = ticketsAsync.value!;
  final menuItems = menuAsync.value!; // Giờ là List<MenuItemModel>
  final orders = ordersAsync.value!;

  // BƯỚC A: XÁC ĐỊNH TRẠNG THÁI "KÍCH HOẠT" VÀ MỐC THỜI GIAN CHUẨN (ANCHOR)
  Map<String, DateTime> orderTargetFinishTimes = {};
  Map<String, bool> orderHasStarted = {};

  for (var t in allTickets) {
    if (t['status'] == 'COOKING') {
      orderHasStarted[t['order_id'].toString()] = true;
    }
  }

  for (var ticket in allTickets) {
    if (ticket['status'] == 'DONE' || ticket['status'] == 'REMAKED' || ticket['status'] == 'CANCELLED') continue;
    
    final String orderId = ticket['order_id'].toString();
    final bool isStarted = orderHasStarted[orderId] ?? false;

    final menuItem = menuItems.firstWhere(
      (m) => m.id == ticket['item_id'], 
      orElse: () => MenuItemModel(id: '', price: 0, nameMap: {'vi': 'Unknown'}, descriptionMap: {}, prepTime: 15, categoryId: '', stationId: '', isAvailable: false)
    );
    
    final int prepTime = menuItem.prepTime;
    final int delay = ticket['delay_minutes'] ?? 0;
    
    DateTime refTime;
    if (isStarted) {
      if (ticket['status'] == 'COOKING') {
        refTime = DateTime.parse(ticket['updated_at']).toLocal();
      } else {
        continue; 
      }
    } else {
      refTime = DateTime.parse(ticket['created_at']).toLocal();
    }

    final finishTime = refTime.add(Duration(minutes: prepTime + delay));

    if (!orderTargetFinishTimes.containsKey(orderId) || finishTime.isAfter(orderTargetFinishTimes[orderId]!)) {
      orderTargetFinishTimes[orderId] = finishTime;
    }
  }

  // BƯỚC B: Tính ngược mốc bắt đầu
  List<SmartTicket> mySmartTickets = [];

  for (var ticket in allTickets) {
    if (ticket['station_id'] != myStationId || ticket['status'] == 'DONE' || ticket['status'] == 'REMAKED' || ticket['status'] == 'CANCELLED') continue;

    final orderId = ticket['order_id'];
    if (!orderTargetFinishTimes.containsKey(orderId)) continue;

    final menuItem = menuItems.firstWhere(
      (m) => m.id == ticket['item_id'], 
      orElse: () => MenuItemModel(id: '', price: 0, nameMap: {'vi': 'Unknown'}, descriptionMap: {}, prepTime: 15, categoryId: '', stationId: '', isAvailable: false)
    );
    final order = orders.firstWhere((o) => o['id'] == orderId, orElse: () => {'room_number': '?'});

    final targetFinish = orderTargetFinishTimes[orderId]!;
    final targetStart = targetFinish.subtract(Duration(minutes: (menuItem.prepTime + (ticket['delay_minutes'] ?? 0)).toInt()));

    final orderTickets = allTickets.where((t) => t['order_id'] == orderId && t['status'] != 'DONE');
    DateTime earliestInOrder = targetStart;
    for(var ot in orderTickets) {
       final m = menuItems.firstWhere((mi) => mi.id == ot['item_id'], orElse: () => MenuItemModel(id: '', price: 0, nameMap: {}, descriptionMap: {}, prepTime: 15, categoryId: '', stationId: '', isAvailable: false));
       final otStart = targetFinish.subtract(Duration(minutes: (m.prepTime + (ot['delay_minutes'] ?? 0)).toInt()));
       if (otStart.isBefore(earliestInOrder)) earliestInOrder = otStart;
    }

    mySmartTickets.add(SmartTicket(
      rawTicket: ticket,
      itemName: menuItem.getName(locale),
      roomNumber: order['room_number']?.toString() ?? '?',
      prepTime: menuItem.prepTime,
      delayMinutes: ticket['delay_minutes'] ?? 0,
      basePrice: menuItem.price,
      targetStartTime: targetStart,
      isOrderStarted: orderHasStarted[orderId] ?? false,
      isInitialAnchor: targetStart.isAtSameMomentAs(earliestInOrder),
      isRemake: ticket['is_remake'] == true,
    ));
  }

  mySmartTickets.sort((a, b) => a.targetStartTime.compareTo(b.targetStartTime));
  return mySmartTickets;
});

// 5. Provider lấy station_id mặc định của User
final defaultStationIdProvider = Provider<AsyncValue<String?>>((ref) {
  return ref.watch(userProfileProvider).whenData((profile) => profile?['station_id'] as String?);
});
