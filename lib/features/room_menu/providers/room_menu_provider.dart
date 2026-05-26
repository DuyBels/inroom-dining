import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';

// ==========================================
// 1. MODEL GIỎ HÀNG (Bản đầy đủ Topping)
// ==========================================
class CartItem {
  final String uniqueId; // Phân biệt cùng 1 món nhưng khác topping/ghi chú
  final Map<String, dynamic> menuItem;
  int quantity;
  String notes;
  final List<Map<String, dynamic>> selectedToppings;

  CartItem({
    required this.uniqueId,
    required this.menuItem,
    this.quantity = 1,
    this.notes = '',
    this.selectedToppings = const [],
  });

  double get singlePrice {
    double basePrice = num.tryParse(menuItem['price'].toString())?.toDouble() ?? 0.0;
    double toppingsPrice = selectedToppings.fold(0.0, (sum, t) => sum + (num.tryParse(t['price'].toString())?.toDouble() ?? 0.0));
    return basePrice + toppingsPrice;
  }

  double get totalPrice => singlePrice * quantity;
}

// ==========================================
// 2. NOTIFIER QUẢN LÝ GIỎ HÀNG
// ==========================================
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void addToCart(Map<String, dynamic> item, List<Map<String, dynamic>> toppings, String notes) {
    final toppingIds = toppings.map((t) => t['id']).toList()..sort();
    final String uniqueKey = "${item['id']}_${toppingIds.join('_')}_$notes";

    final existingIndex = state.indexWhere((c) => c.uniqueId == uniqueKey);

    if (existingIndex >= 0) {
      final newState = [...state];
      newState[existingIndex] = CartItem(
        uniqueId: state[existingIndex].uniqueId,
        menuItem: state[existingIndex].menuItem,
        selectedToppings: state[existingIndex].selectedToppings,
        notes: state[existingIndex].notes,
        quantity: state[existingIndex].quantity + 1,
      );
      state = newState;
    } else {
      state = [...state, CartItem(
        uniqueId: uniqueKey,
        menuItem: item,
        selectedToppings: toppings,
        notes: notes,
      )];
    }
  }

  void updateQuantity(String uniqueId, int delta) {
    final index = state.indexWhere((c) => c.uniqueId == uniqueId);
    if (index >= 0) {
      final newState = [...state];
      final newQuantity = newState[index].quantity + delta;
      if (newQuantity <= 0) {
        newState.removeAt(index);
      } else {
        newState[index] = CartItem(
          uniqueId: newState[index].uniqueId,
          menuItem: newState[index].menuItem,
          selectedToppings: newState[index].selectedToppings,
          notes: newState[index].notes,
          quantity: newQuantity,
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
  return cart.fold(0.0, (sum, item) => sum + item.totalPrice);
});

// ==========================================
// 3. QUẢN LÝ BỘ LỌC & STREAMS
// ==========================================
class ActiveFiltersNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];
  void toggle(String tagId) {
    state = state.contains(tagId) ? state.where((id) => id != tagId).toList() : [...state, tagId];
  }
}
final activeFiltersProvider = NotifierProvider<ActiveFiltersNotifier, List<String>>(ActiveFiltersNotifier.new);

final allTicketsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase.from('tickets').stream(primaryKey: ['id']).order('created_at', ascending: false);
});

final roomOrdersStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, roomNumber) {
  return supabase.from('orders').stream(primaryKey: ['id']).eq('room_number', roomNumber).order('created_at', ascending: false);
});

final activeRoomTicketsProvider = Provider.family<List<Map<String, dynamic>>, String>((ref, roomNumber) {
  final allTicketsAsync = ref.watch(allTicketsStreamProvider);
  final roomOrdersAsync = ref.watch(roomOrdersStreamProvider(roomNumber));
  
  if (allTicketsAsync.value == null || roomOrdersAsync.value == null) return [];

  final allTickets = allTicketsAsync.value!;
  final roomOrders = roomOrdersAsync.value!;
  
  // LỌC: Chỉ lấy ID của các đơn hàng CHƯA GIAO XONG (status != 'DELIVERED')
  final activeOrderIds = roomOrders
      .where((o) => o['status'] != 'DELIVERED')
      .map((o) => o['id'])
      .toSet();

  return allTickets.where((t) => activeOrderIds.contains(t['order_id'])).toList();
});

// Toppings Suggester
final menuItemToppingsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, menuItemId) async {
  final data = await supabase.from('menu_toppings').select('*').eq('menu_item_id', menuItemId);
  return List<Map<String, dynamic>>.from(data);
});
