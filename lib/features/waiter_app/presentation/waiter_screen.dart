import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart';
import '../../admin_panel/providers/menu_provider.dart';
import '../providers/waiter_provider.dart';

class WaiterScreen extends ConsumerStatefulWidget {
  const WaiterScreen({super.key});

  @override
  ConsumerState<WaiterScreen> createState() => _WaiterScreenState();
}

class _WaiterScreenState extends ConsumerState<WaiterScreen> {

  // Hàm xử lý khi Nhân viên bấm "Đã giao lên phòng"
  Future<void> _markAsDelivered(String orderId) async {
    try {
      await supabase.from('orders').update({
        'status': 'DELIVERED',
        'delivered_at': DateTime.now().toUtc().toIso8601String(), // Lưu lịch sử giao xong chuẩn UTC
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

  // Hàm hỗ trợ format thời gian
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

  // Hàm hiển thị Lịch sử giao nhận
  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LỊCH SỬ ĐƠN HÀNG ĐÃ GIAO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        content: SizedBox(
          width: 600,
          height: 500,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('orders')
                .select('*')
                .eq('status', 'DELIVERED')
                .order('delivered_at', ascending: false)
                .limit(20),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data ?? [];
              if (data.isEmpty) return const Center(child: Text('Chưa có đơn hàng nào được giao.'));

              return ListView.separated(
                itemCount: data.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, idx) {
                  final o = data[idx];
                  return ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text('Phòng ${o['room_number']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Đã giao lúc: ${_formatDateTime(o['delivered_at'])}'),
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
    final waiterOrders = ref.watch(waiterOrdersProvider);
    final menuAsync = ref.watch(menuItemsStreamProvider);

    // ==========================================
    // LOGIC THÔNG BÁO KHI BẾP NẤU XONG MÓN (REALTIME)
    // ==========================================
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(activeTicketsStreamProvider, (previous, next) {
      // Chỉ kiểm tra nếu đã có dữ liệu cũ (tránh báo ảo lúc mới mở app)
      if (previous != null && previous.hasValue && next.hasValue) {
        final prevTickets = previous.value!;
        final nextTickets = next.value!;

        // Tìm các vé vừa được chuyển sang DONE
        for (var newTicket in nextTickets) {
          if (newTicket['status'] == 'DONE') {
            // Kiểm tra xem trong state trước đó, vé này đã DONE chưa
            final oldTicket = prevTickets.firstWhere((t) => t['id'] == newTicket['id'], orElse: () => {});
            if (oldTicket.isNotEmpty && oldTicket['status'] != 'DONE') {

              // Lấy tên món và số phòng để thông báo
              String itemName = 'Một món ăn';
              menuAsync.whenData((menu) {
                final match = menu.where((m) => m['id'] == newTicket['item_id']);
                if (match.isNotEmpty) itemName = match.first['name'];
              });

              // Nổ thông báo bằng SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.notifications_active, color: Colors.yellow),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Ting! $itemName đã nấu xong. Hãy lấy và mang lên phòng ngay!', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    backgroundColor: Colors.green[700],
                    duration: const Duration(seconds: 5),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(20),
                  )
              );
            }
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('ĐIỀU PHỐI GIAO NHẬN (WAITER)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.green[700],
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            tooltip: 'Lịch sử giao',
            onPressed: _showHistoryDialog,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await supabase.auth.signOut();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: waiterOrders.isEmpty
          ? const Center(child: Text('Hiện không có đơn hàng nào cần xử lý.', style: TextStyle(fontSize: 18, color: Colors.grey)))
          : GridView.builder(
        padding: const EdgeInsets.all(24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // Hiển thị 3 đơn 1 hàng trên Tablet
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 0.85,
        ),
        itemCount: waiterOrders.length,
        itemBuilder: (context, index) {
          final orderData = waiterOrders[index];
          return _buildOrderCard(orderData, menuAsync.value ?? []);
        },
      ),
    );
  }

  // Widget hiển thị Từng Đơn hàng (Card)
  Widget _buildOrderCard(WaiterOrderModel orderData, List<Map<String, dynamic>> menuItems) {
    final order = orderData.order;
    final tickets = orderData.tickets;
    final isFullyDone = orderData.isFullyDone;

    // Đếm số lượng món
    final totalItems = tickets.length;
    final doneItems = tickets.where((t) => t['status'] == 'DONE').length;

    return Card(
      elevation: isFullyDone ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isFullyDone ? Colors.green : Colors.transparent, width: 3),
      ),
      child: Column(
        children: [
          // Header: Số phòng & Trạng thái tổng
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: isFullyDone ? Colors.green[100] : Colors.blue[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    'Phòng ${order['room_number']}',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isFullyDone ? Colors.green[800] : Colors.blue[900])
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: isFullyDone ? Colors.green[700] : Colors.orange,
                      borderRadius: BorderRadius.circular(20)
                  ),
                  child: Text(
                      isFullyDone ? 'SẴN SÀNG GIAO' : 'ĐANG NẤU ($doneItems/$totalItems)',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                  ),
                )
              ],
            ),
          ),

          // Body: Danh sách món ăn chi tiết
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final ticket = tickets[idx];

                // Lấy tên món
                String itemName = 'Đang tải...';
                final match = menuItems.where((m) => m['id'] == ticket['item_id']);
                if (match.isNotEmpty) itemName = match.first['name'];

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _getTicketIcon(ticket['status']),
                  title: Text('${ticket['quantity']}x $itemName', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: ticket['notes'] != null && ticket['notes'].toString().isNotEmpty
                      ? Text('Ghi chú: ${ticket['notes']}', style: const TextStyle(color: Colors.red, fontStyle: FontStyle.italic))
                      : null,
                );
              },
            ),
          ),

          // Footer: Nút Giao Hàng
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.room_service),
                label: Text(isFullyDone ? 'XÁC NHẬN ĐÃ GIAO XONG' : 'ĐỢI BẾP NẤU XONG'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFullyDone ? Colors.green[700] : Colors.grey[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: isFullyDone ? () => _markAsDelivered(order['id']) : null,
              ),
            ),
          )
        ],
      ),
    );
  }

  // Icon hiển thị theo trạng thái món
  Widget _getTicketIcon(String status) {
    switch (status) {
      case 'PENDING': return const Icon(Icons.access_time, color: Colors.grey);
      case 'COOKING': return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange));
      case 'DONE': return const Icon(Icons.check_circle, color: Colors.green);
      default: return const Icon(Icons.help_outline);
    }
  }
}