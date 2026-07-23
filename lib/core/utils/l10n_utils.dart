import 'dart:convert';

class L10nUtils {
  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'vi', 'name': 'Tiếng Việt'},
    {'code': 'en', 'name': 'English'},
  ];

  static String getL10n(dynamic jsonField, String locale) {
    if (jsonField == null) return '';
    
    dynamic data = jsonField;

    // Nếu dữ liệu là String, thử kiểm tra xem có phải chuỗi JSON (bắt đầu bằng { và kết thúc bằng })
    if (jsonField is String) {
      final trimmed = jsonField.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          data = jsonDecode(trimmed);
        } catch (_) {
          return jsonField; // Không phải JSON thực sự
        }
      } else {
        return jsonField; // String bình thường
      }
    }
    
    if (data is Map) {
      final requested = data[locale]?.toString();
      if (requested != null && requested.trim().isNotEmpty) {
        return requested;
      }
      final viFallback = data['vi']?.toString();
      if (viFallback != null && viFallback.trim().isNotEmpty) {
        return viFallback;
      }
      return data.values.firstOrNull?.toString() ?? '';
    }
    
    return data.toString();
  }

  /// Hàm giải mã field JSONB thành Map an toàn để dùng trong các Form nhập liệu
  static Map<String, dynamic> decodeField(dynamic field) {
    if (field == null) return {};
    if (field is Map) return Map<String, dynamic>.from(field);
    if (field is String) {
      final trimmed = field.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        try {
          return Map<String, dynamic>.from(jsonDecode(trimmed));
        } catch (_) {}
      }
      return {'vi': field}; // Nếu là chuỗi thường, coi như là Tiếng Việt
    }
    return {};
  }
}
