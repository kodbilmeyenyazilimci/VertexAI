import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

class ApiService {
  final String googleApiKey = dotenv.env['API_KEY'] ?? '';
  final String openRouterApiKey = dotenv.env['API_KEY_2'] ?? '';

  // Google Generative AI için fonksiyon
  Future<String> getGeminiResponse(String userInput) async {
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: googleApiKey);

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final content = [Content.text(userInput)];
        final response = await model.generateContent(content);
        return response.text ?? 'Cevap alınamadı';
      } catch (e) {
        if (attempt == 3) {
          throw Exception('Google API isteği 3 kez başarısız oldu: $e');
        }
        await Future.delayed(Duration(seconds: 2)); // Bir sonraki denemeden önce bekleme süresi
      }
    }
    return 'Cevap alınamadı';
  }

  // OpenRouter için güncellenmiş fonksiyon
  Future<String> getLlamaResponse(String userInput) async {
    const String url = "https://openrouter.ai/api/v1/chat/completions";

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {
            "Authorization": "Bearer $openRouterApiKey",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "model": "meta-llama/llama-3.2-90b-vision-instruct:free",
            "messages": [
              {"role": "user", "content": userInput}
            ],
          }),
        );

        final decodedBody = utf8.decode(response.bodyBytes);
        print('OpenRouter Response Status: ${response.statusCode}');
        print('OpenRouter Decoded Response Body: $decodedBody');

        if (response.statusCode == 200) {
          var data = jsonDecode(decodedBody);
          print('Decoded JSON: $data');

          if (data != null && data['choices'] != null && data['choices'].isNotEmpty) {
            var message = data['choices'][0]['message'];
            if (message != null && message['content'] != null) {
              return message['content'];
            } else {
              throw Exception('Yanıt yapısı beklenenden farklı: message veya content eksik');
            }
          } else {
            throw Exception('Yanıt yapısı beklenenden farklı: choices eksik veya boş');
          }
        } else {
          throw Exception("OpenRouter API isteği başarısız oldu: ${response.statusCode} - $decodedBody");
        }
      } catch (e) {
        if (attempt == 3) {
          throw Exception('OpenRouter API isteği 3 kez başarısız oldu: $e');
        }
        await Future.delayed(Duration(seconds: 2)); // Bir sonraki denemeden önce bekleme süresi
      }
    }
    return 'Cevap alınamadı';
  }

  // OpenRouter için Hermes 3 fonksiyonu
  Future<String> getHermesResponse(String userInput) async {
    const String url = "https://openrouter.ai/api/v1/chat/completions";

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {
            "Authorization": "Bearer $openRouterApiKey",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "model": "nousresearch/hermes-3-llama-3.1-405b:free",
            "messages": [
              {"role": "user", "content": userInput}
            ],
          }),
        );

        final decodedBody = utf8.decode(response.bodyBytes);
        print('OpenRouter Response Status: ${response.statusCode}');
        print('OpenRouter Decoded Response Body: $decodedBody');

        if (response.statusCode == 200) {
          var data = jsonDecode(decodedBody);
          print('Decoded JSON: $data');

          if (data != null && data['choices'] != null && data['choices'].isNotEmpty) {
            var message = data['choices'][0]['message'];
            if (message != null && message['content'] != null) {
              return message['content'];
            } else {
              throw Exception('Yanıt yapısı beklenenden farklı: message veya content eksik');
            }
          } else {
            throw Exception('Yanıt yapısı beklenenden farklı: choices eksik veya boş');
          }
        } else {
          throw Exception("OpenRouter API isteği başarısız oldu: ${response.statusCode} - $decodedBody");
        }
      } catch (e) {
        if (attempt == 3) {
          throw Exception('OpenRouter API isteği 3 kez başarısız oldu: $e');
        }
        await Future.delayed(Duration(seconds: 2)); // Bir sonraki denemeden önce bekleme süresi
      }
    }
    return 'Cevap alınamadı';
  }
}
