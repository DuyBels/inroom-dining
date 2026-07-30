import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../auth/providers/auth_provider.dart';

final staffMessagesStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return supabase
      .from('staff_messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(50);
});

final hasUnreadMessagesProvider = Provider.autoDispose<bool>((ref) {
  final messagesAsync = ref.watch(staffMessagesStreamProvider);
  final myId = ref.watch(currentUserProvider)?.id;
  
  if (messagesAsync.value == null || myId == null) return false;
  
  return messagesAsync.value!.any((m) {
    final List readBy = m['read_by'] ?? [];
    return m['sender_id'] != myId && !readBy.contains(myId);
  });
});

final chatActionsProvider = Provider.autoDispose((ref) {
  return ChatActions(ref);
});

class ChatActions {
  final Ref ref;
  ChatActions(this.ref);

  Future<void> sendMessage(String message) async {
    final profile = ref.read(userProfileProvider).value;
    final user = ref.read(currentUserProvider);
    if (profile == null || user == null || message.trim().isEmpty) return;

    try {
      await supabase.from('staff_messages').insert({
        'sender_id': user.id,
        'sender_name': profile['display_name'] ?? 'Staff',
        'message': message.trim(),
        'read_by': [user.id],
      });
    } catch (e) {
      print("CHAT ERROR: $e");
    }
  }

  Future<void> markAllAsRead() async {
    final user = ref.read(currentUserProvider);
    final messages = ref.read(staffMessagesStreamProvider).value;
    if (user == null || messages == null) return;

    final unreadMsgs = messages.where((m) {
      final List readBy = m['read_by'] ?? [];
      return m['sender_id'] != user.id && !readBy.contains(user.id);
    }).toList();

    if (unreadMsgs.isEmpty) return;

    // Chạy song song tất cả các request đánh dấu để nhanh nhất
    try {
      await Future.wait(unreadMsgs.map((m) => 
        supabase.rpc('append_read_by', params: {
          'msg_id': m['id'], 
          'user_id': user.id
        })
      ));
    } catch (e) {
      print("MARK READ ERROR: $e");
    }
  }
}
