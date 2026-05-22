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

  Future<void> _startDelivery(String orderId, String currentWaiterId) async {
    try {
      await supabase.from('orders').update({
        'delivery_waiter_id': currentWaiterId,
      }).eq('id', orderId);
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã hoàn tất giao đơn hàng!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _startCleaning(String orderId, String currentWaiterId) async {
    try {
      await supabase.from('orders').update({
        'cleaning_waiter_id': currentWaiterId,
      }).eq('id', orderId);
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
            const SnackBar(content: Text('Đã dọn dẹp xong phòng!'), backgroundColor: Colors.blue)
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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
                .limit(40),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data ?? [];
              if (data.isEmpty) return const Center(child: Text('Chưa có lịch sử phục vụ.'));

              return ListView.separated(
                itemCount: data.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, idx) {
                  final o = data[idx];
                  final bool isCleaning = o['cleaning_completed_at'] != null;
                  final deliveryName = o['delivery']?['display_name'] ?? 'Không rõ';
                  final cleaningName = o['cleaning']?['display_name'] ?? 'Không rõ';

                  return ListTile(
                    leading: Icon(
                      isCleaning ? Icons.cleaning_services : Icons.check_circle, 
                      color: isCleaning ? Colors.blue : Colors.green
                    ),
                    title: Text('Phòng ${o['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (o['delivered_at'] != null)
                          Text('Đã giao lúc: ${_formatDateTime(o['delivered_at'])} (Bởi: $deliveryName)'),
                        if (isCleaning)
                          Text('Đã dọn lúc: ${_formatDateTime(o['cleaning_completed_at'])} (Bởi: $cleaningName)', style: const TextStyle(color: Colors.blue)),
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

    // 1. Kiểm tra trạng thái Redirect (Nếu chưa có ID trên URL)
    if (waiterId == null) {
      return profileAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, s) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
        data: (profile) {
          if (profile != null && (profile['role'] == 'WAITER' || profile['role'] == 'ADMIN')) {
            final id = profile['id'];
            Future.microtask(() => context.go('/waiter/$id'));
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return const Scaffold(
            body: Center(
              child: Text('Tài khoản không có quyền truy cập hoặc không tìm thấy thông tin nhân viên.'),
            ),
          );
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

        // Logic thông báo Realtime
        ref.listen<AsyncValue<List<Map<String, dynamic>>>>(activeTicketsStreamProvider, (previous, next) {
          if (previous != null && previous.hasValue && next.hasValue) {
            final prevTickets = previous.value!;
            final nextTickets = next.value!;
            for (var newTicket in nextTickets) {
              if (newTicket['status'] == 'DONE') {
                final oldTicket = prevTickets.firstWhere((t) => t['id'] == newTicket['id'], orElse: () => {});
                if (oldTicket.isNotEmpty && oldTicket['status'] != 'DONE') {
                  String itemName = 'Món ăn';
                  menuAsync.whenData((menu) {
                    final match = menu.where((m) => m['id'] == newTicket['item_id']);
                    if (match.isNotEmpty) itemName = match.first['name'];
                  });
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Ting! $itemName đã nấu xong!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            }
          }
        });

        return Scaffold(
          backgroundColor: Colors.grey[200],
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ĐIỀU PHỐI GIAO NHẬN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                Row(
                  children: [
                    Text('Nhân viên: ${currentProfile['display_name']}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                    const SizedBox(width: 10),
                    Text('Tab: ${waiterId.substring(0, 5)}...', style: const TextStyle(color: Colors.white38, fontSize: 9)),
                  ],
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            actions: [
              IconButton(icon: const Icon(Icons.history, color: Colors.white), onPressed: _showHistoryDialog),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () async {
                  ref.invalidate(userProfileProvider);
                  await supabase.auth.signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: waiterOrders.isEmpty
              ? const Center(child: Text('Hiện không có đơn hàng nào cần xử lý.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    childAspectRatio: 0.85,
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
    
    // Logic dọn bàn
    final bool needsCleaning = order['needs_cleaning'] ?? false;
    final String? cleaningWaiterId = order['cleaning_waiter_id'];
    final bool isIAmCleaning = cleaningWaiterId == currentWaiterId;
    final bool isSomeoneElseCleaning = cleaningWaiterId != null && cleaningWaiterId != currentWaiterId;

    // Logic giao hàng
    final String? deliveryWaiterId = order['delivery_waiter_id'];
    final bool isIAmDelivering = deliveryWaiterId == currentWaiterId;
    final bool isSomeoneElseDelivering = deliveryWaiterId != null && deliveryWaiterId != currentWaiterId;

    final doneItems = tickets.where((t) => t['status'] == 'DONE').length;

    Color cardBorderColor = Colors.transparent;
    if (needsCleaning) {
      cardBorderColor = isSomeoneElseCleaning ? Colors.grey : Colors.blue;
    } else if (isFullyDone) {
      cardBorderColor = isSomeoneElseDelivering ? Colors.grey : Colors.green;
    }

    String statusText = 'ĐANG NẤU ($doneItems/${tickets.length})';
    Color statusBgColor = Colors.orange;

    if (needsCleaning) {
      if (isSomeoneElseCleaning) {
        statusText = 'ĐANG DỌN...';
        statusBgColor = Colors.grey;
      } else if (isIAmCleaning) {
        statusText = 'TÔI ĐANG DỌN';
        statusBgColor = Colors.orange;
      } else {
        statusText = 'CẦN DỌN BÀN';
        statusBgColor = Colors.blue[700]!;
      }
    } else if (isFullyDone) {
      if (isSomeoneElseDelivering) {
        statusText = 'ĐANG GIAO...';
        statusBgColor = Colors.grey;
      } else if (isIAmDelivering) {
        statusText = 'TÔI ĐANG GIAO';
        statusBgColor = Colors.orange;
      } else {
        statusText = 'SẴN SÀNG GIAO';
        statusBgColor = Colors.green[700]!;
      }
    }

    return Card(
      elevation: (isFullyDone || needsCleaning) ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorderColor, width: 3),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: needsCleaning ? Colors.blue[50] : (isFullyDone ? Colors.green[100] : Colors.blue[50]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Phòng ${order['room_number']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20)
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: needsCleaning
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cleaning_services, size: 64, color: Colors.blue),
                        const SizedBox(height: 8),
                        const Text('YÊU CẦU DỌN MÂM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        if (order['cleaning_requested_at'] != null)
                          Text('Yêu cầu lúc: ${_formatDateTime(order['cleaning_requested_at'])}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: tickets.length,
                    itemBuilder: (context, idx) {
                      final ticket = tickets[idx];
                      final match = menuItems.where((m) => m['id'] == ticket['item_id']);
                      final itemName = match.isNotEmpty ? match.first['name'] : 'Đang tải...';
                      return ListTile(
                        leading: _getTicketIcon(ticket['status']),
                        title: Text('${ticket['quantity']}x $itemName', style: const TextStyle(fontSize: 14)),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 45,
              child: needsCleaning
                  ? ElevatedButton.icon(
                      icon: Icon(isIAmCleaning ? Icons.check_circle : Icons.cleaning_services),
                      label: Text(isSomeoneElseCleaning ? 'CÓ NGƯỜI ĐANG DỌN' : (isIAmCleaning ? 'XÁC NHẬN XONG' : 'NHẬN DỌN PHÒNG')),
                      style: ElevatedButton.styleFrom(backgroundColor: isIAmCleaning ? Colors.green : Colors.blue),
                      onPressed: isSomeoneElseCleaning ? null : (isIAmCleaning ? () => _completeCleaning(order['id']) : () => _startCleaning(order['id'], currentWaiterId)),
                    )
                  : ElevatedButton.icon(
                      icon: Icon(isIAmDelivering ? Icons.check_circle : Icons.room_service),
                      label: Text(isSomeoneElseDelivering ? 'CÓ NGƯỜI ĐANG GIAO' : (isIAmDelivering ? 'XÁC NHẬN ĐÃ GIAO' : (isFullyDone ? 'NHẬN GIAO MÓN' : 'ĐỢI BẾP...'))),
                      style: ElevatedButton.styleFrom(backgroundColor: isIAmDelivering ? Colors.green : (isFullyDone ? Colors.green[700] : Colors.grey)),
                      onPressed: (isFullyDone && !isSomeoneElseDelivering) ? (isIAmDelivering ? () => _markAsDelivered(order['id']) : () => _startDelivery(order['id'], currentWaiterId)) : null,
                    ),
            ),
          )
        ],
      ),
    );
  }

  Widget _getTicketIcon(String status) {
    switch (status) {
      case 'DONE': return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'COOKING': return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
      default: return const Icon(Icons.access_time, color: Colors.grey, size: 20);
    }
  }
}
