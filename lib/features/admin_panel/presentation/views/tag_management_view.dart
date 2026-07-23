import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../main.dart';
import '../../providers/tag_provider.dart';
import '../widgets/tag_form_dialog.dart';

class TagManagementView extends ConsumerWidget {
  const TagManagementView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsStreamProvider);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quản lý Thẻ (Tags)', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(icon: const Icon(Icons.add), label: const Text('Thêm Thẻ Mới'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)), onPressed: () => _showTagDialog(context, null)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: tagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Lỗi tải dữ liệu: $err')),
              data: (tags) {
                if (tags.isEmpty) return const Center(child: Text('Chưa có thẻ nào.'));
                return Card(
                  elevation: 2, color: Colors.white, clipBehavior: Clip.antiAlias,
                  child: ListView(
                    children: [
                      DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                        columns: const [DataColumn(label: Text('Tên Thẻ')), DataColumn(label: Text('Phân loại')), DataColumn(label: Text('Hành động'))],
                        rows: tags.map((tag) {
                          return DataRow(cells: [
                            DataCell(Text(tag.getName('vi'), style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(_buildTypeBadge(tag.tagType)),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.edit_square, color: Colors.orange), onPressed: () => _showTagDialog(context, {'id': tag.id, 'name': tag.nameMap, 'tag_type': tag.tagType})),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(context, ref, tag.id)),
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

  Widget _buildTypeBadge(String tagType) {
    Color color; String label;
    switch (tagType) {
      case 'ALLERGY': color = Colors.red; label = 'DỊ ỨNG'; break;
      case 'WEATHER': color = Colors.blue; label = 'THỜI TIẾT'; break;
      case 'TIME': color = Colors.green; label = 'BUỔI TRONG NGÀY'; break;
      case 'TASTE': color = Colors.orange; label = 'KHẨU VỊ'; break;
      default: color = Colors.grey; label = 'KHÁC';
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))), child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)));
  }

  void _showTagDialog(BuildContext context, Map<String, dynamic>? tag) { showDialog(context: context, barrierDismissible: false, builder: (context) => TagFormDialog(tag: tag)); }
  void _confirmDelete(BuildContext context, WidgetRef ref, String id) { showDialog(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Xác nhận xóa'), content: const Text('Xóa thẻ này?'), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () async { try { Navigator.pop(dialogContext); await supabase.from('tags').delete().eq('id', id); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'))); } }, child: const Text('Xóa'))])); }
}
