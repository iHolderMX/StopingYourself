import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  Future<List<Map<String, dynamic>>> extractReceiptData(String base64Image) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'tu_api_key_aqui') {
      throw Exception('API Key de OpenAI no configurada en el archivo .env');
    }

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4o',
        'messages': [
          {
            'role': 'system',
            'content': 'Eres un asistente experto en extraer datos de tickets de compra. Tu objetivo es devolver un JSON estricto con una lista de productos y sus precios. El formato debe ser: {"items": [{"name": "Producto 1", "price": 10.50}, {"name": "Producto 2", "price": 5.00}]}. No incluyas texto adicional, solo el JSON válido.'
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': 'Extrae los productos y precios de este ticket de compra.'
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image'
                }
              }
            ]
          }
        ],
        'max_tokens': 1000,
        'response_format': {'type': 'json_object'}
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices'][0]['message']['content'];
      final parsedContent = jsonDecode(content);
      
      if (parsedContent['items'] != null) {
        return List<Map<String, dynamic>>.from(parsedContent['items']);
      }
      return [];
    } else {
      throw Exception('Error al procesar la imagen: ${response.body}');
    }
  }
}
