import 'package:http/http.dart' as http;

void main() async {
  print('Testing HF Space from Dart...');
  final uri = Uri.parse('https://negzaoui-antiimagesenvirement.hf.space/scan');
  final request = http.MultipartRequest('POST', uri);
  request.headers['Authorization'] = 'Bearer YOUR_TOKEN_HERE';
  
  // Create dummy image bytes
  final bytes = List<int>.generate(100, (i) => i);
  request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: 'test.jpg'));
  
  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    print('Status: ${response.statusCode}');
    print('Body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}

