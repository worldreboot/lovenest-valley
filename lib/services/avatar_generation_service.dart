import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lovenest/config/supabase_config.dart';

class AvatarGenerationService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Generate a custom avatar and spritesheet for a user from text description
  Future<Map<String, dynamic>> generateUserAvatar({
    required String userId,
    required String userPrompt,
    Map<String, dynamic>? stylePreferences,
  }) async {
    try {
      // Update profile with generation status
      await _supabase
          .from('profiles')
          .update({
            'avatar_generation_status': 'generating',
            'avatar_generation_prompt': userPrompt,
            'avatar_style_preferences': stylePreferences ?? {},
          })
          .eq('id', userId);

      // Call the initiate-generation Edge Function
      final result = await _callInitiateGenerationEdgeFunction(
        userPrompt: userPrompt,
        stylePreferences: stylePreferences,
      );

      if (result['success']) {
        final jobId = result['jobId'];
        
        // Update profile with job ID
        await _supabase
            .from('profiles')
            .update({
              'spritesheet_generation_job_id': jobId,
            })
            .eq('id', userId);

        return {
          'success': true,
          'job_id': jobId,
          'message': 'Avatar generation started successfully',
        };
      } else {
        // Update status to failed
        await _supabase
            .from('profiles')
            .update({
              'avatar_generation_status': 'failed',
            })
            .eq('id', userId);

        return {
          'success': false,
          'error': result['error'] ?? 'Failed to start generation',
        };
      }
    } catch (e) {
      // Update status to failed
      await _supabase
          .from('profiles')
          .update({
            'avatar_generation_status': 'failed',
          })
          .eq('id', userId);

      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Generate a custom avatar and spritesheet for a user from an image
  Future<Map<String, dynamic>> generateUserAvatarFromImage({
    required String userId,
    required File imageFile,
    String? userPrompt,
    Map<String, dynamic>? stylePreferences,
  }) async {
    try {
      // Update profile with generation status
      await _supabase
          .from('profiles')
          .update({
            'avatar_generation_status': 'generating',
            'avatar_generation_prompt': userPrompt ?? 'Generate spritesheet from user image',
            'avatar_style_preferences': stylePreferences ?? {},
          })
          .eq('id', userId);

      // Call the initiate-generation Edge Function with image
      final result = await _callInitiateGenerationEdgeFunctionWithImage(
        imageFile: imageFile,
        userPrompt: userPrompt,
        stylePreferences: stylePreferences,
      );

      if (result['success']) {
        final jobId = result['jobId'];
        
        // Update profile with job ID
        await _supabase
            .from('profiles')
            .update({
              'spritesheet_generation_job_id': jobId,
            })
            .eq('id', userId);

        return {
          'success': true,
          'job_id': jobId,
          'message': 'Avatar generation started successfully',
        };
      } else {
        // Update status to failed
        await _supabase
            .from('profiles')
            .update({
              'avatar_generation_status': 'failed',
            })
            .eq('id', userId);

        return {
          'success': false,
          'error': result['error'] ?? 'Failed to start generation',
        };
      }
    } catch (e) {
      // Update status to failed
      await _supabase
          .from('profiles')
          .update({
            'avatar_generation_status': 'failed',
          })
          .eq('id', userId);

      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Call the initiate-generation Edge Function
  Future<Map<String, dynamic>> _callInitiateGenerationEdgeFunction({
    required String userPrompt,
    Map<String, dynamic>? stylePreferences,
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      // Build the final prompt combining user input and style preferences
      final finalPrompt = _buildAvatarPrompt(userPrompt, stylePreferences);
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/initiate-generation'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      request.headers['apikey'] = SupabaseConfig.supabaseAnonKey;

      // Add form fields
      request.fields['preset_name'] = 'avatar_spritesheet';
      request.fields['user_description'] = finalPrompt;

      // Send the request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'jobId': responseData['jobId'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Call the initiate-generation Edge Function with image upload
  Future<Map<String, dynamic>> _callInitiateGenerationEdgeFunctionWithImage({
    required File imageFile,
    String? userPrompt,
    Map<String, dynamic>? stylePreferences,
  }) async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('User not authenticated');
      }

      // Build the final prompt combining user input and style preferences
      final finalPrompt = _buildAvatarPrompt(userPrompt ?? 'Generate spritesheet from user image', stylePreferences);
      
      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/initiate-generation'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      request.headers['apikey'] = SupabaseConfig.supabaseAnonKey;

      // Add form fields
      request.fields['preset_name'] = 'avatar_spritesheet';
      if (userPrompt != null && userPrompt.isNotEmpty) {
        request.fields['user_description'] = finalPrompt;
      }

      // Add the image file
      final imageBytes = await imageFile.readAsBytes();
      final imageStream = http.ByteStream.fromBytes(imageBytes);
      final imageLength = imageBytes.length;
      
      final multipartFile = http.MultipartFile(
        'source_image',
        imageStream,
        imageLength,
        filename: 'user_image.jpg',
      );
      
      request.files.add(multipartFile);

      // Send the request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'jobId': responseData['jobId'],
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ?? 'Unknown error',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Build the prompt for avatar generation
  String _buildAvatarPrompt(String userPrompt, Map<String, dynamic>? stylePreferences) {
    final basePrompt = '''
Create a pixel art character spritesheet for a 2D game. The character should be:
- Cute and friendly looking
- Suitable for a romantic/couple game
- Pixel art style with clear outlines
- 32x32 pixel base size for each frame
- 4 frames per row, 3 rows (up, right, down directions)
- Left direction will be created by flipping right frames

User description: $userPrompt
''';

    if (stylePreferences != null) {
      final style = stylePreferences['style'] ?? 'casual';
      final colors = stylePreferences['colors'] ?? 'warm';
      final clothing = stylePreferences['clothing'] ?? 'casual';
      
      return '''
$basePrompt
Style: $style
Color scheme: $colors
Clothing: $clothing
''';
    }

    return basePrompt;
  }



  /// Get user's avatar generation status
  Future<Map<String, dynamic>> getAvatarStatus(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select('avatar_generation_status, spritesheet_url, avatar_url, avatar_generation_prompt, spritesheet_generation_job_id')
        .eq('id', userId)
        .single();

    return response;
  }

  /// Poll for job completion and update profile when done
  Future<Map<String, dynamic>> pollJobCompletion(String userId) async {
    try {
      final profile = await getAvatarStatus(userId);
      final jobId = profile['spritesheet_generation_job_id'];
      
      if (jobId == null) {
        return {
          'success': false,
          'error': 'No generation job found',
        };
      }

      // Check the generation_jobs table for status
      final jobResponse = await _supabase
          .from('generation_jobs')
          .select('status, final_image_url, error_message')
          .eq('id', jobId)
          .single();

      final status = jobResponse['status'];
      
      if (status == 'completed') {
        final imageUrl = jobResponse['final_image_url'];
        
        // Update profile with the generated spritesheet
        await _supabase
            .from('profiles')
            .update({
              'spritesheet_url': imageUrl,
              'avatar_generation_status': 'completed',
            })
            .eq('id', userId);

        return {
          'success': true,
          'status': 'completed',
          'spritesheet_url': imageUrl,
        };
      } else if (status == 'failed') {
        final errorMessage = jobResponse['error_message'];
        
        // Update profile status to failed
        await _supabase
            .from('profiles')
            .update({
              'avatar_generation_status': 'failed',
            })
            .eq('id', userId);

        return {
          'success': false,
          'status': 'failed',
          'error': errorMessage ?? 'Generation failed',
        };
      } else {
        // Still processing
        return {
          'success': true,
          'status': 'processing',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get user's custom spritesheet URL
  Future<String?> getSpritesheetUrl(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select('normalized_sprite_path, spritesheet_url, avatar_generation_status')
        .eq('id', userId)
        .single();

    // Prefer normalized sheet if available
    final normalizedPath = response['normalized_sprite_path'];
    if (normalizedPath != null && normalizedPath is String && normalizedPath.isNotEmpty) {
      try {
        final String publicUrl = _supabase.storage.from('avatars').getPublicUrl(normalizedPath);
        if (publicUrl.isNotEmpty) {
          // Log that we are using the normalized spritesheet
          // Note: keep logs concise to avoid spamming
          // ignore: avoid_print
          print('AvatarGenerationService: using normalized spritesheet: path=$normalizedPath');
          return publicUrl;
        }
      } catch (_) {
        // Fall through to legacy URL if building public URL fails
      }
    }

    // Fallback to legacy spritesheet_url when generation completed
    if (response['avatar_generation_status'] == 'completed' && 
        response['spritesheet_url'] != null) {
      // ignore: avoid_print
      print('AvatarGenerationService: using legacy spritesheet_url');
      return response['spritesheet_url'];
    }
    // ignore: avoid_print
    print('AvatarGenerationService: no spritesheet available yet for user=$userId');
    return null;
  }

  /// Retry failed avatar generation
  Future<Map<String, dynamic>> retryAvatarGeneration(String userId) async {
    final profile = await _supabase
        .from('profiles')
        .select('avatar_generation_prompt, avatar_style_preferences')
        .eq('id', userId)
        .single();

    return await generateUserAvatar(
      userId: userId,
      userPrompt: profile['avatar_generation_prompt'] ?? '',
      stylePreferences: profile['avatar_style_preferences'],
    );
  }

  /// Update avatar style preferences
  Future<void> updateStylePreferences(
    String userId,
    Map<String, dynamic> preferences,
  ) async {
    await _supabase
        .from('profiles')
        .update({
          'avatar_style_preferences': preferences,
        })
        .eq('id', userId);
  }

  /// Check if the avatar spritesheet preset exists
  Future<bool> checkPresetExists() async {
    try {
      final response = await _supabase
          .from('prompt_presets')
          .select('id')
          .eq('preset_name', 'avatar_spritesheet')
          .eq('is_active', true)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      return false;
    }
  }
} 