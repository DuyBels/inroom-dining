import 'package:flutter_riverpod/flutter_riverpod.dart';
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
// 2. NOTIFIER QUẢN LÝ GIỎ HÀNG (Modern Riverpod 3.x)
// ==========================================
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void addToCart(Map<String, dynamic> item) {
    final existingIndex = state.indexWhere((c) => c.menuItem['id'] == item['id']);
    if (existingIndex >= 0) {
      final newState = [...state];
      newState[existingIndex] = CartItem(
        menuItem: state[existingIndex].menuItem,
        quantity: state[existingIndex].quantity + 1,
        notes: state[existingIndex].notes,
      );
      state = newState;
    } else {
      state = [...state, CartItem(menuItem: item)];
    }
  }

  void updateQuantity(String itemId, int delta) {
    final index = state.indexWhere((c) => c.menuItem['id'] == itemId);
    if (index >= 0) {
      final newState = [...state];
      final newQuantity = newState[index].quantity + delta;
      if (newQuantity <= 0) {
        newState.removeAt(index);
      } else {
        newState[index] = CartItem(
          menuItem: newState[index].menuItem,
          quantity: newQuantity,
          notes: newState[index].notes,
        );
      }
      state = newState;
    }
  }

  void clearCart() => state = [];
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) {
    final price = num.tryParse(item.menuItem['price'].toString())?.toDouble() ?? 0.0;
    return sum + (price * item.quantity);
  });
});

// ==========================================
// 3. QUẢN LÝ BỘ LỌC THẺ
// ==========================================
class ActiveFiltersNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void toggle(String tagId) {
    if (state.contains(tagId)) {
      state = state.where((id) => id != tagId).toList();
    } else {
      state = [...state, tagId];
    }
  }
}

final activeFiltersProvider = NotifierProvider<ActiveFiltersNotifier, List<String>>(ActiveFiltersNotifier.new);

// ==========================================
// 4. WEBSOCKET - THEO DÕI TRẠNG THÁI RIÊNG TỪNG PHÒNG
// ==========================================

// Stream lấy toàn bộ tickets (Realtime)
final allTicketsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('tickets')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);
});

// Stream lấy orders của phòng hiện tại (Realtime)
final roomOrdersStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomNumber) {
  return supabase
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('room_number', roomNumber)
      .order('created_at', ascending: false);
});

// Provider tổng hợp: CHỈ LẤY TICKETS THUỘC VỀ PHÒNG HIỆN TẠI
final activeRoomTicketsProvider = Provider.family<List<Map<String, dynamic>>, String>((ref, roomNumber) {
  final allTicketsAsync = ref.watch(allTicketsStreamProvider);
  final roomOrdersAsync = ref.watch(roomOrdersStreamProvider(roomNumber));

  if (allTicketsAsync.value == null || roomOrdersAsync.value == null) return [];

  final allTickets = allTicketsAsync.value!;
  final roomOrders = roomOrdersAsync.value!;
  
  // Tạo bộ lọc IDs của các đơn hàng thuộc phòng này
  final myOrderIds = roomOrders.map((o) => o['id']).toSet();

  // Trả về các tickets có order_id nằm trong danh sách đơn hàng của phòng
  return allTickets.where((t) => myOrderIds.contains(t['order_id'])).toList();
});
