import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../main.dart';
import '../../providers/category_provider.dart';
import '../widgets/category_form_dialog.dart';

class CategoryManagementView extends ConsumerWidget {
  const CategoryManagementView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final l10n = ref.watch(l10nProvider);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.manageCategories, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(icon: const Icon(Icons.add), label: Text(l10n.addCategory), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)), onPressed: () => _showCategoryDialog(context, null)),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('${l10n.errorLoading}: $err')),
              data: (categories) {
                if (categories.isEmpty) return Center(child: Text(l10n.noOptions));
                return Card(
                  elevation: 2, color: Colors.white, clipBehavior: Clip.antiAlias,
                  child: ListView(
                    children: [
                      DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
                        columns: [DataColumn(label: Text(l10n.categoriesTab)), DataColumn(label: Text(l10n.descriptionLabel)), DataColumn(label: Text(l10n.actionsLabel))],
                        rows: categories.map((category) {
                          final locale = ref.watch(localeProvider);
                          return DataRow(cells: [
                            DataCell(Text(category.getName(locale), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                            DataCell(Text(L10nUtils.getL10n(category.descriptionMap, locale) == '' ? '-' : L10nUtils.getL10n(category.descriptionMap, locale))),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(icon: const Icon(Icons.edit_square, color: Colors.orange), onPressed: () => _showCategoryDialog(context, {'id': category.id, 'name': category.nameMap, 'description': category.descriptionMap})),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(context, ref, category.id)),
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

  void _showCategoryDialog(BuildContext context, Map<String, dynamic>? category) { showDialog(context: context, barrierDismissible: false, builder: (context) => CategoryFormDialog(category: category)); }
  void _confirmDelete(BuildContext context, WidgetRef ref, String id) { final l10n = ref.read(l10nProvider); showDialog(context: context, builder: (dialogContext) => AlertDialog(title: Text(l10n.confirmDeleteTitle), content: Text(l10n.deleteCategoryConfirm), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () async { try { Navigator.pop(dialogContext); await supabase.from('categories').delete().eq('id', id); } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cannotDeleteCategory))); } }, child: Text(l10n.delete))])); }
}
