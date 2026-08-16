import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/admin_theme.dart';
import '../../../../main.dart';
import '../../../../core/services/print_service.dart';
import '../../providers/menu_provider.dart';
import '../../../../core/l10n/app_localizations.dart';

class PrintBillView extends ConsumerStatefulWidget {
  const PrintBillView({super.key});

  @override
  ConsumerState<PrintBillView> createState() => _PrintBillViewState();
}

class _PrintBillViewState extends ConsumerState<PrintBillView> {
  late Future<List<Map<String, dynamic>>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrders();
  }

  Future<List<Map<String, dynamic>>> _fetchOrders() async {
    final response = await supabase
        .from('orders')
        .select('*, tickets(*, menu_items(*))')
        .order('created_at', ascending: false)
        .limit(50);
        
    final List<Map<String, dynamic>> processed = [];
    for (var o in response) {
      final isPrinted = await PrintService.isOrderPrinted(o['id'].toString());
      final orderMap = Map<String, dynamic>.from(o);
      orderMap['is_printed'] = isPrinted;
      processed.add(orderMap);
    }
    return processed;
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = _fetchOrders();
    });
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

  Future<void> _printOrder(Map<String, dynamic> order) async {
    final menuItems = ref.read(menuItemsStreamProvider).value ?? [];
    
    // Convert tickets to expected format
    final List<Map<String, dynamic>> tickets = List<Map<String, dynamic>>.from(order['tickets'] ?? []);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(localeProvider) == 'vi' ? 'Đang tạo hóa đơn...' : 'Creating bill...'), 
            backgroundColor: AdminTheme.primaryBlue
          ),
        );
      }
      await PrintService.printOrderBill(
        order: order,
        tickets: tickets,
        menuItems: menuItems,
        locale: ref.read(localeProvider),
      );
      
      if (mounted) {
        _refreshOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(localeProvider) == 'vi' ? 'Lỗi in hóa đơn: $e' : 'Print error: $e'), 
            backgroundColor: Colors.red
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ref.watch(localeProvider) == 'vi' ? 'In hóa đơn & Lịch sử' : 'Print Bill & History',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AdminTheme.primaryDarkWood,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshOrders,
                tooltip: ref.watch(localeProvider) == 'vi' ? 'Làm mới' : 'Refresh',
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ref.watch(localeProvider) == 'vi' ? 'Hiển thị danh sách các đơn hàng gần đây và trạng thái in.' : 'Showing recent orders and their print status.',
            style: const TextStyle(color: AdminTheme.textMutedWood),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final orders = snapshot.data ?? [];
                
                if (orders.isEmpty) {
                  return Center(
                    child: Text(ref.watch(localeProvider) == 'vi' ? 'Chưa có đơn hàng nào.' : 'No orders yet.')
                  );
                }

                return ListView.separated(
                  itemCount: orders.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final date = DateTime.parse(order['created_at']).toLocal();
                    
                    return ListTile(
                      tileColor: AdminTheme.surfaceWhite,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      title: Text(
                        ref.watch(localeProvider) == 'vi'
                            ? 'Phòng: ${order['room_number']} - Đơn #${order['id'].toString().substring(0, 8)}'
                            : 'Room: ${order['room_number']} - Order #${order['id'].toString().substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        ref.watch(localeProvider) == 'vi'
                            ? 'Thời gian: ${DateFormat('HH:mm - dd/MM/yyyy').format(date)} | Trạng thái: ${_getTranslatedOrderStatus(order['status'], l10n)}'
                            : 'Time: ${DateFormat('HH:mm - dd/MM/yyyy').format(date)} | Status: ${_getTranslatedOrderStatus(order['status'], l10n)}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: order['is_printed'] == true ? Colors.green[100] : Colors.orange[100], 
                              borderRadius: BorderRadius.circular(8)
                            ),
                            child: Text(
                              order['is_printed'] == true 
                                ? (ref.watch(localeProvider) == 'vi' ? 'Đã in' : 'Printed')
                                : (ref.watch(localeProvider) == 'vi' ? 'Chưa in' : 'Not printed'), 
                              style: TextStyle(
                                color: order['is_printed'] == true ? Colors.green[800] : Colors.orange[800], 
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              )
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.print, size: 18),
                            label: Text(ref.watch(localeProvider) == 'vi' ? 'In bill' : 'Print'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              _printOrder(order);
                              // Mark as printed optimistically in UI
                              setState(() {
                                order['is_printed'] = true;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
