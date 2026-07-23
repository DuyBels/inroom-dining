import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../main.dart';
import '../../providers/category_provider.dart';
import '../widgets/category_form_dialog.dart';

class CategoryManagementView extends ConsumerWidget {
  const CategoryManagementView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quản lý Danh mục', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Thêm Danh Mục'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)), onPressed: () => _showCategoryDialog(context, null)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Lỗi tải dữ liệu: $err')),
              data: (categories) {
                if (categories.isEmpty) return const Center(child: Text('Chưa có danh mục nào.'));
                return Card(
                  elevation: 2, color: Colors.white, clipBehavior: Clip.antiAlias,
                  child: ListView(
                    children: [
                      DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                        columns: const [DataColumn(label: Text('Tên Danh mục')), DataColumn(label: Text('Mô tả')), DataColumn(label: Text('Hành động'))],
                        rows: categories.map((category) {
                          return DataRow(cells: [
                            DataCell(Text(category.getName('vi'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                            DataCell(Text(L10nUtils.getL10n(category.descriptionMap, 'vi') == '' ? '-' : L10nUtils.getL10n(category.descriptionMap, 'vi'))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.edit_square, color: Colors.orange), onPressed: () => _showCategoryDialog(context, {'id': category.id, 'name': category.nameMap, 'description': category.descriptionMap})),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(context, ref, category.id)),
                            ])),
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

  void _showCategoryDialog(BuildContext context, Map<String, dynamic>? category) { showDialog(context: context, barrierDismissible: false, builder: (context) => CategoryFormDialog(category: category)); }
  void _confirmDelete(BuildContext context, WidgetRef ref, String id) { showDialog(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Xác nhận xóa'), content: const Text('Xóa danh mục này?'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () async { try { Navigator.pop(dialogContext); await supabase.from('categories').delete().eq('id', id); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể xóa! Có món ăn thuộc danh mục này.'))); } }, child: const Text('Xóa'))])); }
}
