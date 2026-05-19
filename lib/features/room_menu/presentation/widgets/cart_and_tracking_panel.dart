import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../main.dart'; // import supabase global
import '../../../admin_panel/providers/menu_provider.dart';
import '../../providers/room_menu_provider.dart';

class CartAndTrackingPanel extends ConsumerStatefulWidget {
  final String roomNumber;

  const CartAndTrackingPanel({super.key, required this.roomNumber});

  @override
  ConsumerState<CartAndTrackingPanel> createState() => _CartAndTrackingPanelState();
}

class _CartAndTrackingPanelState extends ConsumerState<CartAndTrackingPanel> {

  // ==========================================
  // HÀM XỬ LÝ ĐẶT MÓN (Được chuyển từ file chính sang đây)
  // ==========================================
  Future<void> _submitOrder() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      final orderResponse = await supabase.from('orders').insert({
        'room_number': widget.roomNumber,
        'status': 'PENDING'
      }).select('id').single();

      final orderId = orderResponse['id'];

      final List<Map<String, dynamic>> ticketsToInsert = cart.map((cartItem) {
        return {
          'order_id': orderId,
          'item_id': cartItem.menuItem['id'],
          'station_id': cartItem.menuItem['station_id'],
          'quantity': cartItem.quantity,
          'notes': cartItem.notes,
          'status': 'PENDING',
        };
      }).toList();

      await supabase.from('tickets').insert(ticketsToInsert);

      ref.read(cartProvider.notifier).clearCart();

      if (mounted) {
        Navigator.pop(context); // Đóng Loading
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi yêu cầu xuống Bếp thành công!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi đặt hàng: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final roomOrdersAsync = ref.watch(roomOrdersStreamProvider);
    final menuAsync = ref.watch(menuItemsStreamProvider);

    return Container(
      width: 350,
      color: Colors.grey[50],
      child: Column(
        children: [
          // ==========================================
          // PHẦN 1: GIỎ HÀNG
          // ==========================================
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: const Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.blue),
                SizedBox(width: 8),
                Text('Giỏ hàng của bạn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: cart.isEmpty
                ? const Center(child: Text('Chưa chọn món nào', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final cItem = cart[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cItem.menuItem['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${cItem.menuItem['price']} đ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => ref.read(cartProvider.notifier).updateQuantity(cItem.menuItem['id'], -1),
                            ),
                            Text('${cItem.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              onPressed: () => ref.read(cartProvider.notifier).updateQuantity(cItem.menuItem['id'], 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // KHU VỰC NÚT THANH TOÁN
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng cộng:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$cartTotal đ', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: cart.isEmpty ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('GỬI YÊU CẦU XUỐNG BẾP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),

          const Divider(thickness: 4, height: 4, color: Colors.black12),

          // ==========================================
          // PHẦN 2: THEO DÕI ĐƠN HÀNG (REALTIME)
          // ==========================================
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.amber[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.room_service, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Trạng thái Bếp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                TextButton.icon(
                  onPressed: _showOrderHistory,
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('Lịch sử', style: TextStyle(fontSize: 12)),
                )
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.amber[50],
              child: roomOrdersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Lỗi realtime: $e')),
                data: (tickets) {
                  if (tickets.isEmpty) return const Center(child: Text('Chưa có món nào đang nấu', style: TextStyle(color: Colors.grey)));

                  return ListView.builder(
                    itemCount: tickets.length,
                    itemBuilder: (context, idx) {
                      final ticket = tickets[idx];

                      String itemName = 'Đang tải...';
                      menuAsync.whenData((menuList) {
                        final match = menuList.where((m) => m['id'] == ticket['item_id']);
                        if (match.isNotEmpty) itemName = match.first['name'];
                      });

                      return ListTile(
                        leading: _getStatusIcon(ticket['status']),
                        title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Số lượng: ${ticket['quantity']} - ${_translateStatus(ticket['status'])}',
                            style: TextStyle(color: ticket['status'] == 'DONE' ? Colors.green : Colors.orange, fontWeight: FontWeight.w500)
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---
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

  void _showOrderHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LỊCH SỬ ĐẶT MÓN CỦA PHÒNG', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        content: SizedBox(
          width: 500,
          height: 500,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase
                .from('tickets')
                .select('*, menu_items(name), orders!inner(room_number)')
                .eq('orders.room_number', widget.roomNumber)
                .order('created_at', ascending: false)
                .limit(30),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data ?? [];
              if (data.isEmpty) return const Center(child: Text('Bạn chưa đặt món nào.'));

              return ListView.separated(
                itemCount: data.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, idx) {
                  final t = data[idx];
                  return ListTile(
                    title: Text('${t['quantity']}x ${t['menu_items']['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Đặt lúc: ${_formatDateTime(t['created_at'])}'),
                        if (t['status'] == 'DONE') 
                           Text('Nấu xong: ${_formatDateTime(t['finished_at'])}', style: const TextStyle(color: Colors.green, fontSize: 12)),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: _getStatusColor(t['status']), borderRadius: BorderRadius.circular(4)),
                      child: Text(_translateStatus(t['status']), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING': return Colors.grey;
      case 'COOKING': return Colors.orange;
      case 'DONE': return Colors.green;
      default: return Colors.blue;
    }
  }

  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING': return const Icon(Icons.access_time_filled, color: Colors.grey, size: 32);
      case 'COOKING': return const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.orange));
      case 'DONE': return const Icon(Icons.check_circle, color: Colors.green, size: 32);
      default: return const Icon(Icons.help_outline, size: 32);
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'PENDING': return 'Đang chờ bếp nhận';
      case 'COOKING': return 'Đang nấu...';
      case 'DONE': return 'Hoàn tất, đang mang lên!';
      default: return status;
    }
  }
}