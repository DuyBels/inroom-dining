import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
// ĐÃ XÓA: import 'package:flutter_riverpod/legacy.dart';
import '../../../main.dart';

// ==========================================
// 1. MODEL GIỎ HÀNG (Cart Model)
// ==========================================
class CartItem {
  final Map<String, dynamic> menuItem;
  int quantity;
  String notes;

  CartItem({
    required this.menuItem,
    this.quantity = 1,
    this.notes = ''
  });
}

// ==========================================
// 2. STATE NOTIFIER QUẢN LÝ GIỎ HÀNG
// ==========================================
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  // Thêm món vào giỏ
  void addToCart(Map<String, dynamic> item) {
    final existingIndex = state.indexWhere((c) => c.menuItem['id'] == item['id']);

    if (existingIndex >= 0) {
      final newState = [...state];
      newState[existingIndex].quantity++;
      state = newState;
    } else {
      state = [...state, CartItem(menuItem: item)];
    }
  }

  // Tăng/giảm số lượng món ăn
  void updateQuantity(String itemId, int delta) {
    final newState = [...state];
    final index = newState.indexWhere((c) => c.menuItem['id'] == itemId);

    if (index >= 0) {
      newState[index].quantity += delta;
      if (newState[index].quantity <= 0) {
        newState.removeAt(index);
      }
      state = newState;
    }
  }

  // Cập nhật ghi chú cho món ăn
  void updateNote(String itemId, String note) {
    final newState = [...state];
    final index = newState.indexWhere((c) => c.menuItem['id'] == itemId);

    if (index >= 0) {
      newState[index].notes = note;
      state = newState;
    }
  }

  // Xóa sạch giỏ hàng
  void clearCart() {
    state = [];
  }
}

// Provider cung cấp danh sách giỏ hàng
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

// Provider tự động tính toán Tổng tiền của giỏ hàng (Đã fix lỗi ép kiểu an toàn)
final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) {
    // Ép kiểu an toàn từ dữ liệu JSON của Supabase (dù là int hay string đều chuyển về double)
    final price = num.tryParse(item.menuItem['price'].toString())?.toDouble() ?? 0.0;
    return sum + (price * item.quantity);
  });
});

// ==========================================
// 3. QUẢN LÝ BỘ LỌC THẺ (Dị ứng, Khẩu vị)
// ==========================================
class ActiveFiltersNotifier extends StateNotifier<List<String>> {
  ActiveFiltersNotifier() : super([]);

  // Bật/tắt một thẻ lọc
  void toggle(String tagId) {
    if (state.contains(tagId)) {
      state = state.where((id) => id != tagId).toList();
    } else {
      state = [...state, tagId];
    }
  }

  // Xóa toàn bộ bộ lọc
  void clearFilters() {
    state = [];
  }
}

// Provider cung cấp danh sách thẻ
final activeFiltersProvider = StateNotifierProvider<ActiveFiltersNotifier, List<String>>((ref) {
  return ActiveFiltersNotifier();
});

// ==========================================
// 4. WEBSOCKET - THEO DÕI TRẠNG THÁI TỪ BẾP
// ==========================================
final roomOrdersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('tickets')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);
});