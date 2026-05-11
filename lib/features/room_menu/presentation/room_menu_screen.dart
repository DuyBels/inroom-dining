import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inroom_dining/features/room_menu/presentation/widgets/cart_and_tracking_panel.dart';
import '../../../main.dart'; // import supabase global
import '../../admin_panel/providers/category_provider.dart';
import '../../admin_panel/providers/menu_provider.dart';
import '../../admin_panel/providers/tag_provider.dart';
import '../providers/room_menu_provider.dart';

class RoomMenuScreen extends ConsumerStatefulWidget {
  const RoomMenuScreen({super.key});

  @override
  ConsumerState<RoomMenuScreen> createState() => _RoomMenuScreenState();
}

class _RoomMenuScreenState extends ConsumerState<RoomMenuScreen> {
  // Biến lưu trữ Danh mục đang được chọn (null = Xem tất cả)
  String? _selectedCategoryId;

  // ==========================================
  // HÀM XỬ LÝ ĐẶT MÓN (CHECKOUT)
  // ==========================================
  Future<void> _submitOrder(String roomNumber) async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    // Hiện vòng xoay loading chờ xử lý
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator())
    );

    try {
      // 1. Tạo Đơn hàng tổng vào bảng `orders`
      final orderResponse = await supabase.from('orders').insert({
        'room_number': roomNumber,
        'status': 'PENDING'
      }).select('id').single();

      final orderId = orderResponse['id'];

      // 2. Tạo danh sách các món ăn chi tiết (Phiếu in bếp - tickets)
      final List<Map<String, dynamic>> ticketsToInsert = cart.map((cartItem) {
        return {
          'order_id': orderId,
          'item_id': cartItem.menuItem['id'],
          'station_id': cartItem.menuItem['station_id'],
          'quantity': cartItem.quantity,
          'notes': cartItem.notes,
          'status': 'PENDING',
        };
      }).toList();

      // Đẩy toàn bộ danh sách phiếu xuống Bếp trong 1 lần gọi API
      await supabase.from('tickets').insert(ticketsToInsert);

      // 3. Xóa sạch giỏ hàng trên máy tính bảng
      ref.read(cartProvider.notifier).clearCart();

      // 4. Đóng loading và báo thành công
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi yêu cầu xuống Bếp thành công!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi đặt hàng: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe dữ liệu từ các Providers
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final menuAsync = ref.watch(menuItemsStreamProvider);
    final tagsAsync = ref.watch(tagsStreamProvider);
    final activeFilters = ref.watch(activeFiltersProvider);

    // Ở bản thực tế, lấy roomNumber từ thông tin đăng nhập của Tablet, ở đây mình giả lập phòng '101'
    const String currentRoomNumber = '101';

    return Scaffold(
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
            // Logic tạo danh sách danh mục
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
            // Xác định vị trí đang chọn
            selectedIndex: _getCategorySelectedIndex(categoriesAsync.value),
            onDestinationSelected: (idx) {
              setState(() {
                if (idx == 0) {
                  _selectedCategoryId = null; // Chọn Tất cả
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
                // Thanh BỘ LỌC THẺ (Dị ứng, khẩu vị...)
                _buildTagFilterBar(tagsAsync, activeFilters),

                // LƯỚI MÓN ĂN
                Expanded(
                  child: menuAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Lỗi: $e')),
                    data: (items) {
                      // Lọc món ăn theo Danh mục
                      var filteredItems = items;
                      if (_selectedCategoryId != null) {
                        filteredItems = filteredItems.where((item) => item['category_id'] == _selectedCategoryId).toList();
                      }

                      // Lọc các món đang mở bán
                      filteredItems = filteredItems.where((item) => item['is_available'] == true).toList();

                      if (filteredItems.isEmpty) return const Center(child: Text('Không có món ăn nào.', style: TextStyle(fontSize: 18, color: Colors.grey)));

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, // 3 cột
                          childAspectRatio: 0.75, // Tỉ lệ chiều cao/rộng của thẻ món ăn
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
          // 3. RIGHT PANEL: GIỎ HÀNG & THEO DÕI ĐƠN (BÊN PHẢI)
          // ==========================================
          CartAndTrackingPanel(roomNumber: currentRoomNumber),
        ],
      ),
    );
  }

  // --- CÁC HÀM XÂY DỰNG GIAO DIỆN PHỤ ---

  // Lấy vị trí Index cho thanh Sidebar
  int _getCategorySelectedIndex(List<Map<String, dynamic>>? categories) {
    if (_selectedCategoryId == null || categories == null) return 0;
    final index = categories.indexWhere((c) => c['id'].toString() == _selectedCategoryId);
    return index >= 0 ? index + 1 : 0;
  }

  // Thanh bộ lọc thẻ phía trên
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
                // Chỉ lấy các thẻ loại ALLERGY (Dị ứng) hoặc TASTE (Khẩu vị) cho khách chọn
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

  // Thẻ Món Ăn
  Widget _buildDishCard(Map<String, dynamic> item, List<String> activeFilters) {
    // LOGIC CẢNH BÁO DỊ ỨNG THÔNG MINH
    // Kiểm tra xem món ăn này có chứa bất kỳ thẻ nào mà khách hàng đang đánh dấu (filter) hay không
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
                // Lớp mờ cảnh báo đỏ nếu trúng dị ứng
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
                    // Khóa nút Thêm nếu món ăn có cảnh báo
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

  // Cột Bên Phải (Giỏ hàng & Theo dõi đơn)
  Widget _buildRightPanel(String roomNumber) {
    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final roomOrdersAsync = ref.watch(roomOrdersStreamProvider);
    final menuAsync = ref.watch(menuItemsStreamProvider); // Để đối chiếu ID lấy tên món

    return Container(
      width: 350,
      color: Colors.grey[50],
      child: Column(
        children: [
          // --- HALF 1: GIỎ HÀNG ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: const Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.blue),
                SizedBox(width: 8),
                Text('Giỏ hàng của bạn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: cart.isEmpty
                ? const Center(child: Text('Chưa chọn món nào', style: TextStyle(color: Colors.grey, fontSize: 16)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final cItem = cart[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cItem.menuItem['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${cItem.menuItem['price']} đ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => ref.read(cartProvider.notifier).updateQuantity(cItem.menuItem['id'], -1),
                            ),
                            Text('${cItem.quantity}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              onPressed: () => ref.read(cartProvider.notifier).updateQuantity(cItem.menuItem['id'], 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // --- KHU VỰC THANH TOÁN ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng cộng:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$cartTotal đ', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: cart.isEmpty ? null : () => _submitOrder(roomNumber),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('GỬI YÊU CẦU XUỐNG BẾP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),

          const Divider(thickness: 4, height: 4, color: Colors.black12),

          // --- HALF 2: THEO DÕI ĐƠN HÀNG (WEBSOCKET REALTIME) ---
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.amber[50],
            child: const Row(
              children: [
                Icon(Icons.room_service, color: Colors.amber),
                SizedBox(width: 8),
                Text('Trạng thái Bếp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.amber[50],
              child: roomOrdersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Lỗi realtime: $e')),
                data: (tickets) {
                  if (tickets.isEmpty) return const Center(child: Text('Chưa có món nào đang nấu', style: TextStyle(color: Colors.grey)));

                  return ListView.builder(
                    itemCount: tickets.length,
                    itemBuilder: (context, idx) {
                      final ticket = tickets[idx];

                      // Đối chiếu để lấy Tên món từ ID món ăn
                      String itemName = 'Đang tải...';
                      menuAsync.whenData((menuList) {
                        final match = menuList.where((m) => m['id'] == ticket['item_id']);
                        if (match.isNotEmpty) itemName = match.first['name'];
                      });

                      return ListTile(
                        leading: _getStatusIcon(ticket['status']),
                        title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Số lượng: ${ticket['quantity']} - ${_translateStatus(ticket['status'])}',
                            style: TextStyle(color: ticket['status'] == 'DONE' ? Colors.green : Colors.orange, fontWeight: FontWeight.w500)
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helpers cho phần Realtime Tracking ---
  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING': return const Icon(Icons.access_time_filled, color: Colors.grey, size: 32);
      case 'COOKING': return const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.orange));
      case 'DONE': return const Icon(Icons.check_circle, color: Colors.green, size: 32);
      default: return const Icon(Icons.help_outline, size: 32);
    }
  }

  String _translateStatus(String status) {
    switch (status) {
      case 'PENDING': return 'Đang chờ bếp nhận';
      case 'COOKING': return 'Đang nấu...';
      case 'DONE': return 'Hoàn tất, đang mang lên!';
      default: return status;
    }
  }
}