import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inroom_dining/core/theme/admin_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/models/menu_item_model.dart';
import '../../../../main.dart';
import '../../../admin_panel/providers/menu_provider.dart';
import '../../providers/room_menu_provider.dart';
import '../../../waiter_app/providers/room_service_provider.dart';

class CartAndTrackingPanel extends ConsumerStatefulWidget {
  final String roomNumber;
  final bool isMobile;
  const CartAndTrackingPanel({
    super.key,
    required this.roomNumber,
    this.isMobile = false,
  });

  @override
  ConsumerState<CartAndTrackingPanel> createState() => _CartAndTrackingPanelState();
}

class _CartAndTrackingPanelState extends ConsumerState<CartAndTrackingPanel> {

  Future<void> _submitOrderWithConfirmation() async {
    final l10n = ref.read(l10nProvider);
    final cart = ref.read(cartProvider);
    final total = ref.read(cartTotalProvider);
    final locale = ref.read(localeProvider);
    if (cart.isEmpty) return;

    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.confirmOrder, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood)),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${l10n.checkOrderList}:', style: const TextStyle(color: AdminTheme.textMutedWood)),
              const Divider(color: AdminTheme.borderWood),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: cart.length,
                  itemBuilder: (c, i) {
                    return ListTile(
                      dense: true,
                      title: Text('${cart[i].quantity}x ${cart[i].menuItem.getName(locale)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood)),
                      subtitle: Text(
                        cart[i].selectedModifiers.map((m) => L10nUtils.getL10n(m.rawModifier ?? m.modifierName, locale)).join(', '),
                        style: const TextStyle(color: AdminTheme.textMutedWood),
                      ),
                      trailing: Text(
                        '${NumberFormat('#,###', 'vi_VN').format(cart[i].totalPrice)} VND',
                        style: const TextStyle(color: AdminTheme.primaryWood, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: AdminTheme.borderWood),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${l10n.total}:', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood)),
                  Text(
                    '${NumberFormat('#,###', 'vi_VN').format(total)} VND',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AdminTheme.accentAmber),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.changeLabel, style: const TextStyle(color: AdminTheme.textMutedWood)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.primaryWood,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.sendRequest, style: const TextStyle(fontWeight: FontWeight.bold)),
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
        'item_id': c.menuItem.id,
        'station_id': c.menuItem.stationId,
        'quantity': c.quantity,
        'notes': c.notes,
        'selected_modifiers': c.selectedModifiers.map((m) => m.toJson()).toList(),
        'status': 'PENDING',
      }).toList();

      await supabase.from('tickets').insert(tickets);
      ref.read(cartProvider.notifier).clearCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.orderSuccess), backgroundColor: const Color(0xFF2E7D32)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ref.read(l10nProvider).errorPrefix}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _requestService(String type) async {
    final l10n = ref.read(l10nProvider);

    // Kiểm tra xem phòng này đã có yêu cầu dọn phòng/hỗ trợ đang chờ hoặc đang xử lý chưa
    try {
      final activeServices = await supabase
          .from('room_services')
          .select('id, status_id')
          .eq('room_number', widget.roomNumber)
          .eq('service_type', type)
          .neq('status_id', 3);

      if (activeServices.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(type == 'CLEANING' ? l10n.cleaningInProgress : l10n.staffProcessing),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
        return;
      }
    } catch (_) {}

    String notes = "";
    if (type == 'CALL_STAFF') {
      final controller = TextEditingController();
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AdminTheme.surfaceWhite,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(l10n.supportQuestion, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.supportHint,
              filled: true,
              fillColor: AdminTheme.bgWarmWhite,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AdminTheme.borderWood)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel, style: const TextStyle(color: AdminTheme.textMutedWood)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primaryWood,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.sendRequest),
            ),
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
        'status_id': 1,
        'notes': notes,
      });
      if (mounted) {
        String msg = type == 'CLEANING' ? l10n.roomCleaningCalled : l10n.staffCalled;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AdminTheme.primaryWood,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showOrderHistory() {
    final l10n = ref.read(l10nProvider);
    final locale = ref.read(localeProvider);

    final ordersFuture = supabase
        .from('orders')
        .select('*, tickets(quantity, menu_items(name))')
        .eq('room_number', widget.roomNumber)
        .order('created_at', ascending: false)
        .limit(20);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.orderHistoryTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 550,
          height: 480,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: ordersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snapshot.data ?? [];
              if (orders.isEmpty) {
                return Center(child: Text(l10n.noOptions, style: const TextStyle(color: AdminTheme.textMutedWood)));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const Divider(height: 24, color: AdminTheme.borderWood),
                itemBuilder: (ctx, i) {
                  final o = orders[i];
                  final date = DateTime.parse(o['created_at']).toLocal();
                  final List tickets = o['tickets'] ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${l10n.orderNo} #${o['id'].toString().substring(0, 5)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood)),
                          _buildStatusBadge(_translateOrderStatus(o['status'], l10n)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${l10n.atTime}: ${DateFormat('HH:mm - dd/MM/yyyy').format(date)}', style: const TextStyle(fontSize: 12, color: AdminTheme.textMutedWood)),
                      const SizedBox(height: 6),
                      ...tickets.map((t) {
                        final dynamic rawName = t['menu_items'] != null ? t['menu_items']['name'] : l10n.menuItemFallback;
                        final String itemName = L10nUtils.getL10n(rawName, locale);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text('• ${t['quantity']}x $itemName', style: const TextStyle(fontSize: 13, color: AdminTheme.textDarkWood)),
                        );
                      }),
                    ],
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close, style: const TextStyle(color: AdminTheme.primaryWood, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AdminTheme.lightWoodCream,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AdminTheme.borderWood),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood),
      ),
    );
  }

  String _translateOrderStatus(String status, AppDictionary l10n) {
    switch (status) {
      case 'PENDING': return l10n.orderReceived;
      case 'PROCESSING': return l10n.orderPreparing;
      case 'READY_FOR_DELIVERY': return l10n.orderDelivering;
      case 'DELIVERED': return l10n.done;
      default: return status;
    }
  }

  String _translateTicketStatus(String status, AppDictionary l10n) {
    switch (status) {
      case 'PENDING': return l10n.pending;
      case 'COOKING': return l10n.cooking;
      case 'DONE': return l10n.done;
      case 'REMAKED': return l10n.remakeLabel;
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final roomTicketsAsync = ref.watch(activeRoomTicketsProvider(widget.roomNumber));
    final roomOrdersAsync = ref.watch(roomOrdersStreamProvider(widget.roomNumber));
    final roomServicesAsync = ref.watch(roomServicesByRoomStreamProvider(widget.roomNumber));
    final menuAsync = ref.watch(menuItemsStreamProvider);
    final activeOrders = (roomOrdersAsync.value ?? []).where((o) => o['status'] != 'DELIVERED').toList();

    return Container(
      width: widget.isMobile ? double.infinity : 480,
      decoration: BoxDecoration(
        color: AdminTheme.surfaceWhite,
        border: Border(
          left: widget.isMobile ? BorderSide.none : const BorderSide(color: AdminTheme.borderBlue, width: 1),
        ),
        boxShadow: [
          BoxShadow(color: AdminTheme.primaryDarkBlue.withValues(alpha: 0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          _buildActionHeader(l10n),
          Expanded(
            flex: 3,
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 44, color: AdminTheme.textMutedBlue.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(l10n.emptyCart, style: const TextStyle(color: AdminTheme.textMutedBlue, fontSize: 14)),
                      ],
                    ),
                  )
                : _buildCartList(cart, l10n),
          ),
          if (cart.isNotEmpty) _buildCheckoutSection(cartTotal, l10n),
          if (activeOrders.isNotEmpty || (roomServicesAsync.value?.isNotEmpty ?? false))
            _buildTrackingSection(activeOrders, roomTicketsAsync, roomServicesAsync.value ?? [], menuAsync.value ?? [], l10n),
        ],
      ),
    );
  }

  Widget _buildActionHeader(AppDictionary l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AdminTheme.blueTint,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: AdminTheme.primaryBlue, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l10n.cart,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AdminTheme.textDarkBlue),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _showOrderHistory,
                icon: const Icon(Icons.receipt_long_outlined, size: 18, color: AdminTheme.primaryBlue),
                label: Text(
                  l10n.history,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.primaryBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person, size: 16),
                  label: Text(l10n.callStaff),
                  onPressed: () => _requestService('CALL_STAFF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.lightBlueContainer,
                    foregroundColor: AdminTheme.primaryDarkBlue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: Text(l10n.cleaning),
                  onPressed: () => _requestService('CLEANING'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AdminTheme.primaryBlue,
                    side: const BorderSide(color: AdminTheme.primaryBlue, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
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
        final String displayName = item.menuItem.getName(locale);
        return Card(
          elevation: 0,
          color: AdminTheme.bgExpressiveBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AdminTheme.borderBlue, width: 0.8),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkBlue, fontSize: 13.5)),
            subtitle: (item.selectedModifiers.isNotEmpty || item.notes.isNotEmpty)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.selectedModifiers.isNotEmpty)
                        Text(
                          '${l10n.extra}: ${item.selectedModifiers.map((m) => L10nUtils.getL10n(m.rawModifier ?? m.modifierName, locale)).join(', ')}',
                          style: const TextStyle(fontSize: 11, color: AdminTheme.textMutedBlue),
                        ),
                      if (item.notes.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: item.selectedModifiers.isNotEmpty ? 4 : 0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.edit_note_rounded, size: 13, color: Colors.amber.shade700),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  item.notes,
                                  style: TextStyle(fontSize: 11, color: Colors.amber.shade800, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${NumberFormat('#,###', 'vi_VN').format(item.totalPrice)} VND',
                  style: const TextStyle(color: AdminTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20, color: AdminTheme.textMutedBlue),
                  onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.uniqueId, -1),
                ),
                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.textDarkBlue)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20, color: AdminTheme.primaryBlue),
                  onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.uniqueId, 1),
                ),
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
      decoration: const BoxDecoration(
        color: AdminTheme.surfaceWhite,
        border: Border(top: BorderSide(color: AdminTheme.borderBlue)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${l10n.totalPayment}:', style: const TextStyle(color: AdminTheme.textDarkBlue, fontWeight: FontWeight.w600, fontSize: 14)),
              Text(
                '${NumberFormat('#,###', 'vi_VN').format(total)} VND',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.primaryBlue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _submitOrderWithConfirmation,
              child: Text(l10n.orderNow, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingSection(List<Map<String, dynamic>> activeOrders, List<Map<String, dynamic>> tickets, List<Map<String, dynamic>> services, List<MenuItemModel> menuItems, AppDictionary l10n) {
    return Expanded(
      flex: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        color: AdminTheme.blueTint,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            Center(
              child: Text(
                l10n.orderStatusTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AdminTheme.primaryDarkBlue, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            ...activeOrders.map((order) {
              final orderTickets = tickets.where((t) => t['order_id'] == order['id']).toList();
              if (orderTickets.isEmpty) return const SizedBox.shrink();
              final bool hasRemake = orderTickets.any((t) => t['is_remake'] == true);
              return _buildOrderTracker(order, orderTickets, menuItems, l10n, isRemakeOrder: hasRemake);
            }),
            if (services.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(l10n.roomServiceLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.textDarkBlue)),
              const SizedBox(height: 8),
              ...services.map((s) => _buildServiceRequestCard(s, l10n)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTracker(Map<String, dynamic> order, List<Map<String, dynamic>> tickets, List<MenuItemModel> menuItems, AppDictionary l10n, {bool isRemakeOrder = false}) {
    final locale = ref.watch(localeProvider);
    // Tính trạng thái 4 bước: 0=Pending, 1=Cooking, 2=Done, 3=Delivering
    final activeTickets = tickets.where((t) => t['status'] != 'REMAKED').toList();
    final bool allDone = activeTickets.isNotEmpty && activeTickets.every((t) => t['status'] == 'DONE');
    final bool anyCooking = tickets.any((t) => t['status'] == 'COOKING');
    final bool isDelivering = order['delivery_waiter_id'] != null;
    int currentStep;
    if (isDelivering) {
      currentStep = 3;
    } else if (allDone) {
      currentStep = 2;
    } else if (anyCooking) {
      currentStep = 1;
    } else {
      currentStep = 0;
    }

    // Tính thời gian ước lượng
    int maxPrepTime = 0;
    for (var t in activeTickets) {
      final item = menuItems.firstWhere(
        (m) => m.id == t['item_id'],
        orElse: () => MenuItemModel(id: '', price: 0, nameMap: {}, descriptionMap: {}, prepTime: 0, categoryId: '', stationId: '', isAvailable: false),
      );
      if (item.prepTime > maxPrepTime) maxPrepTime = item.prepTime;
    }
    final int estimatedTotal = maxPrepTime + 5;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isRemakeOrder ? Colors.deepOrange.withValues(alpha: 0.5) : AdminTheme.borderBlue),
        boxShadow: [BoxShadow(color: AdminTheme.primaryBlue.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Order ID + Remake badge
          Row(
            children: [
              Icon(Icons.receipt_long, size: 18, color: isRemakeOrder ? Colors.deepOrange : AdminTheme.primaryBlue),
              const SizedBox(width: 8),
              Text(
                '${l10n.orderNo} #${order['id'].toString().substring(0, 5)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isRemakeOrder ? Colors.deepOrange : AdminTheme.primaryDarkBlue,
                ),
              ),
              if (isRemakeOrder) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(l10n.remakeLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // 4-step tracker
          _MinimalistTracker(currentStep: currentStep, l10n: l10n),
          const SizedBox(height: 12),
          // Estimated time
          if (currentStep < 2)
            Container(
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AdminTheme.lightBlueContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminTheme.borderBlue),
              ),
              child: Text(
                '${l10n.estimatedFinish} $estimatedTotal ${l10n.minute}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkBlue, fontSize: 12),
              ),
            ),
          const SizedBox(height: 10),
          // Ticket list
          ...tickets.map((t) {
            final item = menuItems.firstWhere(
              (m) => m.id == t['item_id'],
              orElse: () => MenuItemModel(id: '', price: 0, nameMap: {}, descriptionMap: {}, prepTime: 0, categoryId: '', stationId: '', isAvailable: false),
            );
            final bool isRemaked = t['status'] == 'REMAKED';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    isRemaked ? Icons.replay : (t['status'] == 'DONE' ? Icons.check_circle : (t['status'] == 'COOKING' ? Icons.restaurant : Icons.radio_button_unchecked)),
                    size: 16,
                    color: isRemaked ? Colors.deepOrange : (t['status'] == 'DONE' ? const Color(0xFF2E7D32) : (t['status'] == 'COOKING' ? Colors.orange : AdminTheme.textMutedBlue)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    '${t['quantity']}x ${item.getName(locale)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isRemaked ? Colors.grey : AdminTheme.textDarkBlue,
                      decoration: isRemaked ? TextDecoration.lineThrough : null,
                    ),
                  )),
                  Text(
                    _translateTicketStatus(t['status'], l10n),
                    style: TextStyle(
                      fontSize: 11,
                      color: isRemaked ? Colors.deepOrange : (t['status'] == 'DONE' ? const Color(0xFF2E7D32) : (t['status'] == 'COOKING' ? Colors.orange : AdminTheme.textMutedBlue)),
                      fontWeight: (isRemaked || t['status'] == 'DONE') ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildServiceRequestCard(Map<String, dynamic> s, AppDictionary l10n) {
    final isCleaning = s['service_type'] == 'CLEANING';
    final int statusId = s['status_id'] ?? 1;
    final bool isPending = statusId == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminTheme.borderBlue),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminTheme.lightBlueContainer,
            radius: 18,
            child: Icon(
              isCleaning ? Icons.cleaning_services : Icons.person,
              size: 18,
              color: AdminTheme.primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isCleaning ? l10n.cleaningRequest : l10n.supportRequest, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.textDarkBlue)),
                const SizedBox(height: 2),
                Text(isPending ? l10n.waitingStaff : l10n.staffProcessing, style: const TextStyle(fontSize: 11.5, color: AdminTheme.textMutedBlue)),
              ],
            ),
          ),
          if (!isPending) const Icon(Icons.sync, size: 18, color: AdminTheme.primaryBlue),
        ],
      ),
    );
  }
}

class _MinimalistTracker extends StatelessWidget {
  final int currentStep; // 0=Pending, 1=Cooking, 2=Done, 3=Delivering
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
        _buildStep(2, l10n.done, Icons.check_circle),
        _buildLine(2),
        _buildStep(3, l10n.delivery, Icons.delivery_dining),
      ],
    );
  }

  Widget _buildStep(int step, String label, IconData icon) {
    bool isActive = currentStep >= step;
    return Column(
      children: [
        Icon(icon, color: isActive ? AdminTheme.primaryBlue : AdminTheme.borderBlue, size: 22),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? AdminTheme.textDarkBlue : AdminTheme.textMutedBlue,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildLine(int step) {
    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.only(bottom: 16),
        color: currentStep > step ? AdminTheme.primaryBlue : AdminTheme.borderBlue,
      ),
    );
  }
}
