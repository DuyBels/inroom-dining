import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inroom_dining/core/theme/admin_theme.dart';
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
                    l10n.manageTags,
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textDarkWood,
                    ),
                  ),
                  if (isMobile) const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addTag, style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primaryWood,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _showTagDialog(context, null),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: tagsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('${l10n.errorLoading}: $err', style: const TextStyle(color: Colors.red))),
                  data: (tags) {
                    if (tags.isEmpty) return Center(child: Text(l10n.noOptions, style: const TextStyle(color: AdminTheme.textMutedWood)));

                    return Card(
                      child: LayoutBuilder(
                        builder: (context, cardConstraints) {
                          final minWidth = isMobile ? 450.0 : 650.0;
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
                                    DataColumn(label: Text(l10n.tagsTab, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood))),
                                    DataColumn(label: Text(l10n.tagTypeLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood))),
                                    DataColumn(label: Text(l10n.actionsLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood))),
                                  ],
                                  rows: tags.map((tag) {
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
                                              child: const Icon(Icons.local_offer, color: AdminTheme.primaryWood, size: 18),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(tag.getName(locale), style: const TextStyle(fontWeight: FontWeight.w600, color: AdminTheme.textDarkWood)),
                                          ],
                                        ),
                                      ),
                                      DataCell(_buildTypeBadge(tag.tagType, l10n)),
                                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_square, color: AdminTheme.accentAmber),
                                          onPressed: () => _showTagDialog(context, {'id': tag.id, 'name': tag.nameMap, 'tag_type': tag.tagType}),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                          onPressed: () => _confirmDelete(context, ref, tag.id),
                                        ),
                                      ])),
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

  Widget _buildTypeBadge(String tagType, AppDictionary l10n) {
    Color bg;
    Color fg;
    Color border;
    String label;

    switch (tagType) {
      case 'ALLERGY':
        bg = const Color(0xFF7A2E26); // Nâu đỏ sẫm (Cảnh báo dị ứng)
        fg = Colors.white;
        border = const Color(0xFF5A1E18);
        label = l10n.allergyWarning;
        break;
      case 'WEATHER':
        bg = const Color(0xFFC87D55); // Cam sienna / Hổ phách
        fg = Colors.white;
        border = const Color(0xFFA05D3B);
        label = l10n.weatherType;
        break;
      case 'TIME':
        bg = const Color(0xFF5D4037); // Nâu gỗ ấm đậm
        fg = Colors.white;
        border = const Color(0xFF3E2723);
        label = l10n.timeType;
        break;
      case 'TASTE':
        bg = const Color(0xFFEFEBE9); // Kem gỗ sáng
        fg = const Color(0xFF3E2723);
        border = const Color(0xFFC7B8B1);
        label = l10n.tasteType;
        break;
      default:
        bg = const Color(0xFFF5F0EB);
        fg = const Color(0xFF6D4C41);
        border = const Color(0xFFE0D7D0);
        label = 'OTHER';
    }

    return Container(
      width: 140,
      height: 30,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  void _showTagDialog(BuildContext context, Map<String, dynamic>? tag) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TagFormDialog(tag: tag),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    final l10n = ref.read(l10nProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmDeleteTitle),
        content: Text(l10n.deleteTagConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel, style: const TextStyle(color: AdminTheme.textMutedWood))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await supabase.from('tags').delete().eq('id', id);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e'), backgroundColor: Colors.red));
              }
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}

