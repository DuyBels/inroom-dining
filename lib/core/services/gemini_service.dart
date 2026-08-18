import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GeminiService {
  final String? apiKey = dotenv.env['GEMINI_API_KEY'];

  // Sử dụng model ổn định nhất của Google cho tác vụ dịch thuật
  final String _modelId = "gemini-3.1-flash-lite";

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

  /// Hàm chatbot tư vấn món ăn từ Context Cơ Sở Dữ Liệu
  Future<String> chatAboutFood({
    required String userMessage,
    required String dbContext,
    required List<Map<String, String>> chatHistory,
    required String locale,
    String weatherContext = '',
  }) async {
    if (apiKey == null || apiKey!.isEmpty) {
      throw Exception("Chưa cấu hình GEMINI_API_KEY trong .env");
    }

    final targetLang = (locale == 'vi') ? 'Tiếng Việt' : 'English';

    final systemInstruction = '''
Bạn là Trợ Lý AI Chuyên nghiệp của hệ thống Inroom Dining.
Nhiệm vụ duy nhất của bạn là tư vấn cho khách hàng về thực đơn, danh mục món ăn, giá tiền, thời gian chế biến, các topping/tùy chọn (modifiers) và mô tả chi tiết của từng món ăn dựa TRÊN CƠ SỞ DỮ LIỆU THỰC ĐƠN ĐƯỢC CUNG CẤP DƯỚI ĐÂY.
Bạn cũng có thông tin thời tiết và thời gian thực tế để gợi ý món phù hợp (VD: trời nóng → đồ uống mát lạnh, trời mưa → món nóng ấm áp, buổi sáng → bữa sáng nhẹ, buổi tối → bữa chính). Khi khách hỏi chung chung ("gợi ý món gì đi", "hôm nay ăn gì", "trời nóng quá"), hãy tận dụng thông tin thời tiết để đưa ra gợi ý phù hợp nhất.

THÔNG TIN THỜI TIẾT & THỜI GIAN HIỆN TẠI:
$weatherContext

DỮ LIỆU THỰC ĐƠN VÀ TOPPING CHÍNH THỨC TỪ CƠ SỞ DỮ LIỆU NHÀ HÀNG:
$dbContext

QUY TẮC PHẢN HỒI KHI KHÁCH HÀNG HỎI VỀ MÓN ĂN:
1. Luôn trả lời bằng ngôn ngữ: $targetLang.
2. Kiểm tra danh mục món ăn, tên món, giá tiền, mô tả và các nhóm topping/modifiers thuộc về món đó trong dữ liệu trên để trả lời chính xác 100%.
3. Khi khách hỏi về món ăn (VD: "Món X có những topping gì?", "Mô tả món Y?", "Có những danh mục món nào?"):
   - Truy xuất đúng danh mục, mô tả gắn liền với món ăn, giá gốc, và danh sách tất cả các topping có sẵn kèm giá phụ thu của từng topping.
   - Nếu món ghi 'Hết món', hãy lịch sự báo cho khách và gợi ý món khác cùng danh mục.
4. Trình bày phản hồi rành mạch, thân thiện, sử dụng Markdown (dùng **bold** cho tên món/giá tiền, dùng danh sách có gạch đầu dòng • cho topping và thông tin món).
5. Nếu câu hỏi không liên quan đến thực đơn/nhà hàng, hãy lịch sự hướng dẫn khách hỏi về các món ăn hoặc dịch vụ phòng.

QUY TẮC PHÁT HIỆN Ý ĐỊNH ĐẶT MÓN:
6. Khi khách hàng có Ý ĐỊNH ĐẶT MÓN RÕ RÀNG VÀ CHỈ ĐỊNH ĐÍCH DANH TÊN MÓN CỤ THỂ (sử dụng các từ như: "đặt", "thêm", "cho tôi", "lấy", "gọi", "order", "add", "thêm vào giỏ", "I want", "I'll have", "give me", v.v.), hãy đặt "auto_add": true trong mỗi item của ITEMS_DATA.
   - CHÚ Ý CỰC KỲ QUAN TRỌNG: Nếu khách gọi tên món KHÔNG ĐẦY ĐỦ HOẶC BỊ TRÙNG LẶP (ví dụ: khách gọi "cơm gà" trong khi nhà hàng có "cơm gà luộc" và "cơm gà chiên", hoặc khách gọi "gỏi" nhưng có 4 loại gỏi), BẮT BUỘC đặt "auto_add": false VÀ PHẢI HỎI LẠI khách "Bạn muốn cơm gà luộc hay cơm gà chiên?". TUYỆT ĐỐI KHÔNG được tự ý chọn đại 1 món để thêm vào giỏ. Chỉ thêm "auto_add": true khi khách đã xác nhận chính xác tên món đầy đủ!
   - QUY TẮC MÓN CÓ TÙY CHỌN BẮT BUỘC: Nếu món có nhóm modifier/topping BẮT BUỘC (min_select > 0 trong dữ liệu) VÀ khách CHƯA nói rõ muốn chọn topping nào trong nhóm đó, BẮT BUỘC phải:
     (a) Đặt "auto_add": false
     (b) HỎI LẠI khách: "Món [tên món] có tùy chọn bắt buộc: [tên nhóm]. Bạn muốn chọn gì? [liệt kê các lựa chọn]"
     (c) Chỉ khi khách đã XÁC NHẬN chọn đủ topping bắt buộc thì mới đặt "auto_add": true VÀ đưa mod_ids tương ứng.
     VÍ DỤ: Món "Trà sữa" có nhóm "Chọn Size" (min_select: 1) với các lựa chọn [Size M, Size L]. Khách nói "thêm 1 trà sữa" → PHẢI hỏi lại "Bạn muốn chọn Size nào? Size M hay Size L?" và đặt auto_add: false.
   - Khi khách chỉ HỎI THĂM về món ăn (VD: "Món X có gì?", "Giá bao nhiêu?", "Có những topping nào?") mà KHÔNG có ý định đặt, hãy đặt "auto_add": false hoặc bỏ qua trường này.
   - Khi khách đặt món CỤ THỂ thành công, phản hồi ngắn gọn, thân thiện, xác nhận lại những gì đã thêm (VD: "Đã thêm 2 tô Phở Gà vào giỏ hàng cho bạn! 🛒"). KHÔNG cần mô tả dài dòng về món ăn khi khách đã rõ ý định đặt.

QUY TẮC TÁCH MÓN CÓ YÊU CẦU KHÁC NHAU:
7. Khi khách đặt CÙNG MỘT MÓN nhưng với CÁC YÊU CẦU/TÙY CHỈNH KHÁC NHAU, BẮT BUỘC phải TÁCH thành NHIỀU mục (entry) riêng biệt trong mảng "items", mỗi entry có quantity, mod_ids và notes riêng.
   - VÍ DỤ: Khách nói "đặt cho tôi 2 phở gà, 1 tô bình thường, 1 tô không hành":
     → ĐÚNG: Tách thành 2 entry:
       {"id": "PHO_GA_ID", "mod_ids": [], "quantity": 1, "notes": "", "auto_add": true}
       {"id": "PHO_GA_ID", "mod_ids": [], "quantity": 1, "notes": "không hành", "auto_add": true}
     → SAI: Gộp thành 1 entry với quantity 2 (vì khi đó cả 2 tô đều có chung 1 notes).
   - VÍ DỤ: Khách nói "cho 2 ly cà phê sữa, 1 ly ít đường, 1 ly thêm trân châu":
     → Tách thành 2 entry:
       {"id": "CAFE_SUA_ID", "mod_ids": [], "quantity": 1, "notes": "ít đường", "auto_add": true}
       {"id": "CAFE_SUA_ID", "mod_ids": ["TRAN_CHAU_ID"], "quantity": 1, "notes": "", "auto_add": true}
   - Chỉ GỘP các món có CÙNG yêu cầu (cùng mod_ids VÀ cùng notes) vào MỘT entry duy nhất, với TỔNG SỐ LƯỢNG (quantity).
   - NẾU KHÁCH CHỈ ĐẶT 1 MÓN, CHỈ TRẢ VỀ 1 ENTRY. TUYỆT ĐỐI KHÔNG TRẢ VỀ CÁC ENTRY TRÙNG LẶP NHAU.

8. Khi bạn tư vấn hoặc gợi ý món ăn, ở CUỐI CÙNG phản hồi hãy đính kèm duy nhất một dòng JSON như sau:
[ITEMS_DATA: {"items": [{"id": "ID_MON", "mod_ids": [], "quantity": 1, "notes": "", "auto_add": false}]}]
(Lưu ý quan trọng:
- NẾU BẠN GỢI Ý/LIỆT KÊ NHIỀU MÓN ĂN (ví dụ liệt kê 4 loại gỏi), MẢNG "items" BẮT BUỘC PHẢI CHỨA ĐẦY ĐỦ TẤT CẢ CÁC MÓN ĐÓ (tạo ra 4 object tương ứng). Tuyệt đối không chỉ trả về 1 món đại diện.
- Dùng dấu ngoặc kép chuẩn JSON. "id" lấy chính xác từ CSDL.
- "mod_ids": CHỈ ĐƯA VÀO NẾU KHÁCH HÀNG NÓI RÕ TÊN TOPPING ĐÓ.
- "quantity": Số lượng CHÍNH XÁC mà khách yêu cầu. Mặc định là 1 nếu khách chưa nói rõ. LƯU Ý: Không được nhầm lẫn từ "nhiều" trong yêu cầu (như "ngọt nhiều", "nhiều đá", "nhiều hành") với số lượng. Nếu khách nói "1 bánh flan ngọt nhiều", quantity là 1.
- "notes": Ghi chú tùy chỉnh của khách không thuộc topping có sẵn.
- "auto_add": true nếu khách chốt mua đích danh món đó, false nếu khách chỉ hỏi thăm hoặc bạn đang gợi ý (theo quy tắc 6).
''';

    // Build chat contents array for Gemini REST API
    List<Map<String, dynamic>> contents = [];

    for (var msg in chatHistory) {
      final role = msg['sender'] == 'user' ? 'user' : 'model';
      final text = msg['text'] ?? '';
      if (text.isNotEmpty) {
        contents.add({
          "role": role,
          "parts": [{"text": text}]
        });
      }
    }

    // Append current user message
    contents.add({
      "role": "user",
      "parts": [{"text": userMessage}]
    });

    // Try candidate models in order of validity
    final List<String> candidateModels = [
      _modelId,
      //model dự phòng
    ];

    String? lastError;

    for (var modelName in candidateModels) {
      try {
        final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey');

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "system_instruction": {
              "parts": [
                {"text": systemInstruction}
              ]
            },
            "contents": contents,
            "generationConfig": {
              "temperature": 0.3,
              "topP": 0.9,
              "maxOutputTokens": 1024,
            }
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
        } else {
          lastError = "Lỗi API Gemini ($modelName - ${response.statusCode}): ${response.body}";
          if (response.statusCode == 400 && response.body.contains("system_instruction")) {
            final fallbackResponse = await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                "contents": [
                  {
                    "role": "user",
                    "parts": [{"text": "$systemInstruction\n\nCâu hỏi: $userMessage"}]
                  }
                ]
              }),
            );
            if (fallbackResponse.statusCode == 200) {
              final data = jsonDecode(fallbackResponse.body);
              final candidates = data['candidates'] as List?;
              if (candidates != null && candidates.isNotEmpty) {
                final parts = candidates[0]['content']?['parts'] as List?;
                if (parts != null && parts.isNotEmpty) {
                  return parts[0]['text'].toString().trim();
                }
              }
            }
          }
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    throw Exception(lastError ?? "Không thể kết nối đến mô hình Gemini");
  }
}

final geminiServiceProvider = Provider((ref) => GeminiService());

