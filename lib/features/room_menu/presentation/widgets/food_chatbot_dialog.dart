import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme/admin_theme.dart';
import '../../providers/room_ai_chat_provider.dart';
import '../../providers/room_menu_provider.dart';
import 'dish_customization_dialog.dart';

class FoodChatbotDialog extends ConsumerStatefulWidget {
  const FoodChatbotDialog({super.key});

  static void show(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const FoodChatbotDialog(),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: SizedBox(
            width: 540,
            height: 720,
            child: const FoodChatbotDialog(),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<FoodChatbotDialog> createState() => _FoodChatbotDialogState();
}

class _FoodChatbotDialogState extends ConsumerState<FoodChatbotDialog> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(String locale) {
    final query = _textController.text.trim();
    if (query.isEmpty) return;

    _textController.clear();
    ref.read(roomAiChatProvider.notifier).sendMessage(query, locale);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(roomAiChatProvider);
    final locale = ref.watch(localeProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    ref.listen<RoomAiChatState>(roomAiChatProvider, (prev, next) {
      if (prev?.messages.length != next.messages.length || next.isLoading) {
        _scrollToBottom();
      }
    });

    final suggestions = locale == 'vi'
        ? [
            "Trà sữa có những topping gì?",
            "Thêm 1 Trà sữa truyền thống vào giỏ",
            "Món nào bán chạy & ngon nhất?",
            "Cho tôi xem danh mục món ăn",
          ]
        : [
            "What toppings are available?",
            "Add 1 Milk Tea to cart",
            "What are the best-selling dishes?",
            "Show me the food categories",
          ];

    final content = Column(
      children: [
        // --- HEADER ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AdminTheme.primaryWood,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.amberAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      locale == 'vi' ? 'Trợ Lý Thực Đơn AI (Gemini)' : 'Menu AI Assistant (Gemini)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          locale == 'vi'
                              ? 'Truy xuất CSDL & Tự động thêm giỏ'
                              : 'Live DB Query & Auto Add to Cart',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70, size: 20),
                tooltip: locale == 'vi' ? 'Xóa đoạn chat' : 'Clear Chat',
                onPressed: () {
                  ref.read(roomAiChatProvider.notifier).clearChat();
                },
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // --- BODY: MESSAGES & QUICK CHIPS ---
        Expanded(
          child: Container(
            color: AdminTheme.bgWarmWhite,
            child: chatState.messages.isEmpty
                ? _buildEmptyWelcomeState(suggestions, locale)
                : _buildChatList(chatState, locale),
          ),
        ),

        // --- QUICK SUGGESTIONS CHIPS (WHEN NOT EMPTY) ---
        if (chatState.messages.isNotEmpty)
          Container(
            height: 42,
            color: AdminTheme.bgWarmWhite,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              scrollDirection: Axis.horizontal,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final chipText = suggestions[index];
                return ActionChip(
                  label: Text(
                    chipText,
                    style: const TextStyle(fontSize: 12, color: AdminTheme.primaryDarkWood),
                  ),
                  backgroundColor: AdminTheme.lightWoodCream,
                  side: const BorderSide(color: AdminTheme.borderWood, width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  onPressed: () {
                    _textController.text = chipText;
                    _handleSend(locale);
                  },
                );
              },
            ),
          ),

        // --- INPUT BAR ---
        Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AdminTheme.borderWood, width: 0.8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(locale),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: locale == 'vi'
                        ? 'Hỏi món, topping hoặc nói "Thêm món vào giỏ"...'
                        : 'Ask about dishes or say "Add to cart"...',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AdminTheme.borderWood),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AdminTheme.borderWood),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AdminTheme.primaryWood, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: chatState.isLoading
                    ? Colors.grey.shade400
                    : AdminTheme.primaryWood,
                shape: const CircleBorder(),
                elevation: 1,
                child: IconButton(
                  icon: chatState.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  onPressed: chatState.isLoading ? null : () => _handleSend(locale),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (isMobile) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: content,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: content,
    );
  }

