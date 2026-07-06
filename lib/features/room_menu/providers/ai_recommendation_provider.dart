import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../main.dart';
import 'room_menu_provider.dart';

class RoomContext {
  final double temp;
  final String weather;
  final int hour;
  final List<String> activeContextTags;
  final bool isApiError;

  RoomContext({
    required this.temp,
    required this.weather,
    required this.hour,
    required this.activeContextTags,
    this.isApiError = false,
  });
}

// Provider lưu lựa chọn thủ công của khách khi API lỗi
class UserManualPreferenceNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void update(String? val) {
    state = val;
  }
}

final userManualPreferenceProvider =
    NotifierProvider<UserManualPreferenceNotifier, String?>(
        UserManualPreferenceNotifier.new);

final roomContextProvider = FutureProvider<RoomContext>((ref) async {
  const String apiKey = '895284fb2d2c1d873467657930104895';
  const String city = 'Da Lat';
  final now = DateTime.now();
  final manualPref = ref.watch(userManualPreferenceProvider);

  double currentTemp = 27.0;
  String weatherDesc = 'Clear';
  bool isApiError = false;

  // 1. LẤY THỜI TIẾT THẬT
  try {
    final response = await http
        .get(Uri.parse(
            'https://api.openweathermap.org/data/2.5/weather?q=$city&units=metric&appid=$apiKey'))
        .timeout(const Duration(seconds: 3));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      currentTemp = data['main']['temp'].toDouble();
      weatherDesc = data['weather'][0]['main'];
    } else {
      isApiError = true;
    }
  } catch (e) {
    isApiError = true;
  }

  // 2. LẤY QUY TẮC TỪ DATABASE
  final rules = await supabase.from('context_rules').select();
  List<String> activeTagIds = [];

  for (var rule in rules) {
    bool isMatched = false;
    final type = rule['criteria_type'];
    final name = rule['rule_name'];

    // ƯU TIÊN 1: Nếu khách đã chọn thủ công qua Popup (Kịch bản API lỗi)
    if (isApiError && manualPref != null) {
      if (manualPref == 'COOL' && name == 'Giải nhiệt ngày nóng') isMatched = true;
      if (manualPref == 'WARM' && name == 'Món ấm ngày lạnh') isMatched = true;
    }
    // ƯU TIÊN 2: Nếu API chạy bình thường hoặc theo khung giờ
    else {
      if (type == 'TEMPERATURE' && !isApiError) {
        double min = double.tryParse(rule['min_value']?.toString() ?? '-100') ?? -100;
        double max = double.tryParse(rule['max_value']?.toString() ?? '100') ?? 100;
        if (currentTemp >= min && currentTemp <= max) isMatched = true;
      } else if (type == 'TIME_RANGE') {
        int minHour = int.tryParse(rule['min_value']?.toString() ?? '0') ?? 0;
        int maxHour = int.tryParse(rule['max_value']?.toString() ?? '24') ?? 24;
        if (now.hour >= minHour && now.hour <= maxHour) isMatched = true;
      }
    }

    if (isMatched && rule['tag_id'] != null) {
      activeTagIds.add(rule['tag_id'].toString());
    }
  }

  // 3. DỰ PHÒNG: Nếu vẫn trống (không khớp quy tắc nào), tìm thẻ "Trưa" hoặc "Trời nóng" để luôn có gợi ý
  if (activeTagIds.isEmpty) {
    final backupTags = await supabase
        .from('tags')
        .select('id')
        .or('name.eq.Trưa,name.eq.Trời nóng');
    if (backupTags.isNotEmpty) {
      activeTagIds = (backupTags as List).map((t) => t['id'].toString()).toList();
    }
  }

  return RoomContext(
    temp: currentTemp,
    weather: weatherDesc,
    hour: now.hour,
    activeContextTags: activeTagIds,
    isApiError: isApiError,
  );
});

final aiRecommendedItemsProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final menuAsync = ref.watch(menuItemsWithTagsProvider);
  final contextAsync = ref.watch(roomContextProvider);

  if (menuAsync.value == null || contextAsync.value == null) {
    return const AsyncValue.loading();
  }

  final menu = menuAsync.value!;
  final roomCtx = contextAsync.value!;

  if (roomCtx.activeContextTags.isEmpty) {
    return const AsyncValue.data([]);
  }

  var scoredItems = menu.map((item) {
    final itemTagIds = (item['tag_ids'] as List? ?? []).cast<String>();
    int score = 0;
    for (var activeId in roomCtx.activeContextTags) {
      if (itemTagIds.contains(activeId)) score++;
    }
    return {'item': item, 'score': score};
  }).toList();

  scoredItems.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

  final result = scoredItems
      .where((s) => (s['score'] as int) > 0)
      .take(4)
      .map((s) => s['item'] as Map<String, dynamic>)
      .toList();

  return AsyncValue.data(result);
});
