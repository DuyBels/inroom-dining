import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inroom_dining/core/theme/admin_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../main.dart';
import '../../providers/admin_provider.dart';
import '../widgets/account_form_dialog.dart';

class StaffManagementView extends ConsumerWidget {
  const StaffManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesStreamProvider);
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return DefaultTabController(
          length: 4,
          child: Padding(
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
                      l10n.manageStaff,
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.textDarkWood,
                      ),
                    ),
                    if (isMobile) const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: Text(l10n.addAccount, style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.primaryWood,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: () => _showAccountDialog(context, null),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AdminTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminTheme.borderWood),
                  ),
                  child: TabBar(
                    isScrollable: true,
                    labelColor: AdminTheme.primaryWood,
                    unselectedLabelColor: AdminTheme.textMutedWood,
                    indicatorColor: AdminTheme.primaryWood,
                    indicatorWeight: 3,
                    tabs: [
                      Tab(text: l10n.allTab),
                      Tab(text: l10n.adminRole),
                      Tab(text: l10n.stationRole),
                      Tab(text: l10n.waiterRole),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: profilesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(
                      child: Text('${l10n.loadDataError}: $err', style: const TextStyle(color: Colors.red)),
                    ),
                    data: (rawProfiles) {
                      final seenIds = <String>{};
                      final allProfiles = rawProfiles.where((p) => seenIds.add(p['id'].toString())).toList();
                      // Chỉ lấy nhân sự (ADMIN, STATION, WAITER)
                      final staffProfiles = allProfiles.where((p) => p['role'] != 'ROOM').toList();

                      const rolePriority = {
                        'ADMIN': 1,
                        'STATION': 2,
                        'WAITER': 3,
                      };

                      staffProfiles.sort((a, b) {
                        final pA = rolePriority[a['role']] ?? 99;
                        final pB = rolePriority[b['role']] ?? 99;
                        if (pA != pB) return pA.compareTo(pB);
                        final nameA = _getProfileDisplayName(a, l10n, locale);
                        final nameB = _getProfileDisplayName(b, l10n, locale);
                        return nameA.compareTo(nameB);
                      });

                      return TabBarView(
                        children: [
                          _buildStaffTable(context, ref, staffProfiles, isMobile: isMobile),
                          _buildStaffTable(context, ref, staffProfiles.where((p) => p['role'] == 'ADMIN').toList(), isMobile: isMobile),
                          _buildStaffTable(context, ref, staffProfiles.where((p) => p['role'] == 'STATION').toList(), isMobile: isMobile),
                          _buildStaffTable(context, ref, staffProfiles.where((p) => p['role'] == 'WAITER').toList(), isMobile: isMobile),
                        ],
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

  String _getProfileDisplayName(Map<String, dynamic> profile, AppDictionary l10n, String locale) {
    final role = profile['role']?.toString();
    final rawName = profile['display_name'];

    if (role == 'ADMIN') {
      return l10n.adminRole;
    } else if (role == 'STATION') {
      return L10nUtils.getL10n(rawName, locale);
    } else if (role == 'WAITER') {
      if (rawName is Map) {
        return rawName['vi']?.toString() ?? rawName['en']?.toString() ?? rawName.values.first.toString();
      }
      return rawName?.toString() ?? l10n.noNameSet;
    }

    return L10nUtils.getL10n(rawName, locale);
  }

  Widget _buildStaffTable(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> filteredProfiles, {
    required bool isMobile,
  }) {
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);
    if (filteredProfiles.isEmpty) {
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
                      label: Text(l10n.displayName, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood)),
                    ),
                    DataColumn(
                      label: Text(l10n.roleLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood)),
                    ),
                    DataColumn(
                      label: Text(l10n.actionsLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood)),
                    ),
                  ],
                  rows: filteredProfiles.map((profile) {
                    final displayName = _getProfileDisplayName(profile, l10n, locale);
                    return DataRow(cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: AdminTheme.lightWoodCream,
                              child: const Icon(Icons.person, size: 18, color: AdminTheme.primaryWood),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              displayName,
                              style: const TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textDarkWood),
                            ),
                          ],
                        ),
                      ),
                      DataCell(_buildRoleBadge(profile['role'] ?? 'UNKNOWN', l10n)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_square, color: AdminTheme.accentAmber),
                              tooltip: l10n.editAccountTooltip,
                              onPressed: () => _showAccountDialog(context, profile),
                            ),
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
  }

  Widget _buildRoleBadge(String role, AppDictionary l10n) {
    Color bg;
    Color fg;
    Color border;
    String label;

    switch (role) {
      case 'ADMIN':
        bg = const Color(0xFF001F3E);
        fg = Colors.white;
        border = const Color(0xFF00152B);
        label = l10n.adminRole;
        break;
      case 'STATION':
        bg = const Color(0xFF00447A);
        fg = Colors.white;
        border = const Color(0xFF002B5E);
        label = l10n.stationRole;
        break;
      case 'WAITER':
        bg = const Color(0xFF0061A4);
        fg = Colors.white;
        border = const Color(0xFF004B80);
        label = l10n.waiterRole;
        break;
      default:
        bg = const Color(0xFFF0F5FF);
        fg = const Color(0xFF0F172A);
        border = const Color(0xFFD8E2F0);
        label = role;
        break;
    }

    return Container(
      width: 120,
      height: 30,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
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
}
