import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/menu_item_model.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/utils/l10n_utils.dart';
import '../../../main.dart';
import 'room_menu_provider.dart';
import 'ai_recommendation_provider.dart';

class AiSuggestedDish {
  final MenuItemModel menuItem;
  final List<SelectedModifier> selectedModifiers;
  final int quantity;
  final bool autoAdded;
  final String notes;
  final bool blockedByRequiredOptions;

  AiSuggestedDish({
    required this.menuItem,
    this.selectedModifiers = const [],
    this.quantity = 1,
    this.autoAdded = false,
    this.notes = '',
    this.blockedByRequiredOptions = false,
  });
}

class ChatMessage {
  final String id;
  final String sender; // 'user' | 'ai'
  final String text;
  final DateTime timestamp;
  final bool isError;
  final List<AiSuggestedDish> suggestedDishes;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.isError = false,
    this.suggestedDishes = const [],
  });
}

class RoomAiChatState {
  final List<ChatMessage> messages;
  final bool isLoading;

  RoomAiChatState({
    this.messages = const [],
    this.isLoading = false,
  });

  RoomAiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return RoomAiChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class RoomAiChatNotifier extends Notifier<RoomAiChatState> {
  /// Cache context menu từ DB để không phải query lại mỗi lần chat
  String? _cachedDbContext;
  String? _cachedLocale;

  @override
  RoomAiChatState build() => RoomAiChatState(messages: []);

  void clearChat() {
    _cachedDbContext = null;
    _cachedLocale = null;
    state = RoomAiChatState(messages: []);
  }

  /// Truy xuất toàn bộ cơ sở dữ liệu (Categories, Menu Items, Descriptions, Toppings/Modifiers, Tags) từ Supabase
  Future<String> fetchFoodDatabaseContext(String locale) async {
    try {
      final categoriesData = List<dynamic>.from(await supabase.from('categories').select());
      final menuItemsData = List<dynamic>.from(await supabase.from('menu_items').select());
      final modifierGroupsData = List<dynamic>.from(await supabase.from('item_modifier_groups').select('item_id, modifier_groups(*, modifiers(*))'));
      final itemTagsData = List<dynamic>.from(await supabase.from('item_tags').select('item_id, tags(*)'));

      // Map item_id -> danh sách tag names
      Map<String, List<String>> itemTagsMap = {};
      for (var row in itemTagsData) {
        final itemId = row['item_id']?.toString();
        final tag = row['tags'];
        if (itemId != null && tag != null) {
          final tagName = L10nUtils.getL10n(L10nUtils.decodeField(tag['name']), locale);
          itemTagsMap.putIfAbsent(itemId, () => []).add(tagName);
        }
      }

      // Map item_id -> danh sách modifier groups
      Map<String, List<dynamic>> itemModifiersMap = {};
      for (var row in modifierGroupsData) {
        final itemId = row['item_id']?.toString();
        final group = row['modifier_groups'];
        if (itemId != null && group != null) {
          itemModifiersMap.putIfAbsent(itemId, () => []).add(group);
        }
      }

      // Map category_id -> category name
      Map<String, String> categoryNames = {};
      for (var cat in categoriesData) {
        final catId = cat['id']?.toString() ?? '';
        final catName = L10nUtils.getL10n(L10nUtils.decodeField(cat['name']), locale);
        categoryNames[catId] = catName;
      }

      final currencyFormat = NumberFormat.currency(
        locale: locale == 'vi' ? 'vi_VN' : 'en_US',
        symbol: locale == 'vi' ? 'đ' : '\$',
        decimalDigits: 0,
      );

      StringBuffer buffer = StringBuffer();
      buffer.writeln("DANH SÁCH THỰC ĐƠN VÀ TOPPING CHÍNH THỨC TỪ CƠ SỞ DỮ LIỆU:\n");

      buffer.writeln("=== 1. DANH MỤC MÓN ĂN ===");
      for (var cat in categoriesData) {
        final catName = L10nUtils.getL10n(L10nUtils.decodeField(cat['name']), locale);
        final catDesc = L10nUtils.getL10n(L10nUtils.decodeField(cat['description']), locale);
        buffer.writeln("- Danh mục ID [${cat['id']}]: $catName${catDesc.isNotEmpty ? ' | Mô tả: $catDesc' : ''}");
      }

      buffer.writeln("\n=== 2. MÓN ĂN, MÔ TẢ VÀ TOPPINGS/MODIFIERS GẮN LIỀN ===");
      for (var item in menuItemsData) {
        final itemId = item['id']?.toString() ?? '';
        final itemName = L10nUtils.getL10n(L10nUtils.decodeField(item['name']), locale);
        final itemDesc = L10nUtils.getL10n(L10nUtils.decodeField(item['description']), locale);
        final price = num.tryParse(item['price']?.toString() ?? '0')?.toDouble() ?? 0.0;
        final prepTime = item['prep_time_minutes'] ?? 15;
        final isAvailable = item['is_available'] ?? true;
        final catName = categoryNames[item['category_id']?.toString()] ?? 'Khác';
        final tags = itemTagsMap[itemId] ?? [];
        final modGroups = itemModifiersMap[itemId] ?? [];

        buffer.writeln("\n• TÊN MÓN: $itemName (ID: $itemId)");
        buffer.writeln("  - Danh mục: $catName");
        buffer.writeln("  - Giá bán: ${currencyFormat.format(price)}");
        buffer.writeln("  - Thời gian chuẩn bị: ~$prepTime phút");
        buffer.writeln("  - Trạng thái: ${isAvailable ? 'Có sẵn (Đang phục vụ)' : 'Tạm hết món'}");
        buffer.writeln("  - Mô tả món ăn: ${itemDesc.isNotEmpty ? itemDesc : 'Chưa có mô tả'}");
        if (tags.isNotEmpty) {
          buffer.writeln("  - Thẻ/Đặc tính: ${tags.join(', ')}");
        }

        if (modGroups.isNotEmpty) {
          buffer.writeln("  - Danh sách Topping / Tùy chọn đi kèm (Modifiers):");
          for (var group in modGroups) {
            final groupName = L10nUtils.getL10n(L10nUtils.decodeField(group['name']), locale);
            final minSel = group['min_select'] ?? 0;
            final maxSel = group['max_select'] ?? 1;
            final modifiers = group['modifiers'] as List? ?? [];
            
            List<String> modDetails = [];
            for (var mod in modifiers) {
              if (mod['is_available'] == true) {
                final modName = L10nUtils.getL10n(L10nUtils.decodeField(mod['name']), locale);
                final modPrice = num.tryParse(mod['price']?.toString() ?? '0')?.toDouble() ?? 0.0;
                modDetails.add("$modName (ID: ${mod['id']}, +${currencyFormat.format(modPrice)})");
              }
            }
            if (modDetails.isNotEmpty) {
              buffer.writeln("    + Nhóm '$groupName' (ID Nhóm: ${group['id']}, Chọn từ $minSel đến $maxSel): ${modDetails.join(', ')}");
            }
          }
        } else {
          buffer.writeln("  - Toppings / Tùy chọn đi kèm: Không có");
        }
      }

      return buffer.toString();
    } catch (e) {
      return "Lỗi khi lấy dữ liệu thực đơn từ database: $e";
    }
  }

  Future<void> sendMessage(String text, String locale) async {
    final userText = text.trim();
    if (userText.isEmpty || state.isLoading) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: 'user',
      text: userText,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    try {
      // 1. Truy xuất cơ sở dữ liệu (chỉ query lần đầu, sau đó dùng cache)
      if (_cachedDbContext == null || _cachedLocale != locale) {
        _cachedDbContext = await fetchFoodDatabaseContext(locale);
        _cachedLocale = locale;
      }
      final dbContext = _cachedDbContext!;

      // 2. Lấy thông tin thời tiết (đã cached bởi Riverpod, không gọi API thêm)
      String weatherContext = '';
      try {
        final roomCtx = await ref.read(roomContextProvider.future);
        final hour = roomCtx.hour;
        String timeOfDay;
        if (hour >= 5 && hour < 11) {
          timeOfDay = 'Buổi sáng (Morning)';
        } else if (hour >= 11 && hour < 14) {
          timeOfDay = 'Buổi trưa (Lunch)';
        } else if (hour >= 14 && hour < 17) {
          timeOfDay = 'Buổi chiều (Afternoon)';
        } else if (hour >= 17 && hour < 21) {
          timeOfDay = 'Buổi tối (Dinner)';
        } else {
          timeOfDay = 'Khuya (Late Night)';
        }
        weatherContext = '- Nhiệt độ hiện tại: ${roomCtx.temp.toStringAsFixed(1)}°C\n'
            '- Thời tiết: ${roomCtx.weather}\n'
            '- Thời điểm: $timeOfDay (${hour}h)\n'
            '${roomCtx.isApiError ? "(Lưu ý: Dữ liệu thời tiết có thể không chính xác do lỗi API)" : ""}';
      } catch (_) {
        weatherContext = '- Không có dữ liệu thời tiết.';
      }

      // 3. Chuẩn bị lịch sử trò chuyện
      final chatHistory = state.messages.map((m) => {
        'sender': m.sender,
        'text': m.text,
      }).toList();

      // 4. Gửi sang Gemini API với Context từ Database + Thời tiết
      String aiRawResponse = await ref.read(geminiServiceProvider).chatAboutFood(
        userMessage: userText,
        dbContext: dbContext,
        chatHistory: chatHistory,
        locale: locale,
        weatherContext: weatherContext,
      );

      // 4. Bóc tách và dọn dẹp dữ liệu JSON đính kèm [ITEMS_DATA: ...] nếu có
      List<AiSuggestedDish> matchedDishes = [];
      String cleanedText = aiRawResponse;

      // Regex sử dụng greedy match để bắt toàn bộ JSON lồng nhau (bao gồm arrays trong mod_ids)
      final match = RegExp(r'\[ITEMS_DATA:\s*(\{.*\})\s*\]', dotAll: true).firstMatch(aiRawResponse);
      if (match != null) {
        final jsonStr = match.group(1);
        if (jsonStr != null) {
          try {
            final sanitizedJson = _sanitizeJsonString(jsonStr);
            final data = json.decode(sanitizedJson);
            final itemsList = data['items'] as List? ?? [];

            matchedDishes = await _processSuggestedItems(itemsList, locale);
          } catch (_) {}
        }
      }

      // Dọn dẹp tuyệt đối mọi chuỗi JSON hoặc thẻ rác metadata ra khỏi câu trả lời của AI
      // Sử dụng greedy match (.*) thay vì lazy (.*?) để match qua nested brackets []{}
      cleanedText = cleanedText.replaceAll(RegExp(r'\[ITEMS_DATA:\s*\{.*\}\s*\]', dotAll: true), '');
      cleanedText = cleanedText.replaceAll(RegExp(r'\[RECOMMEND_DISHES:\s*\{.*\}\s*\]', dotAll: true), '');
      cleanedText = cleanedText.replaceAll(RegExp(r'\{"items"\s*:.*\}\s*\]?\s*\}', dotAll: true), '');
      cleanedText = cleanedText.trim();

      // DỰ PHÒNG CHẮC CHẮN: Nếu JSON không có hoặc parse lỗi -> luôn fuzzy match từ CSDL
      if (matchedDishes.isEmpty) {
        matchedDishes = await _fuzzyMatchDishesFromText(aiRawResponse, userText, locale);
      }

      // 5. TỰ ĐỘNG THÊM VÀO GIỎ HÀNG nếu có auto_add = true
      // Khi khách có ý định đặt món rõ ràng, tự động thêm vào giỏ hàng
      final autoAddDishes = matchedDishes.where((d) => d.autoAdded).toList();
      if (autoAddDishes.isNotEmpty) {
        final cartNotifier = ref.read(cartProvider.notifier);
        for (final dish in autoAddDishes) {
          cartNotifier.addToCart(
            dish.menuItem,
            dish.selectedModifiers,
            dish.notes,
            quantity: dish.quantity,
          );
        }
      }

      // THÊM CẢNH BÁO nếu AI định auto_add nhưng bị chặn vì thiếu tùy chọn bắt buộc
      final blockedDishes = matchedDishes.where((d) => d.blockedByRequiredOptions).toList();
      if (blockedDishes.isNotEmpty) {
        final warningMsg = locale == 'vi' 
            ? '\n\n⚠️ **Lưu ý:** Một số món có tùy chọn bắt buộc. Vui lòng nhấn "Tùy chỉnh" ở bên dưới để hoàn tất thêm vào giỏ hàng nhé!'
            : '\n\n⚠️ **Note:** Some items require specific options. Please click "Customize" below to add them to your cart!';
        cleanedText += warningMsg;
      }


      final aiMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        sender: 'ai',
        text: cleanedText,
        timestamp: DateTime.now(),
        suggestedDishes: matchedDishes,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMessage],
        isLoading: false,
      );
    } catch (e) {
      final errorMessage = ChatMessage(
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
        sender: 'ai',
        text: locale == 'vi'
            ? "Xin lỗi, đã xảy ra lỗi khi trao đổi với AI Gemini: $e"
            : "Sorry, an error occurred while connecting to Gemini AI: $e",
        timestamp: DateTime.now(),
        isError: true,
      );

      state = state.copyWith(
        messages: [...state.messages, errorMessage],
        isLoading: false,
      );
    }
  }

  String _sanitizeJsonString(String raw) {
    String s = raw.trim();
    // 1. Khử khối mã markdown
    s = s.replaceAll(RegExp(r'^```(json)?\s*', multiLine: true), '');
    s = s.replaceAll(RegExp(r'^```\s*', multiLine: true), '');

    // 2. Sửa lỗi thiếu dấu phẩy giữa các phần tử mảng chuỗi ("str1" "str2" -> "str1", "str2")
    s = s.replaceAll(RegExp(r'"\s+"'), '", "');

    // 3. Sửa lỗi thiếu dấu phẩy giữa các đối tượng JSON (} { -> }, {)
    s = s.replaceAll(RegExp(r'\}\s*\{'), '}, {');

    // 4. Khử dấu phẩy thừa ở cuối đối tượng hoặc mảng (, } -> } hoặc , ] -> ])
    s = s.replaceAll(RegExp(r',\s*([\}\]])'), r'$1');

    // 5. Chuyển đổi nháy đơn thành nháy kép chuẩn JSON
    s = s.replaceAllMapped(RegExp(r"'([^'\\]*(?:\\.[^'\\]*)*)'"), (m) => '"${m.group(1)}"');

    // 6. Sửa lỗi key chưa được bọc ngoặc kép ({ key: -> { "key":)
    s = s.replaceAllMapped(RegExp(r'([{,]\s*)([a-zA-Z0-9_]+)\s*:'), (m) => '${m.group(1)}"${m.group(2)}":');

    return s;
  }

  Future<List<AiSuggestedDish>> _processSuggestedItems(List itemsList, String locale) async {
    List<AiSuggestedDish> result = [];
    final allMenuItems = ref.read(menuItemsWithTagsProvider).value ?? [];

    for (var itemObj in itemsList) {
      final itemId = itemObj['id']?.toString();
      if (itemId == null) continue;

      final matchedItem = allMenuItems.firstWhere(
        (i) => i.id == itemId,
        orElse: () => MenuItemModel(
          id: '',
          price: 0,
          nameMap: {},
          descriptionMap: {},
          prepTime: 15,
          categoryId: '',
          stationId: '',
          isAvailable: false,
        ),
      );

      if (matchedItem.id.isEmpty) continue;

      final modIds = (itemObj['mod_ids'] as List? ?? []).map((e) => e.toString()).toList();
      List<SelectedModifier> selectedMods = await _fetchModifiersByIds(itemId, modIds, locale);
      final int qty = num.tryParse(itemObj['quantity']?.toString() ?? '1')?.toInt() ?? 1;
      final String notes = itemObj['notes']?.toString() ?? '';
      bool isAutoAdd = itemObj['auto_add'] == true;
      bool isBlocked = false;

      // KIỂM TRA TÙY CHỌN BẮT BUỘC:
      // Nếu món có nhóm modifier bắt buộc (min_select > 0) mà AI chưa cung cấp đủ
      // modifier cho nhóm đó → KHÔNG được auto_add, bắt buộc khách phải chọn thủ công.
      if (isAutoAdd) {
        isAutoAdd = await _canAutoAdd(itemId, selectedMods);
        if (!isAutoAdd) isBlocked = true;
      }

      // DEDUPLICATION: Gemini đôi khi trả trùng entry cho cùng 1 món.
      // Prompt đã yêu cầu gộp sẵn, nên entry trùng là lỗi hallucination → bỏ qua.
      final modIdsKey = modIds.join('_');
      final existingIndex = result.indexWhere((d) {
        final dModIdsKey = d.selectedModifiers.map((m) => m.modifierId).toList().join('_');
        return d.menuItem.id == itemId && dModIdsKey == modIdsKey && d.notes == notes;
      });

      if (existingIndex >= 0) {
        // Đã có entry giống hệt → bỏ qua entry trùng, giữ nguyên số lượng gốc
        continue;
      }

      result.add(AiSuggestedDish(
        menuItem: matchedItem,
        selectedModifiers: selectedMods,
        quantity: qty > 0 ? qty : 1,
        autoAdded: isAutoAdd,
        notes: notes,
        blockedByRequiredOptions: isBlocked,
      ));
    }

    return result;
  }

  /// Kiểm tra xem món có thể auto_add hay không.
  /// Trả về false CHỈ KHI xác nhận chắc chắn có nhóm modifier bắt buộc chưa được chọn đủ.
  /// Nếu không query được DB → cho phép auto_add (fallback an toàn, AI đã xác nhận ý định).
  Future<bool> _canAutoAdd(String itemId, List<SelectedModifier> selectedMods) async {
    try {
      final res = await supabase
          .from('item_modifier_groups')
          .select('modifier_groups(id, min_select)')
          .eq('item_id', itemId);

      for (var row in res) {
        final group = row['modifier_groups'];
        if (group == null) continue;
        final int minSelect = group['min_select'] ?? 0;
        if (minSelect > 0) {
          final groupId = group['id']?.toString() ?? '';
          final selectedInGroup = selectedMods.where((m) => m.groupId == groupId).length;
          if (selectedInGroup < minSelect) {
            // Xác nhận chắc chắn: có nhóm bắt buộc chưa chọn đủ → chặn auto_add
            return false;
          }
        }
      }
    } catch (_) {
      // Lỗi khi query DB → KHÔNG chặn auto_add vì AI đã xác nhận ý định khách.
      // Thà thêm vào giỏ (khách có thể sửa) còn hơn chặn im lặng.
      return true;
    }
    return true;
  }

  Future<List<SelectedModifier>> _fetchModifiersByIds(String itemId, List<String> modIds, String locale) async {
    if (modIds.isEmpty) return [];
    List<SelectedModifier> mods = [];
    try {
      final res = await supabase
          .from('item_modifier_groups')
          .select('modifier_groups(*, modifiers(*))')
          .eq('item_id', itemId);
      final groups = res.map((e) => e['modifier_groups']).toList();

      for (var g in groups) {
        final gName = L10nUtils.getL10n(L10nUtils.decodeField(g['name']), locale);
        final modifiers = g['modifiers'] as List? ?? [];
        for (var m in modifiers) {
          final mId = m['id']?.toString();
          if (mId != null && modIds.contains(mId)) {
            final mName = L10nUtils.getL10n(L10nUtils.decodeField(m['name']), locale);
            final price = num.tryParse(m['price']?.toString() ?? '0')?.toDouble() ?? 0.0;
            mods.add(SelectedModifier(
              groupId: g['id']?.toString() ?? '',
              rawGroup: g['name'],
              groupName: gName,
              modifierId: mId,
              rawModifier: m['name'],
              modifierName: mName,
              price: price,
            ));
          }
        }
      }
    } catch (_) {}
    return mods;
  }

  Future<List<AiSuggestedDish>> _fuzzyMatchDishesFromText(
    String aiText,
    String userText,
    String locale,
  ) async {
    List<AiSuggestedDish> matched = [];
    final allMenuItems = ref.read(menuItemsWithTagsProvider).value ?? [];
    final combinedText = L10nUtils.removeDiacritics("$userText $aiText".toLowerCase());

    // Phát hiện ý định đặt món từ từ khóa trong câu của khách
    final lowerUserText = userText.toLowerCase();
    final hasOrderIntent = RegExp(
      r'(đặt|thêm|cho tôi|order|add|lấy|gọi|mua|đặt cho|thêm vào|cho xin|cho mình|gọi cho)',
      caseSensitive: false,
    ).hasMatch(lowerUserText);

    for (var item in allMenuItems) {
      final itemName = item.getName(locale).toLowerCase();
      final normalizedItemName = L10nUtils.removeDiacritics(itemName);

      if (normalizedItemName.length >= 3 && combinedText.contains(normalizedItemName)) {
        // Chỉ ghép topping nếu người dùng thực sự nhắc tên topping trong câu hỏi
        List<SelectedModifier> matchedMods = await _findModifiersInText(item.id, userText, locale);
        int qty = _extractQuantityFromText(userText, item.getName(locale));
        String customNotes = _extractCustomNotesFromText(userText, matchedMods, locale);

        // KHÁCH PHẢI THỰC SỰ GỌI TÊN MÓN THÌ MỚI AUTO_ADD (kiểm tra trong userText thay vì combinedText)
        final userMentionedItem = lowerUserText.contains(normalizedItemName) || 
                                  L10nUtils.removeDiacritics(lowerUserText).contains(normalizedItemName);

        bool shouldAutoAdd = hasOrderIntent && userMentionedItem;
        bool isBlocked = false;
        // Kiểm tra tùy chọn bắt buộc trước khi auto_add (fuzzy match path)
        if (shouldAutoAdd) {
          shouldAutoAdd = await _canAutoAdd(item.id, matchedMods);
          if (!shouldAutoAdd) isBlocked = true;
        }

        matched.add(AiSuggestedDish(
          menuItem: item,
          selectedModifiers: matchedMods,
          quantity: qty,
          autoAdded: shouldAutoAdd,
          notes: customNotes,
          blockedByRequiredOptions: isBlocked,
        ));

        if (matched.length >= 3) break;
      }
    }
    return matched;
  }

  int _extractQuantityFromText(String userText, String itemName) {
    if (userText.isEmpty) return 1;
    final lowerUser = L10nUtils.removeDiacritics(userText.toLowerCase());
    final lowerItem = L10nUtils.removeDiacritics(itemName.toLowerCase());

    try {
      // Pattern 1: Số + (đơn vị)? + tên món  → VD: "2 tô phở gà", "3 trà sữa"
      final pattern1 = RegExp(r'(\d+)\s*(tô|phần|ly|cốc|đĩa|chén|suất|món|sp|x)?\s*' + RegExp.escape(lowerItem));
      final match1 = pattern1.firstMatch(lowerUser);
      if (match1 != null) {
        final q = int.tryParse(match1.group(1) ?? '1');
        if (q != null && q > 0) return q;
      }

      // Pattern 2: Tên món + x/*/: + số  → VD: "phở gà x2", "trà sữa *3"
      final pattern2 = RegExp(RegExp.escape(lowerItem) + r'\s*(x|\*|\:)?\s*(\d+)');
      final match2 = pattern2.firstMatch(lowerUser);
      if (match2 != null) {
        final q = int.tryParse(match2.group(2) ?? '1');
        if (q != null && q > 0) return q;
      }

      // Pattern 3: Động từ đặt hàng + số + đơn vị (BẮT BUỘC có đơn vị để tránh bắt nhầm)
      // VD: "cho 2 phần", "thêm 3 ly", "đặt 1 tô"
      final actionUnitPattern = RegExp(r'(cho|thêm|đặt|lấy|gọi|cho toi|cho minh|cho xin)\s+(\d+)\s*(tô|phần|ly|cốc|đĩa|chén|bát|suất|món|sp)\b');
      final actionUnitMatch = actionUnitPattern.firstMatch(lowerUser);
      if (actionUnitMatch != null) {
        final q = int.tryParse(actionUnitMatch.group(2) ?? '1');
        if (q != null && q > 0) return q;
      }

      // Pattern 4: Số + đơn vị (phải có đơn vị để tránh bắt nhầm số phòng/bàn)
      // VD: "2 tô", "3 ly"
      final unitPattern = RegExp(r'(\d+)\s*(tô|phần|ly|cốc|đĩa|chén|bát|suất|món|sp)\b');
      final unitMatch = unitPattern.firstMatch(lowerUser);
      if (unitMatch != null) {
        final q = int.tryParse(unitMatch.group(1) ?? '1');
        if (q != null && q > 0) return q;
      }

      // KHÔNG dùng catch-all regex bắt bất kỳ số nào nữa.
      // Nếu không match được pattern nào ở trên → mặc định 1.
    } catch (_) {}

    return 1;
  }

  String _extractCustomNotesFromText(String userText, List<SelectedModifier> matchedMods, String locale) {
    if (userText.isEmpty) return '';
    final lower = userText.toLowerCase();
    final keywords = ['không ', 'ít ', 'nhiều ', 'bỏ ', 'đừng ', 'giao '];
    List<String> foundNotes = [];

    final parts = lower.split(RegExp(r'[,;\.\n]+|và\s+|hoặc\s+'));
    for (var part in parts) {
      final p = part.trim();
      for (var kw in keywords) {
        if (p.contains(kw)) {
          bool isAlreadyModifier = matchedMods.any((m) => p.contains(m.modifierName.toLowerCase()));
          if (!isAlreadyModifier && !foundNotes.contains(p)) {
            foundNotes.add(p);
          }
        }
      }
    }
    return foundNotes.join(', ');
  }

  Future<List<SelectedModifier>> _findModifiersInText(String itemId, String combinedText, String locale) async {
    List<SelectedModifier> mods = [];
    try {
      final res = await supabase
          .from('item_modifier_groups')
          .select('modifier_groups(*, modifiers(*))')
          .eq('item_id', itemId);
      final groups = res.map((e) => e['modifier_groups']).toList();

      for (var g in groups) {
        final gName = L10nUtils.getL10n(L10nUtils.decodeField(g['name']), locale);
        final modifiers = g['modifiers'] as List? ?? [];
        for (var m in modifiers) {
          final mName = L10nUtils.getL10n(L10nUtils.decodeField(m['name']), locale);
          final normalizedMName = L10nUtils.removeDiacritics(mName.toLowerCase());

          if (normalizedMName.length >= 3 && combinedText.contains(normalizedMName)) {
            final price = num.tryParse(m['price']?.toString() ?? '0')?.toDouble() ?? 0.0;
            mods.add(SelectedModifier(
              groupId: g['id']?.toString() ?? '',
              rawGroup: g['name'],
              groupName: gName,
              modifierId: m['id']?.toString() ?? '',
              rawModifier: m['name'],
              modifierName: mName,
              price: price,
            ));
          }
        }
      }
    } catch (_) {}
    return mods;
  }
}

final roomAiChatProvider = NotifierProvider<RoomAiChatNotifier, RoomAiChatState>(
  RoomAiChatNotifier.new,
);
