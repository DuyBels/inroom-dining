import 'dart:async';
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
import '../../../core/widgets/language_selector.dart';
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
  String _animatedHint = "";
  int _charIndex = 0;
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();
    _startTypewriter();
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }

  void _startTypewriter() {
    _typewriterTimer?.cancel();
    _charIndex = 0;
    _animatedHint = "";
    
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      final l10n = ref.read(l10nProvider);
      final fullText = l10n.searchTypewriter;
      
      if (_charIndex < fullText.length) {
        setState(() {
          _animatedHint += fullText[_charIndex];
          _charIndex++;
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _startTypewriter();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomNumber = widget.roomNumber;
    final profileAsync = ref.watch(userProfileProvider);

    ref.listen(localeProvider, (previous, next) {
      if (previous != next) _startTypewriter();
    });

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
    final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
    final String currentRoomNumber = widget.roomNumber!;
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey[900],
        title: Text('${l10n.room} $currentRoomNumber', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        actions: [
          const LanguageSelector(),
          const SizedBox(width: 8),
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
                _buildSearchBar(l10n),
                _buildAISuggestionBar(),
                Expanded(
                  child: menuWithTagsAsync.when(
                    data: (items) {
                      final allTags = tagsAsync.value ?? [];
                      
                      // 1. Lọc theo trạng thái và tìm kiếm
                      var list = items.where((i) => i.isAvailable).toList();
                      
                      if (searchQuery.isNotEmpty) {
                        list = list.where((item) {
                          final name = item.getName(locale).toLowerCase();
                          final desc = item.getDescription(locale).toLowerCase();
                          return name.contains(searchQuery) || desc.contains(searchQuery);
                        }).toList();
                      }

                      // 2. Lọc theo Danh mục
                      if (_selectedCategoryId != null) {
                        list = list.where((i) => i.categoryId == _selectedCategoryId).toList();
                      }

                      // 3. Lọc theo Thẻ Preferences (Không phải ALLERGY)
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
                    error: (e, s) => Center(child: Text('Lỗi tải thực đơn: $e')),
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
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
      data: (roomCtx) {
        if (roomCtx.isApiError && manualPref == null) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey[100]!)),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blueGrey, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n.aiIntro, style: const TextStyle(fontSize: 13, color: Colors.blueGrey))),
                TextButton(onPressed: () => ref.read(userManualPreferenceProvider.notifier).update('COOL'), child: Text(l10n.cool)),
                TextButton(onPressed: () => ref.read(userManualPreferenceProvider.notifier).update('WARM'), child: Text(l10n.warm)),
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
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.amber[50]!, Colors.white]), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber[200]!)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l10n.aiSuggestion}: ${roomCtx.isApiError ? (manualPref == 'COOL' ? l10n.cool : l10n.warm) : "${roomCtx.temp.toInt()}°C"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        return GestureDetector(
                          onTap: () => _showCustomizationDialog(item.id),
                          child: Container(
                            width: 200, margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                  child: item.imageUrl != null ? Image.network(item.imageUrl!, width: 60, height: 80, fit: BoxFit.cover) : Container(width: 60, color: Colors.grey[200]),
                                ),
                                Expanded(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(item.getName(locale), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis))),
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

  Widget _buildSearchBar(AppDictionary l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: Colors.white,
      child: TextField(
        onChanged: (val) => ref.read(searchQueryProvider.notifier).update(val),
        decoration: InputDecoration(
          hintText: _animatedHint,
          prefixIcon: const Icon(Icons.search, color: Colors.amber),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey[200]!)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey[200]!)),
        ),
      ),
    );
  }

  Widget _buildTagFilterBar(AsyncValue<List<TagModel>> tagsAsync, List<String> activeFilters, String locale) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey[100]!))),
      child: tagsAsync.maybeWhen(
        data: (tags) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: tags.map((t) {
              final isSelected = activeFilters.contains(t.id);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(t.getName(locale), style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                  selected: isSelected,
                  selectedColor: Colors.amber[700],
                  checkmarkColor: Colors.white,
                  onSelected: (_) => ref.read(activeFiltersProvider.notifier).toggle(t.id),
                ),
              );
            }).toList(),
          ),
        ),
        orElse: () => const SizedBox(height: 50),
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasAllergyWarning ? null : () => _showCustomizationDialog(item.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Stack(fit: StackFit.expand, children: [
              item.imageUrl != null ? Image.network(item.imageUrl!, fit: BoxFit.cover) : Container(color: Colors.grey[200], child: const Icon(Icons.restaurant, color: Colors.white, size: 40)),
              if (hasAllergyWarning) Container(color: Colors.red.withOpacity(0.8), child: Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.warning, color: Colors.white), const SizedBox(height: 4), Text(l10n.allergyWarning, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)), Text(allergyNames, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 8))])))),
            ])),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.getName(locale), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${NumberFormat('#,###', 'vi_VN').format(item.price)} VND', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('⏱️ ${item.prepTime}p', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                if (widget.item.imageUrl != null) Image.network(widget.item.imageUrl!, height: 200, width: double.infinity, fit: BoxFit.cover) else Container(height: 100, color: Colors.amber),
                Positioned(top: 10, right: 10, child: CircleAvatar(backgroundColor: Colors.black26, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)))),
                Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])), child: Text(widget.item.getName(locale), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)))),
              ],
            ),
            Flexible(
              child: modifiersAsync.when(
                data: (groups) {
                  if (groups.isEmpty) return Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(l10n.noOptions, style: const TextStyle(color: Colors.grey))));
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...groups.map((group) => _buildModifierGroup(group, l10n, locale)),
                        const SizedBox(height: 16),
                        Text(l10n.specialNotes, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        TextField(controller: _noteController, decoration: InputDecoration(hintText: locale == 'vi' ? 'Ghi chú thêm...' : 'Special instructions...', filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Padding(padding: const EdgeInsets.all(20), child: Text('${l10n.errorLoading}: $e')),
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
        Row(children: [Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), if (min > 0) Padding(padding: const EdgeInsets.only(left: 8), child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)), child: Text(l10n.requiredLabel, style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold))))]),
        const SizedBox(height: 8),
        ...modifiers.map((m) {
          final modName = L10nUtils.getL10n(m['name'], locale);
          final price = (m['price'] ?? 0).toDouble();
          final isSelected = _selectedModifiers.any((sm) => sm.modifierId == m['id']);
          return CheckboxListTile(
            title: Text(modName, style: const TextStyle(fontSize: 14)),
            subtitle: price > 0 ? Text('+${NumberFormat('#,###', 'vi_VN').format(price)} VND', style: const TextStyle(color: Colors.green, fontSize: 12)) : null,
            value: isSelected,
            activeColor: Colors.amber[800],
            dense: true,
            onChanged: (val) {
              setState(() {
                if (val!) {
                  if (_selectedModifiers.where((sm) => sm.groupId == group['id']).length < max) {
                    _selectedModifiers.add(SelectedModifier(groupId: group['id'], groupName: groupName, modifierId: m['id'], modifierName: modName, price: price));
                  }
                } else {
                  _selectedModifiers.removeWhere((sm) => sm.modifierId == m['id']);
                }
              });
            },
          );
        }).toList(),
        const Divider(height: 30),
      ],
    );
  }

  Widget _buildFooter(bool isValid, AppDictionary l10n) {
    final double totalPrice = widget.item.price + _selectedModifiers.fold(0, (sum, m) => sum + m.price);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l10n.total, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text('${NumberFormat('#,###', 'vi_VN').format(totalPrice)} VND', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber[900]))]),
          SizedBox(height: 48, width: 200, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isValid ? Colors.amber[800] : Colors.grey[300], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: isValid ? () { ref.read(cartProvider.notifier).addToCart(widget.item, _selectedModifiers, _noteController.text); Navigator.pop(context); } : null, child: Text(isValid ? l10n.orderNow : l10n.selectFullLabel, style: const TextStyle(fontWeight: FontWeight.bold)))),
        ],
      ),
    );
  }
}
