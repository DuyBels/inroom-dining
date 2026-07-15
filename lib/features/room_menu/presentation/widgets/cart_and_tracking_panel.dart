import 'package:flutter/material.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/l10n_utils.dart';
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
    final l10n = ref.read(l10nProvider);
    final cart = ref.read(cartProvider);
    final total = ref.read(cartTotalProvider);
    if (cart.isEmpty) return;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmOrder, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${l10n.checkOrderList}:'),
              const Divider(),
              Flexible(child: ListView.builder(
                shrinkWrap: true,
                itemCount: cart.length,
                itemBuilder: (c, i) {
                   final locale = ref.watch(localeProvider);
                   final String displayName = L10nUtils.getL10n(cart[i].menuItem['name'], locale);
                   return ListTile(
                    dense: true,
                    title: Text('${cart[i].quantity}x $displayName', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(cart[i].selectedModifiers.map((m) => m.modifierName).join(', ')),
                    trailing: Text('${NumberFormat('#,###', 'vi_VN').format(cart[i].totalPrice)} VND'),
                  );
                },
              )),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${l10n.total}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${NumberFormat('#,###', 'vi_VN').format(total)} VND', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red)
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.changeLabel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.sendRequest, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

      ref.read(cartProvider.notifier).clearCart();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.orderSuccess), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _requestService(String type) async {
    String notes = "";

    // Nếu là Gọi nhân viên, hiện Dialog nhập lý do
    if (type == 'CALL_STAFF') {
      final controller = TextEditingController();
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bạn cần hỗ trợ gì?'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ví dụ: Mượn thêm máy sấy, hỏng điều hòa...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Gửi yêu cầu')),
          ],
        ),
      );
      if (confirmed != true) return;
      notes = controller.text.trim();
    }

    try {
      await supabase.from('room_services').insert({
        'room_number': widget.roomNumber,
        'service_type': type,
        'status_id': 1, // 1 = PENDING
        'notes': notes,
      });
      if (mounted) {
        String msg = type == 'CLEANING' ? 'Đã gọi dọn phòng!' : 'Đã gọi nhân viên!';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: type == 'CLEANING' ? Colors.blue : Colors.purple));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  // --- LOGIC: XEM LỊCH SỬ HOẠT ĐỘNG ---
  void _showOrderHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lịch sử hoạt động của phòng', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 600,
          height: 500,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase.from('orders')
                .select('*, tickets(quantity, menu_items(name))')
                .eq('room_number', widget.roomNumber)
                .order('created_at', ascending: false)
                .limit(20),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) return const Center(child: Text('Chưa có dữ liệu lịch sử.'));

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(height: 32),
                itemBuilder: (ctx, i) {
                  final o = orders[i];
                  final date = DateTime.parse(o['created_at']).toLocal();
                  final List tickets = o['tickets'] ?? [];
                  final locale = ref.watch(localeProvider);
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Đơn hàng #${o['id'].toString().substring(0, 5)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          _buildStatusBadge(_translateOrderStatus(o['status'])),
                        ],
                      ),
                      Text('Lúc: ${DateFormat('HH:mm - dd/MM/yyyy').format(date)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      ...tickets.map((t) {
                        final String itemName = L10nUtils.getL10n(t['menu_items']?['name'], locale);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• ${t['quantity']}x $itemName', style: const TextStyle(fontSize: 13)),
                        );
                      }),
                    ],
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

  Widget _buildStatusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
    );
  }

  String _translateOrderStatus(String status) {
    switch (status) {
      case 'PENDING': return 'Đã nhận đơn';
      case 'PROCESSING': return 'Đang chuẩn bị';
      case 'READY_FOR_DELIVERY': return 'Đang giao';
      case 'DELIVERED': return 'Hoàn tất';
      default: return status;
    }
  }

  String _translateTicketStatus(String status, AppDictionary l10n) {
    switch (status) {
      case 'PENDING': return l10n.pending;
      case 'COOKING': return l10n.cooking;
      case 'DONE': return l10n.done;
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final roomTicketsAsync = ref.watch(activeRoomTicketsProvider(widget.roomNumber));
    final roomServicesAsync = ref.watch(roomServicesByRoomStreamProvider(widget.roomNumber));
    final menuAsync = ref.watch(menuItemsStreamProvider);

    // --- LẮNG NGHE SỰ KIỆN HOÀN THÀNH ĐỂ THÔNG BÁO CHO KHÁCH ---
    
    // 1. Thông báo Giao món thành công
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(roomOrdersStreamProvider(widget.roomNumber), (prev, next) {
      if (prev?.hasValue == true && next.hasValue) {
        for (var newOrder in next.value!) {
          final oldOrder = prev!.value!.firstWhere((o) => o['id'] == newOrder['id'], orElse: () => {});
          if (newOrder['status'] == 'DELIVERED' && oldOrder.isNotEmpty && oldOrder['status'] != 'DELIVERED') {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 12), Text(l10n.enjoyMeal)]),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      }
    });

    // 2. Thông báo Dọn bàn/Hỗ trợ thành công
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(allRoomServicesStreamProvider(widget.roomNumber), (prev, next) {
      if (prev?.hasValue == true && next.hasValue) {
        for (var newSvc in next.value!) {
          final oldSvc = prev!.value!.firstWhere((s) => s['id'] == newSvc['id'], orElse: () => {});
          if (newSvc['status_id'] == ServiceStatus.completed && oldSvc.isNotEmpty && oldSvc['status_id'] != ServiceStatus.completed) {
            String msg = newSvc['service_type'] == 'CLEANING' ? 'Phòng đã được dọn dẹp xong!' : 'Yêu cầu hỗ trợ đã hoàn tất!';
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(children: [const Icon(Icons.stars, color: Colors.white), const SizedBox(width: 12), Text(msg)]),
              backgroundColor: Colors.blueAccent,
              behavior: SnackBarBehavior.floating,
            ));
          }
        }
      }
    });

    return Container(
      width: 400,
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        children: [
          // 1. Header Dịch vụ & Nút Lịch sử
          _buildActionHeader(l10n),

          Expanded(
            flex: 3,
            child: cart.isEmpty 
              ? Center(child: Text(l10n.emptyCart, style: const TextStyle(color: Colors.grey))) 
              : _buildCartList(cart, l10n),
          ),

          // 3. Checkout Section
          if (cart.isNotEmpty) _buildCheckoutSection(cartTotal, l10n),

          if (roomTicketsAsync.isNotEmpty || (roomServicesAsync.value?.isNotEmpty ?? false))
            _buildTrackingSection(roomTicketsAsync, roomServicesAsync.value ?? [], menuAsync.value ?? [], l10n),
        ],
      ),
    );
  }

  Widget _buildActionHeader(AppDictionary l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [const Icon(Icons.shopping_bag_outlined), const SizedBox(width: 8), Text(l10n.cart, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
              TextButton.icon(
                onPressed: _showOrderHistory, 
                icon: const Icon(Icons.history, size: 18), 
                label: Text(l10n.history, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person, size: 16),
                  label: Text(l10n.callStaff),
                  onPressed: () => _requestService('CALL_STAFF'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[50], foregroundColor: Colors.purple[800], elevation: 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: Text(l10n.cleaning),
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

  Widget _buildCartList(List<CartItem> cart, AppDictionary l10n) {
    final locale = ref.watch(localeProvider);
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: cart.length,
      itemBuilder: (context, index) {
        final item = cart[index];
        final locale = ref.watch(localeProvider);
        final String displayName = L10nUtils.getL10n(item.menuItem['name'], locale);
        
        return Card(
          elevation: 0, color: Colors.grey[50],
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: item.selectedModifiers.isNotEmpty ? Text('${l10n.extra}: ${item.selectedModifiers.map((m) => m.modifierName).join(', ')}', style: const TextStyle(fontSize: 11)) : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${NumberFormat('#,###', 'vi_VN').format(item.totalPrice)} VND', 
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)
                ),
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

  Widget _buildCheckoutSection(double total, AppDictionary l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${l10n.totalPayment}:'), 
              Text(
                '${NumberFormat('#,###', 'vi_VN').format(total)} VND', 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)
              )
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, elevation: 0),
              onPressed: _submitOrderWithConfirmation,
              child: Text(l10n.orderNow, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTrackingSection(List<Map<String, dynamic>> tickets, List<Map<String, dynamic>> services, List<Map<String, dynamic>> menuItems, AppDictionary l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.blueGrey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text(l10n.history.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1))),
          const SizedBox(height: 20),

          // 1. TIẾN ĐỘ GỌI MÓN (Dùng Stepper)
          if (tickets.isNotEmpty) ...[
            _buildFoodProgress(tickets, menuItems, l10n),
            const SizedBox(height: 25),
          ],

          // 2. YÊU CẦU DỊCH VỤ (Giao diện Thẻ riêng biệt)
          if (services.isNotEmpty) ...[
            const Text('Dịch vụ tại phòng:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 8),
            ...services.map((s) => _buildServiceRequestCard(s, l10n)),
          ],
        ],
      ),
    );
  }

  Widget _buildFoodProgress(List<Map<String, dynamic>> tickets, List<Map<String, dynamic>> menuItems, AppDictionary l10n) {
    bool allDone = tickets.every((t) => t['status'] == 'DONE');
    bool anyCooking = tickets.any((t) => t['status'] == 'COOKING');
    int currentStep = allDone ? 2 : (anyCooking ? 1 : 0);

    // Tính tổng thời gian dự kiến (Món lâu nhất + 5p giao hàng)
    int maxPrepTime = 0;
    for (var t in tickets) {
      final item = menuItems.firstWhere((m) => m['id'] == t['item_id'], orElse: () => {});
      final pTime = item['prep_time_minutes'] ?? 15;
      if (pTime > maxPrepTime) maxPrepTime = pTime;
    }
    final int estimatedTotal = maxPrepTime + 5;

    return Column(
      children: [
        _MinimalistTracker(currentStep: currentStep, l10n: l10n),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.amber[100], 
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber[300]!)
          ),
          child: Column(
            children: [
              Text(
                '${l10n.estimatedFinish} $estimatedTotal ${l10n.minute}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                "(${l10n.includeDelivery})",
                style: const TextStyle(fontSize: 10, color: Colors.brown),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: Text(
            currentStep == 0 ? l10n.orderReceived : (currentStep == 1 ? l10n.orderPreparing : l10n.orderDelivering),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blueGrey),
          ),
        ),
        const SizedBox(height: 15),
        ...tickets.map((t) {
          final locale = ref.watch(localeProvider);
          final item = menuItems.firstWhere((m) => m['id'] == t['item_id'], orElse: () => {'name': 'Món ăn'});
          final String displayName = L10nUtils.getL10n(item['name'], locale);
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(t['status'] == 'DONE' ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: t['status'] == 'DONE' ? Colors.green : Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text('${t['quantity']}x $displayName', style: const TextStyle(fontSize: 12))),
                Text(_translateTicketStatus(t['status'], l10n), style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildServiceRequestCard(Map<String, dynamic> s, AppDictionary l10n) {
    final isCleaning = s['service_type'] == 'CLEANING';
    final int statusId = s['status_id'] ?? 1;
    final bool isPending = statusId == 1; // 1 = PENDING
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPending ? Colors.amber[200]! : Colors.blue[200]!),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isPending ? Colors.amber[50] : Colors.blue[50],
            radius: 18,
            child: Icon(isCleaning ? Icons.cleaning_services : Icons.person, size: 18, color: isPending ? Colors.amber[800] : Colors.blue[800]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isCleaning ? l10n.cleaningRequest : l10n.supportRequest, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text(isPending ? l10n.waitingStaff : l10n.staffProcessing, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
          if (!isPending) const Icon(Icons.sync, size: 16, color: Colors.blue),
        ],
      ),
    );
  }
}

class _MinimalistTracker extends StatelessWidget {
  final int currentStep;
  final AppDictionary l10n;
  const _MinimalistTracker({required this.currentStep, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildStep(0, l10n.pending, Icons.assignment_turned_in),
        _buildLine(0),
        _buildStep(1, l10n.cooking, Icons.restaurant),
        _buildLine(1),
        _buildStep(2, l10n.delivery, Icons.delivery_dining),
      ],
    );
  }

  Widget _buildStep(int step, String label, IconData icon) {
    bool isActive = currentStep >= step;
    return Column(
      children: [
        Icon(icon, color: isActive ? Colors.orange : Colors.grey[400], size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: isActive ? Colors.black : Colors.grey, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildLine(int step) {
    return Expanded(child: Container(height: 2, color: currentStep > step ? Colors.orange : Colors.grey[300]));
  }
}
