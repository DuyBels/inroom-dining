import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../main.dart';
import '../../../admin_panel/providers/menu_provider.dart';
import '../../providers/room_menu_provider.dart';
import '../../../waiter_app/providers/room_service_provider.dart';

class CartAndTrackingPanel extends ConsumerStatefulWidget {
  final String roomNumber;
  const CartAndTrackingPanel({super.key, required this.roomNumber});

  @override
  ConsumerState<CartAndTrackingPanel> createState() => _CartAndTrackingPanelState();
}

class _CartAndTrackingPanelState extends ConsumerState<CartAndTrackingPanel> {

  // --- LOGIC: ĐẶT MÓN & XÁC NHẬN ---
  Future<void> _submitOrderWithConfirmation() async {
    final cart = ref.read(cartProvider);
    final total = ref.read(cartTotalProvider);
    if (cart.isEmpty) return;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận Đặt món', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Kiểm tra lại danh sách món ăn:'),
              const Divider(),
              Flexible(child: ListView.builder(
                shrinkWrap: true,
                itemCount: cart.length,
                itemBuilder: (c, i) => ListTile(
                  dense: true,
                  title: Text('${cart[i].quantity}x ${cart[i].menuItem['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(cart[i].selectedModifiers.map((m) => m.modifierName).join(', ')),
                  trailing: Text('${cart[i].totalPrice} đ'),
                ),
              )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TỔNG CỘNG:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('$total đ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thay đổi')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gửi yêu cầu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final orderRes = await supabase.from('orders').insert({'room_number': widget.roomNumber, 'status': 'PENDING'}).select('id').single();
      final orderId = orderRes['id'];

      final List<Map<String, dynamic>> tickets = cart.map((c) => {
        'order_id': orderId,
        'item_id': c.menuItem['id'],
        'station_id': c.menuItem['station_id'],
        'quantity': c.quantity,
        'notes': c.notes,
        'selected_modifiers': c.selectedModifiers.map((m) => m.toJson()).toList(),
        'status': 'PENDING',
      }).toList();

      await supabase.from('tickets').insert(tickets);
      ref.read(cartProvider.notifier).clearCart();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đặt món thành công!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _requestService(String type) async {
    try {
      await supabase.from('room_services').insert({'room_number': widget.roomNumber, 'service_type': type, 'status': 'PENDING'});
      if (mounted) {
        String msg = type == 'CLEANING' ? 'Đã gọi dọn phòng!' : 'Đã gọi nhân viên!';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.blue));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  // --- LOGIC: XEM LỊCH SỬ ---
  void _showOrderHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lịch sử hoạt động', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 600,
          height: 450,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase.from('orders')
                .select('*, tickets(quantity, menu_items(name))')
                .eq('room_number', widget.roomNumber)
                .order('created_at', ascending: false)
                .limit(20),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) return const Center(child: Text('Chưa có lịch sử.'));

              return ListView.separated(
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (ctx, i) {
                  final o = orders[i];
                  final date = DateTime.parse(o['created_at']).toLocal();
                  final List tickets = o['tickets'] ?? [];
                  
                  return ExpansionTile(
                    title: Text('Đơn hàng #${o['id'].toString().substring(0, 5)}'),
                    subtitle: Text('Lúc: ${DateFormat('HH:mm dd/MM').format(date)} - ${_translateOrderStatus(o['status'])}'),
                    children: tickets.map((t) => ListTile(
                      dense: true,
                      title: Text(t['menu_items']?['name'] ?? 'Món ăn'),
                      trailing: Text('${t['quantity']} phần'),
                    )).toList(),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
      ),
    );
  }

  String _translateOrderStatus(String status) {
    switch (status) {
      case 'PENDING': return 'Đã nhận';
      case 'PROCESSING': return 'Đang chuẩn bị';
      case 'READY_FOR_DELIVERY': return 'Đang giao';
      case 'DELIVERED': return 'Đã hoàn tất';
      default: return status;
    }
  }

  String _translateTicketStatus(String status) {
    switch (status) {
      case 'PENDING': return 'Đang chờ';
      case 'COOKING': return 'Đang chế biến';
      case 'DONE': return 'Đã xong';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final roomTicketsAsync = ref.watch(activeRoomTicketsProvider(widget.roomNumber));
    final roomServicesAsync = ref.watch(roomServicesByRoomStreamProvider(widget.roomNumber));
    final menuAsync = ref.watch(menuItemsStreamProvider);

    return Container(
      width: 400,
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        children: [
          // 1. Header Dịch vụ
          _buildActionHeader(),

          // 2. Giỏ hàng
          Expanded(
            flex: 3,
            child: cart.isEmpty 
              ? const Center(child: Text('Giỏ hàng trống', style: TextStyle(color: Colors.grey))) 
              : _buildCartList(cart),
          ),

          // 3. Checkout
          if (cart.isNotEmpty) _buildCheckoutSection(cartTotal),

          const Divider(height: 1, thickness: 1),

          // 4. TIẾN ĐỘ & TRẠNG THÁI (UX CAO CẤP)
          _buildTrackingSection(roomTicketsAsync, roomServicesAsync.value ?? []),
        ],
      ),
    );
  }

  Widget _buildActionHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [Icon(Icons.shopping_bag_outlined), SizedBox(width: 8), Text('GIỎ HÀNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
              TextButton.icon(onPressed: _showOrderHistory, icon: const Icon(Icons.history, size: 18), label: const Text('Lịch sử', style: TextStyle(fontSize: 12))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person, size: 16),
                  label: const Text('GỌI NV'),
                  onPressed: () => _requestService('CALL_STAFF'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[50], foregroundColor: Colors.purple[800], elevation: 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('DỌN BÀN'),
                  onPressed: () => _requestService('CLEANING'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.blue[800], side: BorderSide(color: Colors.blue[200]!)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCartList(List<CartItem> cart) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final item = cart[index];
        return Card(
          elevation: 0, color: Colors.grey[50],
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(item.menuItem['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.selectedModifiers.isNotEmpty)
                  ...item.selectedModifiers.map((m) => Text('↳ ${m.groupName}: ${m.modifierName}', style: const TextStyle(fontSize: 11, color: Colors.blueGrey))),
                if (item.notes.isNotEmpty)
                  Text('Ghi chú: ${item.notes}', style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontStyle: FontStyle.italic)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${item.totalPrice} đ', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.uniqueId, -1)),
                Text('${item.quantity}'),
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.uniqueId, 1)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutSection(double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text('Tổng cộng:'), Text('$total đ', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red))],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              onPressed: _submitOrderWithConfirmation,
              child: const Text('ĐẶT MÓN NGAY', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTrackingSection(List<Map<String, dynamic>> tickets, List<Map<String, dynamic>> services) {
    if (tickets.isEmpty && services.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.blueGrey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Text('TRẠNG THÁI YÊU CẦU', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2))),
          const SizedBox(height: 15),

          // 1. PHẦN TIẾN ĐỘ MÓN ĂN (Nếu có)
          if (tickets.isNotEmpty) ...[
            _buildFoodProgress(tickets),
            const SizedBox(height: 20),
          ],

          // 2. PHẦN YÊU CẦU DỊCH VỤ (Nếu có)
          if (services.isNotEmpty) ...[
            if (tickets.isNotEmpty) const Divider(height: 30),
            _buildServiceProgress(services),
          ],
        ],
      ),
    );
  }

  Widget _buildFoodProgress(List<Map<String, dynamic>> tickets) {
    final menuItems = ref.read(menuItemsStreamProvider).value ?? [];
    
    int currentStep = 0;
    
    // Logic tiến độ mới:
    bool allDone = tickets.isNotEmpty && tickets.every((t) => t['status'] == 'DONE');
    bool anyCooking = tickets.any((t) => t['status'] == 'COOKING');

    if (allDone) {
      currentStep = 2; // Đang giao
    } else if (anyCooking) {
      currentStep = 1; // Chuẩn bị (Bếp đang nấu ít nhất 1 món)
    } else {
      currentStep = 0; // Đã nhận (Bếp chưa nấu món nào hoặc đang đợi)
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.restaurant, size: 16, color: Colors.orange),
            SizedBox(width: 8),
            Text('Tiến độ món ăn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 15),
        _MinimalistTracker(currentStep: currentStep),
        const SizedBox(height: 15),
        ...tickets.map((t) {
          final item = menuItems.firstWhere((m) => m['id'] == t['item_id'], orElse: () => {'name': 'Món ăn'});
          final List modifiers = t['selected_modifiers'] ?? [];
          final String notes = t['notes'] ?? '';

          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(t['status'] == 'DONE' ? Icons.check_circle : Icons.radio_button_unchecked, 
                         size: 12, color: t['status'] == 'DONE' ? Colors.green : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${t['quantity']}x ${item['name']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    Text(_translateTicketStatus(t['status']), style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                  ],
                ),
                if (modifiers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(
                      modifiers.map((e) => '↳ ${e['group_name']}: ${e['modifier_name']}').join('\n'), 
                      style: const TextStyle(fontSize: 9, color: Colors.grey)
                    ),
                  ),
                if (notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text('Ghi chú: $notes', style: const TextStyle(fontSize: 9, color: Colors.redAccent, fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildServiceProgress(List<Map<String, dynamic>> services) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.room_service, size: 16, color: Colors.purple),
            SizedBox(width: 8),
            Text('Hỗ trợ & Dịch vụ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        ...services.map((s) {
          final isPending = s['status'] == 'PENDING';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(
                  color: isPending ? Colors.amber : Colors.purple, 
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPending ? Icons.hourglass_empty : Icons.directions_run, 
                  size: 18, 
                  color: isPending ? Colors.amber[800] : Colors.purple
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['service_type'] == 'CLEANING' ? 'Yêu cầu dọn bàn' : 'Yêu cầu gọi nhân viên',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)
                      ),
                      Text(
                        isPending ? 'Đã gửi yêu cầu - Vui lòng đợi' : 'Nhân viên đang trên đường tới',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600])
                      ),
                    ],
                  ),
                ),
                if (!isPending)
                  const Icon(Icons.check, color: Colors.green, size: 16),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _MinimalistTracker extends StatelessWidget {
  final int currentStep;
  const _MinimalistTracker({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStep(0, "Đã nhận", Icons.assignment_turned_in),
        _buildLine(0),
        _buildStep(1, "Chuẩn bị", Icons.restaurant),
        _buildLine(1),
        _buildStep(2, "Đang giao", Icons.delivery_dining),
      ],
    );
  }

  Widget _buildStep(int step, String label, IconData icon) {
    bool isActive = currentStep >= step;
    return Column(
      children: [
        Icon(icon, color: isActive ? Colors.orange : Colors.grey[400], size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: isActive ? Colors.black : Colors.grey)),
      ],
    );
  }

  Widget _buildLine(int step) {
    return Expanded(child: Container(height: 2, color: currentStep > step ? Colors.orange : Colors.grey[300]));
  }
}
