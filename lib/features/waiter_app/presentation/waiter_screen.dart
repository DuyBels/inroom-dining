import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    await supabase.from('room_services').update({'status': 'PROCESSING', 'waiter_id': waiterId}).eq('id', serviceId);
  }

  Future<void> _completeService(String serviceId) async {
    await supabase.from('room_services').update({'status': 'COMPLETED', 'completed_at': DateTime.now().toUtc().toIso8601String()}).eq('id', serviceId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Hoàn tất nhiệm vụ!'), backgroundColor: Colors.blue));
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.parse(isoString).toLocal();
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
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

    // SnackBar Listeners
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
          backgroundColor: Colors.grey[200],
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('🧹 PHÒNG ${s['room_number']} yêu cầu dịch vụ!'),
              backgroundColor: Colors.blue[900],
            ));
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
          const Spacer(),
          Icon(isCleaning ? Icons.cleaning_services : Icons.person_search, size: 80, color: themeColor),
          const SizedBox(height: 12),
          Text(isCleaning ? "CẦN DỌN DẸP" : "KHÁCH CẦN HỖ TRỢ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: themeColor)),
          const Spacer(),
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
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final t = tickets[idx];
                final name = menuItems.firstWhere((m) => m['id'] == t['item_id'], orElse: () => {'name': '...'})['name'];
                return ListTile(dense: true, title: Text('${t['quantity']}x $name'), leading: Icon(t['status'] == 'DONE' ? Icons.check_circle : Icons.timer, color: t['status'] == 'DONE' ? Colors.green : Colors.grey));
              },
            ),
          ),
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
    // Xác định đúng cột quan hệ dựa trên bảng
    // orders -> delivery_waiter_id
    // room_services -> waiter_id
    final String selectQuery = table == 'orders' 
        ? '*, delivery:delivery_waiter_id(display_name)' 
        : '*, waiter:waiter_id(display_name)';

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase
          .from(table)
          .select(selectQuery)
          .eq('status', table == 'orders' ? 'DELIVERED' : 'COMPLETED')
          .order(timeField, ascending: false)
          .limit(30),
      builder: (context, snapshot) {
        // 1. Xử lý trạng thái đang tải
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Xử lý trạng thái lỗi (Nếu có lỗi query sẽ hiện ở đây)
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Lỗi tải lịch sử: ${snapshot.error}', 
                textAlign: TextAlign.center, 
                style: const TextStyle(color: Colors.red)),
            ),
          );
        }

        final data = snapshot.data ?? [];
        
        // 3. Xử lý khi không có dữ liệu
        if (data.isEmpty) {
          return const Center(child: Text('Chưa có lịch sử hoạt động.'));
        }

        // 4. Hiển thị danh sách
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: data.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, idx) {
            final item = data[idx];
            // Lấy tên nhân viên dựa trên quan hệ của từng bảng
            final name = table == 'orders' 
                ? (item['delivery']?['display_name'] ?? 'Không rõ')
                : (item['waiter']?['display_name'] ?? 'Không rõ');

            return ListTile(
              leading: Icon(
                table == 'orders' ? Icons.check_circle : Icons.cleaning_services, 
                color: table == 'orders' ? Colors.green : Colors.purple
              ),
              title: Text('Phòng ${item['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Hoàn tất: ${_formatDateTime(item[timeField])} | Bởi: $name'),
            );
          },
        );
      },
    );
  }
}
