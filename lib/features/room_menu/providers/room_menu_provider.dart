import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../admin_panel/providers/menu_provider.dart';

// ==========================================
// 1. MODEL GIỎ HÀNG (Modifier Groups)
// ==========================================
class SelectedModifier {
  final String groupId;
  final String groupName;
  final String modifierId;
  final String modifierName;
  final double price;

  SelectedModifier({
    required this.groupId,
    required this.groupName,
    required this.modifierId,
    required this.modifierName,
    required this.price,
  });

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'group_name': groupName,
    'modifier_id': modifierId,
    'modifier_name': modifierName,
    'price': price,
  };
}

class CartItem {
  final String uniqueId;
  final Map<String, dynamic> menuItem;
  int quantity;
  String notes;
  final List<SelectedModifier> selectedModifiers;

  CartItem({
    required this.uniqueId,
    required this.menuItem,
    this.quantity = 1,
    this.notes = '',
    this.selectedModifiers = const [],
  });

  double get singlePrice {
    double basePrice = num.tryParse(menuItem['price'].toString())?.toDouble() ?? 0.0;
    double modifiersPrice = selectedModifiers.fold(0.0, (sum, m) => sum + m.price);
    return basePrice + modifiersPrice;
  }

  double get totalPrice => singlePrice * quantity;
}

// ==========================================
// 2. NOTIFIER QUẢN LÝ GIỎ HÀNG
// ==========================================
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void addToCart(Map<String, dynamic> item, List<SelectedModifier> modifiers, String notes) {
    final modIds = modifiers.map((m) => m.modifierId).toList()..sort();
    final String uniqueKey = "${item['id']}_${modIds.join('_')}_$notes";

    final existingIndex = state.indexWhere((c) => c.uniqueId == uniqueKey);

    if (existingIndex >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex)
            CartItem(
              uniqueId: state[i].uniqueId,
              menuItem: state[i].menuItem,
              selectedModifiers: state[i].selectedModifiers,
              notes: state[i].notes,
              quantity: state[i].quantity + 1,
            )
          else
            state[i]
      ];
    } else {
      state = [...state, CartItem(
        uniqueId: uniqueKey,
        menuItem: item,
        selectedModifiers: modifiers,
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
          selectedModifiers: newState[index].selectedModifiers,
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

// Stream lấy toàn bộ quan hệ Item-Tag để join phía Client
final itemTagsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase.from('item_tags').stream(primaryKey: ['item_id', 'tag_id']);
});

// Provider kết hợp Món ăn và các Thẻ của nó
final menuItemsWithTagsProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final menuAsync = ref.watch(menuItemsStreamProvider);
  final itemTagsAsync = ref.watch(itemTagsStreamProvider);

  if (menuAsync.value == null || itemTagsAsync.value == null) {
    return const AsyncValue.loading();
  }

  final items = menuAsync.value!;
  final relations = itemTagsAsync.value!;

  final combined = items.map((item) {
    final tagIds = relations
        .where((r) => r['item_id'] == item['id'])
        .map((r) => r['tag_id'].toString())
        .toList();
    return {...item, 'tag_ids': tagIds};
  }).toList();

  return AsyncValue.data(combined);
});

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
  
  final activeOrderIds = roomOrders
      .where((o) => o['status'] != 'DELIVERED')
      .map((o) => o['id'])
      .toSet();

  return allTickets.where((t) => activeOrderIds.contains(t['order_id'])).toList();
});

// Provider lấy nhóm tùy chỉnh trực tiếp từ món ăn (Kiến trúc Độc lập)
final itemModifiersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, menuItemId) async {
  try {
    final groupsData = await supabase
        .from('modifier_groups')
        .select('*, modifiers(*)')
        .eq('item_id', menuItemId)
        .order('created_at', ascending: true);
        
    return List<Map<String, dynamic>>.from(groupsData);
  } catch (e) {
    print("LỖI PROVIDER: $e");
    return [];
  }
});
