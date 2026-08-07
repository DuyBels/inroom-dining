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
import '../../providers/admin_provider.dart';
import '../../../waiter_app/providers/room_service_provider.dart';

/// Chế độ xem Theo dõi hoạt động trực tuyến dành cho Admin
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
    final profilesAsync = ref.watch(profilesStreamProvider);
    final roomServicesAsync = ref.watch(activeRoomServicesStreamProvider);

    return Scaffold(
      backgroundColor: AdminTheme.bgWarmWhite,
      appBar: AppBar(
        title: Text(
          isVi ? 'Theo dõi hoạt động trực tuyến' : 'Live Operations Monitor',
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
          
          // Lấy các yêu cầu dịch vụ
          final roomServicesList = roomServicesAsync.value ?? [];
          final activeRoomServices = roomServicesList.where((s) => s['status_id'] != 3).toList(); // Khác completed
          
          final combinedList = [...activeOrders, ...activeRoomServices];
          
          if (combinedList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: AdminTheme.textMutedWood),
                  const SizedBox(height: 16),
                  Text(
                    isVi ? 'Chưa có hoạt động nào' : 'No active operations',
                    style: TextStyle(fontSize: 18, color: AdminTheme.textMutedWood),
                  ),
                ],
              ),
            );
          }

          // Phân loại trạng thái đơn hàng
          final pendingCount = activeOrders.where((o) => o['status'] == 'PENDING').length;
          final processingCount = activeOrders.where((o) => o['status'] == 'PROCESSING').length;
          final readyCount = activeOrders.where((o) => o['status'] == 'READY_FOR_DELIVERY').length;
          
          // Phân loại trạng thái dịch vụ
          final pendingRsCount = activeRoomServices.where((s) => s['status_id'] == 1).length;
          final processingRsCount = activeRoomServices.where((s) => s['status_id'] == 2).length;

          // Sắp xếp danh sách hỗn hợp: Cũ nhất lên trước
          combinedList.sort((a, b) {
            final timeA = DateTime.parse(a['created_at'] ?? a['requested_at'] ?? DateTime.now().toIso8601String());
            final timeB = DateTime.parse(b['created_at'] ?? b['requested_at'] ?? DateTime.now().toIso8601String());
            return timeA.compareTo(timeB);
          });

          return Column(
            children: [
              // Bảng tóm tắt
              Container(
                padding: const EdgeInsets.all(16),
                color: AdminTheme.surfaceWhite,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant, size: 18, color: AdminTheme.textDarkWood),
                        const SizedBox(width: 8),
                        Text(
                          '${activeOrders.length} ${isVi ? 'đơn ẩm thực' : 'food orders'}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood),
                        ),
                        const Spacer(),
                        _buildStatusChip(l10n.pending, pendingCount, Colors.orange),
                        const SizedBox(width: 8),
                        _buildStatusChip(isVi ? 'Đang nấu' : 'Cooking', processingCount, const Color(0xFF1565C0)),
                        const SizedBox(width: 8),
                        _buildStatusChip(isVi ? 'Sẵn sàng giao' : 'Ready for delivery', readyCount, const Color(0xFF00897B)),
                      ],
                    ),
                    if (activeRoomServices.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.room_service, size: 18, color: AdminTheme.textDarkWood),
                          const SizedBox(width: 8),
                          Text(
                            '${activeRoomServices.length} ${isVi ? 'yêu cầu dịch vụ' : 'service requests'}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood),
                          ),
                          const Spacer(),
                          _buildStatusChip(isVi ? 'Chờ nhận' : 'Pending', pendingRsCount, Colors.orange),
                          const SizedBox(width: 8),
                          _buildStatusChip(isVi ? 'Đang làm' : 'Processing', processingRsCount, const Color(0xFF1565C0)),
                        ],
                      ),
                    ]
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
                              itemCount: combinedList.length,
                              itemBuilder: (context, index) {
                                final item = combinedList[index];
                                final profiles = profilesAsync.value ?? [];
                                
                                if (item.containsKey('service_type')) {
                                  return _buildServiceCard(context, item, profiles, l10n, locale);
                                } else {
                                  final orderTickets = tickets.where((t) => t['order_id'] == item['id']).toList();
                                  return _buildOrderCard(context, item, orderTickets, menuItems, profiles, l10n, locale);
                                }
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

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order, List<Map<String, dynamic>> tickets, List<MenuItemModel> menuItems, List<Map<String, dynamic>> profiles, dynamic l10n, String locale) {
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
              
              // Người nhận giao đơn
              if (order['delivery_waiter_id'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.delivery_dining, size: 16, color: Color(0xFF00897B)),
                      const SizedBox(width: 6),
                      Text(
                        isVi ? 'Người nhận giao: ' : 'Delivery by: ',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood),
                      ),
                      Text(
                        profiles.firstWhere(
                          (p) => p['id'] == order['delivery_waiter_id'], 
                          orElse: () => {'display_name': 'Unknown'}
                        )['display_name'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF00897B), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              
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
                          String tStatusText;
                          switch (tStatus) {
                            case 'PENDING': 
                              tColor = Colors.orange; 
                              tStatusText = isVi ? 'Chờ nhận' : 'Pending';
                              break;
                            case 'COOKING': 
                              tColor = const Color(0xFF1565C0); 
                              tStatusText = isVi ? 'Đang nấu' : 'Cooking';
                              break;
                            case 'DONE': 
                              tColor = const Color(0xFF2E7D32); 
                              tStatusText = isVi ? 'Xong' : 'Done';
                              break;
                            case 'REMAKED': 
                              tColor = Colors.purple; 
                              tStatusText = isVi ? 'Làm lại' : 'Remake';
                              break;
                            case 'CANCELLED': 
                              tColor = Colors.red; 
                              tStatusText = isVi ? 'Hủy' : 'Cancelled';
                              break;
                            default: 
                              tColor = Colors.grey;
                              tStatusText = tStatus;
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
                              Text(
                                tStatusText,
                                style: TextStyle(color: tColor, fontSize: 12, fontStyle: FontStyle.italic),
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

  Widget _buildServiceCard(BuildContext context, Map<String, dynamic> service, List<Map<String, dynamic>> profiles, dynamic l10n, String locale) {
    final statusId = service['status_id'] ?? 1;
    final isVi = locale == 'vi';
    final isCleaning = service['service_type'] == 'CLEANING';
    
    Color statusColor;
    String statusText;
    
    switch (statusId) {
      case 1: // pending
        statusColor = Colors.orange;
        statusText = isVi ? 'Chờ nhận' : 'Pending';
        break;
      case 2: // processing
        statusColor = const Color(0xFF1565C0);
        statusText = isVi ? 'Đang thực hiện' : 'Processing';
        break;
      case 3: // completed
        statusColor = const Color(0xFF2E7D32);
        statusText = isVi ? 'Hoàn tất' : 'Completed';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Unknown';
    }

    final createdAt = service['requested_at'] != null ? DateTime.parse(service['requested_at']) : DateTime.now();
    final formattedTime = DateFormat('HH:mm dd/MM').format(createdAt);

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
                    '${l10n.room} ${service['room_number'] ?? ''}',
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
              
              // Thời gian
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: AdminTheme.textMutedWood),
                  const SizedBox(width: 4),
                  Text(
                    formattedTime,
                    style: TextStyle(fontSize: 13, color: AdminTheme.textMutedWood),
                  ),
                ],
              ),
              const Divider(color: AdminTheme.borderWood, height: 24),
              
              // Người nhận
              if (service['waiter_id'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(isCleaning ? Icons.cleaning_services : Icons.support_agent, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        isVi ? 'Người phụ trách: ' : 'Assigned to: ',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood),
                      ),
                      Text(
                        profiles.firstWhere(
                          (p) => p['id'] == service['waiter_id'], 
                          orElse: () => {'display_name': 'Unknown'}
                        )['display_name'] ?? 'Unknown',
                        style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              
              // Loại dịch vụ
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isCleaning ? Icons.cleaning_services_outlined : Icons.room_service_outlined, 
                      size: 24, 
                      color: AdminTheme.textDarkWood
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCleaning ? (isVi ? 'Dọn phòng' : 'Cleaning') : (isVi ? 'Hỗ trợ' : 'Support'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood),
                          ),
                          if (service['notes'] != null && service['notes'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                service['notes'],
                                style: const TextStyle(fontSize: 13, color: Colors.black87),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
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
