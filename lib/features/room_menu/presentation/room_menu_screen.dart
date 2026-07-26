import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inroom_dining/core/theme/admin_theme.dart';
import 'package:inroom_dining/features/room_menu/presentation/widgets/cart_and_tracking_panel.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/l10n_utils.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/tag_model.dart';
import '../../../core/widgets/language_selector.dart';
import '../../../core/services/qr_session_service.dart';
import '../../../main.dart';
import '../../admin_panel/providers/category_provider.dart';
import '../../admin_panel/providers/menu_provider.dart';
import '../../admin_panel/providers/tag_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/ai_recommendation_provider.dart';
import '../providers/room_menu_provider.dart';
import 'widgets/dish_customization_dialog.dart';
import 'widgets/food_chatbot_dialog.dart';

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
  Timer? _qrCountdownTimer;

  @override
  void initState() {
    super.initState();
    _startTypewriter();
    _qrCountdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _qrCountdownTimer?.cancel();
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
        error: (e, s) => Scaffold(body: Center(child: Text('${ref.watch(l10nProvider).errorPrefix}: $e'))),
        data: (profile) {
          if (profile != null && (profile['role'] == 'ROOM' || profile['role'] == 'ADMIN')) {
            Future.microtask(() => context.go('/menu/${profile['room_number']}'));
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return Scaffold(body: Center(child: Text(ref.watch(l10nProvider).pleaseLogin)));
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
    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);

    return Theme(
      data: AdminTheme.themeData,
      child: Scaffold(
        backgroundColor: AdminTheme.bgWarmWhite,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => FoodChatbotDialog.show(context),
          backgroundColor: AdminTheme.primaryWood,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
          label: Text(
            locale == 'vi' ? 'Hỏi AI Món Ăn' : 'Ask AI Food',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AdminTheme.primaryWood,
          elevation: 0,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminTheme.lightWoodCream,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.meeting_room, color: AdminTheme.primaryDarkWood, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '${l10n.room} $currentRoomNumber',
                      style: const TextStyle(
                        color: AdminTheme.primaryDarkWood,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            const LanguageSelector(),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Đăng xuất',
              onPressed: () async {
                await supabase.auth.signOut();
                if (context.mounted) context.go('/login');
              },
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;

            Widget menuContent = Column(
              children: [
                _buildQrSessionBanner(),
                _buildSearchBar(l10n),
                if (isMobile) _buildTopCategoryChips(categoriesAsync.value, l10n, locale),
                _buildTagFilterBar(tagsAsync, activeFilters, locale),
                _buildAISuggestionBar(),
                Expanded(
                  child: menuWithTagsAsync.when(
                    data: (items) {
                      final allTags = tagsAsync.value ?? [];

                      var list = items.where((i) => i.isAvailable).toList();

                      if (searchQuery.isNotEmpty) {
                        final normalizedQuery = L10nUtils.removeDiacritics(searchQuery);
                        list = list.where((item) {
                          final name = L10nUtils.removeDiacritics(item.getName(locale).toLowerCase());
                          final desc = L10nUtils.removeDiacritics(item.getDescription(locale).toLowerCase());
                          return name.contains(normalizedQuery) || desc.contains(normalizedQuery);
                        }).toList();
                      }

                      if (_selectedCategoryId != null) {
                        list = list.where((i) => i.categoryId == _selectedCategoryId).toList();
                      }

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
                        return Center(
                          child: Text(
                            l10n.emptyCart,
                            style: const TextStyle(color: AdminTheme.textMutedWood, fontSize: 15),
                          ),
                        );
                      }

                      final crossCount = isMobile
                          ? (constraints.maxWidth < 420 ? 1 : 2)
                          : (constraints.maxWidth < 1100 ? 2 : 3);

                      return GridView.builder(
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossCount,
                          childAspectRatio: isMobile ? 0.82 : 0.78,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: list.length,
                        itemBuilder: (c, idx) => _buildDishCard(list[idx], activeFilters, allTags, l10n),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('${l10n.loadMenuError}: $e')),
                  ),
                ),
              ],
            );

            if (isMobile) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: cart.isNotEmpty ? 70.0 : 0),
                      child: menuContent,
                    ),
                  ),
                  if (cart.isNotEmpty)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.primaryWood,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        onPressed: () => _openCartBottomSheet(context, currentRoomNumber),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                                const SizedBox(width: 10),
                                Text(
                                  '${l10n.cart} (${cart.fold(0, (sum, i) => sum + i.quantity)})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            Text(
                              '${NumberFormat('#,###', 'vi_VN').format(cartTotal)} VND',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminTheme.lightWoodCream),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            }

            return Row(
              children: [
                NavigationRail(
                  backgroundColor: AdminTheme.surfaceWhite,
                  selectedIndex: _getSelectedIndex(categoriesAsync.value),
                  onDestinationSelected: (idx) {
                    if (idx == 0) {
                      setState(() => _selectedCategoryId = null);
                    } else {
                      setState(() => _selectedCategoryId = categoriesAsync.value![idx - 1].id);
                    }
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.menu_book),
                      selectedIcon: const Icon(Icons.menu_book, color: AdminTheme.primaryWood),
                      label: Text(l10n.all),
                    ),
                    ...categoriesAsync.maybeWhen(
                      data: (cats) => cats.map((c) => NavigationRailDestination(
                        icon: const Icon(Icons.restaurant_menu),
                        selectedIcon: const Icon(Icons.restaurant_menu, color: AdminTheme.primaryWood),
                        label: Text(c.getName(locale), textAlign: TextAlign.center),
                      )).toList(),
                      orElse: () => [],
                    ),
                  ],
                ),
                Expanded(child: menuContent),
                CartAndTrackingPanel(roomNumber: currentRoomNumber, isMobile: false),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openCartBottomSheet(BuildContext context, String roomNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AdminTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AdminTheme.borderWood, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(child: CartAndTrackingPanel(roomNumber: roomNumber, isMobile: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCategoryChips(List<CategoryModel>? cats, AppDictionary l10n, String locale) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AdminTheme.surfaceWhite,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(l10n.all),
                selected: _selectedCategoryId == null,
                selectedColor: AdminTheme.primaryWood,
                labelStyle: TextStyle(
                  color: _selectedCategoryId == null ? Colors.white : AdminTheme.textDarkWood,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(() => _selectedCategoryId = null),
              ),
            ),
            if (cats != null)
              ...cats.map((c) {
                final isSelected = _selectedCategoryId == c.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c.getName(locale)),
                    selected: isSelected,
                    selectedColor: AdminTheme.primaryWood,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AdminTheme.textDarkWood,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    onSelected: (_) => setState(() => _selectedCategoryId = c.id),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildQrSessionBanner() {
    final activeQr = ref.watch(activeRoomQrSessionProvider);
    if (activeQr == null || activeQr.roomNumber != widget.roomNumber) {
      return const SizedBox();
    }

    final remaining = activeQr.remainingTime;
    final minutes = remaining.inMinutes;
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    final isWarning = remaining.inMinutes < 10;
    final isExpired = activeQr.isExpired;

    if (isExpired) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFC62828)),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_off, color: Color(0xFFC62828), size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '🔴 Mã QR của phòng này đã hết hạn. Vui lòng liên hệ lễ tân để lấy mã mới.',
                style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isWarning ? const Color(0xFFFFF3E0) : AdminTheme.lightWoodCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isWarning ? const Color(0xFFE65100) : AdminTheme.borderWood),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_2, color: isWarning ? const Color(0xFFE65100) : AdminTheme.primaryWood, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Phòng ${activeQr.roomNumber} • QR tự động',
              style: TextStyle(
                color: isWarning ? const Color(0xFFE65100) : AdminTheme.textDarkWood,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isWarning ? const Color(0xFFE65100) : AdminTheme.primaryWood,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Còn $minutes:$seconds',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),
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
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminTheme.lightWoodCream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminTheme.borderWood),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AdminTheme.primaryWood, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.aiIntro, style: const TextStyle(fontSize: 12, color: AdminTheme.textDarkWood))),
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
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AdminTheme.woodTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminTheme.borderWood),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.aiSuggestion}: ${roomCtx.isApiError ? (manualPref == 'COOL' ? l10n.cool : l10n.warm) : "${roomCtx.temp.toInt()}°C"}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminTheme.primaryDarkWood),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 75,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        return GestureDetector(
                          onTap: () => _showCustomizationDialog(item.id),
                          child: Container(
                            width: 180,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: AdminTheme.surfaceWhite,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AdminTheme.borderWood),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                  child: item.imageUrl != null
                                      ? Image.network(item.imageUrl!, width: 55, height: 75, fit: BoxFit.cover)
                                      : Container(width: 55, color: AdminTheme.lightWoodCream),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(6.0),
                                    child: Text(
                                      item.getName(locale),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AdminTheme.textDarkWood),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
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
    final locale = ref.watch(localeProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      color: AdminTheme.bgWarmWhite,
      child: TextField(
        onChanged: (val) => ref.read(searchQueryProvider.notifier).update(val),
        decoration: InputDecoration(
          hintText: _animatedHint,
          prefixIcon: const Icon(Icons.search, color: AdminTheme.primaryWood),
          suffixIcon: Tooltip(
            message: locale == 'vi' ? 'Hỏi AI Gemini về thực đơn & topping' : 'Ask Gemini AI about menu & toppings',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => FoodChatbotDialog.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AdminTheme.lightWoodCream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminTheme.borderWood),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Hỏi AI',
                      style: TextStyle(
                        color: AdminTheme.primaryDarkWood,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          filled: true,
          fillColor: AdminTheme.surfaceWhite,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AdminTheme.borderWood)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AdminTheme.borderWood)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AdminTheme.primaryWood, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildTagFilterBar(AsyncValue<List<TagModel>> tagsAsync, List<String> activeFilters, String locale) {
    return const SizedBox();
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
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AdminTheme.borderWood, width: 0.8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasAllergyWarning ? null : () => _showCustomizationDialog(item.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.imageUrl != null
                      ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                      : Container(color: AdminTheme.lightWoodCream, child: const Icon(Icons.restaurant, color: AdminTheme.primaryWood, size: 36)),
                  if (hasAllergyWarning)
                    Container(
                      color: Colors.red.withValues(alpha: 0.85),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning, color: Colors.white, size: 22),
                              const SizedBox(height: 4),
                              Text(l10n.allergyWarning, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                              Text(allergyNames, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 8)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.getName(locale),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.textDarkWood),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${NumberFormat('#,###', 'vi_VN').format(item.price)} VND',
                        style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text('⏱️ ${item.prepTime}p', style: const TextStyle(fontSize: 10, color: AdminTheme.textMutedWood)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
