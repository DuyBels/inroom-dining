import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inroom_dining/core/theme/admin_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../main.dart';

class AdminHistoryView extends ConsumerStatefulWidget {
  const AdminHistoryView({super.key});

  @override
  ConsumerState<AdminHistoryView> createState() => _AdminHistoryViewState();
}

class _AdminHistoryViewState extends ConsumerState<AdminHistoryView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null) return '--:--';
    final dt = DateTime.parse(isoString).toLocal();
    return DateFormat('HH:mm - dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.systemHistoryTitle,
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.textDarkWood,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AdminTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminTheme.borderWood),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AdminTheme.primaryWood,
                  unselectedLabelColor: AdminTheme.textMutedWood,
                  indicatorColor: AdminTheme.primaryWood,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(icon: const Icon(Icons.shopping_cart, size: 20), text: l10n.ordersTab),
                    Tab(icon: const Icon(Icons.restaurant, size: 20), text: l10n.kitchenTab),
                    Tab(icon: const Icon(Icons.person_pin_circle, size: 20), text: l10n.staffTab),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOrderHistory(l10n),
                    _buildKitchenHistory(l10n),
                    _buildStaffActivityHistory(l10n),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 1. LỊCH SỬ GỌI MÓN (CỦA PHÒNG)
  Widget _buildOrderHistory(AppDictionary l10n) {
    return _buildFutureList(
      future: supabase.from('orders').select('*, profiles:delivery_waiter_id(display_name)').order('created_at', ascending: false).limit(50),
      itemBuilder: (order) {
        final status = order['status'] as String? ?? '';
        final statusColor = _getOrderStatusColor(status);
        final statusText = _getTranslatedOrderStatus(status, l10n);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor.withValues(alpha: 0.15),
              child: Icon(Icons.room_service, color: statusColor),
            ),
            title: Row(
              children: [
                Text(
                  '${l10n.room} ${order['room_number']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusText.toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${l10n.timeLabel}: ${_formatDateTime(order['created_at'])}', style: const TextStyle(color: AdminTheme.textMutedWood)),
                if (order['profiles'] != null) Text('${l10n.deliveryPersonLabel}: ${order['profiles']['display_name']}', style: const TextStyle(color: AdminTheme.textMutedWood)),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: AdminTheme.textMutedWood),
            onTap: () => _showOrderDetails(order['id'], order['room_number'], l10n),
          ),
        );
      },
    );
  }

  // 2. LỊCH SỬ BẾP HOÀN THÀNH MÓN
  Widget _buildKitchenHistory(AppDictionary l10n) {
    return _buildFutureList(
      future: supabase.from('tickets').select('*, menu_items(name), kitchen_stations(name)').eq('status', 'DONE').order('finished_at', ascending: false).limit(50),
      itemBuilder: (ticket) {
        final locale = ref.watch(localeProvider);
        final itemName = L10nUtils.getL10n(ticket['menu_items']?['name'], locale);
        final stationName = L10nUtils.getL10n(ticket['kitchen_stations']?['name'], locale);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
            ),
            title: Text('${ticket['quantity']}x $itemName', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text('${l10n.stationsTab}: $stationName | ${l10n.done}: ${_formatDateTime(ticket['finished_at'])}', style: const TextStyle(color: AdminTheme.textMutedWood)),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFA5D6A7)),
              ),
              child: Text(l10n.done.toUpperCase(), style: const TextStyle(fontSize: 10, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
    );
  }

  // 3. LỊCH SỬ HOẠT ĐỘNG CỦA NHÂN VIÊN (DỊCH VỤ PHÒNG)
  Widget _buildStaffActivityHistory(AppDictionary l10n) {
    return _buildFutureList(
      future: supabase.from('room_services').select('*, waiter:waiter_id(display_name)').order('created_at', ascending: false).limit(50),
      itemBuilder: (service) {
        final bool isCleaning = service['service_type'] == 'CLEANING';
        final name = service['waiter']?['display_name'] ?? '...';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCleaning ? const Color(0xFFE3F2FD) : const Color(0xFFF3E5F5),
              child: Icon(
                isCleaning ? Icons.cleaning_services : Icons.support_agent,
                color: isCleaning ? const Color(0xFF1565C0) : const Color(0xFF6A1B9A),
              ),
            ),
            title: Text(
              '${isCleaning ? l10n.cleaningTab : l10n.supportTask} - ${l10n.room} ${service['room_number']}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${l10n.performerLabel}: $name', style: const TextStyle(color: AdminTheme.textMutedWood)),
                Text('${l10n.requestedAtLabel}: ${_formatDateTime(service['created_at'])}', style: const TextStyle(color: AdminTheme.textMutedWood)),
                if (service['completed_at'] != null) Text('${l10n.completedAtLabel}: ${_formatDateTime(service['completed_at'])}', style: const TextStyle(color: Color(0xFF2E7D32))),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper hiển thị chi tiết món ăn trong một đơn hàng
  void _showOrderDetails(String orderId, String room, AppDictionary l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.orderDetailsTitle} - ${l10n.room} $room'),
        content: SizedBox(
          width: 500,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: supabase.from('tickets').select('*, menu_items(name)').eq('order_id', orderId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final tickets = snapshot.data ?? [];
              return ListView.builder(
                shrinkWrap: true,
                itemCount: tickets.length,
                itemBuilder: (c, i) {
                  final t = tickets[i];
                  final locale = ref.watch(localeProvider);
                  final name = L10nUtils.getL10n(t['menu_items']?['name'], locale);
                  final ticketStatusText = _getTranslatedTicketStatus(t['status'], l10n);
                  return ListTile(
                    leading: Text('${t['quantity']}x', style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryWood)),
                    title: Text(name, style: const TextStyle(color: AdminTheme.textDarkWood)),
                    subtitle: Text('${l10n.statusLabel}: $ticketStatusText'),
                  );
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close, style: const TextStyle(color: AdminTheme.primaryWood)))],
      ),
    );
  }

  // Helper Widget cho danh sách Future
  Widget _buildFutureList({required Future<List<Map<String, dynamic>>> future, required Widget Function(Map<String, dynamic>) itemBuilder}) {
    final l10n = ref.watch(l10nProvider);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('${l10n.errorLoading}: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
        final data = snapshot.data ?? [];
        if (data.isEmpty) return Center(child: Text(l10n.noOptions, style: const TextStyle(color: AdminTheme.textMutedWood)));
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (context, index) => itemBuilder(data[index]),
        );
      },
    );
  }

  String _getTranslatedOrderStatus(String? status, AppDictionary l10n) {
    switch (status) {
      case 'PENDING':
        return l10n.pending;
      case 'PROCESSING':
        return l10n.cooking;
      case 'READY_FOR_DELIVERY':
        return l10n.delivery;
      case 'DELIVERED':
        return l10n.done;
      case 'CANCELLED':
        return l10n.cancelledStatus;
      default:
        return status ?? '--';
    }
  }

  String _getTranslatedTicketStatus(String? status, AppDictionary l10n) {
    switch (status) {
      case 'PENDING':
        return l10n.pending;
      case 'COOKING':
        return l10n.cooking;
      case 'DONE':
        return l10n.done;
      case 'REMAKED':
        return l10n.remakeLabel;
      case 'CANCELLED':
        return l10n.cancelledStatus;
      default:
        return status ?? '--';
    }
  }

  Color _getOrderStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'PROCESSING':
        return const Color(0xFF1565C0);
      case 'READY_FOR_DELIVERY':
        return const Color(0xFF00897B);
      case 'DELIVERED':
        return const Color(0xFF2E7D32);
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }
}

