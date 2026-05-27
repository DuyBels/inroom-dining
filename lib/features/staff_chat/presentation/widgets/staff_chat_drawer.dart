import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/chat_provider.dart';
import '../../../auth/providers/auth_provider.dart';

class StaffChatDrawer extends ConsumerStatefulWidget {
  const StaffChatDrawer({super.key});

  @override
  ConsumerState<StaffChatDrawer> createState() => _StaffChatDrawerState();
}

class _StaffChatDrawerState extends ConsumerState<StaffChatDrawer> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Vừa mở là đánh dấu đã xem ngay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatActionsProvider).markAllAsRead();
    });
  }

  void _send() {
    if (_controller.text.trim().isNotEmpty) {
      ref.read(chatActionsProvider).sendMessage(_controller.text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(staffMessagesStreamProvider);
    final myId = ref.watch(currentUserProvider)?.id;

    // Lắng nghe tin nhắn mới: Nếu Drawer đang mở thì mark as read ngay lập tức
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(staffMessagesStreamProvider, (prev, next) {
      if (next.hasValue && next.value != prev?.value) {
        ref.read(chatActionsProvider).markAllAsRead();
      }
    });

    return Drawer(
      width: 380,
      backgroundColor: const Color(0xFFF0F2F5),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 15, left: 16, right: 16),
            decoration: BoxDecoration(color: Colors.blue[800]),
            child: const Row(
              children: [
                Icon(Icons.group, color: Colors.white),
                SizedBox(width: 12),
                Text('NHÓM PHỤC VỤ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              data: (msgs) => ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                itemCount: msgs.length,
                itemBuilder: (context, index) {
                  final m = msgs[index];
                  final isMe = m['sender_id'] == myId;
                  final List readList = m['read_by'] ?? [];
                  
                  // LOGIC TRẠNG THÁI:
                  // 1 tích: Chỉ có người gửi (readList.length == 1)
                  // 2 tích: Có ít nhất 1 người khác xem (readList.length > 1)
                  final isReadByOthers = readList.length > 1;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe) Text(m['sender_name'], style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(m['message'], style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(DateFormat('HH:mm').format(DateTime.parse(m['created_at']).toLocal()), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      isReadByOthers ? Icons.done_all : Icons.done,
                                      size: 14,
                                      color: isReadByOthers ? Colors.green : Colors.grey, // Đã đổi sang Xanh lá
                                    ),
                                  ]
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Lỗi: $e')),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Nhập tin nhắn...',
                filled: true, fillColor: const Color(0xFFF0F2F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _send),
        ],
      ),
    );
  }
}
