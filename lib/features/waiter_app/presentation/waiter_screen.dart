import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart';
import '../../admin_panel/providers/menu_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/waiter_provider.dart';

class WaiterScreen extends ConsumerStatefulWidget {
  final String? waiterId;
  const WaiterScreen({super.key, this.waiterId});

  @override
  ConsumerState<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends ConsumerState<WaiterScreen> {

  // --- LOGIC GIAO MÓN ---
  Future<void> _startDelivery(String orderId, String currentWaiterId) async {
    try {
      await supabase.from('orders').update({'delivery_waiter_id': currentWaiterId}).eq('id', orderId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _markAsDelivered(String orderId) async {
    try {
      await supabase.from('orders').update({
        'status': 'DELIVERED',
        'delivered_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', orderId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  // --- LOGIC DỌN PHÒNG ---
  Future<void> _startCleaning(String orderId, String currentWaiterId) async {
    try {
      await supabase.from('orders').update({'cleaning_waiter_id': currentWaiterId}).eq('id', orderId);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _completeCleaning(String orderId) async {
    try {
      await supabase.from('orders').update({
        'needs_cleaning': false,
        'cleaning_completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã hoàn tất dọn phòng!'), backgroundColor: Colors.blue)
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.parse(isoString).toLocal();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LỊCH SỬ PHỤC VỤ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        content: SizedBox(
          width: 600,
          height: 500,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('orders')
                .select('*, delivery:delivery_waiter_id(display_name), cleaning:cleaning_waiter_id(display_name)')
                .or('status.eq.DELIVERED,cleaning_completed_at.not.is.null')
                .order('created_at', ascending: false)
                .limit(30),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data ?? [];
              if (data.isEmpty) return const Center(child: Text('Chưa có lịch sử.'));
              return ListView.separated(
                itemCount: data.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, idx) {
                  final o = data[idx];
                  final deliveryName = o['delivery']?['display_name'] ?? 'Chưa rõ';
                  final cleaningName = o['cleaning']?['display_name'] ?? 'Chưa rõ';

                  return ListTile(
                    leading: Icon(
                      o['status'] == 'DELIVERED' ? Icons.check_circle : Icons.cleaning_services, 
                      color: o['cleaning_completed_at'] != null ? Colors.blue : Colors.green
                    ),
                    title: Text('Phòng ${o['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (o['delivered_at'] != null)
                          Text('📦 Giao: ${_formatDateTime(o['delivered_at'])} (Bởi: $deliveryName)'),
                        if (o['cleaning_completed_at'] != null)
                          Text('🧹 Dọn: ${_formatDateTime(o['cleaning_completed_at'])} (Bởi: $cleaningName)', 
                              style: const TextStyle(color: Colors.blue)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ĐÓNG'))],
      ),
    );
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
          if (profile != null && (profile['role'] == 'WAITER' || profile['role'] == 'ADMIN')) {
            Future.microtask(() => context.go('/waiter/${profile['id']}'));
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return const Scaffold(body: Center(child: Text('Không có quyền truy cập.')));
        },
      );
    }

    final waiterOrders = ref.watch(waiterOrdersProvider);
    final menuAsync = ref.watch(menuItemsStreamProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
      data: (currentProfile) {
        if (currentProfile == null || (currentProfile['role'] != 'WAITER' && currentProfile['role'] != 'ADMIN')) {
          Future.microtask(() => context.go('/'));
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // --- BỘ LẮNG NGHE THÔNG BÁO REALTIME ---
        
        // 1. Thông báo khi bếp nấu xong (Tickets DONE)
        ref.listen<AsyncValue<List<Map<String, dynamic>>>>(activeTicketsStreamProvider, (prev, next) {
          if (next.hasValue && prev?.hasValue == true) {
            final orders = ref.read(activeOrdersStreamProvider).value ?? [];
            
            for (var t in next.value!) {
              final oldT = prev!.value!.firstWhere((p) => p['id'] == t['id'], orElse: () => {});
              if (t['status'] == 'DONE' && oldT.isNotEmpty && oldT['status'] != 'DONE') {
                // Lấy thông tin phòng và tên món
                final order = orders.firstWhere((o) => o['id'] == t['order_id'], orElse: () => {});
                final roomNum = order.isNotEmpty ? order['room_number'] : '???';
                
                String itemName = 'Món ăn';
                menuAsync.whenData((menu) {
                  final match = menu.where((m) => m['id'] == t['item_id']);
                  if (match.isNotEmpty) itemName = match.first['name'];
                });

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('🔔 PHÒNG $roomNum: $itemName đã nấu xong!'),
                  backgroundColor: Colors.green[700],
                  behavior: SnackBarBehavior.floating,
                ));
              }
            }
          }
        });

        // 2. Thông báo khi có khách yêu cầu dọn bàn (needs_cleaning = true)
        ref.listen<AsyncValue<List<Map<String, dynamic>>>>(activeOrdersStreamProvider, (prev, next) {
          if (next.hasValue && prev?.hasValue == true) {
            for (var o in next.value!) {
              final oldO = prev!.value!.firstWhere((p) => p['id'] == o['id'], orElse: () => {});
              if (o['needs_cleaning'] == true && (oldO.isEmpty || oldO['needs_cleaning'] != true)) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.cleaning_services, color: Colors.white),
                      const SizedBox(width: 12),
                      Text('🧹 PHÒNG ${o['room_number']} yêu cầu dọn bàn!', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  backgroundColor: Colors.blue[800],
                  duration: const Duration(seconds: 10),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            }
          }
        });

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ĐIỀU PHỐI CÔNG VIỆC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Text('Nhân viên: ${currentProfile['display_name']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.green[800],
            actions: [
              IconButton(icon: const Icon(Icons.history, color: Colors.white), onPressed: _showHistoryDialog),
              IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: () async {
                ref.invalidate(userProfileProvider);
                await supabase.auth.signOut();
                if (context.mounted) context.go('/login');
              }),
              const SizedBox(width: 16),
            ],
          ),
          body: waiterOrders.isEmpty
              ? const Center(child: Text('Hiện tại chưa có nhiệm vụ nào.', style: TextStyle(fontSize: 18, color: Colors.grey)))
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 24, mainAxisSpacing: 24, childAspectRatio: 0.82,
                  ),
                  itemCount: waiterOrders.length,
                  itemBuilder: (context, index) => _buildOrderCard(waiterOrders[index], menuAsync.value ?? [], waiterId),
                ),
        );
      },
    );
  }

  Widget _buildOrderCard(WaiterOrderModel orderData, List<Map<String, dynamic>> menuItems, String currentWaiterId) {
    final order = orderData.order;
    final tickets = orderData.tickets;
    final isFullyDone = orderData.isFullyDone;
    final bool isCleaning = order['needs_cleaning'] ?? false;

    // Phân quyền thực hiện (Locking logic)
    final String? cleaningId = order['cleaning_waiter_id'];
    final bool isIAmCleaning = cleaningId == currentWaiterId;
    final bool isOtherCleaning = cleaningId != null && cleaningId != currentWaiterId;

    final String? deliveryId = order['delivery_waiter_id'];
    final bool isIAmDelivering = deliveryId == currentWaiterId;
    final bool isOtherDelivering = deliveryId != null && deliveryId != currentWaiterId;

    // Màu sắc & Nhãn
    Color themeColor = isCleaning ? Colors.blue : (isFullyDone ? Colors.green : Colors.orange);
    String taskTitle = isCleaning ? "NHIỆM VỤ: DỌN PHÒNG" : "NHIỆM VỤ: GIAO MÓN";
    String statusText = isCleaning 
        ? (isOtherCleaning ? "ĐANG DỌN..." : (isIAmCleaning ? "TÔI ĐANG DỌN" : "CẦN DỌN BÀN"))
        : (isOtherDelivering ? "ĐANG GIAO..." : (isIAmDelivering ? "TÔI ĐANG GIAO" : (isFullyDone ? "SẴN SÀNG" : "ĐANG NẤU")));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: (isIAmCleaning || isIAmDelivering) ? Colors.orange : themeColor, width: 3),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(taskTitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: themeColor)),
                    Text('Phòng ${order['room_number']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(12)),
                  child: Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final ticket = tickets[idx];
                final match = menuItems.where((m) => m['id'] == ticket['item_id']);
                final name = match.isNotEmpty ? match.first['name'] : '...';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: _getTicketIcon(ticket['status']),
                  title: Text('${ticket['quantity']}x $name', style: const TextStyle(fontSize: 14)),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity, height: 48,
              child: isCleaning
                ? ElevatedButton.icon(
                    icon: Icon(isIAmCleaning ? Icons.check_circle : Icons.cleaning_services),
                    label: Text(isOtherCleaning ? 'ĐÃ CÓ NGƯỜI NHẬN' : (isIAmCleaning ? 'XÁC NHẬN XONG' : 'NHẬN DỌN PHÒNG')),
                    style: ElevatedButton.styleFrom(backgroundColor: isIAmCleaning ? Colors.orange : Colors.blue),
                    onPressed: isOtherCleaning ? null : (isIAmCleaning ? () => _completeCleaning(order['id']) : () => _startCleaning(order['id'], currentWaiterId)),
                  )
                : ElevatedButton.icon(
                    icon: Icon(isIAmDelivering ? Icons.check_circle : Icons.room_service),
                    label: Text(isOtherDelivering ? 'ĐÃ CÓ NGƯỜI NHẬN' : (isIAmDelivering ? 'XÁC NHẬN ĐÃ GIAO' : (isFullyDone ? 'NHẬN GIAO MÓN' : 'ĐỢI BẾP...'))),
                    style: ElevatedButton.styleFrom(backgroundColor: isIAmDelivering ? Colors.orange : (isFullyDone ? Colors.green : Colors.grey)),
                    onPressed: (isFullyDone && !isOtherDelivering) ? (isIAmDelivering ? () => _markAsDelivered(order['id']) : () => _startDelivery(order['id'], currentWaiterId)) : null,
                  ),
            ),
          )
        ],
      ),
    );
  }

  Widget _getTicketIcon(String status) {
    switch (status) {
      case 'DONE': return const Icon(Icons.check_circle, color: Colors.green, size: 18);
      case 'COOKING': return const SizedBox(width: 16, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
      default: return const Icon(Icons.access_time, color: Colors.grey, size: 18);
    }
  }
}
