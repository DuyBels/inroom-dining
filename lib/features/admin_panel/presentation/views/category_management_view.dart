import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
              const Text(
                  'Quản lý Danh mục',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Thêm Danh Mục', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: () => _showCategoryDialog(context, null),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Lỗi tải dữ liệu: $err', style: const TextStyle(color: Colors.red))),
              data: (rawCategories) {
                if (rawCategories.isEmpty) {
                  return const Center(child: Text('Chưa có danh mục nào. Hãy tạo danh mục mới!'));
                }

                // Loại bỏ trùng lặp nếu có
                final seenIds = <String>{};
                final categories = rawCategories.where((c) => seenIds.add(c['id'].toString())).toList();

                return Card(
                  elevation: 2,
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    children: [
                      DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                        dataRowMinHeight: 60,
                        dataRowMaxHeight: 60,
                        columns: const [
                          DataColumn(label: Text('Tên Danh mục', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Mô tả', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Hành động', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: categories.map((category) {
                          return DataRow(cells: [
                            DataCell(Text(category['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                            DataCell(Text(category['description'] ?? '-', style: TextStyle(color: Colors.grey[700]))),
                            DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_square, color: Colors.orange),
                                      tooltip: 'Sửa danh mục',
                                      splashRadius: 24,
                                      onPressed: () => _showCategoryDialog(context, category),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Xóa danh mục',
                                      splashRadius: 24,
                                      onPressed: () => _confirmDelete(context, ref, category['id']),
                                    ),
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

  void _showCategoryDialog(BuildContext context, Map<String, dynamic>? category) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CategoryFormDialog(category: category),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa danh mục này? (Hệ thống sẽ chặn nếu danh mục này đang chứa món ăn).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await supabase.from('categories').delete().eq('id', id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa danh mục'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  // Thông báo lỗi nếu dính ON DELETE RESTRICT
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Không thể xóa! Vui lòng xóa/chuyển các món ăn thuộc danh mục này trước.'), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}