import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';

class ApiService {
  // URL for your Node.js backend
  static const String _nodeBaseUrl = "https://clearview-backend.onrender.com/api"; 
  
  // --- UPDATE THIS LINE ---
  // URL for your NEW Python analysis backend
  static const String _pythonBaseUrl = "https://clearview-analysis.onrender.com"; // <-- PASTE YOUR NEW PYTHON SERVER URL HERE

  // ... existing login, register, saveTestResult, getTestHistory functions ...

  static Future<Map<String, dynamic>?> analyzeKeratometryImage(XFile imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_pythonBaseUrl/analyze_cornea'),
      );

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        return json.decode(responseBody);
      } else {
        print('Image analysis failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error uploading image for analysis: $e');
      return null;
    }
  }
}