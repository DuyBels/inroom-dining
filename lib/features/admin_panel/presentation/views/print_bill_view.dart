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
  final Future<List<Map<String, dynamic>>> _ordersFuture = supabase
      .from('orders')
      .select('*, tickets(*, menu_items(*))')
      .eq('status', 'PENDING')
      .order('created_at', ascending: false)
      .limit(50);

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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ref.watch(localeProvider) == 'vi' ? 'In hóa đơn' : 'Print Bill',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AdminTheme.primaryDarkWood,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ref.watch(localeProvider) == 'vi' ? 'Chỉ hiển thị các đơn hàng mới (Đang gửi) để in lại hóa đơn.' : 'Only showing PENDING orders to reprint bill.',
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
                            ? 'Thời gian: ${DateFormat('HH:mm - dd/MM/yyyy').format(date)} | Trạng thái: ${order['status'] == 'PENDING' ? 'Đang gửi' : order['status']}'
                            : 'Time: ${DateFormat('HH:mm - dd/MM/yyyy').format(date)} | Status: ${order['status']}',
                      ),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.print, size: 18),
                        label: Text(ref.watch(localeProvider) == 'vi' ? 'In hóa đơn' : 'Print Bill'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _printOrder(order),
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
