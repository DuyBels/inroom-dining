import '../providers/ai_recommendation_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/l10n_utils.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/tag_model.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inroom_dining/features/room_menu/presentation/widgets/cart_and_tracking_panel.dart';
import '../../../main.dart';
import '../../admin_panel/providers/category_provider.dart';
import '../../admin_panel/providers/menu_provider.dart';
import '../../admin_panel/providers/tag_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/room_menu_provider.dart';

class RoomMenuScreen extends ConsumerStatefulWidget {
  final String? roomNumber;
  const RoomMenuScreen({super.key, this.roomNumber});

  @override
  ConsumerState<RoomMenuScreen> createState() => _RoomMenuScreenState();
}

class _RoomMenuScreenState extends ConsumerState<RoomMenuScreen> {
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final roomNumber = widget.roomNumber;
    final profileAsync = ref.watch(userProfileProvider);

    // LẮNG NGHE LỖI API
    ref.listen<AsyncValue<RoomContext>>(roomContextProvider, (prev, next) {});

    if (roomNumber == null) {
      return profileAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, s) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
        data: (profile) {
          if (profile != null && (profile['role'] == 'ROOM' || profile['role'] == 'ADMIN')) {
            Future.microtask(() => context.go('/menu/${profile['room_number']}'));
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return const Scaffold(body: Center(child: Text('Vui lòng đăng nhập.')));
        },
      );
    }

    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final menuWithTagsAsync = ref.watch(menuItemsWithTagsProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);
    final activeFilters = ref.watch(activeFiltersProvider);
    final String currentRoomNumber = widget.roomNumber!;
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey[900],
        title: Text('${l10n.room} $currentRoomNumber', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () => ref.read(localeProvider.notifier).toggleLanguage(),
            child: Text(
              locale == 'vi' ? 'EN 🇺🇸' : 'VI 🇻🇳',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: () async {
            await supabase.auth.signOut();
            if (context.mounted) context.go('/login');
          }),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Colors.grey[900],
            unselectedLabelTextStyle: const TextStyle(color: Colors.grey, fontSize: 12),
            selectedLabelTextStyle: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
            unselectedIconTheme: const IconThemeData(color: Colors.grey),
            selectedIconTheme: const IconThemeData(color: Colors.amber),
            selectedIndex: _getSelectedIndex(categoriesAsync.value),
            onDestinationSelected: (idx) {
              if (idx == 0) setState(() => _selectedCategoryId = null);
              else setState(() => _selectedCategoryId = categoriesAsync.value![idx - 1].id);
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.menu_book), 
                selectedIcon: const Icon(Icons.menu_book, color: Colors.amber),
                label: Text(l10n.all)
              ),
              ...categoriesAsync.maybeWhen(
                data: (cats) => cats.map((c) => NavigationRailDestination(
                  icon: const Icon(Icons.restaurant_menu), 
                  label: Text(c.getName(locale), textAlign: TextAlign.center)
                )).toList(), 
                orElse: () => []
              ),
            ],
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildTagFilterBar(tagsAsync, activeFilters, locale),
                _buildAISuggestionBar(),
                Expanded(
                  child: menuWithTagsAsync.when(
                    data: (items) {
                      var list = items.where((i) => i.isAvailable).toList();
                      if (_selectedCategoryId != null) {
                        list = list.where((i) => i.categoryId == _selectedCategoryId).toList();
                      }

                      final allTags = tagsAsync.value ?? [];
                      final selectedPrefTagIds = activeFilters.where((id) {
                        final tag = allTags.firstWhere((t) => t.id == id, orElse: () => TagModel(id: '', nameMap: {}, tagType: ''));
                        return tag.id.isNotEmpty && tag.tagType != 'ALLERGY';
                      }).toList();

                      if (selectedPrefTagIds.isNotEmpty) {
                        list = list.where((item) {
                          return selectedPrefTagIds.any((selectedId) => item.tagIds.contains(selectedId));
                        }).toList();
                      }

                      if (list.isEmpty) {
                        return Center(child: Text(l10n.emptyCart, style: const TextStyle(color: Colors.grey, fontSize: 16)));
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, childAspectRatio: 0.72, crossAxisSpacing: 16, mainAxisSpacing: 16
                        ),
                        itemCount: list.length,
                        itemBuilder: (c, idx) => _buildDishCard(list[idx], activeFilters, allTags, l10n),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Lỗi: $e')),
                  ),
                ),
              ],
            ),
          ),
          CartAndTrackingPanel(roomNumber: currentRoomNumber),
        ],
      ),
    );
  }

  Widget _buildAISuggestionBar() {
    final aiItemsAsync = ref.watch(aiRecommendedItemsProvider);
    final contextAsync = ref.watch(roomContextProvider);
    final manualPref = ref.watch(userManualPreferenceProvider);
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);

    return contextAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator())),
      error: (e, s) => const SizedBox(),
      data: (roomCtx) {
        if (roomCtx.isApiError && manualPref == null) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blueGrey),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.aiIntro, style: const TextStyle(fontSize: 14, color: Colors.blueGrey))),
                TextButton.icon(onPressed: () => ref.read(userManualPreferenceProvider.notifier).update('COOL'), icon: const Text('❄️'), label: Text(l10n.cool)),
                TextButton.icon(onPressed: () => ref.read(userManualPreferenceProvider.notifier).update('WARM'), icon: const Text('🔥'), label: Text(l10n.warm)),
              ],
            ),
          );
        }

        return aiItemsAsync.when(
          loading: () => const SizedBox(),
          error: (e, s) => const SizedBox(),
          data: (items) {
            if (items.isEmpty) return const SizedBox();
            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber[50]!, Colors.white]), borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l10n.aiSuggestion}: ${roomCtx.isApiError ? (manualPref == 'COOL' ? l10n.cool : l10n.warm) : "${roomCtx.temp.toInt()}°C"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        return GestureDetector(
                          onTap: () => _showCustomizationDialog(item.id),
                          child: Container(
                            width: 250, margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                  child: item.imageUrl != null ? Image.network(item.imageUrl!, width: 80, height: 100, fit: BoxFit.cover) : Container(width: 80, color: Colors.grey[200]),
                                ),
                                Expanded(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(item.getName(locale), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  int _getSelectedIndex(List<CategoryModel>? cats) {
    if (_selectedCategoryId == null || cats == null) return 0;
    final idx = cats.indexWhere((c) => c.id == _selectedCategoryId);
    return idx >= 0 ? idx + 1 : 0;
  }

  Widget _buildTagFilterBar(AsyncValue<List<TagModel>> tagsAsync, List<String> activeFilters, String locale) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: tagsAsync.maybeWhen(
        data: (tags) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: tags.map((t) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(t.getName(locale)),
                selected: activeFilters.contains(t.id),
                onSelected: (_) => ref.read(activeFiltersProvider.notifier).toggle(t.id),
              ),
            )).toList(),
          ),
        ),
        orElse: () => const SizedBox(height: 60),
      ),
    );
  }

  void _showCustomizationDialog(String itemId) {
    final items = ref.read(menuItemsWithTagsProvider).value ?? [];
    final itemModel = items.firstWhere((i) => i.id == itemId);
    showDialog(context: context, builder: (context) => DishCustomizationDialog(item: itemModel));
  }

  Widget _buildDishCard(MenuItemModel item, List<String> activeFilters, List<TagModel> allTags, AppDictionary l10n) {
    final locale = ref.watch(localeProvider);
    final activeAllergyTagIds = activeFilters.where((id) {
      final tag = allTags.firstWhere((t) => t.id == id, orElse: () => TagModel(id: '', nameMap: {}, tagType: ''));
      return tag.id.isNotEmpty && tag.tagType == 'ALLERGY';
    }).toList();

    final hasAllergyWarning = activeAllergyTagIds.any((id) => item.tagIds.contains(id));
    String allergyNames = "";
    if (hasAllergyWarning) {
      allergyNames = allTags.where((t) => activeAllergyTagIds.contains(t.id) && item.tagIds.contains(t.id)).map((t) => t.getName(locale)).join(', ');
    }

    return Card(
      elevation: 4,
      child: InkWell(
        onTap: hasAllergyWarning ? null : () => _showCustomizationDialog(item.id),
        child: Column(
          children: [
            Expanded(child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: item.imageUrl != null ? Image.network(item.imageUrl!, fit: BoxFit.cover) : Container(color: Colors.grey[200]),
              ),
              if (hasAllergyWarning) Container(color: Colors.red.withOpacity(0.8), child: Center(child: Text(l10n.allergyWarning, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            ])),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.getName(locale), style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${NumberFormat('#,###', 'vi_VN').format(item.price)} VND', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    Text('⏱️ ${item.prepTime}p', style: const TextStyle(fontSize: 11)),
                  ]),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

class DishCustomizationDialog extends ConsumerStatefulWidget {
  final MenuItemModel item;
  const DishCustomizationDialog({super.key, required this.item});
  @override
  ConsumerState<DishCustomizationDialog> createState() => _DishCustomizationDialogState();
}

class _DishCustomizationDialogState extends ConsumerState<DishCustomizationDialog> {
  final List<SelectedModifier> _selectedModifiers = [];
  final _noteController = TextEditingController();

  bool _isSelectionValid(List<Map<String, dynamic>> groups) {
    for (var group in groups) {
      final int min = group['min_select'] ?? 0;
      final selectedInGroup = _selectedModifiers.where((m) => m.groupId == group['id']).length;
      if (selectedInGroup < min) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);
    final modifiersAsync = ref.watch(itemModifiersProvider(widget.item.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 650,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                if (widget.item.imageUrl != null) Image.network(widget.item.imageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover),
                Positioned(top: 10, right: 10, child: CircleAvatar(child: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)))),
                Positioned(bottom: 10, left: 16, child: Text(widget.item.getName(locale), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, backgroundColor: Colors.black45))),
              ],
            ),
            Flexible(
              child: modifiersAsync.when(
                data: (groups) {
                  if (groups.isEmpty) return Padding(padding: const EdgeInsets.all(40), child: Text(l10n.noOptions));
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        ...groups.map((group) => _buildModifierGroup(group, l10n, locale)),
                        Text(l10n.specialNotes, style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextField(controller: _noteController),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text(l10n.errorLoading),
              ),
            ),
            modifiersAsync.maybeWhen(data: (groups) => _buildFooter(_isSelectionValid(groups), l10n), orElse: () => const SizedBox()),
          ],
        ),
      ),
    );
  }

  Widget _buildModifierGroup(Map<String, dynamic> group, AppDictionary l10n, String locale) {
    final List modifiers = group['modifiers'] ?? [];
    final int min = group['min_select'] ?? 0;
    final int max = group['max_select'] ?? 1;
    final String groupName = L10nUtils.getL10n(group['name'], locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
        ...modifiers.map((m) {
          final modName = L10nUtils.getL10n(m['name'], locale);
          final isSelected = _selectedModifiers.any((sm) => sm.modifierId == m['id']);
          return CheckboxListTile(
            title: Text(modName),
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val!) {
                  if (_selectedModifiers.where((sm) => sm.groupId == group['id']).length < max) {
                    _selectedModifiers.add(SelectedModifier(groupId: group['id'], groupName: groupName, modifierId: m['id'], modifierName: modName, price: (m['price'] ?? 0).toDouble()));
                  }
                } else {
                  _selectedModifiers.removeWhere((sm) => sm.modifierId == m['id']);
                }
              });
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFooter(bool isValid, AppDictionary l10n) {
    final double totalPrice = widget.item.price + _selectedModifiers.fold(0, (sum, m) => sum + m.price);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${l10n.total}: ${NumberFormat('#,###', 'vi_VN').format(totalPrice)} VND'),
          ElevatedButton(
            onPressed: isValid ? () {
              ref.read(cartProvider.notifier).addToCart(widget.item, _selectedModifiers, _noteController.text);
              Navigator.pop(context);
            } : null,
            child: Text(isValid ? l10n.orderNow : l10n.selectFullLabel),
          )
        ],
      ),
    );
  }
}
