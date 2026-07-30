import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';

// Provider lắng nghe trạng thái Session của Supabase
final sessionStreamProvider = StreamProvider.autoDispose((ref) {
  return supabase.auth.onAuthStateChange;
});

// Provider lấy User hiện tại
final currentUserProvider = Provider.autoDispose((ref) {
  return supabase.auth.currentUser;
});

// Provider lấy Profile tập trung (Dùng cho toàn app để check Role)
// autoDispose giúp xóa cache ngay khi người dùng logout hoặc đóng tab
final userProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  // Lắng nghe auth state change để trigger reload profile khi login/logout
  final authState = ref.watch(sessionStreamProvider);
  
  if (authState.value?.event == AuthChangeEvent.signedOut) {
    return null;
  }

  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final data = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .maybeSingle();
  return data;
});
