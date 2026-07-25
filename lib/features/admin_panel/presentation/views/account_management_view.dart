import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/qr_session_service.dart';
import '../../../../main.dart'; // Biến supabase global
import '../../providers/admin_provider.dart';
import '../widgets/account_form_dialog.dart';

class AccountManagementView extends ConsumerWidget {
  const AccountManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lắng nghe dữ liệu danh sách tài khoản từ Provider
    final profilesAsync = ref.watch(profilesStreamProvider);
    final l10n = ref.watch(l10nProvider);

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
                Text(
                    l10n.manageAccounts,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addAccount, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                tabs: [
                  Tab(text: l10n.allTab),
                  Tab(text: l10n.adminRole),
                  Tab(text: l10n.roomRole),
                  Tab(text: l10n.stationRole),
                  Tab(text: l10n.waiterRole),
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
                error: (err, stack) => Center(child: Text('${l10n.loadDataError}: $err', style: const TextStyle(color: Colors.red))),
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
    final l10n = ref.watch(l10nProvider);
    if (filteredProfiles.isEmpty) {
      return Center(child: Text(l10n.noOptions));
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
            columns: [
              DataColumn(label: Text(l10n.displayName, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(l10n.roleLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(l10n.actionsLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: filteredProfiles.map((profile) {
              return DataRow(cells: [
                DataCell(Text(profile['display_name'] ?? l10n.noNameSet, style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(_buildRoleBadge(profile['role'] ?? 'UNKNOWN', l10n)),
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
                            tooltip: l10n.checkoutRoomTooltip,
                            onPressed: () => _confirmCheckout(context, ref, profile['room_number'].toString()),
                          ),

                        IconButton(
                          icon: const Icon(Icons.edit_square, color: Colors.orange),
                          tooltip: l10n.editAccountTooltip,
                          onPressed: () => _showAccountDialog(context, profile),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          tooltip: l10n.deleteAccountTooltip,
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

  Widget _buildRoleBadge(String role, AppDictionary l10n) {
    Color color;
    String label;
    switch (role) {
      case 'ADMIN': color = Colors.red; label = l10n.adminRole; break;
      case 'WAITER': color = Colors.green; label = l10n.waiterRole; break;
      case 'STATION': color = Colors.orange; label = l10n.stationRole; break;
      case 'ROOM': color = Colors.purple; label = l10n.roomRole; break;
      default: color = Colors.grey; label = role;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5))
      ),
      child: Text(
          label.toUpperCase(),
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
    final l10n = ref.read(l10nProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmDeleteTitle),
        content: Text(l10n.deleteAccountConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await deleteProfile(id);
                if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${l10n.deleteAccountSuccess}'), backgroundColor: Colors.green)
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  // Hiển thị lỗi thật từ hệ thống để dễ kiểm tra
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${l10n.systemError}: $e'), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: Text(l10n.confirmDeleteBtn),
          ),
        ],
      ),
    );
  }

  // HÀM XÁC NHẬN TRẢ PHÒNG
  void _confirmCheckout(BuildContext context, WidgetRef ref, String roomNumber) {
    final l10n = ref.read(l10nProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${l10n.checkoutRoomTitle} $roomNumber'),
        content: Text(l10n.checkoutRoomConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await checkoutRoom(roomNumber);
                await ref.read(qrSessionServiceProvider).revokeRoomSessions(roomNumber);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n.checkoutRoomTitle} $roomNumber - ${l10n.checkoutRoomSuccess} (Mã QR đã hủy)'), backgroundColor: Colors.green)
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: Text(l10n.confirmCheckoutBtn),
          ),
        ],
      ),
    );
  }
}
