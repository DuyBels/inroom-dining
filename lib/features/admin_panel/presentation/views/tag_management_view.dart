import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../main.dart';
import '../../providers/tag_provider.dart';
import '../widgets/tag_form_dialog.dart';

class TagManagementView extends ConsumerWidget {
  const TagManagementView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsStreamProvider);
    final l10n = ref.watch(l10nProvider);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.manageTags, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(icon: const Icon(Icons.add), label: Text(l10n.addTag), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)), onPressed: () => _showTagDialog(context, null)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: tagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('${l10n.errorLoading}: $err')),
              data: (tags) {
                if (tags.isEmpty) return Center(child: Text(l10n.noOptions));
                return Card(
                  elevation: 2, color: Colors.white, clipBehavior: Clip.antiAlias,
                  child: ListView(
                    children: [
                      DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                        columns: [DataColumn(label: Text(l10n.tagsTab)), DataColumn(label: Text(l10n.tagTypeLabel)), DataColumn(label: Text(l10n.actionsLabel))],
                        rows: tags.map((tag) {
                          final locale = ref.watch(localeProvider);
                          return DataRow(cells: [
                            DataCell(Text(tag.getName(locale), style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(_buildTypeBadge(tag.tagType, l10n)),
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

  Widget _buildTypeBadge(String tagType, AppDictionary l10n) {
    Color color; String label;
    switch (tagType) {
      case 'ALLERGY': color = Colors.red; label = l10n.allergyWarning; break;
      case 'WEATHER': color = Colors.blue; label = l10n.weatherType; break;
      case 'TIME': color = Colors.green; label = l10n.timeType; break;
      case 'TASTE': color = Colors.orange; label = l10n.tasteType; break;
      default: color = Colors.grey; label = 'OTHER';
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))), child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)));
  }

  void _showTagDialog(BuildContext context, Map<String, dynamic>? tag) { showDialog(context: context, barrierDismissible: false, builder: (context) => TagFormDialog(tag: tag)); }
  void _confirmDelete(BuildContext context, WidgetRef ref, String id) { final l10n = ref.read(l10nProvider); showDialog(context: context, builder: (dialogContext) => AlertDialog(title: Text(l10n.confirmDeleteTitle), content: Text(l10n.deleteTagConfirm), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () async { try { Navigator.pop(dialogContext); await supabase.from('tags').delete().eq('id', id); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e'))); } }, child: Text(l10n.delete))])); }
}