  Widget _buildEmptyWelcomeState(List<String> suggestions, String locale) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AdminTheme.lightWoodCream,
                shape: BoxShape.circle,
                border: Border.all(color: AdminTheme.borderWood, width: 1),
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                size: 36,
                color: AdminTheme.primaryDarkWood,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              locale == 'vi'
                  ? 'Trợ Lý Tư Vấn Món & Đặt Món AI'
                  : 'Smart AI Food & Ordering Assistant',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AdminTheme.primaryDarkWood,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              locale == 'vi'
                  ? 'Hỏi AI về món ăn, tùy chỉnh topping, hoặc nói "Thêm món vào giỏ". Bạn chỉ cần bấm nút Đặt Món ở giỏ hàng khi sẵn sàng!'
                  : 'Ask AI for recommendations, custom toppings, or say "Add to cart". Just click Order Now in your cart when ready!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AdminTheme.textMutedWood,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                locale == 'vi' ? 'Gợi ý trải nghiệm:' : 'Suggested prompts:',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: AdminTheme.primaryWood,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: suggestions.map((text) {
                return InkWell(
                  onTap: () {
                    _textController.text = text;
                    _handleSend(locale);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AdminTheme.borderWood),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat_bubble_outline, size: 14, color: AdminTheme.secondaryWood),
                        const SizedBox(width: 6),
                        Text(
                          text,
                          style: const TextStyle(fontSize: 12, color: AdminTheme.textDarkWood),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(RoomAiChatState chatState, String locale) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatState.messages.length && chatState.isLoading) {
          return _buildLoadingBubble(locale);
        }

