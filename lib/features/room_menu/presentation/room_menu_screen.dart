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
    final menuAsync = ref.watch(menuItemsStreamProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);
    final activeFilters = ref.watch(activeFiltersProvider);
    final String currentRoomNumber = widget.roomNumber!;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey[900],
        title: Text('IN-ROOM DINING - PHÒNG $currentRoomNumber', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
        actions: [
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
              const NavigationRailDestination(
                icon: Icon(Icons.menu_book), 
                selectedIcon: Icon(Icons.menu_book, color: Colors.amber),
                label: Text('Tất cả')
              ),
              ...categoriesAsync.maybeWhen(
                data: (cats) => cats.map((c) => NavigationRailDestination(
                  icon: const Icon(Icons.restaurant_menu), 
                  label: Text(c['name'], textAlign: TextAlign.center)
                )).toList(), 
                orElse: () => []
              ),
            ],
          ),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildTagFilterBar(tagsAsync, activeFilters),
                Expanded(
                  child: menuAsync.when(
                    data: (items) {
                      var list = items.where((i) => i['is_available'] == true).toList();
                      if (_selectedCategoryId != null) list = list.where((i) => i['category_id'] == _selectedCategoryId).toList();
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.75, crossAxisSpacing: 16, mainAxisSpacing: 16),
                        itemCount: list.length,
                        itemBuilder: (c, idx) => _buildDishCard(list[idx], activeFilters),
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

  int _getSelectedIndex(List? cats) {
    if (_selectedCategoryId == null || cats == null) return 0;
    final idx = cats.indexWhere((c) => c['id'] == _selectedCategoryId);
    return idx >= 0 ? idx + 1 : 0;
  }

  Widget _buildTagFilterBar(AsyncValue<List<Map<String, dynamic>>> tagsAsync, List<String> activeFilters) {
    return Container(
      height: 60, color: Colors.white,
      child: tagsAsync.maybeWhen(
        data: (tags) => ListView(
          scrollDirection: Axis.horizontal,
          children: tags.map((t) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(label: Text(t['name']), selected: activeFilters.contains(t['id']), onSelected: (_) => ref.read(activeFiltersProvider.notifier).toggle(t['id'])),
          )).toList(),
        ),
        orElse: () => const SizedBox(),
      ),
    );
  }

  void _showCustomizationDialog(Map<String, dynamic> item) {
    showDialog(context: context, builder: (context) => DishCustomizationDialog(item: item));
  }

  Widget _buildDishCard(Map<String, dynamic> item, List<String> activeFilters) {
    final itemTags = item['tag_ids'] != null ? List<String>.from(item['tag_ids']) : [];
    final hasWarning = activeFilters.any((f) => itemTags.contains(f));
    return Card(
      elevation: hasWarning ? 0 : 4,
      child: InkWell(
        onTap: hasWarning ? null : () => _showCustomizationDialog(item),
        child: Column(
          children: [
            Expanded(child: Stack(fit: StackFit.expand, children: [
              if (item['image_url'] != null) Image.network(item['image_url'], fit: BoxFit.cover) else Container(color: Colors.grey[200]),
              if (hasWarning) Container(color: Colors.red.withOpacity(0.6), child: const Center(child: Text('CẢNH BÁO DỊ QUY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            ])),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${NumberFormat('#,###', 'vi_VN').format(num.tryParse(item['price'].toString()) ?? 0)} VND', 
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)
                ),
              ]),
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
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: Text('Món ăn này không có tùy chọn thêm.\nBạn có thể nhập ghi chú ở dưới.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...groups.map((group) => _buildModifierGroup(group)),
                        const SizedBox(height: 20),
                        const Text('GHI CHÚ ĐẶC BIỆT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _noteController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'VD: Không lấy hành, ít cay...',
                            filled: true, fillColor: Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(60), child: CircularProgressIndicator())),
                error: (e, s) => Center(child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text('Lỗi tải tùy chọn: $e\n\nVui lòng kiểm tra lại cấu hình Database.'),
                )),
              ),
            ),

            // Footer với Nút Thêm vào giỏ (Có Validation)
            modifiersAsync.maybeWhen(
              data: (groups) => _buildFooter(_isSelectionValid(groups)),
              orElse: () => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModifierGroup(Map<String, dynamic> group) {
    final List modifiers = group['modifiers'] ?? [];
    final int min = group['min_select'] ?? 0;
    final int max = group['max_select'] ?? 1;
    final bool isRequired = min > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(group['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (isRequired) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
              child: const Text('BẮT BUỘC', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Text('Chọn ${min == max ? min : '$min đến $max'} lựa chọn', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 10),
        
        if (modifiers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(' (Chưa có lựa chọn nào trong nhóm này)', style: TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic)),
          ),

        ...modifiers.map((m) {
          final isSelected = _selectedModifiers.any((sm) => sm.modifierId == m['id']);
          final price = num.tryParse(m['price'].toString())?.toDouble() ?? 0.0;

          if (max == 1) {
            // Radio Button Style
            return RadioListTile<String>(
              value: m['id'],
              groupValue: isSelected ? m['id'] : null,
              title: Text(m['name']),
              secondary: Text(
                price > 0 ? '+${NumberFormat('#,###', 'vi_VN').format(price)} VND' : 'Miễn phí', 
                style: TextStyle(color: price > 0 ? Colors.green : Colors.grey, fontWeight: price > 0 ? FontWeight.bold : FontWeight.normal)
              ),
              onChanged: (val) => setState(() {
                _selectedModifiers.removeWhere((sm) => sm.groupId == group['id']);
                _selectedModifiers.add(SelectedModifier(groupId: group['id'], groupName: group['name'], modifierId: m['id'], modifierName: m['name'], price: price));
              }),
            );
          } else {
            // Checkbox Style
            return CheckboxListTile(
              value: isSelected,
              title: Text(m['name']),
              subtitle: Text(
                price > 0 ? '+${NumberFormat('#,###', 'vi_VN').format(price)} VND' : 'Miễn phí', 
                style: TextStyle(color: price > 0 ? Colors.green : Colors.grey, fontWeight: price > 0 ? FontWeight.bold : FontWeight.normal)
              ),
              onChanged: (val) => setState(() {
                if (val!) {
                  if (_selectedModifiers.where((sm) => sm.groupId == group['id']).length < max) {
                    _selectedModifiers.add(SelectedModifier(groupId: group['id'], groupName: group['name'], modifierId: m['id'], modifierName: m['name'], price: price));
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
            child: Text(widget.item['name'], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isValid) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TỔNG CỘNG', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
              child: Text(isValid ? 'THÊM VÀO GIỎ' : 'VUI LÒNG CHỌN ĐỦ', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}
