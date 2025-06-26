import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = "http://192.168.0.106:3000/api/auth"; 

  static Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        // The backend now sends user data directly in the 'user' field
        return data['user'];
      } else {
        final errorData = json.decode(response.body);
        print('Login failed: ${errorData['error']}');
        return null;
      }
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }

  static Future<bool> registerUser(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'email': email, 'password': password}),
      );

      if (response.statusCode == 201) { // 201 Created for successful registration
        print('Registration successful!');
        return true;
      } else {
        final errorData = json.decode(response.body);
        print('Registration failed: ${errorData['error']}');
        return false;
      }
    } catch (e) {
      print('Error during registration: $e');
      return false;
    }
  }

  // Add more API calls here as needed (e.g., fetching test results)
}