        final msg = chatState.messages[index];
        final isUser = msg.sender == 'user';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AdminTheme.primaryWood,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, size: 16, color: Colors.amberAccent),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AdminTheme.primaryWood
                            : (msg.isError ? Colors.red.shade50 : Colors.white),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 4),
                          bottomRight: Radius.circular(isUser ? 4 : 16),
                        ),
                        border: isUser
                            ? null
                            : Border.all(
                                color: msg.isError ? Colors.red.shade200 : AdminTheme.borderWood,
                                width: 0.8,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Gemini AI',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: msg.isError ? Colors.red : AdminTheme.primaryWood,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: msg.text));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(locale == 'vi' ? 'Đã sao chép nội dung!' : 'Copied to clipboard!'),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          if (!isUser) const SizedBox(height: 4),
                          _buildFormattedText(msg.text, isUser: isUser, isError: msg.isError),
                        ],
                      ),
                    ),

                    // --- INTERACTIVE SUGGESTED DISH CARDS (AI SELECTION & AUTO ADD TO CART) ---
                    if (!isUser && msg.suggestedDishes.isNotEmpty)
                      _buildSuggestedDishCards(msg.suggestedDishes, locale),
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AdminTheme.secondaryWood,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, size: 18, color: Colors.white),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestedDishCards(List<AiSuggestedDish> dishes, String locale) {
    final currencyFormatter = NumberFormat.currency(
      locale: locale == 'vi' ? 'vi_VN' : 'en_US',
      symbol: locale == 'vi' ? 'đ' : '\$',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: dishes.map((dish) {
          final item = dish.menuItem;
          final mods = dish.selectedModifiers;
          final double modsPrice = mods.fold(0.0, (sum, m) => sum + m.price);
          final double unitPrice = item.price + modsPrice;
          final double totalPrice = unitPrice * dish.quantity;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.lightWoodCream,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminTheme.borderWood, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.imageUrl != null
                          ? Image.network(item.imageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                          : Container(
                              width: 50,
                              height: 50,
                              color: AdminTheme.secondaryWood,
                              child: const Icon(Icons.restaurant, color: Colors.white, size: 24),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.getName(locale),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: AdminTheme.primaryDarkWood,
                                  ),
                                ),
                              ),
                              if (dish.quantity > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AdminTheme.primaryWood,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'x${dish.quantity}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormatter.format(totalPrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // TOPPINGS LIST IF SELECTED
                if (mods.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AdminTheme.borderWood, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          locale == 'vi' ? 'Toppings/Tùy chọn:' : 'Selected Toppings:',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AdminTheme.primaryWood,
                          ),
                        ),
                        ...mods.map((m) => Text(
                              '• ${m.modifierName} (+${currencyFormatter.format(m.price)})',
                              style: const TextStyle(fontSize: 11, color: AdminTheme.textDarkWood),
                            )),
                      ],
                    ),
                  ),
                ],

                // CUSTOM REQUEST NOTES BADGE
                if (dish.notes.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade400, width: 0.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 15, color: Colors.amber.shade900),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${locale == 'vi' ? 'Ghi chú yêu cầu riêng' : 'Custom Note'}: ${dish.notes}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                // ACTION BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.tune_rounded, size: 14),
                        label: Text(locale == 'vi' ? 'Tùy chỉnh' : 'Customize'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => DishCustomizationDialog(
                              item: item,
                              initialSelectedModifiers: mods,
                              initialNotes: dish.notes,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart_rounded, size: 14),
                        label: Text(
                          locale == 'vi'
                              ? (dish.quantity > 1 ? 'Thêm giỏ (x${dish.quantity})' : 'Thêm giỏ')
                              : (dish.quantity > 1 ? 'Add Cart (x${dish.quantity})' : 'Add Cart'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.primaryWood,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          ref.read(cartProvider.notifier).addToCart(
                                item,
                                mods,
                                dish.notes,
                                quantity: dish.quantity,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                locale == 'vi'
                                    ? 'Đã thêm ${dish.quantity > 1 ? "${dish.quantity}x " : ""}${item.getName(locale)} vào giỏ hàng!${dish.notes.isNotEmpty ? ' (Ghi chú: ${dish.notes})' : ''}'
                                    : 'Added ${dish.quantity > 1 ? "${dish.quantity}x " : ""}${item.getName(locale)} to cart!',
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFormattedText(String rawText, {required bool isUser, bool isError = false}) {
    if (isUser) {
      return Text(
        rawText,
        style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
      );
    }

    final List<Widget> spans = [];
    final lines = rawText.split('\n');

    for (var line in lines) {
      if (line.trim().isEmpty) {
        spans.add(const SizedBox(height: 4));
        continue;
      }

      bool isBullet = line.trim().startsWith('•') || line.trim().startsWith('-') || line.trim().startsWith('+');
      String cleanLine = isBullet ? line.trim().substring(1).trim() : line;

      List<InlineSpan> inlineSpans = [];
      final parts = cleanLine.split('**');

      for (int i = 0; i < parts.length; i++) {
        final text = parts[i];
        if (text.isEmpty) continue;
        if (i % 2 == 1) {
          inlineSpans.add(TextSpan(
            text: text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isError ? Colors.red.shade900 : AdminTheme.primaryDarkWood,
            ),
          ));
        } else {
          inlineSpans.add(TextSpan(
            text: text,
            style: TextStyle(
              color: isError ? Colors.red.shade800 : AdminTheme.textDarkWood,
            ),
          ));
        }
      }

      spans.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBullet)
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 3),
                  child: Icon(
                    Icons.fiber_manual_record,
                    size: 7,
                    color: isError ? Colors.red : AdminTheme.primaryWood,
                  ),
                ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, height: 1.45),
                    children: inlineSpans,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spans,
    );
  }

  Widget _buildLoadingBubble(String locale) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AdminTheme.primaryWood,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, size: 16, color: Colors.amberAccent),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AdminTheme.borderWood, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AdminTheme.primaryWood),
                ),
                const SizedBox(width: 8),
                Text(
                  locale == 'vi'
                      ? 'Gemini đang truy xuất CSDL & chọn món...'
                      : 'Gemini is querying DB & selecting items...',
                  style: const TextStyle(fontSize: 12, color: AdminTheme.textMutedWood),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
