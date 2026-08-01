import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inroom_dining/core/theme/admin_theme.dart';
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

class MenuManagementView extends ConsumerStatefulWidget {
  const MenuManagementView({super.key});

  @override
  ConsumerState<MenuManagementView> createState() => _MenuManagementViewState();
}

class _MenuManagementViewState extends ConsumerState<MenuManagementView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatPrice(dynamic price) => NumberFormat('#,###', 'vi_VN').format(num.tryParse(price.toString()) ?? 0);

  List<MenuItemModel> _filterBySearch(List<MenuItemModel> items, String locale) {
    if (_searchQuery.isEmpty) return items;
    final query = _searchQuery.toLowerCase();
    return items.where((item) {
      final nameVi = (item.nameMap['vi'] ?? '').toLowerCase();
      final nameEn = (item.nameMap['en'] ?? '').toLowerCase();
      return nameVi.contains(query) || nameEn.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(menuItemsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final stationsAsync = ref.watch(stationsStreamProvider);
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('${l10n.errorLoading}: $err', style: const TextStyle(color: Colors.red))),
      data: (categories) {
        final List<Map<String, dynamic>> fullCategories = [
          {'id': 'all', 'name': {'vi': 'Tất cả', 'en': 'All'}},
          ...categories.map((c) => {'id': c.id, 'name': c.nameMap})
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            return DefaultTabController(
              length: fullCategories.length,
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
                          l10n.manageMenu,
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: AdminTheme.textDarkWood,
                          ),
                        ),
                        if (isMobile) const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(l10n.addItem, style: const TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AdminTheme.primaryWood,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                          onPressed: () => _showMenuDialog(context, null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // === THANH TÌM KIẾM MÓN ĂN ===
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: locale == 'vi' ? 'Tìm kiếm món ăn...' : 'Search menu items...',
                        hintStyle: const TextStyle(color: AdminTheme.textMutedWood),
                        prefixIcon: const Icon(Icons.search, color: AdminTheme.primaryWood),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AdminTheme.textMutedWood),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AdminTheme.surfaceWhite,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AdminTheme.borderWood),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AdminTheme.borderWood),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AdminTheme.primaryWood, width: 2),
                        ),
                      ),
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
                        tabs: fullCategories.map((c) => Tab(text: L10nUtils.getL10n(c['name'], locale))).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: menuAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(child: Text('${l10n.errorLoading}: $err', style: const TextStyle(color: Colors.red))),
                        data: (menuItems) {
                          if (menuItems.isEmpty) return Center(child: Text(l10n.noOptions, style: const TextStyle(color: AdminTheme.textMutedWood)));
                          return TabBarView(
                            children: fullCategories.map((cat) {
                              final categoryFiltered = cat['id'] == 'all' ? menuItems : menuItems.where((item) => item.categoryId == cat['id']).toList();
                              final filteredItems = _filterBySearch(categoryFiltered, locale);
                              return _buildMenuTable(context, ref, filteredItems, categories, stationsAsync.value ?? [], isMobile: isMobile);
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
      },
    );
  }

  Widget _buildMenuTable(
    BuildContext context,
    WidgetRef ref,
    List<MenuItemModel> menuItems,
    List<CategoryModel> categories,
    List<Map<String, dynamic>> stations, {
    required bool isMobile,
  }) {
    final l10n = ref.watch(l10nProvider);
    if (menuItems.isEmpty) return Center(child: Text(_searchQuery.isNotEmpty ? (ref.watch(localeProvider) == 'vi' ? 'Không tìm thấy món ăn nào.' : 'No menu items found.') : l10n.noOptions, style: const TextStyle(color: AdminTheme.textMutedWood)));

    return Card(
      child: LayoutBuilder(
        builder: (context, cardConstraints) {
          final minWidth = isMobile ? 650.0 : 850.0;
          final tableWidth = cardConstraints.maxWidth > minWidth ? cardConstraints.maxWidth : minWidth;

          return SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AdminTheme.lightWoodCream),
                  dataRowMinHeight: 70,
                  dataRowMaxHeight: 70,
                  columns: [
                    DataColumn(label: Text(l10n.menuTab, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood))),
                    DataColumn(label: Text(l10n.price, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood))),
                    DataColumn(label: Text(l10n.infoLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood))),
                    DataColumn(label: Text(l10n.statusLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood))),
                    DataColumn(label: Text(l10n.actionsLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.primaryDarkWood))),
                  ],
                  rows: menuItems.map((item) {
                    final locale = ref.watch(localeProvider);
                    final categoryMatch = categories.where((c) => c.id == item.categoryId);
                    final categoryName = categoryMatch.isNotEmpty ? categoryMatch.first.getName(locale) : '...';
                    final stationMatch = stations.where((s) => s['id'] == item.stationId);
                    final stationName = stationMatch.isNotEmpty ? L10nUtils.getL10n(stationMatch.first['name'], locale) : '...';
                    return DataRow(cells: [
                      DataCell(Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                              ? Image.network(
                                  item.imageUrl!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    width: 50,
                                    height: 50,
                                    color: AdminTheme.lightWoodCream,
                                    child: const Icon(Icons.broken_image, color: AdminTheme.textMutedWood),
                                  ),
                                )
                              : Container(
                                  width: 50,
                                  height: 50,
                                  color: AdminTheme.lightWoodCream,
                                  child: const Icon(Icons.restaurant, color: AdminTheme.primaryWood),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Text(item.getName(locale), style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textDarkWood)),
                      ])),
                      DataCell(Text('${_formatPrice(item.price)} VND', style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold))),
                      DataCell(Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(categoryName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AdminTheme.textDarkWood)),
                          Text('${l10n.stationsTab}: $stationName', style: const TextStyle(fontSize: 11, color: AdminTheme.textMutedWood)),
                        ],
                      )),
                      DataCell(Switch(
                        value: item.isAvailable,
                        activeColor: AdminTheme.primaryWood,
                        onChanged: (val) async {
                          await supabase.from('menu_items').update({'is_available': val}).eq('id', item.id);
                        },
                      )),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: AdminTheme.primaryWood),
                          tooltip: l10n.manageToppingTooltip,
                          onPressed: () => _showToppingsDialog(context, item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_square, color: AdminTheme.accentAmber),
                          onPressed: () => _showMenuDialog(context, item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _confirmDelete(context, ref, item.id),
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
  }

  void _showMenuDialog(BuildContext context, MenuItemModel? item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MenuFormDialog(
        item: item != null
            ? {
                'id': item.id,
                'name': item.nameMap,
                'description': item.descriptionMap,
                'price': item.price,
                'prep_time_minutes': item.prepTime,
                'category_id': item.categoryId,
                'category_variant_id': item.categoryVariantId,
                'station_id': item.stationId,
                'is_available': item.isAvailable,
                'image_url': item.imageUrl,
                'variant_name': item.variantName,
              }
            : null,
      ),
    );
  }

  void _showToppingsDialog(BuildContext context, MenuItemModel item) {
    showDialog(context: context, builder: (context) => ModifierManagementDialog(menuItem: {'id': item.id, 'name': item.nameMap}));
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    final l10n = ref.read(l10nProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.confirmDeleteTitle),
        content: Text(l10n.deleteItemConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel, style: const TextStyle(color: AdminTheme.textMutedWood))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                Navigator.pop(dialogContext);
                await supabase.from('menu_items').delete().eq('id', id);
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


