import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeminiService {
  final String? apiKey = dotenv.env['GEMINI_API_KEY'];

  Future<String> translate(String text, {String sourceLanguage = "Vietnamese", String targetLanguage = "English"}) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception("Chưa cấu hình GEMINI_API_KEY trong .env");
    }

    if (text.isEmpty) return "";

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent?key=$apiKey');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": "Translate the following $sourceLanguage text to $targetLanguage. Return ONLY the translated text, no extra explanation:\n\n$text"
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
    } else {
      throw Exception("Gemini Error: ${response.body}");
    }
  }

  /// Hàm gợi ý món ăn thông minh cho khách
  Future<String> getSuggestion(String userInput, String locale, String menuContext) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception("Chưa cấu hình GEMINI_API_KEY trong .env");
    }

    final languageName = locale == 'vi' ? 'Vietnamese' : 'English';
    
    final prompt = """
      You are a luxury hotel room service assistant.
      The customer says: "$userInput"
      The current app language is $languageName. 
      Please respond POLITELY and ONLY in $languageName.
      
      Based on this menu: $menuContext
      Suggest the best 3 items.
    """;
    
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent?key=$apiKey');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
                "text": prompt
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
    } else {
      throw Exception("Gemini Error: ${response.body}");
    }
  }
}

final geminiServiceProvider = Provider((ref) => GeminiService());
