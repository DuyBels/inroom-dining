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
      .order('created_at', ascending: false)
      .limit(50);

  Future<void> _printOrder(Map<String, dynamic> order) async {
    final menuItems = ref.read(menuItemsStreamProvider).value ?? [];
    
    // Convert tickets to expected format
    final List<Map<String, dynamic>> tickets = List<Map<String, dynamic>>.from(order['tickets'] ?? []);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đang tạo bill...'), backgroundColor: AdminTheme.primaryBlue),
        );
      }
      await PrintService.printOrderBill(
        order: order,
        tickets: tickets,
        menuItems: menuItems,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi in bill: $e'), backgroundColor: Colors.red),
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
          const Text(
            'In Hóa Đơn (Bill)',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AdminTheme.primaryDarkWood,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chọn đơn hàng bên dưới để in lại bill.',
            style: TextStyle(color: AdminTheme.textMutedWood),
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
                  return const Center(child: Text('Chưa có đơn hàng nào.'));
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
                        'Phòng: ${order['room_number']} - Đơn #${order['id'].toString().substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Thời gian: ${DateFormat('HH:mm - dd/MM/yyyy').format(date)} | Trạng thái: ${order['status']}',
                      ),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('In Bill'),
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
