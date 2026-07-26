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
        title: Text(l10n.historyTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood)),
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
      width: widget.isMobile ? double.infinity : 360,
      decoration: BoxDecoration(
        color: AdminTheme.surfaceWhite,
        border: Border(
          left: widget.isMobile ? BorderSide.none : const BorderSide(color: AdminTheme.borderWood, width: 1),
        ),
        boxShadow: [
          BoxShadow(color: AdminTheme.primaryDarkWood.withValues(alpha: 0.05), blurRadius: 10),
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
                        Icon(Icons.shopping_bag_outlined, size: 40, color: AdminTheme.textMutedWood.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        Text(l10n.emptyCart, style: const TextStyle(color: AdminTheme.textMutedWood)),
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
      color: AdminTheme.woodTint,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: AdminTheme.primaryWood),
                  const SizedBox(width: 8),
                  Text(
                    l10n.cart,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AdminTheme.textDarkWood),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _showOrderHistory,
                icon: const Icon(Icons.history, size: 18, color: AdminTheme.primaryWood),
                label: Text(
                  l10n.history,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.primaryWood),
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
                    backgroundColor: AdminTheme.lightWoodCream,
                    foregroundColor: AdminTheme.primaryDarkWood,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    foregroundColor: AdminTheme.primaryWood,
                    side: const BorderSide(color: AdminTheme.primaryWood),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          color: AdminTheme.bgWarmWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AdminTheme.borderWood, width: 0.8),
          ),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood)),
            subtitle: item.selectedModifiers.isNotEmpty
                ? Text(
                    '${l10n.extra}: ${item.selectedModifiers.map((m) => L10nUtils.getL10n(m.rawModifier ?? m.modifierName, locale)).join(', ')}',
                    style: const TextStyle(fontSize: 11, color: AdminTheme.textMutedWood),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${NumberFormat('#,###', 'vi_VN').format(item.totalPrice)} VND',
                  style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20, color: AdminTheme.textMutedWood),
                  onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.uniqueId, -1),
                ),
                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20, color: AdminTheme.primaryWood),
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
        border: Border(top: BorderSide(color: AdminTheme.borderWood)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${l10n.totalPayment}:', style: const TextStyle(color: AdminTheme.textDarkWood, fontWeight: FontWeight.w600)),
              Text(
                '${NumberFormat('#,###', 'vi_VN').format(total)} VND',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.accentAmber),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primaryWood,
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        color: AdminTheme.woodTint,
        child: ListView(
          children: [
            Center(
              child: Text(
                l10n.history.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, color: AdminTheme.primaryDarkWood, fontSize: 12),
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
              Text(l10n.roomServiceLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood)),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isRemakeOrder ? Colors.deepOrange.withValues(alpha: 0.5) : AdminTheme.borderWood),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Order ID + Remake badge
          Row(
            children: [
              Icon(Icons.receipt_long, size: 16, color: isRemakeOrder ? Colors.deepOrange : AdminTheme.primaryWood),
              const SizedBox(width: 6),
              Text(
                '${l10n.orderNo} #${order['id'].toString().substring(0, 5)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isRemakeOrder ? Colors.deepOrange : AdminTheme.primaryDarkWood,
                ),
              ),
              if (isRemakeOrder) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(l10n.remakeLabel, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // 4-step tracker
          _MinimalistTracker(currentStep: currentStep, l10n: l10n),
          const SizedBox(height: 10),
          // Estimated time
          if (currentStep < 2)
            Container(
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AdminTheme.lightWoodCream,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AdminTheme.borderWood),
              ),
              child: Text(
                '${l10n.estimatedFinish} $estimatedTotal ${l10n.minute}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood, fontSize: 11),
              ),
            ),
          const SizedBox(height: 8),
          // Ticket list
          ...tickets.map((t) {
            final item = menuItems.firstWhere(
              (m) => m.id == t['item_id'],
              orElse: () => MenuItemModel(id: '', price: 0, nameMap: {}, descriptionMap: {}, prepTime: 0, categoryId: '', stationId: '', isAvailable: false),
            );
            final bool isRemaked = t['status'] == 'REMAKED';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    isRemaked ? Icons.replay : (t['status'] == 'DONE' ? Icons.check_circle : (t['status'] == 'COOKING' ? Icons.restaurant : Icons.radio_button_unchecked)),
                    size: 14,
                    color: isRemaked ? Colors.deepOrange : (t['status'] == 'DONE' ? const Color(0xFF2E7D32) : (t['status'] == 'COOKING' ? Colors.orange : AdminTheme.textMutedWood)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    '${t['quantity']}x ${item.getName(locale)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isRemaked ? Colors.grey : AdminTheme.textDarkWood,
                      decoration: isRemaked ? TextDecoration.lineThrough : null,
                    ),
                  )),
                  Text(
                    _translateTicketStatus(t['status'], l10n),
                    style: TextStyle(
                      fontSize: 10,
                      color: isRemaked ? Colors.deepOrange : (t['status'] == 'DONE' ? const Color(0xFF2E7D32) : (t['status'] == 'COOKING' ? Colors.orange : AdminTheme.textMutedWood)),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AdminTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminTheme.borderWood),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminTheme.lightWoodCream,
            radius: 16,
            child: Icon(
              isCleaning ? Icons.cleaning_services : Icons.person,
              size: 16,
              color: AdminTheme.primaryWood,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isCleaning ? l10n.cleaningRequest : l10n.supportRequest, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood)),
                Text(isPending ? l10n.waitingStaff : l10n.staffProcessing, style: const TextStyle(fontSize: 11, color: AdminTheme.textMutedWood)),
              ],
            ),
          ),
          if (!isPending) const Icon(Icons.sync, size: 16, color: AdminTheme.primaryWood),
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
        Icon(icon, color: isActive ? AdminTheme.primaryWood : AdminTheme.borderWood, size: 20),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isActive ? AdminTheme.textDarkWood : AdminTheme.textMutedWood,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildLine(int step) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14),
        color: currentStep > step ? AdminTheme.primaryWood : AdminTheme.borderWood,
      ),
    );
  }
}
