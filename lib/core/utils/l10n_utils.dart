class L10nUtils {
  /// Hàm hỗ trợ lấy văn bản từ cột JSONB dựa trên ngôn ngữ hiện tại
  /// format: {"vi": "...", "en": "..."}
  static String getL10n(dynamic jsonField, String locale) {
    if (jsonField == null) return '';
    if (jsonField is String) return jsonField;
    
    if (jsonField is Map) {
      final requested = jsonField[locale]?.toString();
      // Nếu có giá trị và không phải chuỗi rỗng thì lấy, ngược lại lấy 'vi'
      if (requested != null && requested.trim().isNotEmpty) {
        return requested;
      }
      return jsonField['vi']?.toString() ?? '';
    }
    
    return '';
  }
}
