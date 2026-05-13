import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../main.dart';
import '../../providers/admin_provider.dart';
import '../widgets/station_form_dialog.dart';

class StationManagementView extends ConsumerWidget {
  const StationManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(stationsStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                  'Quản lý Trạm Bếp',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Thêm Trạm Bếp', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, // Đổi màu cho hợp với Bếp
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onPressed: () => _showStationDialog(context, null),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: stationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Lỗi tải dữ liệu: $err', style: const TextStyle(color: Colors.red))),
              data: (stations) {
                if (stations.isEmpty) {
                  return const Center(child: Text('Chưa có trạm bếp nào. Hãy thêm mới!'));
                }

                return Card(
                  elevation: 2,
                  color: Colors.white,
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    children: [
                      DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.orange[50]),
                        dataRowMinHeight: 60,
                        dataRowMaxHeight: 60,
                        columns: const [
                          DataColumn(label: Text('Tên Trạm Bếp', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Mã ID (Rút gọn)', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Hành động', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: stations.map((station) {
                          return DataRow(cells: [
                            DataCell(
                                Row(
                                  children: [
                                    const Icon(Icons.countertops, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(station['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  ],
                                )
                            ),
                            DataCell(Text(station['id'].toString().substring(0, 8) + '...', style: TextStyle(color: Colors.grey[600]))),
                            DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_square, color: Colors.blue),
                                      tooltip: 'Sửa trạm bếp',
                                      splashRadius: 24,
                                      onPressed: () => _showStationDialog(context, station),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Xóa trạm bếp',
                                      splashRadius: 24,
                                      onPressed: () => _confirmDelete(context, ref, station['id']),
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

  void _showStationDialog(BuildContext context, Map<String, dynamic>? station) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StationFormDialog(station: station),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa Trạm bếp này? Không thể xóa nếu đang có Món ăn hoặc Tài khoản Bếp thuộc về trạm này.'),
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
                await supabase.from('kitchen_stations').delete().eq('id', id);
                ref.invalidate(stationsStreamProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa trạm bếp'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  // Hiển thị lỗi rõ ràng nếu bị chặn bởi Foreign Key (ON DELETE RESTRICT)
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Không thể xóa! Có món ăn hoặc tài khoản đang liên kết với trạm bếp này.'), backgroundColor: Colors.red)
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