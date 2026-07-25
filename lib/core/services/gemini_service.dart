import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeminiService {
  final String? apiKey = dotenv.env['GEMINI_API_KEY'];

  // Sử dụng model ổn định nhất của Google cho tác vụ dịch thuật
  final String _modelId = "gemini-3.5-flash-lite";

  Future<String> translate(String text, {String sourceLanguage = "Vietnamese", String targetLanguage = "English"}) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception("Chưa cấu hình GEMINI_API_KEY trong file .env");
    }

    if (text.isEmpty) return "";

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_modelId:generateContent?key=$apiKey');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": "Translate the following $sourceLanguage text to $targetLanguage. Return ONLY the translated text, no extra explanation, no markdown, no quotes:\n\n$text"
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = candidates[0]['content']?['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'].toString().trim();
        }
      }
      throw Exception("Phản hồi dịch thuật không hợp lệ từ AI");
    } else {
      throw Exception("Lỗi API Gemini (${response.statusCode}): ${response.body}");
    }
  }

  /// Tự động dịch giữa 2 trường VI và EN.
  /// - Nếu cả 2 đều có dữ liệu: giữ nguyên, KHÔNG dịch ("khi các trường có đủ thì khong cần dịch").
  /// - Nếu VI có và EN trống: dịch VI -> EN.
  /// - Nếu EN có và VI trống: dịch EN -> VI ("khi tôi nhập tiếng anh thì dịch ngược ra tiếng Việt").
  /// - Nếu [force] = true: buộc dịch từ trường có dữ liệu sang trường kia.
  Future<void> autoTranslatePair({
    required TextEditingController viController,
    required TextEditingController enController,
    bool force = false,
  }) async {
    final viText = viController.text.trim();
    final enText = enController.text.trim();

    if (!force && viText.isNotEmpty && enText.isNotEmpty) {
      return;
    }

    if (viText.isNotEmpty && (enText.isEmpty || force)) {
      final translated = await translate(viText, sourceLanguage: "Vietnamese", targetLanguage: "English");
      if (translated.isNotEmpty) {
        enController.text = translated;
      }
    } else if (enText.isNotEmpty && (viText.isEmpty || force)) {
      final translated = await translate(enText, sourceLanguage: "English", targetLanguage: "Vietnamese");
      if (translated.isNotEmpty) {
        viController.text = translated;
      }
    }
  }

  /// Tự động dịch cho Map các TextEditingController theo mã ngôn ngữ (vi, en, ...).
  /// Tự động tìm trường ngôn ngữ có dữ liệu để dịch sang các trường còn thiếu.
  Future<void> autoTranslateMap(Map<String, TextEditingController> controllers, {bool force = false}) async {
    String? sourceCode;
    String? sourceText;

    // Ưu tiên VI nếu có, tiếp theo EN, rồi các ngôn ngữ khác
    if (controllers['vi']?.text.trim().isNotEmpty == true) {
      sourceCode = 'vi';
      sourceText = controllers['vi']!.text.trim();
    } else if (controllers['en']?.text.trim().isNotEmpty == true) {
      sourceCode = 'en';
      sourceText = controllers['en']!.text.trim();
    } else {
      for (var entry in controllers.entries) {
        if (entry.value.text.trim().isNotEmpty) {
          sourceCode = entry.key;
          sourceText = entry.value.text.trim();
          break;
        }
      }
    }

    if (sourceCode == null || sourceText == null || sourceText.isEmpty) return;

    final sourceLangName = sourceCode == 'vi' ? 'Vietnamese' : (sourceCode == 'en' ? 'English' : sourceCode);

    for (var entry in controllers.entries) {
      final code = entry.key;
      final controller = entry.value;
      if (code != sourceCode && (controller.text.trim().isEmpty || force)) {
        final targetLangName = code == 'vi' ? 'Vietnamese' : (code == 'en' ? 'English' : code);
        try {
          final translated = await translate(
            sourceText,
            sourceLanguage: sourceLangName,
            targetLanguage: targetLangName,
          );
          if (translated.isNotEmpty) {
            controller.text = translated;
          }
        } catch (_) {}
      }
    }
  }

  /// Hàm gợi ý món ăn cho khách
  Future<String> getSuggestion(String prompt, String locale, String menuContext) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception("Chưa cấu hình GEMINI_API_KEY trong .env");
    }

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_modelId:generateContent?key=$apiKey');

    final targetLang = (locale == 'vi') ? 'Vietnamese' : 'English';
    final fullPrompt = "$prompt\n\nContext:\n$menuContext\n\nPlease respond in $targetLang.";

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [{"text": fullPrompt}]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final parts = candidates[0]['content']?['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'].toString().trim();
        }
      }
      throw Exception("Phản hồi gợi ý không hợp lệ");
    } else {
      throw Exception("Lỗi AI gợi ý: ${response.body}");
    }
  }
}

final geminiServiceProvider = Provider((ref) => GeminiService());

