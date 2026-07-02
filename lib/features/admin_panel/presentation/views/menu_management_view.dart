import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../main.dart';
import '../../providers/menu_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/admin_provider.dart'; // Chứa stationsStreamProvider
import '../widgets/menu_form_dialog.dart';
import '../widgets/modifier_management_dialog.dart';

class MenuManagementView extends ConsumerWidget {
  const MenuManagementView({super.key});

  // Hàm định dạng tiền tệ VN
  String _formatPrice(dynamic price) {
    final n = num.tryParse(price.toString()) ?? 0;
    return NumberFormat('#,###', 'vi_VN').format(n);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuItemsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final stationsAsync = ref.watch(stationsStreamProvider);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Lỗi tải danh mục: $err')),
      data: (categories) {
        final allCategories = [{'id': 'all', 'name': 'Tất cả'}, ...categories];

        return DefaultTabController(
          length: allCategories.length,
          child: Padding(
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
                const SizedBox(height: 16),

                // THANH TAB DANH MỤC
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    isScrollable: true,
                    labelColor: Colors.blue[800],
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue[800],
                    tabs: allCategories.map((c) => Tab(text: c['name'])).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: menuAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Lỗi: $err')),
                    data: (rawMenuItems) {
                      if (rawMenuItems.isEmpty) return const Center(child: Text('Chưa có món ăn nào.'));

                      // Chống trùng lặp ID
                      final seenIds = <String>{};
                      final menuItems = rawMenuItems.where((m) => seenIds.add(m['id'].toString())).toList();

                      return TabBarView(
                        children: allCategories.map((cat) {
                          final filteredItems = cat['id'] == 'all'
                              ? menuItems
                              : menuItems.where((item) => item['category_id'] == cat['id']).toList();

                          return _buildMenuTable(context, ref, filteredItems, categories, stationsAsync.value ?? []);
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuTable(
    BuildContext context, 
    WidgetRef ref, 
    List<Map<String, dynamic>> menuItems, 
    List<Map<String, dynamic>> categories,
    List<Map<String, dynamic>> stations,
  ) {
    if (menuItems.isEmpty) {
      return const Center(child: Text('Không có món ăn nào trong danh mục này.'));
    }

    return Card(
      elevation: 2, color: Colors.white, clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: ListView(
        children: [
          DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
            dataRowMinHeight: 70, dataRowMaxHeight: 70,
            columns: const [
              DataColumn(label: Text('Món ăn', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Giá', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Thông tin', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Hành động', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: menuItems.map((item) {
              // Tìm tên Danh mục từ ID
              final categoryMatch = categories.where((c) => c['id'] == item['category_id']);
              final categoryName = categoryMatch.isNotEmpty ? categoryMatch.first['name'] : 'Chưa phân loại';

              // Tìm tên Bếp từ ID
              final stationMatch = stations.where((s) => s['id'] == item['station_id']);
              final stationName = stationMatch.isNotEmpty ? stationMatch.first['name'] : 'Chưa gán bếp';

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
                        Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    )
                ),
                DataCell(Text('${_formatPrice(item['price'])} VND', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(categoryName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    Text('Trạm: $stationName', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                )),
                DataCell(
                    Switch(
                      value: item['is_available'] ?? false,
                      activeColor: Colors.green,
                      onChanged: (val) async {
                        await supabase.from('menu_items').update({'is_available': val}).eq('id', item['id']);
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
                // Tự động cập nhật qua Stream
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