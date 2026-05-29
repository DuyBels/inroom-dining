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
                Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('${item['price']} đ', style: const TextStyle(color: Colors.green)),
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
  final List<Map<String, dynamic>> _selectedToppings = [];
  final _noteController = TextEditingController();

  double get _basePrice => num.tryParse(widget.item['price'].toString())?.toDouble() ?? 0.0;
  double get _toppingsPrice => _selectedToppings.fold(0.0, (sum, t) => sum + (num.tryParse(t['price'].toString())?.toDouble() ?? 0.0));
  double get _totalPrice => _basePrice + _toppingsPrice;

  @override
  Widget build(BuildContext context) {
    final toppingsAsync = ref.watch(menuItemToppingsProvider(widget.item['id']));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600, // Làm popup to ra
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Image & Title
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: widget.item['image_url'] != null 
                      ? Image.network(widget.item['image_url'], height: 200, width: double.infinity, fit: BoxFit.cover)
                      : Container(height: 100, color: Colors.amber),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])
                    ),
                    child: Text(widget.item['name'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                ),
                Positioned(
                  top: 10, right: 10,
                  child: CircleAvatar(backgroundColor: Colors.black26, child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))),
                )
              ],
            ),
            
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TÙY CHỌN THÊM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const Divider(),
                    toppingsAsync.when(
                      data: (list) {
                        if (list.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Không có topping cho món này.'));
                        return Column(
                          children: list.map((t) {
                            final existing = _selectedToppings.firstWhere((st) => st['id'] == t['id'], orElse: () => {});
                            final int qty = existing.isEmpty ? 0 : (existing['quantity'] ?? 0);

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(t['name']),
                              subtitle: Text('+ ${t['price']} đ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (qty > 0) IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                                    onPressed: () => setState(() {
                                      if (qty == 1) _selectedToppings.removeWhere((st) => st['id'] == t['id']);
                                      else existing['quantity'] = qty - 1;
                                    }),
                                  ),
                                  if (qty > 0) Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.orange),
                                    onPressed: () => setState(() {
                                      if (existing.isEmpty) {
                                        _selectedToppings.add({...t, 'quantity': 1});
                                      } else {
                                        existing['quantity'] = qty + 1;
                                      }
                                    }),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: LinearProgressIndicator()),
                      error: (e, s) => Text('Lỗi: $e'),
                    ),
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
              ),
            ),

            // Footer - Total & Add Button
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TỔNG CỘNG', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('${_totalPrice.toInt()} đ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber[900])),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 50, width: 200,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        ref.read(cartProvider.notifier).addToCart(widget.item, _selectedToppings, _noteController.text);
                        Navigator.pop(context);
                      },
                      child: const Text('THÊM VÀO GIỎ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
