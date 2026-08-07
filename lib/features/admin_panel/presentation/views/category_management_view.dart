import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inroom_dining/core/theme/admin_theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../main.dart';
import '../../providers/category_provider.dart';
import '../widgets/category_form_dialog.dart';
import '../widgets/category_variant_management_dialog.dart';
import '../../../../core/models/category_model.dart';

class CategoryManagementView extends ConsumerWidget {
  const CategoryManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
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
                    l10n.manageCategories,
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: AdminTheme.textDarkWood,
                    ),
                  ),
                  if (isMobile) const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.addCategory, style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primaryWood,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => _showCategoryDialog(context, null),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: categoriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(child: Text('${l10n.errorLoading}: $err', style: const TextStyle(color: Colors.red))),
                  data: (categories) {
                    if (categories.isEmpty) {
                      return Center(child: Text(l10n.noOptions, style: const TextStyle(color: AdminTheme.textMutedWood)));
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
                                    DataColumn(label: Text(l10n.categoriesTab, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood))),
                                    DataColumn(label: Text(l10n.actionsLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood))),
                                  ],
                                  rows: categories.map((category) {
                                    final locale = ref.watch(localeProvider);
                                    return DataRow(cells: [
                                      DataCell(
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AdminTheme.lightBlueContainer,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(category.iconData, color: AdminTheme.primaryBlue, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              category.getName(locale),
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AdminTheme.textDarkBlue),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                                        IconButton(
                                          icon: const Icon(Icons.list_alt_rounded, color: AdminTheme.primaryWood),
                                          tooltip: 'Quản lý nhóm tùy chọn',
                                          onPressed: () => _showCategoryVariantDialog(context, category),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_square, color: AdminTheme.primaryBlue),
                                          onPressed: () => _showCategoryDialog(context, {
                                            'id': category.id,
                                            'name': category.nameMap,
                                            'description': category.descriptionMap,
                                            'icon_name': category.iconName,
                                          }),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                          onPressed: () => _confirmDelete(context, ref, category.id),
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

  void _showCategoryDialog(BuildContext context, Map<String, dynamic>? category) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CategoryFormDialog(category: category),
    );
  }

  void _showCategoryVariantDialog(BuildContext context, CategoryModel category) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CategoryVariantManagementDialog(category: category),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    final l10n = ref.read(l10nProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmDeleteTitle),
        content: Text(l10n.deleteCategoryConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel, style: const TextStyle(color: AdminTheme.textMutedWood))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await supabase.from('categories').delete().eq('id', id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.cannotDeleteCategory), backgroundColor: Colors.red));
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

