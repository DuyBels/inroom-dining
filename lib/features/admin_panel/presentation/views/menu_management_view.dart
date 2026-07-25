import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/l10n_utils.dart';
import '../../../../core/models/menu_item_model.dart';
import '../../../../core/models/category_model.dart';
import '../../../../main.dart';
import '../../providers/menu_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/admin_provider.dart';
import '../widgets/menu_form_dialog.dart';
import '../widgets/modifier_management_dialog.dart';

class MenuManagementView extends ConsumerWidget {
  const MenuManagementView({super.key});
  String _formatPrice(dynamic price) => NumberFormat('#,###', 'vi_VN').format(num.tryParse(price.toString()) ?? 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuItemsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final stationsAsync = ref.watch(stationsStreamProvider);
    final l10n = ref.watch(l10nProvider);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${l10n.errorLoading}: $err')),
      data: (categories) {
        final List<Map<String, dynamic>> fullCategories = [
          {'id': 'all', 'name': {'vi': 'Tất cả', 'en': 'All'}},
          ...categories.map((c) => {'id': c.id, 'name': c.nameMap})
        ];

        return DefaultTabController(
          length: fullCategories.length,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.manageMenu, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addItem, style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                      onPressed: () => _showMenuDialog(context, null),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: TabBar(
                    isScrollable: true,
                    labelColor: Colors.blue[800], unselectedLabelColor: Colors.grey, indicatorColor: Colors.blue[800],
                    tabs: fullCategories.map((c) => Tab(text: L10nUtils.getL10n(c['name'], ref.watch(localeProvider)))).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: menuAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('${l10n.errorLoading}: $err')),
                    data: (menuItems) {
                      if (menuItems.isEmpty) return Center(child: Text(l10n.noOptions));
                      return TabBarView(
                        children: fullCategories.map((cat) {
                          final filteredItems = cat['id'] == 'all' ? menuItems : menuItems.where((item) => item.categoryId == cat['id']).toList();
                          return _buildMenuTable(context, ref, filteredItems, categories, stationsAsync.value ?? []);
                        }).toList(),
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

  Widget _buildMenuTable(BuildContext context, WidgetRef ref, List<MenuItemModel> menuItems, List<CategoryModel> categories, List<Map<String, dynamic>> stations) {
    final l10n = ref.watch(l10nProvider);
    if (menuItems.isEmpty) return Center(child: Text(l10n.noOptions));
    return Card(
      elevation: 2, color: Colors.white, clipBehavior: Clip.antiAlias, margin: EdgeInsets.zero,
      child: ListView(
        children: [
          DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue[50]),
            dataRowMinHeight: 70, dataRowMaxHeight: 70,
            columns: [
              DataColumn(label: Text(l10n.menuTab, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(l10n.price, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(l10n.infoLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(l10n.statusLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text(l10n.actionsLabel, style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: menuItems.map((item) {
              final locale = ref.watch(localeProvider);
              final categoryMatch = categories.where((c) => c.id == item.categoryId);
              final categoryName = categoryMatch.isNotEmpty ? categoryMatch.first.getName(locale) : '...';
              final stationMatch = stations.where((s) => s['id'] == item.stationId);
              final stationName = stationMatch.isNotEmpty ? L10nUtils.getL10n(stationMatch.first['name'], locale) : '...';
              return DataRow(cells: [
                DataCell(Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: item.imageUrl != null && item.imageUrl!.isNotEmpty ? Image.network(item.imageUrl!, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(width: 50, height: 50, color: Colors.grey[300], child: const Icon(Icons.broken_image))) : Container(width: 50, height: 50, color: Colors.grey[300], child: const Icon(Icons.restaurant))),
                  const SizedBox(width: 12),
                  Text(item.getName(locale), style: const TextStyle(fontWeight: FontWeight.bold)),
                ])),
                DataCell(Text('${_formatPrice(item.price)} VND', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                DataCell(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(categoryName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)), Text('${l10n.stationsTab}: $stationName', style: TextStyle(fontSize: 11, color: Colors.grey[600]))])),
                DataCell(Switch(value: item.isAvailable, activeColor: Colors.green, onChanged: (val) async { await supabase.from('menu_items').update({'is_available': val}).eq('id', item.id); })),
                DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blueGrey), tooltip: l10n.manageToppingTooltip, onPressed: () => _showToppingsDialog(context, item)),
                  IconButton(icon: const Icon(Icons.edit_square, color: Colors.orange), onPressed: () => _showMenuDialog(context, item)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _confirmDelete(context, ref, item.id)),
                ])),
              ]);
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showMenuDialog(BuildContext context, MenuItemModel? item) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => MenuFormDialog(item: item != null ? {'id': item.id, 'name': item.nameMap, 'description': item.descriptionMap, 'price': item.price, 'prep_time_minutes': item.prepTime, 'category_id': item.categoryId, 'station_id': item.stationId, 'is_available': item.isAvailable, 'image_url': item.imageUrl} : null));
  }

  void _showToppingsDialog(BuildContext context, MenuItemModel item) {
    showDialog(context: context, builder: (context) => ModifierManagementDialog(menuItem: {'id': item.id, 'name': item.nameMap}));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    final l10n = ref.read(l10nProvider);
    showDialog(context: context, builder: (dialogContext) => AlertDialog(title: Text(l10n.confirmDeleteTitle), content: Text(l10n.deleteItemConfirm), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () async { try { Navigator.pop(dialogContext); await supabase.from('menu_items').delete().eq('id', id); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e'))); } }, child: Text(l10n.delete))]));
  }
}
