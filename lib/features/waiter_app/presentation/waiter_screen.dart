import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inroom_dining/features/staff_chat/presentation/widgets/staff_chat_drawer.dart';
import '../../staff_chat/providers/chat_provider.dart';
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

  // --- LOGIC GIAO MÓN ---
  Future<void> _startDelivery(String orderId, String currentWaiterId) async {
    await supabase.from('orders').update({'delivery_waiter_id': currentWaiterId}).eq('id', orderId);
  }

  Future<void> _markAsDelivered(String orderId) async {
    await supabase.from('orders').update({
      'status': 'DELIVERED',
      'delivered_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Giao món thành công!'), backgroundColor: Colors.green));
  }

  // --- LOGIC DỊCH VỤ PHÒNG ---
  Future<void> _receiveService(String serviceId, String waiterId) async {
    try {
      await supabase.from('room_services').update({
        'status_id': ServiceStatus.processing,
        'waiter_id': waiterId,
      }).eq('id', serviceId);
    } catch (e) {
      debugPrint('Lỗi nhận dịch vụ: $e');
    }
  }

  Future<void> _completeService(String serviceId) async {
    try {
      await supabase.from('room_services').update({
        'status_id': ServiceStatus.completed,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', serviceId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Hoàn tất nhiệm vụ!'), backgroundColor: Colors.blue));
    } catch (e) {
      debugPrint('Lỗi xong dịch vụ: $e');
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.parse(isoString).toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final y = dt.year;
    return "$h:$m:$s $d/$mo/$y";
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
          if (profile != null) {
            Future.microtask(() => context.go('/waiter/${profile['id']}'));
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return const Scaffold(body: Center(child: Text('Vui lòng đăng nhập.')));
        },
      );
    }

    _setupNotificationListeners();

    final waiterOrders = ref.watch(waiterOrdersProvider);
    final roomServicesAsync = ref.watch(activeRoomServicesStreamProvider);
    final menuItems = ref.watch(menuItemsStreamProvider).value ?? [];

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
      data: (currentProfile) {
        if (currentProfile == null) return const Scaffold(body: Center(child: Text('Lỗi xác thực.')));

        return Scaffold(
          key: _scaffoldKey,
          endDrawer: const StaffChatDrawer(),
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ĐIỀU PHỐI CÔNG VIỆC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Nhân viên: ${currentProfile['display_name']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.green[800],
            actions: [
              Builder(
                builder: (ctx) {
                  final hasUnread = ref.watch(hasUnreadMessagesProvider);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                        onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 12, top: 12,
                          child: Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.green[800]!, width: 1.5)),
                          ),
                        ),
                    ],
                  );
                },
              ),
              IconButton(icon: const Icon(Icons.history, color: Colors.white), onPressed: _showHistoryDialog),
              IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () async {
                ref.invalidate(userProfileProvider);
                await supabase.auth.signOut();
                if (context.mounted) context.go('/login');
              }),
              const SizedBox(width: 16),
            ],
          ),
          body: roomServicesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Lỗi tải dữ liệu: $err', style: const TextStyle(color: Colors.red))),
            data: (roomServices) {
              if (waiterOrders.isEmpty && roomServices.isEmpty) {
                return const Center(child: Text('Hiện không có yêu cầu nào.', style: TextStyle(fontSize: 18, color: Colors.grey)));
              }

              return GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 24, mainAxisSpacing: 24, childAspectRatio: 0.82,
                ),
                itemCount: roomServices.length + waiterOrders.length,
                itemBuilder: (context, index) {
                  if (index < roomServices.length) {
                    return _buildServiceCard(roomServices[index], waiterId!);
                  }
                  return _buildOrderCard(waiterOrders[index - roomServices.length], menuItems, waiterId!);
                },
              );
            },
          ),
        );
      },
    );
  }

  void _setupNotificationListeners() {
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(staffMessagesStreamProvider, (prev, next) {
      final messages = next.value;
      if (messages != null && messages.isNotEmpty) {
        final newMsg = messages.first;
        final myId = ref.read(currentUserProvider)?.id;
        final lastMsgId = prev?.value?.isNotEmpty == true ? prev!.value!.first['id'] : null;
        final isDrawerOpen = _scaffoldKey.currentState?.isEndDrawerOpen ?? false;
        final List readBy = newMsg['read_by'] ?? [];
        if (newMsg['sender_id'] != myId && newMsg['id'] != lastMsgId && !isDrawerOpen && !readBy.contains(myId)) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('💬 ${newMsg['sender_name']}: ${newMsg['message']}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.blueGrey[900],
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: 'XEM', textColor: Colors.amber, onPressed: () => _scaffoldKey.currentState?.openEndDrawer()),
          ));
        }
      }
    });

    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(activeTicketsStreamProvider, (prev, next) {
      if (next.hasValue && prev?.hasValue == true) {
        for (var t in next.value!) {
          if (t['status'] == 'DONE' && !prev!.value!.any((p) => p['id'] == t['id'] && p['status'] == 'DONE')) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🔔 Một món ăn đã nấu xong!'), backgroundColor: Colors.green));
          }
        }
      }
    });

    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(activeRoomServicesStreamProvider, (prev, next) {
      if (next.hasValue && prev?.hasValue == true) {
        for (var s in next.value!) {
          if (!prev!.value!.any((p) => p['id'] == s['id'])) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🧹 PHÒNG ${s['room_number']} yêu cầu dịch vụ!'), backgroundColor: Colors.blue[900]));
          }
        }
      }
    });
  }

  Widget _buildServiceCard(Map<String, dynamic> service, String currentWaiterId) {
    final bool isCleaning = service['service_type'] == 'CLEANING';
    final Color themeColor = isCleaning ? Colors.blue : Colors.purple;
    final String? assignedId = service['waiter_id'];
    final bool isIAmDoing = assignedId == currentWaiterId;
    final bool isOtherDoing = assignedId != null && assignedId != currentWaiterId;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isIAmDoing ? Colors.orange : themeColor, width: 3)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: themeColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(13))),
            child: Center(child: Text('PHÒNG ${service['room_number']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24))),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isCleaning ? Icons.cleaning_services : Icons.person_search, size: 80, color: themeColor),
                const SizedBox(height: 12),
                Text(isCleaning ? "CẦN DỌN DẸP" : "KHÁCH CẦN HỖ TRỢ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeColor)),
                if (service['notes'] != null && service['notes'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Lý do: ${service['notes']}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isIAmDoing ? Colors.orange : themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: isOtherDoing ? null : (isIAmDoing ? () => _completeService(service['id']) : () => _receiveService(service['id'], currentWaiterId)),
                child: Text(isOtherDoing ? 'ĐÃ CÓ NGƯỜI NHẬN' : (isIAmDoing ? 'XÁC NHẬN XONG' : 'NHẬN NHIỆM VỤ'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildOrderCard(WaiterOrderModel orderData, List<Map<String, dynamic>> menuItems, String currentWaiterId) {
    final order = orderData.order;
    final tickets = orderData.tickets;
    final isFullyDone = orderData.isFullyDone;
    final String? assignedId = order['delivery_waiter_id'];
    final bool isIAmDoing = assignedId == currentWaiterId;
    final bool isOtherDoing = assignedId != null && assignedId != currentWaiterId;

    return Card(
      elevation: isFullyDone ? 8 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isIAmDoing ? Colors.orange : (isFullyDone ? Colors.green : Colors.grey), width: 3)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isFullyDone ? Colors.green[100] : Colors.grey[200], borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PHÒNG ${order['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(isFullyDone ? 'SẴN SÀNG' : 'ĐANG NẤU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isFullyDone ? Colors.green[800] : Colors.orange)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final t = tickets[idx];
                final menuItem = menuItems.firstWhere((m) => m['id'] == t['item_id'], orElse: () => {'name': '...', 'price': 0});
                final basePrice = num.tryParse(menuItem['price'].toString())?.toDouble() ?? 0.0;
                final modifiers = t['selected_modifiers'] as List? ?? [];
                final double modsTotal = modifiers.fold(0.0, (sum, m) => sum + (num.tryParse(m['price'].toString())?.toDouble() ?? 0.0));
                final double itemTotal = (basePrice + modsTotal) * (t['quantity'] ?? 1);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(t['status'] == 'DONE' ? Icons.check_circle : Icons.timer, color: t['status'] == 'DONE' ? Colors.green : Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${t['quantity']}x ${menuItem['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                          Text('${NumberFormat('#,###', 'vi_VN').format(itemTotal)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (modifiers.isNotEmpty)
                        ...modifiers.map((m) => Padding(
                          padding: const EdgeInsets.only(left: 28.0, top: 2),
                          child: Text('↳ ${m['group_name']}: ${m['modifier_name']}', style: TextStyle(fontSize: 12, color: Colors.blue[700])),
                        )),
                      if (t['notes'] != null && t['notes'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 28.0, top: 2),
                          child: Text('Ghi chú: ${t['notes']}', style: const TextStyle(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // HIỂN THỊ TỔNG TIỀN CỦA CẢ BILL
          Builder(builder: (context) {
             double grandTotal = 0;
             for (var t in tickets) {
               final menuItem = menuItems.firstWhere((m) => m['id'] == t['item_id'], orElse: () => {'price': 0});
               final base = num.tryParse(menuItem['price'].toString())?.toDouble() ?? 0.0;
               final mods = (t['selected_modifiers'] as List? ?? []).fold(0.0, (sum, m) => sum + (num.tryParse(m['price'].toString())?.toDouble() ?? 0.0));
               grandTotal += (base + mods) * (t['quantity'] ?? 1);
             }
             return Container(
               padding: const EdgeInsets.all(12),
               color: Colors.yellow[50],
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   const Text('TỔNG BILL:', style: TextStyle(fontWeight: FontWeight.bold)),
                   Text(
                     '${NumberFormat('#,###', 'vi_VN').format(grandTotal)} VND',
                     style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red),
                   ),
                 ],
               ),
             );
          }),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity, height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isIAmDoing ? Colors.orange : (isFullyDone ? Colors.green : Colors.grey)),
                onPressed: (isFullyDone && !isOtherDoing) ? (isIAmDoing ? () => _markAsDelivered(order['id']) : () => _startDelivery(order['id'], currentWaiterId)) : null,
                child: Text(isOtherDoing ? 'ĐÃ CÓ NGƯỜI GIAO' : (isIAmDoing ? 'XÁC NHẬN ĐÃ GIAO' : (isFullyDone ? 'NHẬN GIAO MÓN' : 'ĐANG NẤU...'))),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 2,
        child: AlertDialog(
          title: const Text('LỊCH SỬ PHỤC VỤ', style: TextStyle(fontWeight: FontWeight.bold)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 700, height: 600,
            child: Column(
              children: [
                const TabBar(labelColor: Colors.blue, unselectedLabelColor: Colors.grey, tabs: [Tab(text: 'GIAO MÓN'), Tab(text: 'DỌN DẸP')]),
                Expanded(child: TabBarView(children: [_buildHistoryList('orders', 'delivered_at'), _buildHistoryList('room_services', 'completed_at')])),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ĐÓNG'))],
        ),
      ),
    );
  }

  Widget _buildHistoryList(String table, String timeField) {
    final String selectQuery = table == 'orders' 
        ? '*, delivery:delivery_waiter_id(display_name)' 
        : '*, waiter:waiter_id(display_name)';
    
    // Sửa lỗi lọc: orders dùng cột 'status' (TEXT), room_services dùng cột 'status_id' (INT)
    final String filterColumn = table == 'orders' ? 'status' : 'status_id';
    final dynamic filterValue = table == 'orders' ? 'DELIVERED' : ServiceStatus.completed;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from(table)
          .select(selectQuery)
          .eq(filterColumn, filterValue)
          .order(timeField, ascending: false)
          .limit(30),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty) return const Center(child: Text('Chưa có lịch sử.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: data.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, idx) {
            final item = data[idx];
            final name = table == 'orders' ? (item['delivery']?['display_name'] ?? 'Không rõ') : (item['waiter']?['display_name'] ?? 'Không rõ');
            
            String titleStr = 'Phòng ${item['room_number']}';
            if (table == 'room_services') {
              final type = item['service_type'] == 'CLEANING' ? 'Dọn dẹp' : 'Hỗ trợ khách';
              titleStr += ' - $type';
            }

            return ListTile(
              leading: Icon(
                table == 'orders' ? Icons.check_circle : Icons.cleaning_services, 
                color: table == 'orders' ? Colors.green : Colors.purple
              ),
              title: Text(titleStr, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Hoàn tất: ${_formatDateTime(item[timeField])} | Bởi: $name'),
            );
          },
        );
      },
    );
  }
}
