import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> _submitOrderWithConfirmation() async {
    final cart = ref.read(cartProvider);
    final total = ref.read(cartTotalProvider);
    if (cart.isEmpty) return;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận Đặt món'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: ListView.builder(
                shrinkWrap: true,
                itemCount: cart.length,
                itemBuilder: (c, i) => ListTile(
                  title: Text('${cart[i].quantity}x ${cart[i].menuItem['name']}'),
                  subtitle: Text(cart[i].selectedToppings.map((t) => t['name']).join(', ')),
                  trailing: Text('${cart[i].totalPrice} đ'),
                ),
              )),
              const Divider(),
              Text('TỔNG CỘNG: $total đ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gửi yêu cầu')),
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
        'selected_toppings': c.selectedToppings,
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
      await supabase.from('room_services').insert({
        'room_number': widget.roomNumber,
        'service_type': type,
        'status': 'PENDING',
      });
      if (mounted) {
        String msg = type == 'CLEANING' ? 'Đã gọi dọn phòng!' : 'Đã gọi nhân viên!';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.blue));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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
      width: 350, color: Colors.grey[50],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Giỏ hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ElevatedButton(onPressed: () => _requestService('CALL_STAFF'), child: const Text('GỌI NV')),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _requestService('CLEANING'), icon: const Icon(Icons.cleaning_services), label: const Text('YÊU CẦU DỌN BÀN'))),
            ]),
          ),
          Expanded(child: cart.isEmpty ? const Center(child: Text('Trống')) : ListView.builder(
            itemCount: cart.length,
            itemBuilder: (context, index) {
              final item = cart[index];
              return Card(margin: const EdgeInsets.all(8), child: ListTile(
                title: Text(item.menuItem['name']),
                subtitle: Text('${item.quantity}x | ${item.totalPrice} đ'),
                trailing: IconButton(icon: const Icon(Icons.remove_circle), onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.uniqueId, -1)),
              ));
            },
          )),
          Container(padding: const EdgeInsets.all(16), color: Colors.white, child: Column(children: [
            Text('TỔNG: $cartTotal đ', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: cart.isEmpty ? null : _submitOrderWithConfirmation, child: const Text('ĐẶT MÓN'))),
          ])),
          const Divider(),
          const Padding(padding: EdgeInsets.all(8), child: Text('TRẠNG THÁI', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Container(
            color: Colors.amber[50],
            child: menuAsync.when(
              data: (menuItems) {
                final tickets = roomTicketsAsync;
                final services = roomServicesAsync.value ?? [];
                return ListView(children: [
                  ...services.map((s) => ListTile(
                    leading: Icon(s['service_type'] == 'CLEANING' ? Icons.cleaning_services : Icons.person_search, color: Colors.purple),
                    title: Text(s['service_type'] == 'CLEANING' ? 'Dọn dẹp' : 'Hỗ trợ'),
                    subtitle: Text(s['status'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
                  ...tickets.map((t) {
                    final m = menuItems.firstWhere((i) => i['id'] == t['item_id'], orElse: () => {'name': '...'});
                    return ListTile(
                      leading: Icon(t['status'] == 'DONE' ? Icons.check_circle : Icons.timer, color: t['status'] == 'DONE' ? Colors.green : Colors.orange),
                      title: Text(m['name']),
                      subtitle: Text(t['status']),
                    );
                  }),
                ]);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Lỗi: $e'),
            ),
          )),
        ],
      ),
    );
  }
}
