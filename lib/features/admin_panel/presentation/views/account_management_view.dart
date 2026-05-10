import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../main.dart'; // Biến supabase global
import '../../providers/admin_provider.dart';
import '../widgets/account_form_dialog.dart';

class AccountManagementView extends ConsumerWidget {
  const AccountManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lắng nghe dữ liệu danh sách tài khoản từ Provider
    final profilesAsync = ref.watch(profilesStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // PHẦN HEADER: TIÊU ĐỀ & NÚT THÊM MỚI
          // ==========================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                  'Quản lý Tài khoản',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Thêm Tài Khoản', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                // Truyền null để báo hiệu đây là luồng Thêm mới
                onPressed: () => _showAccountDialog(context, null),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ==========================================
          // PHẦN BODY: BẢNG DANH SÁCH TÀI KHOẢN
          // ==========================================
          Expanded(
            child: profilesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Lỗi tải dữ liệu: $err', style: const TextStyle(color: Colors.red))),
              data: (profiles) {
                if (profiles.isEmpty) {
                  return const Center(child: Text('Chưa có tài khoản nào. Hãy thêm mới!'));
                }

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
                          DataColumn(label: Text('Tên hiển thị', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Phân quyền', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Thông tin thêm', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Hành động', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: profiles.map((profile) {
                          // Format dữ liệu hiển thị cho cột "Thông tin thêm"
                          String extraInfo = '-';
                          if (profile['role'] == 'STATION' && profile['station_id'] != null) {
                            extraInfo = 'Bếp (ID: ${profile['station_id'].toString().substring(0, 5)}...)';
                          }
                          if (profile['role'] == 'ROOM' && profile['room_number'] != null) {
                            extraInfo = 'Phòng ${profile['room_number']}';
                          }

                          return DataRow(cells: [
                            DataCell(Text(profile['display_name'] ?? 'Chưa đặt tên', style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(_buildRoleBadge(profile['role'] ?? 'UNKNOWN')),
                            DataCell(Text(extraInfo, style: TextStyle(color: Colors.grey[700]))),
                            DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // NÚT SỬA
                                    IconButton(
                                      icon: const Icon(Icons.edit_square, color: Colors.orange),
                                      tooltip: 'Sửa tài khoản',
                                      splashRadius: 24,
                                      // Truyền dữ liệu profile hiện tại sang form để Sửa
                                      onPressed: () => _showAccountDialog(context, profile),
                                    ),
                                    // NÚT XÓA
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Xóa tài khoản',
                                      splashRadius: 24,
                                      onPressed: () => _confirmDelete(context, ref, profile['id']),
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

  // ==========================================
  // CÁC HÀM HỖ TRỢ (UI & LOGIC)
  // ==========================================

  // 1. Hàm vẽ nhãn màu sắc cho Phân quyền
  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role) {
      case 'ADMIN': color = Colors.red; break;
      case 'WAITER': color = Colors.green; break;
      case 'STATION': color = Colors.orange; break;
      case 'ROOM': color = Colors.purple; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5))
      ),
      child: Text(
          role,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)
      ),
    );
  }

  // 2. Hàm mở Popup Thêm/Sửa
  void _showAccountDialog(BuildContext context, Map<String, dynamic>? existingProfile) {
    showDialog(
      context: context,
      barrierDismissible: false, // Bắt buộc bấm Hủy hoặc Lưu mới đóng được
      builder: (context) => AccountFormDialog(profile: existingProfile),
    );
  }

  // 3. Hàm hiển thị Popup Xác nhận Xóa & Xử lý Xóa
  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Xác nhận xóa'),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn xóa tài khoản này không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                // Đóng popup xác nhận trước
                Navigator.pop(dialogContext);

                // Gọi lệnh xóa dưới Supabase (Chỉ xóa profile, nếu muốn xóa triệt để Auth
                // thì lại phải gọi Edge Function, nhưng hiện tại xóa profile là đủ để chặn đăng nhập vào app)
                await supabase.from('profiles').delete().eq('id', id);

                // ÉP TẢI LẠI TRANG (Invalidate Provider)
                ref.invalidate(profilesStreamProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã xóa tài khoản thành công'), backgroundColor: Colors.green)
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Lỗi khi xóa: $e'), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
  }
}