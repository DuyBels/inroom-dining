import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../main.dart';
import '../../providers/admin_provider.dart';
import '../widgets/station_form_dialog.dart';

class StationManagementView extends ConsumerWidget {
  const StationManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stationsAsync = ref.watch(stationsStreamProvider);
    final l10n = ref.watch(l10nProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  l10n.manageStations,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l10n.addStation, style: const TextStyle(fontWeight: FontWeight.bold)),
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
              error: (err, stack) => Center(child: Text('${l10n.errorLoading}: $err', style: const TextStyle(color: Colors.red))),
              data: (rawStations) {
                if (rawStations.isEmpty) {
                  return Center(child: Text(l10n.noOptions));
                }

                // Đảm bảo không có ID trùng lặp (tránh lỗi UI nhảy 2 cái giống nhau)
                final seenIds = <String>{};
                final stations = rawStations.where((s) => seenIds.add(s['id'].toString())).toList();

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
                        columns: [
                          DataColumn(label: Text(l10n.stationsTab, style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text(l10n.actionsLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: stations.map((station) {
                          final locale = ref.watch(localeProvider);
                          return DataRow(cells: [
                            DataCell(
                                Row(
                                  children: [
                                    const Icon(Icons.countertops, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(L10nUtils.getL10n(station['name'], locale), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                  ],
                                )
                            ),
                            DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_square, color: Colors.blue),
                                      tooltip: l10n.editStationTooltip,
                                      splashRadius: 24,
                                      onPressed: () => _showStationDialog(context, station),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: l10n.deleteStationTooltip,
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
    final l10n = ref.read(l10nProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmDeleteTitle),
        content: Text(l10n.deleteStationConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await supabase.from('kitchen_stations').delete().eq('id', id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.stationDeleted), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (context.mounted) {
                  // Hiển thị lỗi rõ ràng nếu bị chặn bởi Foreign Key (ON DELETE RESTRICT)
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.cannotDeleteStation), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}