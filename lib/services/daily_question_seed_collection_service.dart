import 'package:lovenest/config/supabase_config.dart';
import 'package:lovenest/models/memory_garden/question.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DailyQuestionSeedCollectionService {
  /// Collect a daily question seed and store it in the backend
  static Future<bool> collectDailyQuestionSeed({
    required String questionId,
    required String questionText,
    required String answer,
    required Color seedColor,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return false;

      // Check if user has already collected this seed for this question
      final existingSeed = await SupabaseConfig.client
          .from('daily_question_seeds')
          .select('id')
          .eq('user_id', userId)
          .eq('question_id', questionId)
          .maybeSingle();

      if (existingSeed != null) {
        debugPrint('[DailyQuestionSeedCollectionService] ❌ User already collected this seed');
        return false;
      }

      // Create a new daily question seed record
      final seedResponse = await SupabaseConfig.client
          .from('daily_question_seeds')
          .insert({
            'user_id': userId,
            'question_id': questionId,
            'question_text': questionText,
            'user_answer': answer,
            'seed_color_hex': '#${seedColor.value.toRadixString(16).padLeft(8, '0')}',
            'collected_at': DateTime.now().toIso8601String(),
            'is_planted': false,
            'planted_at': null,
            'water_count': 0,
            'last_watered_at': null,
            'growth_stage': 'collected',
            'generated_sprite_url': null,
          })
          .select()
          .single();

      debugPrint('[DailyQuestionSeedCollectionService] ✅ Daily question seed collected: ${seedResponse['id']}');
      return true;
    } catch (e) {
      debugPrint('[DailyQuestionSeedCollectionService] ❌ Error collecting seed: $e');
      return false;
    }
  }

  /// Get all collected seeds for the current user
  static Future<List<Map<String, dynamic>>> getUserCollectedSeeds() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return [];

      final response = await SupabaseConfig.client
          .from('daily_question_seeds')
          .select('*')
          .eq('user_id', userId)
          .order('collected_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[DailyQuestionSeedCollectionService] ❌ Error fetching user seeds: $e');
      return [];
    }
  }

  /// Check if user has already collected a seed for a specific question
  static Future<bool> hasUserCollectedSeed(String questionId) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[DailyQuestionSeedCollectionService] ❌ No current user ID');
        return false;
      }

      debugPrint('[DailyQuestionSeedCollectionService] 🔍 Checking if user $userId has collected seed for question $questionId');
      debugPrint('[DailyQuestionSeedCollectionService] 🔍 Current user ID: $userId');

      final response = await SupabaseConfig.client
          .from('daily_question_seeds')
          .select('id')
          .eq('user_id', userId)
          .eq('question_id', questionId)
          .maybeSingle();

      final hasCollected = response != null;
      debugPrint('[DailyQuestionSeedCollectionService] ${hasCollected ? '✅' : '❌'} User has${hasCollected ? '' : ' not'} collected this seed');
      
      return hasCollected;
    } catch (e) {
      debugPrint('[DailyQuestionSeedCollectionService] ❌ Error checking seed collection: $e');
      return false;
    }
  }

  /// Get seed data by ID
  static Future<Map<String, dynamic>?> getSeedById(String seedId) async {
    try {
      final response = await SupabaseConfig.client
          .from('daily_question_seeds')
          .select('*')
          .eq('id', seedId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('[DailyQuestionSeedCollectionService] ❌ Error fetching seed: $e');
      return null;
    }
  }

  /// Update the user's answer for a collected seed
  static Future<bool> updateSeedAnswer(String questionId, String answer) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        debugPrint('[DailyQuestionSeedCollectionService] ❌ No current user ID');
        return false;
      }

      debugPrint('[DailyQuestionSeedCollectionService] 🔄 Updating answer for question $questionId: $answer');

      final response = await SupabaseConfig.client
          .from('daily_question_seeds')
          .update({
            'user_answer': answer,
          })
          .eq('user_id', userId)
          .eq('question_id', questionId);

      debugPrint('[DailyQuestionSeedCollectionService] ✅ Answer updated successfully');
      return true;
    } catch (e) {
      debugPrint('[DailyQuestionSeedCollectionService] ❌ Error updating seed answer: $e');
      return false;
    }
  }
} 