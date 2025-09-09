import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import '../config/supabase_config.dart';

class ImageGenerationService {
  final supabase = SupabaseConfig.client;

  // Replace with your actual Edge Function name
  static const String _functionName = 'initiate-generation';

  Future<Map<String, dynamic>> generate({
    required String presetName,
    String? userDescription,
    XFile? sourceImage,
  }) async {
    // 1. Get the currently logged-in user's token for authorization
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw Exception('User is not authenticated.');
    }

    // Always use multipart/form-data for this endpoint
    final url = Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/$_functionName');
    final request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    // Provide anon key for Edge Functions that expect it
    request.headers['apikey'] = SupabaseConfig.supabaseAnonKey;
    request.fields['preset_name'] = presetName;

    if (userDescription != null) {
      print('Preparing Text-to-Image request (multipart/form-data)...');
      request.fields['user_description'] = userDescription;
    } else if (sourceImage != null) {
      print('Preparing Image-to-Image request (multipart/form-data)...');
      request.files.add(
        await http.MultipartFile.fromPath(
          'source_image',
          sourceImage.path,
          contentType: MediaType('image', sourceImage.mimeType?.split('/')[1] ?? 'png'),
        ),
      );
    } else {
      throw Exception('Must provide either a description or an image.');
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final body = response.body;
      if (response.statusCode == 200) {
        print('SUCCESS: Job created successfully!');
        print('Response body: $body');
        try {
          final decoded = json.decode(body) as Map<String, dynamic>;
          return decoded;
        } catch (_) {
          return {'success': true};
        }
      } else {
        print('ERROR: Failed to create job.');
        print('Status code: ${response.statusCode}');
        print('Response body: $body');
        throw Exception('Failed to create generation job.');
      }
    } catch (e, stack) {
      print('Exception during image generation request: ${e.toString()}');
      print('Stack trace: ${stack.toString()}');
      rethrow;
    }
  }
} 
