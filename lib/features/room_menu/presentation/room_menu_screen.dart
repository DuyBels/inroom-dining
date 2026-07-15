import '../providers/ai_recommendation_provider.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/utils/l10n_utils.dart';
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

    // LẮNG NGHE LỖI API (Bỏ Popup tự động theo yêu cầu user)
    ref.listen<AsyncValue<RoomContext>>(roomContextProvider, (prev, next) {
      // Không làm gì cả, Logic sẽ hiển thị Inline trong _buildAISuggestionBar
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
    final String currentRoomNumber = widget.roomNumber!;
    final l10n = ref.watch(l10nProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey[900],
        title: Text('${l10n.room} $currentRoomNumber', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        actions: [
          // Nút Đổi Ngôn Ngữ
          TextButton(
            onPressed: () => ref.read(localeProvider.notifier).toggleLanguage(),
            child: Text(
              ref.watch(localeProvider) == 'vi' ? 'EN 🇺🇸' : 'VI 🇻🇳',
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
              else setState(() => _selectedCategoryId = categoriesAsync.value![idx - 1]['id']);
            },
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.menu_book), 
                selectedIcon: const Icon(Icons.menu_book, color: Colors.amber),
                label: Text(l10n.all)
              ),
              ...categoriesAsync.maybeWhen(
                data: (cats) {
                  final locale = ref.watch(localeProvider);
                  return cats.map((c) {
                    final String catName = L10nUtils.getL10n(c['name'], locale);
                    return NavigationRailDestination(
                      icon: const Icon(Icons.restaurant_menu), 
                      label: Text(catName, textAlign: TextAlign.center)
                    );
                  }).toList();
                }, 
                orElse: () => []
              ),
            ],
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildTagFilterBar(tagsAsync, activeFilters),
                _buildAISuggestionBar(), // Thêm dòng này
                Expanded(
                  child: menuWithTagsAsync.when(
                    data: (items) {
                      // 1. Lọc theo trạng thái khả dụng
                      var list = items.where((i) => i['is_available'] == true).toList();
                      
                      // 2. Lọc theo Danh mục
                      if (_selectedCategoryId != null) {
                        list = list.where((i) => i['category_id'] == _selectedCategoryId).toList();
                      }

                      // 3. Lọc theo Thẻ (CHỈ ÁP DỤNG LỌC CHO CÁC THẺ KHÔNG PHẢI DỊ ỨNG)
                      // Thẻ Dị ứng sẽ dùng để hiện Warning chứ không ẩn món ăn.
                      final allTags = tagsAsync.value ?? [];
                      final selectedPrefTagIds = activeFilters.where((id) {
                        final tag = allTags.firstWhere((t) => t['id'] == id, orElse: () => {});
                        return tag.isNotEmpty && tag['tag_type'] != 'ALLERGY';
                      }).toList();

                      if (selectedPrefTagIds.isNotEmpty) {
                        list = list.where((item) {
                          final itemTagIds = (item['tag_ids'] as List? ?? []);
                          // Món ăn phải có ít nhất 1 trong các thẻ Preference đang chọn
                          return selectedPrefTagIds.any((selectedId) => itemTagIds.contains(selectedId));
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

    return contextAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('AI đang tìm món ngon cho bạn...')
            ],
          ),
        ),
      ),
      error: (e, s) => const SizedBox(),
      data: (roomCtx) {
        // TRƯỜNG HỢP: API Lỗi và khách chưa chọn tâm trạng -> Hiện câu hỏi nhỏ
        if (roomCtx.isApiError && manualPref == null) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blueGrey[100]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.blueGrey, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.aiIntro,
                    style: const TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => ref.read(userManualPreferenceProvider.notifier).update('COOL'),
                  icon: const Text('❄️'),
                  label: Text(l10n.cool),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => ref.read(userManualPreferenceProvider.notifier).update('WARM'),
                  icon: const Text('🔥'),
                  label: Text(l10n.warm),
                  style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
                ),
              ],
            ),
          );
        }

        // TRƯỜNG HỢP: Đã có dữ liệu (từ API hoặc từ manual chọn)
        return aiItemsAsync.when(
          loading: () => const SizedBox(),
          error: (e, s) => const SizedBox(),
          data: (items) {
            if (items.isEmpty) return const SizedBox();

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.amber[50]!, Colors.white]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.aiSuggestion}: ${roomCtx.isApiError ? (manualPref == 'COOL' ? l10n.cool : l10n.warm) : (roomCtx.temp.toInt().toString() + "°C")}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.brown),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        final locale = ref.watch(localeProvider);
                        final String displayName = L10nUtils.getL10n(item['name'], locale);

                        return GestureDetector(
                          onTap: () => _showCustomizationDialog(item),
                          child: Container(
                            width: 250,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                  child: item['image_url'] != null
                                      ? Image.network(item['image_url'], width: 80, height: 100, fit: BoxFit.cover)
                                      : Container(width: 80, color: Colors.grey[200]),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        Text('${NumberFormat('#,###', 'vi_VN').format(item['price'])} VND', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
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

  int _getSelectedIndex(List? cats) {
    if (_selectedCategoryId == null || cats == null) return 0;
    final idx = cats.indexWhere((c) => c['id'] == _selectedCategoryId);
    return idx >= 0 ? idx + 1 : 0;
  }

  Widget _buildTagFilterBar(AsyncValue<List<Map<String, dynamic>>> tagsAsync, List<String> activeFilters) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: tagsAsync.maybeWhen(
        data: (tags) {
          if (tags.isEmpty) return const SizedBox();

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: tags.map((t) {
                final isSelected = activeFilters.contains(t['id']);
                final type = t['tag_type'] ?? '';
                final locale = ref.watch(localeProvider);
                final String tagName = L10nUtils.getL10n(t['name'], locale);
                
                IconData icon;
                Color color;
                switch (type) {
                  case 'ALLERGY': icon = Icons.warning_amber_rounded; color = Colors.red; break;
                  case 'WEATHER': icon = Icons.cloud_outlined; color = Colors.blue; break;
                  case 'TIME': icon = Icons.access_time; color = Colors.green; break;
                  case 'TASTE': icon = Icons.restaurant; color = Colors.orange; break;
                  default: icon = Icons.label_outline; color = Colors.grey;
                }

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : color),
                    label: Text(tagName),
                    selected: isSelected,
                    selectedColor: color,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (_) => ref.read(activeFiltersProvider.notifier).toggle(t['id']),
                  ),
                );
              }).toList(),
            ),
          );
        },
        orElse: () => const SizedBox(height: 60),
      ),
    );
  }

  void _showCustomizationDialog(Map<String, dynamic> item) {
    showDialog(context: context, builder: (context) => DishCustomizationDialog(item: item));
  }

  Widget _buildDishCard(Map<String, dynamic> item, List<String> activeFilters, List<Map<String, dynamic>> allTags, AppDictionary l10n) {
    final itemTagIds = (item['tag_ids'] as List? ?? []).cast<String>();
    final locale = ref.watch(localeProvider);
    final String displayName = L10nUtils.getL10n(item['name'], locale);
    
    // Tìm các thẻ Dị ứng đang kích hoạt mà món này có
    final activeAllergyTagIds = activeFilters.where((id) {
      final tag = allTags.firstWhere((t) => t['id'] == id, orElse: () => {});
      return tag.isNotEmpty && tag['tag_type'] == 'ALLERGY';
    }).toList();

    final hasAllergyWarning = activeAllergyTagIds.any((id) => itemTagIds.contains(id));
    
    // Lấy tên các loại dị ứng bị dính để hiện thông báo
    String allergyNames = "";
    if (hasAllergyWarning) {
      allergyNames = allTags
          .where((t) => activeAllergyTagIds.contains(t['id']) && itemTagIds.contains(t['id']))
          .map((t) => t['name'])
          .join(', ');
    }

    return Card(
      elevation: hasAllergyWarning ? 0 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: hasAllergyWarning ? null : () => _showCustomizationDialog(item),
        child: Column(
          children: [
            Expanded(child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: item['image_url'] != null 
                    ? Image.network(item['image_url'], fit: BoxFit.cover) 
                    : Container(color: Colors.grey[200], child: const Icon(Icons.restaurant, color: Colors.white, size: 40)),
              ),
              if (hasAllergyWarning) 
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            l10n.allergyWarning, 
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)
                          ),
                          Text(
                            allergyNames,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 10)
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ])),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${NumberFormat('#,###', 'vi_VN').format(num.tryParse(item['price'].toString()) ?? 0)} VND', 
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)
                      ),
                      Text(
                        '⏱️ ${item['prep_time_minutes'] ?? 15}p',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      ),
                    ],
                  ),
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
  final Map<String, dynamic> item;
  const DishCustomizationDialog({super.key, required this.item});
  @override
  ConsumerState<DishCustomizationDialog> createState() => _DishCustomizationDialogState();
}

