import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiInterface {
  final String baseUrl;
  static const String apikey = String.fromEnvironment("API_KEY");

  ApiInterface({required this.baseUrl});

  Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('$baseUrl/$endpoint');
    return http.get(url);
  }

  Future<http.Response> post(String endpoint,
      {Map<String, dynamic>? body, File? file}) async {
    final url = Uri(
        scheme: "https", host: baseUrl, path: endpoint, fragment: "numbers");

    // Create a multipart request
    var request = http.MultipartRequest('POST', url);

    // Add headers
    request.headers.addAll({
      "Authorization": "Bearer $apikey", // Use actual token here
      "Accept": "application/json*"
    });

    // Add text fields from body
    body?.forEach((key, value) {
      request.fields[key] = value.toString();
    });

    // Check if there's a file to add
    if (file != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'file_field', // Adjust field name as required by your endpoint
        file.path,
      ));
    }

    // Send the request
    var streamedResponse = await request.send();

    // Get the response back and convert to http.Response
    return await http.Response.fromStream(streamedResponse);
  }
}
