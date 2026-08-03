import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inroom_dining/core/theme/admin_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/services/qr_session_service.dart';
import '../../../../main.dart';
import '../../providers/admin_provider.dart';
import '../widgets/account_form_dialog.dart';

class RoomManagementView extends ConsumerWidget {
  const RoomManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesStreamProvider);
    final l10n = ref.watch(l10nProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isMobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                children: [
                  Text(
                    l10n.manageRooms,
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textDarkWood,
                    ),
                  ),
                  if (isMobile) const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_business, size: 18),
                    label: Text(l10n.addRoom, style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primaryWood,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _showAccountDialog(context, null),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: profilesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text('${l10n.loadDataError}: $err', style: const TextStyle(color: Colors.red)),
                  ),
                  data: (rawProfiles) {
                    final seenIds = <String>{};
                    final allProfiles = rawProfiles.where((p) => seenIds.add(p['id'].toString())).toList();
                    // Chỉ lấy tài khoản Phòng (ROOM)
                    final roomProfiles = allProfiles.where((p) => p['role'] == 'ROOM').toList();

                    roomProfiles.sort((a, b) {
                      final roomA = a['room_number']?.toString() ?? '';
                      final roomB = b['room_number']?.toString() ?? '';
                      return roomA.compareTo(roomB);
                    });

                    if (roomProfiles.isEmpty) {
                      return Center(
                        child: Text(l10n.noOptions, style: const TextStyle(color: AdminTheme.textMutedWood)),
                      );
                    }

                    return Card(
                      child: LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final minWidth = isMobile ? 500.0 : 700.0;
                          final tableWidth = cardConstraints.maxWidth > minWidth ? cardConstraints.maxWidth : minWidth;

                          return SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: tableWidth,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(AdminTheme.lightWoodCream),
                                  dataRowMinHeight: 60,
                                  dataRowMaxHeight: 60,
                                  columns: [
                                    DataColumn(
                                      label: Text(l10n.room, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood)),
                                    ),
                                    DataColumn(
                                      label: Text(l10n.actionsLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood)),
                                    ),
                                  ],
                                  rows: roomProfiles.map((profile) {
                                    final roomNumber = profile['room_number']?.toString() ?? '';
                                    final displayName = roomNumber.isNotEmpty ? '${l10n.room} $roomNumber' : l10n.noNameSet;

                                    return DataRow(cells: [
                                      DataCell(
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: AdminTheme.lightWoodCream,
                                              child: const Icon(Icons.meeting_room, size: 18, color: AdminTheme.primaryWood),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              displayName,
                                              style: const TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textDarkWood),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Nút Trả phòng
                                            if (roomNumber.isNotEmpty)
                                              IconButton(
                                                icon: const Icon(Icons.exit_to_app, color: Color(0xFF8B5E3C)),
                                                tooltip: l10n.checkoutRoomTooltip,
                                                onPressed: () => _confirmCheckout(context, ref, roomNumber),
                                              ),
                                            // Nút Sửa
                                            IconButton(
                                              icon: const Icon(Icons.edit_square, color: AdminTheme.accentAmber),
                                              tooltip: l10n.editAccountTooltip,
                                              onPressed: () => _showAccountDialog(context, profile),
                                            ),
                                            // Nút Xóa
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                              tooltip: l10n.deleteAccountTooltip,
                                              onPressed: () => _confirmDelete(context, ref, profile['id']),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await deleteProfile(id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('✅ ${l10n.deleteAccountSuccess}'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ ${l10n.systemError}: $e'), backgroundColor: Colors.red),
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
            style: ElevatedButton.styleFrom(backgroundColor: AdminTheme.primaryWood, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await checkoutRoom(roomNumber);
                await ref.read(qrSessionServiceProvider).revokeRoomSessions(roomNumber);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${l10n.checkoutRoomTitle} $roomNumber - ${l10n.checkoutRoomSuccess} (Mã QR đã hủy)'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: Colors.red),
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
