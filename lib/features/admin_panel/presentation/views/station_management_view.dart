import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inroom_dining/core/theme/admin_theme.dart';
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Responsive
              Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isMobile ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                children: [
                  Text(
                    l10n.manageStations,
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textDarkWood,
                    ),
                  ),
                  if (isMobile) const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addStation, style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primaryWood,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _showStationDialog(context, null),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Expanded(
                child: stationsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Text('${l10n.errorLoading}: $err', style: const TextStyle(color: Colors.red)),
                  ),
                  data: (rawStations) {
                    if (rawStations.isEmpty) {
                      return Center(
                        child: Text(l10n.noOptions, style: const TextStyle(color: AdminTheme.textMutedWood)),
                      );
                    }

                    final seenIds = <String>{};
                    final stations = rawStations.where((s) => seenIds.add(s['id'].toString())).toList();

                    return Card(
                      child: LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final minWidth = isMobile ? 400.0 : 600.0;
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
                                      label: Text(
                                        l10n.stationsTab,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        l10n.actionsLabel,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood),
                                      ),
                                    ),
                                  ],
                                  rows: stations.map((station) {
                                    final locale = ref.watch(localeProvider);
                                    return DataRow(cells: [
                                      DataCell(
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AdminTheme.lightWoodCream,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.countertops, color: AdminTheme.primaryWood, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              L10nUtils.getL10n(station['name'], locale),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: AdminTheme.textDarkWood,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit_square, color: AdminTheme.accentAmber),
                                              tooltip: l10n.editStationTooltip,
                                              onPressed: () => _showStationDialog(context, station),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                              tooltip: l10n.deleteStationTooltip,
                                              onPressed: () => _confirmDelete(context, ref, station['id']),
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
            child: Text(l10n.cancel, style: const TextStyle(color: AdminTheme.textMutedWood)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await supabase.from('kitchen_stations').delete().eq('id', id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.stationDeleted), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.cannotDeleteStation), backgroundColor: Colors.red),
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