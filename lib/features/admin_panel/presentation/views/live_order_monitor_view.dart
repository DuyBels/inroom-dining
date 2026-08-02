import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/admin_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/models/menu_item_model.dart';
import '../../../waiter_app/providers/waiter_provider.dart';
import '../../providers/menu_provider.dart';

/// Chế độ xem Giám sát đơn hàng trực tiếp (chỉ đọc) dành cho Admin
class LiveOrderMonitorView extends ConsumerWidget {
  const LiveOrderMonitorView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);
    final isVi = locale == 'vi';
    
    // Lắng nghe luồng dữ liệu đơn hàng và vé
    final ordersAsync = ref.watch(activeOrdersStreamProvider);
    final ticketsAsync = ref.watch(activeTicketsStreamProvider);
    final menuItemsAsync = ref.watch(menuItemsStreamProvider);

    return Scaffold(
      backgroundColor: AdminTheme.bgWarmWhite,
      appBar: AppBar(
        title: Text(
          isVi ? 'Giám sát đơn hàng' : 'Live Order Monitor',
          style: const TextStyle(color: AdminTheme.textDarkWood, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AdminTheme.surfaceWhite,
        elevation: 1,
        iconTheme: const IconThemeData(color: AdminTheme.textDarkWood),
      ),
      body: ordersAsync.when(
        data: (orders) {
          // Chỉ lấy các đơn hàng đang hoạt động (không phải DELIVERED, CANCELLED)
          final activeOrders = orders.where((o) => o['status'] != 'DELIVERED' && o['status'] != 'CANCELLED').toList();
          
          if (activeOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: AdminTheme.textMutedWood),
                  const SizedBox(height: 16),
                  Text(
                    isVi ? 'Chưa có đơn hàng nào' : 'No active orders',
                    style: TextStyle(fontSize: 18, color: AdminTheme.textMutedWood),
                  ),
                ],
              ),
            );
          }

          // Phân loại trạng thái
          final pendingCount = activeOrders.where((o) => o['status'] == 'PENDING').length;
          final processingCount = activeOrders.where((o) => o['status'] == 'PROCESSING').length;
          final readyCount = activeOrders.where((o) => o['status'] == 'READY_FOR_DELIVERY').length;

          return Column(
            children: [
              // Bảng tóm tắt
              Container(
                padding: const EdgeInsets.all(16),
                color: AdminTheme.surfaceWhite,
                child: Row(
                  children: [
                    Text(
                      '${activeOrders.length} ${isVi ? 'đơn đang hoạt động' : 'active orders'}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood),
                    ),
                    const Spacer(),
                    _buildStatusChip(l10n.pending, pendingCount, Colors.orange),
                    const SizedBox(width: 8),
                    _buildStatusChip(isVi ? 'Đang nấu' : 'Cooking', processingCount, const Color(0xFF1565C0)),
                    const SizedBox(width: 8),
                    _buildStatusChip(isVi ? 'Sẵn sàng giao' : 'Ready for delivery', readyCount, const Color(0xFF00897B)),
                  ],
                ),
              ),
              
              // Lưới thẻ đơn hàng
              Expanded(
                child: ticketsAsync.when(
                  data: (tickets) {
                    return menuItemsAsync.when(
                      data: (menuItems) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = 1;
                            if (constraints.maxWidth >= 1024) {
                              crossAxisCount = 3;
                            } else if (constraints.maxWidth >= 600) {
                              crossAxisCount = 2;
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                childAspectRatio: 1.2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                              ),
                              itemCount: activeOrders.length,
                              itemBuilder: (context, index) {
                                final order = activeOrders[index];
                                final orderTickets = tickets.where((t) => t['order_id'] == order['id']).toList();
                                return _buildOrderCard(context, order, orderTickets, menuItems, l10n, locale);
                              },
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Center(child: Text('${l10n.errorLoading}: $e')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('${l10n.errorLoading}: $e')),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('${l10n.errorLoading}: $e')),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order, List<Map<String, dynamic>> tickets, List<MenuItemModel> menuItems, dynamic l10n, String locale) {
    final status = order['status'] ?? 'PENDING';
    final isVi = locale == 'vi';
    
    Color statusColor;
    String statusText;
    
    switch (status) {
      case 'PENDING':
        statusColor = Colors.orange;
        statusText = l10n.pending;
        break;
      case 'PROCESSING':
        statusColor = const Color(0xFF1565C0); // Blue
        statusText = isVi ? 'Đang chờ bếp nấu' : 'Waiting for kitchen';
        break;
      case 'READY_FOR_DELIVERY':
        statusColor = const Color(0xFF00897B); // Teal
        statusText = isVi ? 'Sẵn sàng giao' : 'Ready for delivery';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    final createdAt = order['created_at'] != null ? DateTime.parse(order['created_at']) : DateTime.now();
    final formattedTime = DateFormat('HH:mm dd/MM').format(createdAt);
    
    final totalTickets = tickets.length;
    final doneTickets = tickets.where((t) => t['status'] == 'DONE').length;
    final progress = totalTickets > 0 ? doneTickets / totalTickets : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AdminTheme.borderWood, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: statusColor, width: 6)),
          color: AdminTheme.surfaceWhite,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${l10n.room} ${order['room_number'] ?? ''}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textDarkWood,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Thời gian & Thông tin thêm
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: AdminTheme.textMutedWood),
                  const SizedBox(width: 4),
                  Text(
                    formattedTime,
                    style: TextStyle(fontSize: 13, color: AdminTheme.textMutedWood),
                  ),
                  const Spacer(),
                  Text(
                    '${l10n.orderNo}: ${order['id'].toString().substring(0, 8)}...',
                    style: TextStyle(fontSize: 12, color: AdminTheme.textMutedWood),
                  ),
                ],
              ),
              const Divider(color: AdminTheme.borderWood, height: 24),
              
              // Tiến trình
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isVi ? 'Tiến độ món ăn' : 'Items progress',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood),
                  ),
                  Text(
                    '$doneTickets/$totalTickets ${l10n.done}',
                    style: TextStyle(fontSize: 13, color: AdminTheme.textMutedWood),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AdminTheme.lightWoodCream,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress == 1.0 ? const Color(0xFF2E7D32) : statusColor,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 12),
              
              // Danh sách món ăn
              Expanded(
                child: tickets.isEmpty
                    ? Center(child: Text(l10n.noOptions ?? '', style: TextStyle(color: AdminTheme.textMutedWood)))
                    : ListView.separated(
                        itemCount: tickets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 4),
                        itemBuilder: (context, idx) {
                          final ticket = tickets[idx];
                          final menuItem = menuItems.firstWhere(
                            (m) => m.id == ticket['item_id'],
                            orElse: () => MenuItemModel(id: '', price: 0, nameMap: {'vi': '...', 'en': '...'}, descriptionMap: {}, prepTime: 0, categoryId: '', stationId: '', isAvailable: false),
                          );
                          final ticketName = menuItem.getName(locale);
                          final qty = ticket['quantity'] ?? 1;
                          final tStatus = ticket['status'] ?? 'PENDING';
                          
                          Color tColor;
                          switch (tStatus) {
                            case 'PENDING': tColor = Colors.orange; break;
                            case 'COOKING': tColor = const Color(0xFF1565C0); break;
                            case 'DONE': tColor = const Color(0xFF2E7D32); break;
                            case 'REMAKED': tColor = Colors.purple; break;
                            case 'CANCELLED': tColor = Colors.red; break;
                            default: tColor = Colors.grey;
                          }
                          
                          return Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: tColor, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${qty}x $ticketName',
                                  style: const TextStyle(color: AdminTheme.textDarkWood, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              
              // Ghi chú nếu có
              if (order['notes'] != null && order['notes'].toString().isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.yellow.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.note, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order['notes'],
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
