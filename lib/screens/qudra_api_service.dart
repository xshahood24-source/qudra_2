import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
class QudraApiService {
  // ملحوظة: لو بتجربي على موبايل حقيقي، غيري localhost للـ IP بتاع جهازك
  final String baseUrl = "http://10.0.2.2:8000";
  Future<String> analyzeImage(File imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/analyze'));
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body); // غيري data لـ body
        // بنرجع الرسالة اللي شفناها في المتصفح (Image Analysis API is running) 
        // أو الوصف اللي الـ API هيطلعه بعد كدة
        return data['message'] ?? "لم يتم العثور على وصف";
      } else {
        return "خطأ في الاتصال بالسيرفر";
      }
    } catch (e) {
      return "حدث خطأ: $e";
    }
  }
}