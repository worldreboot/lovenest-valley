import 'package:flutter/foundation.dart';
import 'package:lovenest_valley/config/supabase_config.dart';

class CoupleDailyPromptService {
  final _client = SupabaseConfig.client;

  Future<Map<String, String>> getOrAssignToday(String coupleId) async {
    try {
      final res = await _client.rpc('get_or_assign_today_question_for_couple', params: {
        'p_couple_id': coupleId,
      });
      // The function returns a row or list depending on client lib; normalize to first row
      final row = res is List && res.isNotEmpty ? res.first as Map<String, dynamic> : res as Map<String, dynamic>;
      return {
        'questionId': row['question_id'] as String,
        'text': row['text'] as String,
      };
    } catch (e) {
      debugPrint('[CoupleDailyPromptService] getOrAssignToday error: $e');
      rethrow;
    }
  }

  Future<String> submitAnswer(String questionId, String answer) async {
    try {
      final status = await _client.rpc('submit_daily_answer', params: {
        'p_question_id': questionId,
        'p_answer': answer,
      });
      return status as String;
    } catch (e) {
      debugPrint('[CoupleDailyPromptService] submitAnswer error: $e');
      rethrow;
    }
  }

  Future<void> linkSeed(String questionId, String seedId) async {
    try {
      await _client.rpc('link_seed_to_daily_question', params: {
        'p_question_id': questionId,
        'p_seed_id': seedId,
      });
    } catch (e) {
      debugPrint('[CoupleDailyPromptService] linkSeed error: $e');
      rethrow;
    }
  }

  Future<String> evaluateBloom(String seedId, {int requiredWaters = 3}) async {
    try {
      final status = await _client.rpc('evaluate_bloom_ready', params: {
        'p_seed_id': seedId,
        'p_required_waters': requiredWaters,
      });
      return status as String;
    } catch (e) {
      debugPrint('[CoupleDailyPromptService] evaluateBloom error: $e');
      rethrow;
    }
  }
}


