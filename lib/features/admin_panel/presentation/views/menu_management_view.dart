import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../main.dart';
import '../../providers/menu_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/admin_provider.dart'; // Chứa stationsStreamProvider
import '../widgets/menu_form_dialog.dart';
import '../widgets/modifier_management_dialog.dart';

class MenuManagementView extends ConsumerWidget {
  const MenuManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuItemsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final stationsAsync = ref.watch(stationsStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quản lý Thực đơn', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Thêm Món Mới', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: () => _showMenuDialog(context, null),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: menuAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Lỗi: $err')),
              data: (menuItems) {
                if (menuItems.isEmpty) return const Center(child: Text('Chưa có món ăn nào.'));

                return Card(
                  elevation: 2, color: Colors.white, clipBehavior: Clip.antiAlias,
                  child: ListView(
                    children: [
                      DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                        dataRowMinHeight: 70, dataRowMaxHeight: 70,
                        columns: const [
                          DataColumn(label: Text('Món ăn', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Giá', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Danh mục & Bếp', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Hành động', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: menuItems.map((item) {
                          // Tìm tên Danh mục từ ID
                          String categoryName = 'Chưa phân loại';
                          categoriesAsync.whenData((cats) {
                            final match = cats.where((c) => c['id'] == item['category_id']);
                            if (match.isNotEmpty) categoryName = match.first['name'];
                          });

                          // Tìm tên Bếp từ ID
                          String stationName = 'Chưa gán bếp';
                          stationsAsync.whenData((stations) {
                            final match = stations.where((s) => s['id'] == item['station_id']);
                            if (match.isNotEmpty) stationName = match.first['name'];
                          });

                          return DataRow(cells: [
                            DataCell(
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                                          ? Image.network(item['image_url'], width: 50, height: 50, fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Container(width: 50, height: 50, color: Colors.grey[300], child: const Icon(Icons.broken_image)))
                                          : Container(width: 50, height: 50, color: Colors.grey[300], child: const Icon(Icons.restaurant)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                )
                            ),
                            DataCell(Text('${item['price'] ?? 0} đ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                            DataCell(Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(categoryName, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text('Trạm: $stationName', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            )),
                            DataCell(
                                Switch(
                                  value: item['is_available'] ?? false,
                                  activeColor: Colors.green,
                                  onChanged: (val) async {
                                    // Nút gạt bật/tắt món ăn nhanh
                                    await supabase.from('menu_items').update({'is_available': val}).eq('id', item['id']);
                                    ref.invalidate(menuItemsStreamProvider);
                                  },
                                )
                            ),
                            DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey), 
                                      tooltip: 'Quản lý Topping',
                                      onPressed: () => _showToppingsDialog(context, item)
                                    ),
                                    IconButton(icon: const Icon(Icons.edit_square, color: Colors.orange), onPressed: () => _showMenuDialog(context, item)),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(context, ref, item['id'])),
                                  ],
                                )
                            ),
                          ]);
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showMenuDialog(BuildContext context, Map<String, dynamic>? item) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => MenuFormDialog(item: item));
  }

  void _showToppingsDialog(BuildContext context, Map<String, dynamic> item) {
    showDialog(context: context, builder: (context) => ModifierManagementDialog(menuItem: item));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa món này khỏi Menu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await supabase.from('menu_items').delete().eq('id', id);
                ref.invalidate(menuItemsStreamProvider);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}