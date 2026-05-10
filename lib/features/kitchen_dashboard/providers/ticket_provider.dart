import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

// StreamProvider tự động quản lý vòng đời của WebSockets
final kitchenTicketsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, stationId) {
  // Lắng nghe các thay đổi trên bảng 'tickets' dành riêng cho stationId này
  return supabase
      .from('tickets')
      .stream(primaryKey: ['id'])
      .eq('station_id', stationId)
      .order('created_at', ascending: true) // Vé cũ làm trước
      .map((data) => data);
});