class _DishCustomizationDialogState extends ConsumerState<DishCustomizationDialog> {
  final List<SelectedModifier> _selectedModifiers = [];
  final _noteController = TextEditingController();

  double get _basePrice => num.tryParse(widget.item['price'].toString())?.toDouble() ?? 0.0;
  double get _modifiersPrice => _selectedModifiers.fold(0.0, (sum, m) => sum + m.price);
  double get _totalPrice => _basePrice + _modifiersPrice;

  // Kiểm tra xem đã chọn đủ số lượng tối thiểu cho TẤT CẢ các nhóm chưa
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
    final modifiersAsync = ref.watch(itemModifiersProvider(widget.item['id']));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 650,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Image (Thêm nút đóng)
            Stack(
              children: [
                _buildHeader(),
                Positioned(
                  top: 10, right: 10,
                  child: CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
            
            Flexible(
              child: modifiersAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(child: Text(l10n.noOptions, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...groups.map((group) => _buildModifierGroup(group, l10n)),
                        const SizedBox(height: 20),
                        Text(l10n.specialNotes, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: ref.watch(localeProvider) == 'vi' ? 'VD: Không lấy hành, ít cay...' : 'Ex: No onions, less spicy...',
                            filled: true, fillColor: Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => Center(child: Padding(padding: const EdgeInsets.all(60), child: Text(ref.watch(l10nProvider).loadingOptions))),
                error: (e, s) => Center(child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(ref.watch(l10nProvider).errorLoading),
                )),
              ),
            ),

            // Footer với Nút Thêm vào giỏ (Có Validation)
            modifiersAsync.maybeWhen(
              data: (groups) => _buildFooter(_isSelectionValid(groups), l10n),
              orElse: () => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModifierGroup(Map<String, dynamic> group, AppDictionary l10n) {
    final List modifiers = group['modifiers'] ?? [];
    final int min = group['min_select'] ?? 0;
    final int max = group['max_select'] ?? 1;
    final bool isRequired = min > 0;
    final locale = ref.watch(localeProvider);

    final String groupName = L10nUtils.getL10n(group['name'], locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(groupName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (isRequired) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
              child: Text(l10n.requiredLabel, style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Text(
          locale == 'vi' 
            ? 'Chọn ${min == max ? min : '$min đến $max'} lựa chọn'
            : 'Select ${min == max ? min : '$min to $max'} options', 
          style: TextStyle(fontSize: 12, color: Colors.grey[600])
        ),
        const SizedBox(height: 10),
        
        if (modifiers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('...', style: TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic)),
          ),

        ...modifiers.map((m) {
          final isSelected = _selectedModifiers.any((sm) => sm.modifierId == m['id']);
          final price = num.tryParse(m['price'].toString())?.toDouble() ?? 0.0;
          final String modName = L10nUtils.getL10n(m['name'], locale);

          if (max == 1) {
            // Radio Button Style
            return RadioListTile<String>(
              value: m['id'],
              groupValue: isSelected ? m['id'] : null,
              title: Text(L10nUtils.getL10n(m['name'], locale)),
              secondary: price > 0 
                ? Text(
                    '+${NumberFormat('#,###', 'vi_VN').format(price)} VND', 
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                  )
                : null,
              onChanged: (val) => setState(() {
                _selectedModifiers.removeWhere((sm) => sm.groupId == group['id']);
                _selectedModifiers.add(SelectedModifier(groupId: group['id'], groupName: groupName, modifierId: m['id'], modifierName: L10nUtils.getL10n(m['name'], locale), price: price));
              }),
            );
          } else {
            // Checkbox Style
            return CheckboxListTile(
              value: isSelected,
              title: Text(L10nUtils.getL10n(m['name'], locale)),
              subtitle: price > 0 
                ? Text(
                    '+${NumberFormat('#,###', 'vi_VN').format(price)} VND', 
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                  )
                : null,
              onChanged: (val) => setState(() {
                if (val!) {
                  if (_selectedModifiers.where((sm) => sm.groupId == group['id']).length < max) {
                    _selectedModifiers.add(SelectedModifier(groupId: group['id'], groupName: groupName, modifierId: m['id'], modifierName: L10nUtils.getL10n(m['name'], locale), price: price));
                  }
                } else {
                  _selectedModifiers.removeWhere((sm) => sm.modifierId == m['id']);
                }
              }),
            );
          }
        }).toList(),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildHeader() {
    final l10n = ref.watch(l10nProvider);
    final locale = ref.watch(localeProvider);
    final String displayName = L10nUtils.getL10n(widget.item['name'], locale);

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: widget.item['image_url'] != null 
              ? Image.network(widget.item['image_url'], height: 180, width: double.infinity, fit: BoxFit.cover)
              : Container(height: 100, color: Colors.amber),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])),
            child: Text(displayName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isValid, AppDictionary l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.total, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(
                '${NumberFormat('#,###', 'vi_VN').format(_totalPrice)} VND', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber[900])
              ),
            ]),
          ),
          SizedBox(
            height: 50, width: 220,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isValid ? Colors.amber[800] : Colors.grey[300],
                foregroundColor: isValid ? Colors.white : Colors.grey[600],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: isValid ? 2 : 0,
              ),
              onPressed: isValid ? () {
                ref.read(cartProvider.notifier).addToCart(widget.item, _selectedModifiers, _noteController.text);
                Navigator.pop(context);
              } : null,
              child: Text(isValid ? l10n.cart.toUpperCase() : l10n.selectFullLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
