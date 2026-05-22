import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // Import go_router để chuyển trang
import 'package:inroom_dining/features/room_menu/presentation/widgets/cart_and_tracking_panel.dart';
import '../../../main.dart'; // import supabase global
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
  // Biến lưu trữ Danh mục đang được chọn (null = Xem tất cả)
  String? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final roomNumber = widget.roomNumber;
    final profileAsync = ref.watch(userProfileProvider);

    // 1. Kiểm tra trạng thái Redirect (Nếu chưa có roomNumber trên URL)
    if (roomNumber == null) {
      return profileAsync.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, s) => Scaffold(body: Center(child: Text('Lỗi: $e'))),
        data: (profile) {
          if (profile != null && (profile['role'] == 'ROOM' || profile['role'] == 'ADMIN')) {
            final rNum = profile['room_number'] ?? 'unknown';
            Future.microtask(() => context.go('/menu/$rNum'));
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return const Scaffold(
            body: Center(
              child: Text('Tài khoản không có quyền truy cập hoặc không tìm thấy số phòng.'),
            ),
          );
        },
      );
    }

    // Lắng nghe dữ liệu từ các Providers
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final menuAsync = ref.watch(menuItemsStreamProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);
    final activeFilters = ref.watch(activeFiltersProvider);

    // Lấy roomNumber từ URL hoặc dự phòng từ Profile
    final String currentRoomNumber = widget.roomNumber ?? '...';

    return Scaffold(
      // ==========================================
      // THÊM APPBAR: HIỂN THỊ PHÒNG VÀ NÚT ĐĂNG XUẤT
      // ==========================================
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: Text(
            'IN-ROOM DINING - PHÒNG $currentRoomNumber',
            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, letterSpacing: 1.2)
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            tooltip: 'Đăng xuất Tablet',
            onPressed: () {
              // Hiển thị hộp thoại xác nhận trước khi đăng xuất
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Xác nhận đăng xuất'),
                  content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi Tablet của phòng này không? Giỏ hàng chưa đặt sẽ bị xóa.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        Navigator.pop(ctx); // Đóng popup
                        await supabase.auth.signOut(); // Đăng xuất khỏi Supabase

                        // Xóa giỏ hàng tạm (để an toàn nếu đăng nhập lại)
                        ref.read(cartProvider.notifier).clearCart();

                        if (context.mounted) {
                          context.go('/login'); // Chuyển về màn hình đăng nhập
                        }
                      },
                      child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // ==========================================
          // 1. SIDEBAR: CHỌN DANH MỤC (BÊN TRÁI)
          // ==========================================
          NavigationRail(
            backgroundColor: Colors.grey[900],
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedIconTheme: const IconThemeData(color: Colors.amber),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
            selectedLabelTextStyle: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
            labelType: NavigationRailLabelType.all,
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.menu_book),
                label: Text('Tất cả'),
              ),
              ...categoriesAsync.maybeWhen(
                data: (cats) => cats.map((c) => NavigationRailDestination(
                  icon: const Icon(Icons.restaurant),
                  label: Text(c['name']),
                )).toList(),
                orElse: () => [],
              )
            ],
            selectedIndex: _getCategorySelectedIndex(categoriesAsync.value),
            onDestinationSelected: (idx) {
              setState(() {
                if (idx == 0) {
                  _selectedCategoryId = null;
                } else {
                  final cats = categoriesAsync.value ?? [];
                  if (idx - 1 < cats.length) {
                    _selectedCategoryId = cats[idx - 1]['id'].toString();
                  }
                }
              });
            },
          ),

          // ==========================================
          // 2. MAIN CONTENT: LƯỚI MÓN ĂN & BỘ LỌC (GIỮA)
          // ==========================================
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Thanh BỘ LỌC THẺ
                _buildTagFilterBar(tagsAsync, activeFilters),

                // LƯỚI MÓN ĂN
                Expanded(
                  child: menuAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Lỗi: $e')),
                    data: (items) {
                      var filteredItems = items;
                      if (_selectedCategoryId != null) {
                        filteredItems = filteredItems.where((item) => item['category_id'] == _selectedCategoryId).toList();
                      }

                      filteredItems = filteredItems.where((item) => item['is_available'] == true).toList();

                      if (filteredItems.isEmpty) return const Center(child: Text('Không có món ăn nào.', style: TextStyle(fontSize: 18, color: Colors.grey)));

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, idx) => _buildDishCard(filteredItems[idx], activeFilters),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // 3. RIGHT PANEL: GIỎ HÀNG & THEO DÕI ĐƠN (Đã tách file)
          // ==========================================
          CartAndTrackingPanel(roomNumber: currentRoomNumber),
        ],
      ),
    );
  }

  // --- CÁC HÀM XÂY DỰNG GIAO DIỆN PHỤ ---

  int _getCategorySelectedIndex(List<Map<String, dynamic>>? categories) {
    if (_selectedCategoryId == null || categories == null) return 0;
    final index = categories.indexWhere((c) => c['id'].toString() == _selectedCategoryId);
    return index >= 0 ? index + 1 : 0;
  }

  Widget _buildTagFilterBar(AsyncValue<List<Map<String, dynamic>>> tagsAsync, List<String> activeFilters) {
    return Container(
      height: 70,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.filter_alt, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('Bộ lọc của bạn:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(
            child: tagsAsync.maybeWhen(
              data: (tags) {
                final filterableTags = tags.where((t) => t['tag_type'] == 'ALLERGY' || t['tag_type'] == 'TASTE').toList();

                return ListView(
                  scrollDirection: Axis.horizontal,
                  children: filterableTags.map((tag) {
                    final tagId = tag['id'].toString();
                    final isSelected = activeFilters.contains(tagId);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tag['name']),
                        selected: isSelected,
                        selectedColor: tag['tag_type'] == 'ALLERGY' ? Colors.red[100] : Colors.amber[100],
                        checkmarkColor: tag['tag_type'] == 'ALLERGY' ? Colors.red[800] : Colors.amber[800],
                        onSelected: (_) => ref.read(activeFiltersProvider.notifier).toggle(tagId),
                      ),
                    );
                  }).toList(),
                );
              },
              orElse: () => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDishCard(Map<String, dynamic> item, List<String> activeFilters) {
    final itemTags = item['tag_ids'] != null ? List<String>.from(item['tag_ids']) : <String>[];
    final bool hasWarning = activeFilters.any((filterId) => itemTags.contains(filterId));

    return Card(
      elevation: hasWarning ? 0 : 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hasWarning ? const BorderSide(color: Colors.red, width: 2) : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: item['image_url'] != null
                      ? Image.network(item['image_url'], fit: BoxFit.cover)
                      : Container(color: Colors.grey[300], child: const Icon(Icons.restaurant, size: 50, color: Colors.grey)),
                ),
                if (hasWarning)
                  Container(
                    color: Colors.red.withOpacity(0.7),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.white, size: 40),
                          SizedBox(height: 8),
                          Text('CÓ CHỨA THÀNH PHẦN\nBẠN ĐÃ LỌC', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('${item['price'] ?? 0} đ', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: hasWarning ? null : () {
                      ref.read(cartProvider.notifier).addToCart(item);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    child: const Text('Thêm vào giỏ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}