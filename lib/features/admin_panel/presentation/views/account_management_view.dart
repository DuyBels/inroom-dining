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

    return DefaultTabController(
      length: 5,
      child: Padding(
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
                  onPressed: () => _showAccountDialog(context, null),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ==========================================
            // THANH TAB: PHÂN NHÓM THEO ROLE
            // ==========================================
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
                tabs: const [
                  Tab(text: 'Tất cả'),
                  Tab(text: 'Quản trị (Admin)'),
                  Tab(text: 'Phòng (Room)'),
                  Tab(text: 'Bếp (Station)'),
                  Tab(text: 'Phục vụ (Waiter)'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ==========================================
            // NỘI DUNG TAB
            // ==========================================
            Expanded(
              child: profilesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Lỗi tải dữ liệu: $err', style: const TextStyle(color: Colors.red))),
                data: (rawProfiles) {
                  // Chống trùng lặp ID
                  final seenIds = <String>{};
                  final profiles = rawProfiles.where((p) => seenIds.add(p['id'].toString())).toList();

                  return TabBarView(
                    children: [
                      _buildAccountTable(context, ref, profiles), // Tất cả
                      _buildAccountTable(context, ref, profiles.where((p) => p['role'] == 'ADMIN').toList()),
                      _buildAccountTable(context, ref, profiles.where((p) => p['role'] == 'ROOM').toList(), isRoomTab: true),
                      _buildAccountTable(context, ref, profiles.where((p) => p['role'] == 'STATION').toList()),
                      _buildAccountTable(context, ref, profiles.where((p) => p['role'] == 'WAITER').toList()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hàm xây dựng bảng danh sách cho từng Tab
  Widget _buildAccountTable(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> filteredProfiles, {bool isRoomTab = false}) {
    if (filteredProfiles.isEmpty) {
      return const Center(child: Text('Không có tài khoản nào trong nhóm này.'));
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
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
              DataColumn(label: Text('Hành động', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: filteredProfiles.map((profile) {
              return DataRow(cells: [
                DataCell(Text(profile['display_name'] ?? 'Chưa đặt tên', style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(_buildRoleBadge(profile['role'] ?? 'UNKNOWN')),
                DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // NÚT TRẢ PHÒNG (Chỉ hiện cho Role ROOM và room_number không trống)
                        if (profile['role'] == 'ROOM' && 
                            profile['room_number'] != null && 
                            profile['room_number'].toString().isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.exit_to_app, color: Colors.blueAccent),
                            tooltip: 'Trả phòng (Xóa lịch sử của phòng ${profile['room_number']})',
                            onPressed: () => _confirmCheckout(context, ref, profile['room_number'].toString()),
                          ),

                        IconButton(
                          icon: const Icon(Icons.edit_square, color: Colors.orange),
                          tooltip: 'Sửa tài khoản',
                          onPressed: () => _showAccountDialog(context, profile),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: 'Xóa tài khoản',
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
  }

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

  void _showAccountDialog(BuildContext context, Map<String, dynamic>? existingProfile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AccountFormDialog(profile: existingProfile),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa tài khoản này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await deleteProfile(id);
                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Đã xóa tài khoản thành công.'), backgroundColor: Colors.green)
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  // Hiển thị lỗi thật từ hệ thống để dễ kiểm tra
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ Lỗi hệ thống: $e'), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: const Text('Xác nhận Xóa'),
          ),
        ],
      ),
    );
  }

  // HÀM XÁC NHẬN TRẢ PHÒNG
  void _confirmCheckout(BuildContext context, WidgetRef ref, String roomNumber) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Trả phòng $roomNumber'),
        content: const Text('Hành động này sẽ xóa toàn bộ lịch sử đơn hàng và yêu cầu dịch vụ của phòng này. Bạn có chắc chắn muốn tiếp tục?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await checkoutRoom(roomNumber);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã trả phòng $roomNumber & dọn dẹp lịch sử thành công'), backgroundColor: Colors.green)
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: const Text('Xác nhận Trả phòng'),
          ),
        ],
      ),
    );
  }
}
