import 'dart:async';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/l10n_utils.dart';
import '../../../core/models/menu_item_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inroom_dining/features/staff_chat/presentation/widgets/staff_chat_drawer.dart';
import '../../staff_chat/providers/chat_provider.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../main.dart';
import '../../admin_panel/providers/menu_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/room_service_provider.dart';
import '../providers/waiter_provider.dart';

class WaiterScreen extends ConsumerStatefulWidget {
  final String? waiterId;
  const WaiterScreen({super.key, this.waiterId});
  @override
  ConsumerState<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends ConsumerState<WaiterScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Future<void> _startDelivery(String orderId, String currentWaiterId) async {
    await supabase.from('orders').update({'delivery_waiter_id': currentWaiterId}).eq('id', orderId);
  }

  Future<void> _markAsDelivered(String orderId) async {
    await supabase.from('orders').update({'status': 'DELIVERED', 'delivered_at': DateTime.now().toUtc().toIso8601String()}).eq('id', orderId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Giao món thành công!'), backgroundColor: Colors.green));
  }

  Future<void> _receiveService(String serviceId, String waiterId) async {
    try { await supabase.from('room_services').update({'status_id': ServiceStatus.processing, 'waiter_id': waiterId}).eq('id', serviceId); } catch (e) { debugPrint('Lỗi nhận dịch vụ: $e'); }
  }

  Future<void> _completeService(String serviceId) async {
    try { await supabase.from('room_services').update({'status_id': ServiceStatus.completed, 'completed_at': DateTime.now().toUtc().toIso8601String()}).eq('id', serviceId); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Hoàn tất nhiệm vụ!'), backgroundColor: Colors.blue)); } catch (e) { debugPrint('Lỗi xong dịch vụ: $e'); }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.parse(isoString).toLocal();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}";
  }

  @override
  Widget build(BuildContext context) {
    final waiterId = widget.waiterId;
    final profileAsync = ref.watch(userProfileProvider);
    if (waiterId == null) {
      return profileAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, s) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
        data: (profile) {
          if (profile != null) { Future.microtask(() => context.go('/waiter/${profile['id']}')); return const Scaffold(body: Center(child: CircularProgressIndicator())); }
          return const Scaffold(body: Center(child: Text('Vui lòng đăng nhập.')));
        },
      );
    }

    final l10n = ref.watch(l10nProvider);
    final waiterOrders = ref.watch(waiterOrdersProvider);
    final roomServicesAsync = ref.watch(activeRoomServicesStreamProvider);
    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
      data: (currentProfile) {
        if (currentProfile == null) return const Scaffold(body: Center(child: Text('Lỗi xác thực.')));
        return Scaffold(
          key: _scaffoldKey, endDrawer: const StaffChatDrawer(), backgroundColor: Colors.grey[100],
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l10n.waiterTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), Text('${l10n.staffLabel}: ${currentProfile['display_name']}', style: const TextStyle(color: Colors.white70, fontSize: 12))]),
            backgroundColor: Colors.green[800],
            actions: [
              const LanguageSelector(),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.history, color: Colors.white), onPressed: _showHistoryDialog),
              IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () async { ref.invalidate(userProfileProvider); await supabase.auth.signOut(); if (context.mounted) context.go('/login'); }),
              const SizedBox(width: 16),
            ],
          ),
          body: roomServicesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Lỗi tải dữ liệu: $err', style: const TextStyle(color: Colors.red))),
            data: (roomServices) {
              if (waiterOrders.isEmpty && roomServices.isEmpty) return const Center(child: Text('Hiện không có yêu cầu nào.', style: TextStyle(fontSize: 18, color: Colors.grey)));
              return GridView.builder(
                padding: const EdgeInsets.all(24), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 24, mainAxisSpacing: 24, childAspectRatio: 0.82),
                itemCount: roomServices.length + waiterOrders.length,
                itemBuilder: (context, index) {
                  if (index < roomServices.length) return _buildServiceCard(roomServices[index], waiterId, l10n);
                  return _buildOrderCard(waiterOrders[index - roomServices.length], menuItems, waiterId, l10n);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, String currentWaiterId, AppDictionary l10n) {
    final bool isCleaning = service['service_type'] == 'CLEANING';
    final Color themeColor = isCleaning ? Colors.blue : Colors.purple;
    final String? assignedId = service['waiter_id'];
    final bool isIAmDoing = assignedId == currentWaiterId;
    final bool isOtherDoing = assignedId != null && assignedId != currentWaiterId;
    return Card(
      elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isIAmDoing ? Colors.orange : themeColor, width: 3)),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: themeColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(13))), child: Center(child: Text('${l10n.room.toUpperCase()} ${service['room_number']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)))),
        Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isCleaning ? Icons.cleaning_services : Icons.person_search, size: 80, color: themeColor), const SizedBox(height: 12), Text(isCleaning ? l10n.cleaningTask : l10n.supportTask, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeColor)), if (service['notes'] != null && service['notes'].toString().isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Text('${l10n.notes}: ${service['notes']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic)))])),
        Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isIAmDoing ? Colors.orange : themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: isOtherDoing ? null : (isIAmDoing ? () => _completeService(service['id']) : () => _receiveService(service['id'], currentWaiterId)), child: Text(isOtherDoing ? l10n.alreadyTaken : (isIAmDoing ? l10n.confirmDone : l10n.takeTask), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))))
      ]),
    );
  }

  Widget _buildOrderCard(WaiterOrderModel orderData, List<MenuItemModel> menuItems, String currentWaiterId, AppDictionary l10n) {
    final order = orderData.order;
    final tickets = orderData.tickets;
    final isFullyDone = orderData.isFullyDone;
    final String? assignedId = order['delivery_waiter_id'];
    final bool isIAmDoing = assignedId == currentWaiterId;
    final bool isOtherDoing = assignedId != null && assignedId != currentWaiterId;
    final locale = ref.watch(localeProvider);
    return Card(
      elevation: isFullyDone ? 8 : 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isIAmDoing ? Colors.orange : (isFullyDone ? Colors.green : Colors.grey), width: 3)),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isFullyDone ? Colors.green[100] : Colors.grey[200], borderRadius: const BorderRadius.vertical(top: Radius.circular(16))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${l10n.room.toUpperCase()} ${order['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(isFullyDone ? l10n.ready : l10n.cooking.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isFullyDone ? Colors.green[800] : Colors.orange))])),
        Expanded(child: ListView.separated(padding: const EdgeInsets.symmetric(vertical: 8), itemCount: tickets.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, idx) {
          final t = tickets[idx];
          final menuItem = menuItems.firstWhere((m) => m.id == t['item_id'], orElse: () => MenuItemModel(id: '', price: 0, nameMap: {'vi': '...'}, descriptionMap: {}, prepTime: 0, categoryId: '', stationId: '', isAvailable: false));
          final double itemTotal = (menuItem.price + (t['selected_modifiers'] as List? ?? []).fold(0.0, (sum, m) => sum + (m['price'] ?? 0))) * (t['quantity'] ?? 1);
          return ListTile(dense: true, title: Text('${t['quantity']}x ${menuItem.getName(locale)}'), trailing: Text(NumberFormat('#,###', 'vi_VN').format(itemTotal)), leading: Icon(t['status'] == 'DONE' ? Icons.check_circle : Icons.timer, color: t['status'] == 'DONE' ? Colors.green : Colors.grey));
        })),
        Builder(builder: (context) {
          double total = 0;
          for (var t in tickets) {
            final m = menuItems.firstWhere((mi) => mi.id == t['item_id'], orElse: () => MenuItemModel(id: '', price: 0, nameMap: {}, descriptionMap: {}, prepTime: 0, categoryId: '', stationId: '', isAvailable: false));
            total += (m.price + (t['selected_modifiers'] as List? ?? []).fold(0.0, (sum, mod) => sum + (mod['price'] ?? 0))) * (t['quantity'] ?? 1);
          }
          return Container(padding: const EdgeInsets.all(12), color: Colors.yellow[50], child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${l10n.totalBill}:', style: const TextStyle(fontWeight: FontWeight.bold)), Text('${NumberFormat('#,###', 'vi_VN').format(total)} VND', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red))]));
        }),
        Padding(padding: const EdgeInsets.all(12), child: SizedBox(width: double.infinity, height: 45, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isIAmDoing ? Colors.orange : (isFullyDone ? Colors.green : Colors.grey)), onPressed: (isFullyDone && !isOtherDoing) ? (isIAmDoing ? () => _markAsDelivered(order['id']) : () => _startDelivery(order['id'], widget.waiterId!)) : null, child: Text(isOtherDoing ? l10n.alreadyTaken : (isIAmDoing ? l10n.confirmDone : l10n.takeTask)))))
      ]),
    );
  }

  void _showHistoryDialog() {
    final l10n = ref.read(l10nProvider);
    showDialog(context: context, builder: (context) => DefaultTabController(length: 2, child: AlertDialog(title: Text(l10n.historyTitle, style: const TextStyle(fontWeight: FontWeight.bold)), contentPadding: EdgeInsets.zero, content: SizedBox(width: 700, height: 600, child: Column(children: [TabBar(labelColor: Colors.blue, unselectedLabelColor: Colors.grey, tabs: [Tab(text: l10n.deliveryTab), Tab(text: l10n.cleaningTab)]), Expanded(child: TabBarView(children: [_buildHistoryList('orders', 'delivered_at', l10n), _buildHistoryList('room_services', 'completed_at', l10n)]))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close))])));
  }

  Widget _buildHistoryList(String table, String timeField, AppDictionary l10n) {
    final String selectQuery = table == 'orders' ? '*, delivery:delivery_waiter_id(display_name)' : '*, waiter:waiter_id(display_name)';
    return FutureBuilder<List<Map<String, dynamic>>>(future: supabase.from(table).select(selectQuery).eq(table == 'orders' ? 'status' : 'status_id', table == 'orders' ? 'DELIVERED' : ServiceStatus.completed).order(timeField, ascending: false).limit(30), builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      final data = snapshot.data ?? []; if (data.isEmpty) return const Center(child: Text('Chưa có lịch sử.'));
      return ListView.separated(padding: const EdgeInsets.all(16), itemCount: data.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (context, idx) {
        final item = data[idx]; final name = table == 'orders' ? (item['delivery']?['display_name'] ?? '...') : (item['waiter']?['display_name'] ?? '...');
        return ListTile(leading: Icon(table == 'orders' ? Icons.check_circle : Icons.cleaning_services, color: table == 'orders' ? Colors.green : Colors.purple), title: Text('${l10n.room} ${item['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${l10n.done}: ${_formatDateTime(item[timeField])} | ${l10n.staffLabel}: $name'));
      });
    });
  }
}
