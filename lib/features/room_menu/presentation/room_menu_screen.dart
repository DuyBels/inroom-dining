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
        backgroundColor: AdminTheme.bgExpressiveBlue,
        floatingActionButton: MediaQuery.of(context).size.width < 768
            ? FloatingActionButton(
                onPressed: () => FoodChatbotDialog.show(context),
                backgroundColor: AdminTheme.primaryBlue,
                foregroundColor: Colors.white,
                elevation: 4,
                tooltip: locale == 'vi' ? 'Hỏi AI Món Ăn' : 'Ask AI Food',
                child: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 24),
              )
            : null,
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
                          ? (constraints.maxWidth < 400 ? 1 : 2)
                          : (constraints.maxWidth < 900 ? 3 : 4);

                      final cardAspectRatio = isMobile
                          ? (constraints.maxWidth < 400 ? 1.1 : 0.78)
                          : (constraints.maxWidth < 900 ? 0.80 : 0.82);

                      return GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.all(isMobile ? 12 : 16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossCount,
                          childAspectRatio: cardAspectRatio,
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
                      padding: EdgeInsets.only(bottom: cart.isNotEmpty ? 75.0 : 0),
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
                          backgroundColor: AdminTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 6,
                          shadowColor: AdminTheme.primaryBlue.withValues(alpha: 0.35),
                        ),
                        onPressed: () => _openCartBottomSheet(context, currentRoomNumber),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  '${l10n.cart} (${cart.fold(0, (sum, i) => sum + i.quantity)})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ],
                            ),
                            Text(
                              '${NumberFormat('#,###', 'vi_VN').format(cartTotal)} VND',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminTheme.lightBlueContainer),
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
                SizedBox(
                  width: 100,
                  child: Container(
                    color: AdminTheme.surfaceWhite,
                    child: Column(
                      children: [
                        Expanded(
                          child: NavigationRail(
                            minWidth: 100,
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
                                selectedIcon: const Icon(Icons.menu_book, color: AdminTheme.primaryBlue),
                                label: Text(l10n.all),
                              ),
                              ...categoriesAsync.maybeWhen(
                                data: (cats) => cats.map((c) => NavigationRailDestination(
                                  icon: Icon(c.iconData),
                                  selectedIcon: Icon(c.iconData, color: AdminTheme.primaryBlue),
                                  label: Text(c.getName(locale), textAlign: TextAlign.center),
                                )).toList(),
                                orElse: () => [],
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20.0, top: 8.0),
                          child: InkWell(
                            onTap: () => FoodChatbotDialog.show(context),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, color: AdminTheme.primaryBlue, size: 24),
                                  const SizedBox(height: 4),
                                  Text(
                                    locale == 'vi' ? 'Hỏi AI' : 'Ask AI',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AdminTheme.primaryDarkBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
        height: MediaQuery.of(ctx).size.height * 0.90,
        decoration: const BoxDecoration(
          color: AdminTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: AdminTheme.borderBlue, borderRadius: BorderRadius.circular(3)),
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
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: const Icon(Icons.menu_book, size: 18),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                label: Text(l10n.all),
                selected: _selectedCategoryId == null,
                selectedColor: AdminTheme.primaryBlue,
                backgroundColor: AdminTheme.blueTint,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(
                  color: _selectedCategoryId == null ? AdminTheme.primaryBlue : AdminTheme.borderBlue,
                ),
                labelStyle: TextStyle(
                  color: _selectedCategoryId == null ? Colors.white : AdminTheme.textDarkBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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
                    avatar: Icon(
                      c.iconData,
                      size: 18,
                      color: isSelected ? Colors.white : AdminTheme.primaryBlue,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    label: Text(c.getName(locale)),
                    selected: isSelected,
                    selectedColor: AdminTheme.primaryBlue,
                    backgroundColor: AdminTheme.blueTint,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(
                      color: isSelected ? AdminTheme.primaryBlue : AdminTheme.borderBlue,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AdminTheme.textDarkBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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
          borderRadius: BorderRadius.circular(14),
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
        color: isWarning ? const Color(0xFFFFF3E0) : AdminTheme.lightBlueContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isWarning ? const Color(0xFFE65100) : AdminTheme.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.qr_code_2, color: isWarning ? const Color(0xFFE65100) : AdminTheme.primaryBlue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Phòng ${activeQr.roomNumber} • QR tự động',
              style: TextStyle(
                color: isWarning ? const Color(0xFFE65100) : AdminTheme.primaryDarkBlue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isWarning ? const Color(0xFFE65100) : AdminTheme.primaryBlue,
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
              color: AdminTheme.lightBlueContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminTheme.borderBlue),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AdminTheme.primaryBlue, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.aiIntro, style: const TextStyle(fontSize: 12, color: AdminTheme.textDarkBlue))),
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
                color: AdminTheme.blueTint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AdminTheme.borderBlue),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.aiSuggestion}: ${roomCtx.isApiError ? (manualPref == 'COOL' ? l10n.cool : l10n.warm) : "${roomCtx.temp.toInt()}°C"}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminTheme.primaryDarkBlue),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 78,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        return GestureDetector(
                          onTap: () => _showCustomizationDialog(item.id),
                          child: Container(
                            width: 185,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: AdminTheme.surfaceWhite,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AdminTheme.borderBlue),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                  child: item.imageUrl != null
                                      ? Image.network(item.imageUrl!, width: 60, height: 78, fit: BoxFit.cover)
                                      : Container(width: 60, color: AdminTheme.blueTint),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      item.getName(locale),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AdminTheme.textDarkBlue),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      color: AdminTheme.bgExpressiveBlue,
      child: TextField(
        onChanged: (val) => ref.read(searchQueryProvider.notifier).update(val),
        style: const TextStyle(fontSize: 14, color: AdminTheme.textDarkBlue),
        decoration: InputDecoration(
          hintText: _animatedHint,
          prefixIcon: const Icon(Icons.search, color: AdminTheme.primaryBlue, size: 22),
          filled: true,
          fillColor: AdminTheme.surfaceWhite,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: AdminTheme.borderBlue)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: AdminTheme.borderBlue)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: const BorderSide(color: AdminTheme.primaryBlue, width: 2.0)),
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

    return Container(
      decoration: BoxDecoration(
        color: AdminTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminTheme.borderBlue.withValues(alpha: 0.8), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.primaryBlue.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: AdminTheme.primaryBlue.withValues(alpha: 0.15),
        highlightColor: AdminTheme.primaryBlue.withValues(alpha: 0.08),
        onTap: hasAllergyWarning ? null : () => _showCustomizationDialog(item.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ANH FILL MAX KICH THUOC CUA CARD
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  item.imageUrl != null
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: AdminTheme.blueTint,
                          child: const Icon(Icons.restaurant, color: AdminTheme.primaryBlue, size: 40),
                        ),

                  // Black gradient overlay bottom edge for clean image readability
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.10),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.25),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Prep time chip on top left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            '${item.prepTime}p',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Quick Add Touch Button on top right (Min 44x44 Touch Target)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: hasAllergyWarning ? null : () => _showCustomizationDialog(item.id),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AdminTheme.primaryBlue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),

                  if (hasAllergyWarning)
                    Container(
                      color: Colors.red.withValues(alpha: 0.88),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
                              const SizedBox(height: 4),
                              Text(l10n.allergyWarning, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(allergyNames, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // COMPACT BOTTOM INFO CONTAINER (Thẻ nhỏ vừa phải)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.getName(locale),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AdminTheme.textDarkBlue,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${NumberFormat('#,###', 'vi_VN').format(item.price)} VND',
                        style: const TextStyle(
                          color: AdminTheme.primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
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


