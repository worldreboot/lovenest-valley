import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lovenest_valley/models/mood_weather_model.dart';
import 'package:lovenest_valley/config/supabase_config.dart';

class MoodWeatherService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Check if user has already responded to today's mood prompt
  Future<bool> hasUserRespondedToday(String userId, String coupleId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final response = await _client
          .from('daily_mood_responses')
          .select('id')
          .eq('user_id', userId)
          .eq('couple_id', coupleId)
          .eq('response_date', today)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      print('[MoodWeatherService] Error checking if user responded today: $e');
      return false;
    }
  }

  /// Submit a daily mood response
  Future<void> submitMoodResponse(String coupleId, MoodType moodType) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final today = DateTime.now().toIso8601String().split('T')[0];
      
      await _client.from('daily_mood_responses').upsert({
        'user_id': userId,
        'couple_id': coupleId,
        'mood_type': moodType.name,
        'response_date': today,
      });

      print('[MoodWeatherService] ✅ Mood response submitted: ${moodType.name}');
      
      // Check if both users have responded and calculate weather
      await _checkAndCalculateWeather(coupleId);
      
    } catch (e) {
      print('[MoodWeatherService] ❌ Error submitting mood response: $e');
      rethrow;
    }
  }

  /// Get today's mood responses for a couple
  Future<List<DailyMoodResponse>> getTodayMoodResponses(String coupleId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final response = await _client
          .from('daily_mood_responses')
          .select('*')
          .eq('couple_id', coupleId)
          .eq('response_date', today);
      
      return (response as List)
          .map((json) => DailyMoodResponse.fromJson(json))
          .toList();
    } catch (e) {
      print('[MoodWeatherService] Error getting today\'s mood responses: $e');
      return [];
    }
  }

  /// Get today's weather condition for a couple
  Future<WeatherCondition?> getTodayWeather(String coupleId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      final response = await _client
          .from('weather_conditions')
          .select('*')
          .eq('couple_id', coupleId)
          .eq('weather_date', today)
          .maybeSingle();
      
      return response != null ? WeatherCondition.fromJson(response) : null;
    } catch (e) {
      print('[MoodWeatherService] Error getting today\'s weather: $e');
      return null;
    }
  }

  /// Check if both users have responded and calculate weather
  Future<void> _checkAndCalculateWeather(String coupleId) async {
    try {
      final responses = await getTodayMoodResponses(coupleId);
      
      if (responses.length == 2) {
        // Both users have responded, calculate weather
        final mood1 = responses[0].moodType;
        final mood2 = responses[1].moodType;
        
        final weatherType = MoodWeatherMapping.getWeatherForMoodCombination(mood1, mood2);
        final moodCombination = '${mood1.name}_${mood2.name}';
        
        final today = DateTime.now().toIso8601String().split('T')[0];
        
        await _client.from('weather_conditions').upsert({
          'couple_id': coupleId,
          'weather_type': weatherType.name,
          'mood_combination': moodCombination,
          'weather_date': today,
        });
        
        print('[MoodWeatherService] 🌤️ Weather calculated: ${weatherType.name} from ${mood1.name} + ${mood2.name}');
      }
    } catch (e) {
      print('[MoodWeatherService] Error calculating weather: $e');
    }
  }

  // TODO: Implement real-time weather subscription when Supabase stream API is available
  // Stream<WeatherCondition?> subscribeToWeatherChanges(String coupleId) {
  //   // Implementation for real-time weather updates
  // }

  /// Get mood statistics for the past week
  Future<Map<MoodType, int>> getWeeklyMoodStats(String coupleId) async {
    try {
      final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String().split('T')[0];
      
      final response = await _client
          .from('daily_mood_responses')
          .select('mood_type')
          .eq('couple_id', coupleId)
          .gte('response_date', weekAgo);
      
      final stats = <MoodType, int>{};
      for (final moodType in MoodType.values) {
        stats[moodType] = 0;
      }
      
      for (final item in response as List) {
        final moodType = MoodType.values.firstWhere(
          (e) => e.name == item['mood_type'],
          orElse: () => MoodType.happy,
        );
        stats[moodType] = (stats[moodType] ?? 0) + 1;
      }
      
      return stats;
    } catch (e) {
      print('[MoodWeatherService] Error getting weekly mood stats: $e');
      return {};
    }
  }
} 
