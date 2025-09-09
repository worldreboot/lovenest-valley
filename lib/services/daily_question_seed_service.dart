import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert'; // Added for json.decode
import 'package:http/http.dart' as http; // Added for http.MultipartRequest
import 'package:lovenest_valley/services/couple_daily_prompt_service.dart';
import 'package:lovenest_valley/services/question_service.dart';
import 'package:lovenest_valley/services/garden_repository.dart';

class DailyQuestionSeedService {
  /// Plant a daily question seed with the user's answer
  static Future<bool> plantDailyQuestionSeed({
    required String questionId,
    required String answer,
    required int plotX,
    required int plotY,
    required String farmId,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return false;

      // Daily question seeds must belong to a couple for linking to work
      final couple = await GardenRepository().getUserCouple();
      if (couple == null) {
        debugPrint('[DailyQuestionSeedService] ❌ Cannot plant daily question seed: user is not in a couple');
        return false;
      }

      // Create a new seed record for the daily question
      final seedResponse = await SupabaseConfig.client
          .from('seeds')
          .insert({
            'couple_id': couple.id,
            'planter_id': userId,
            'question_id': questionId,
            'text_content': answer,
            'state': 'sprout',
            'growth_score': 0,
            'plot_x': plotX.toDouble(),
            'plot_y': plotY.toDouble(),
            'media_type': 'text',
            'secret_hope': answer, // Use answer as the secret hope
          })
          .select()
          .single();

      // Link the planted seed to both partners' daily answer via RPC (idempotent)
      await CoupleDailyPromptService()
          .linkSeed(questionId, seedResponse['id'] as String);

      // Create a farm seed record using the new system
      await SupabaseConfig.client
          .from('farm_seeds')
          .insert({
            'farm_id': farmId,
            'user_id': userId,
            'x': plotX,
            'y': plotY,
            'plant_type': 'daily_question_seed',
            'growth_stage': 'planted',
            'water_count': 0,
            'planted_at': DateTime.now().toIso8601String(),
            'last_watered_at': null,
            'properties': {
              'question_id': questionId,
              'answer': answer,
              'seed_id': seedResponse['id'],
            },
          });

      // Mark current user's answer at this farm tile (for partner notification logic)
      await SupabaseConfig.client
          .from('farm_seed_answers')
          .upsert({
            'farm_id': farmId,
            'x': plotX,
            'y': plotY,
            'question_id': questionId,
            'user_id': userId,
            'answered_at': DateTime.now().toIso8601String(),
          }, onConflict: 'farm_id,x,y,user_id');

      debugPrint('[DailyQuestionSeedService] 🌱 Daily question seed planted at ($plotX, $plotY) using new farm_seeds system');

      // 🧪 TESTING: Generate sprite immediately after planting
      debugPrint('[DailyQuestionSeedService] 🧪 TESTING: Generating sprite immediately after planting...');
      await _generateAndStoreSprite(plotX, plotY, farmId);
      debugPrint('[DailyQuestionSeedService] ✅ TESTING: Sprite generation completed!');

      return true;
    } catch (e) {
      debugPrint('[DailyQuestionSeedService] ❌ Error planting daily question seed: $e');
      return false;
    }
  }

  /// Water a daily question seed and track progress
  static Future<bool> waterDailyQuestionSeed({
    required int plotX,
    required int plotY,
    required String farmId,
  }) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return false;

      debugPrint('[DailyQuestionSeedService] 🚰 User $userId attempting to water daily question seed at ($plotX, $plotY) on farm $farmId');

      // Get current seed state from farm_seeds table (by farm/tile)
      final seedResponse = await SupabaseConfig.client
          .from('farm_seeds')
          .select('water_count, growth_stage, plant_type, last_watered_at, properties')
          .eq('farm_id', farmId)
          .eq('x', plotX)
          .eq('y', plotY)
          .maybeSingle();

      if (seedResponse == null || seedResponse['plant_type'] != 'daily_question_seed') {
        debugPrint('[DailyQuestionSeedService] ❌ No daily question seed found at ($plotX, $plotY)');
        return false;
      }

      final currentWaterCount = (seedResponse['water_count'] as int?) ?? 0;
      final currentGrowthStage = seedResponse['growth_stage'] as String? ?? 'planted';
      final lastWateredAt = seedResponse['last_watered_at'] as String?;
      final props = (seedResponse['properties'] as Map<String, dynamic>?) ?? {};
      final questionId = props['question_id'] as String?;

      debugPrint('[DailyQuestionSeedService] 📊 Current state - Water count: $currentWaterCount, Growth stage: $currentGrowthStage');
      debugPrint('[DailyQuestionSeedService] ⏰ Last watered at: ${lastWateredAt ?? 'Never'}');

      if (currentGrowthStage != 'planted') {
        debugPrint('[DailyQuestionSeedService] ❌ Seed is already fully grown');
        return false;
      }

      // Require both users to have answered before watering can proceed
      if (questionId != null) {
        // Check farm_seed_answers table for this specific seed location
        final answersResponse = await SupabaseConfig.client
            .from('farm_seed_answers')
            .select('user_id')
            .eq('farm_id', farmId)
            .eq('x', plotX)
            .eq('y', plotY)
            .eq('question_id', questionId);
        
        final answeredUserIds = answersResponse.map((row) => row['user_id'] as String).toSet();
        final currentUserId = SupabaseConfig.currentUserId;
        
        if (currentUserId == null) {
          debugPrint('[DailyQuestionSeedService] ❌ No current user ID');
          return false;
        }
        
        // Get the couple to find the partner ID
        final couple = await GardenRepository().getUserCouple();
        if (couple == null) {
          debugPrint('[DailyQuestionSeedService] ❌ No couple found');
          return false;
        }
        
        final partnerId = couple.user1Id == currentUserId ? couple.user2Id : couple.user1Id;
        final hasMine = answeredUserIds.contains(currentUserId);
        final hasPartner = answeredUserIds.contains(partnerId);
        
        debugPrint('[DailyQuestionSeedService] 🔍 Checking answers for question $questionId at ($plotX, $plotY)');
        debugPrint('[DailyQuestionSeedService] 🔍 Current user ($currentUserId): $hasMine');
        debugPrint('[DailyQuestionSeedService] 🔍 Partner ($partnerId): $hasPartner');
        debugPrint('[DailyQuestionSeedService] 🔍 All answered users: $answeredUserIds');
        
        if (!(hasMine && hasPartner)) {
          debugPrint('[DailyQuestionSeedService] ❌ Both partners must answer before watering. Mine=$hasMine Partner=$hasPartner');
          return false;
        }
      }

      // Check if enough time has passed since last watering (24 hours)
      if (lastWateredAt != null) {
        final lastWatered = DateTime.parse(lastWateredAt);
        final now = DateTime.now();
        final hoursSinceLastWater = now.difference(lastWatered).inHours;
        
        debugPrint('[DailyQuestionSeedService] ⏱️ Hours since last watering: $hoursSinceLastWater');
        
        if (hoursSinceLastWater < 24) {
          final remainingHours = 24 - hoursSinceLastWater;
          debugPrint('[DailyQuestionSeedService] ❌ Must wait $remainingHours more hours before watering again');
          return false;
        }
      } else {
        debugPrint('[DailyQuestionSeedService] ✅ First time watering - no time restriction');
      }

      // Increment water count
      final newWaterCount = currentWaterCount + 1;
      final now = DateTime.now().toIso8601String();

      // Update farm seed using new system
      final updateData = {
        'water_count': newWaterCount,
        'last_watered_at': now,
      };

      // Note: growth visuals will be controlled via evaluate_bloom_ready RPC

      await SupabaseConfig.client
          .from('farm_seeds')
          .update(updateData)
          .eq('farm_id', farmId)
          .eq('user_id', userId)
          .eq('x', plotX)
          .eq('y', plotY);

      // Enhanced success logging
      final timestamp = DateTime.now();
      debugPrint('[DailyQuestionSeedService] ✅ SUCCESS: User $userId watered daily question seed at ($plotX, $plotY)');
      debugPrint('[DailyQuestionSeedService] 📈 Progress: $currentWaterCount → $newWaterCount/3 days');
      debugPrint('[DailyQuestionSeedService] 🌱 Growth stage: $currentGrowthStage');
      debugPrint('[DailyQuestionSeedService] ⏰ Timestamp: ${timestamp.toIso8601String()}');
      debugPrint('[DailyQuestionSeedService] 🏁 Status: ${newWaterCount >= 3 ? 'READY TO BLOOM!' : 'Still growing...'}');

      // Use comprehensive logging
      logSuccessfulWatering(
        userId: userId,
        plotX: plotX,
        plotY: plotY,
        farmId: farmId,
        previousWaterCount: currentWaterCount,
        newWaterCount: newWaterCount,
        growthStage: currentGrowthStage,
        isReadyToBloom: newWaterCount >= 3,
      );

      // Evaluate readiness via RPC using the planted seed id from properties
      final plantedSeed = await SupabaseConfig.client
          .from('seeds')
          .select('id')
          .eq('plot_x', plotX.toDouble())
          .eq('plot_y', plotY.toDouble())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (plantedSeed != null) {
        final status = await CoupleDailyPromptService()
            .evaluateBloom(plantedSeed['id'] as String);
        if (status == 'bloom_ready') {
          debugPrint('[DailyQuestionSeedService] 🌸 Bloom is ready per RPC — triggering visuals');
          await _generateAndStoreSprite(plotX, plotY, farmId);
        } else {
          debugPrint('[DailyQuestionSeedService] 🌱 Bloom not ready yet (status: $status)');
        }
      }

      return true;
    } catch (e) {
      debugPrint('[DailyQuestionSeedService] ❌ Error watering daily question seed: $e');
      return false;
    }
  }

  /// Comprehensive logging for successful daily question seed watering
  static void logSuccessfulWatering({
    required String userId,
    required int plotX,
    required int plotY,
    required String farmId,
    required int previousWaterCount,
    required int newWaterCount,
    required String growthStage,
    required bool isReadyToBloom,
  }) {
    final now = DateTime.now();
    final timestamp = now.toIso8601String();
    
    debugPrint('🌱 === DAILY QUESTION SEED WATERING SUCCESS LOG ===');
    debugPrint('👤 User ID: $userId');
    debugPrint('📍 Location: ($plotX, $plotY) on farm $farmId');
    debugPrint('🌿 Seed Type: daily_question_seed');
    debugPrint('📊 Water Progress: $previousWaterCount → $newWaterCount/3 days');
    debugPrint('🌱 Growth Stage: $growthStage');
    debugPrint('⏰ Timestamp: $timestamp');
    debugPrint('🏁 Status: ${isReadyToBloom ? 'READY TO BLOOM!' : 'Still growing...'}');
    debugPrint('🌱 === END SUCCESS LOG ===');
  }

  /// Generate and store a sprite for the bloomed daily question seed
  static Future<void> _generateAndStoreSprite(int plotX, int plotY, String farmId) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return;

      // Get the seed data to extract answer and question ID
      final seedResponse = await SupabaseConfig.client
          .from('seeds')
          .select('text_content, question_id')
          .eq('plot_x', plotX.toDouble())
          .eq('plot_y', plotY.toDouble())
          .maybeSingle();

      final answer = seedResponse?['text_content'] as String?;
      final questionId = seedResponse?['question_id'] as String?;

      if (answer == null || questionId == null) {
        debugPrint('[DailyQuestionSeedService] ❌ Missing answer or question ID for sprite generation');
        return;
      }

      // Get the question text
      final questionResponse = await SupabaseConfig.client
          .from('questions')
          .select('text')
          .eq('id', questionId)
          .maybeSingle();

      final questionText = questionResponse?['text'] as String? ?? 'Daily Question';

      // Create user description for the sprite
      final userDescription = 'Generate a beautiful, colorful flower sprite that represents the answer to this daily question: "$questionText". The answer was: "$answer". Make it a vibrant, blooming flower with petals in warm colors like pink, orange, yellow, or purple. The flower should look happy and full of life.';

      // Call the initiate-generation Edge Function
      final session = SupabaseConfig.client.auth.currentSession;
      if (session == null) {
        debugPrint('[DailyQuestionSeedService] ❌ User not authenticated');
        return;
      }

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/initiate-generation'),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer ${session.accessToken}';
      request.headers['apikey'] = SupabaseConfig.supabaseAnonKey;

      // Add form fields
      request.fields['preset_name'] = 'seed_bloom_sprite';
      request.fields['user_description'] = userDescription;

      // Send the request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final responseData = json.decode(responseBody);

      if (response.statusCode == 200 && responseData['success'] == true) {
        final jobId = responseData['jobId'];
        
        // Update the seed to link to the generation job and mark as blooming
        await SupabaseConfig.client
            .from('seeds')
            .update({
              'state': 'bloom_stage_3',
              'growth_score': 100,
              'bloom_variant_seed': jobId,
            })
            .eq('plot_x', plotX.toDouble())
            .eq('plot_y', plotY.toDouble());

        // For immediate sprite generation (testing), don't set to fully grown
        // This allows the user to still water the seed normally
        // The sprite will be available when the seed actually blooms
        debugPrint('[DailyQuestionSeedService] 🧪 TESTING: Keeping seed as planted for normal watering flow');

        debugPrint('[DailyQuestionSeedService] 🌸 Daily question seed bloomed! Generation job created: $jobId');
      } else {
        debugPrint('[DailyQuestionSeedService] ❌ Failed to create generation job: ${responseData['error']}');
      }
    } catch (e) {
      debugPrint('[DailyQuestionSeedService] ❌ Error generating sprite: $e');
    }
  }

  /// Get the sprite URL for a bloomed daily question seed
  static Future<String?> getSpriteUrl(int plotX, int plotY) async {
    try {
      final seedResponse = await SupabaseConfig.client
          .from('seeds')
          .select('bloom_variant_seed, state')
          .eq('plot_x', plotX.toDouble())
          .eq('plot_y', plotY.toDouble())
          .maybeSingle();

      // Check if seed has a generated sprite (either bloomed or generated for testing)
      if (seedResponse == null || seedResponse['bloom_variant_seed'] == null) {
        return null;
      }

      final generationJobId = seedResponse['bloom_variant_seed'] as String?;
      if (generationJobId == null) return null;

      // Get the generation job result
      final jobResponse = await SupabaseConfig.client
          .from('generation_jobs')
          .select('final_image_url, status')
          .eq('id', generationJobId)
          .maybeSingle();

      if (jobResponse == null || jobResponse['status'] != 'completed') {
        return null;
      }

      return jobResponse['final_image_url'] as String?;
    } catch (e) {
      debugPrint('[DailyQuestionSeedService] ❌ Error getting sprite URL: $e');
      return null;
    }
  }

  /// Check if a daily question seed is ready to bloom (3 days watered)
  static Future<bool> isReadyToBloom(int plotX, int plotY, String farmId) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return false;

      final seedResponse = await SupabaseConfig.client
          .from('farm_seeds')
          .select('water_count, growth_stage, plant_type')
          .eq('farm_id', farmId)
          .eq('user_id', userId)
          .eq('x', plotX)
          .eq('y', plotY)
          .maybeSingle();

      if (seedResponse == null || seedResponse['plant_type'] != 'daily_question_seed') {
        return false;
      }

      final waterCount = (seedResponse['water_count'] as int?) ?? 0;
      final growthStage = seedResponse['growth_stage'] as String? ?? 'planted';

      return waterCount >= 3 && growthStage == 'planted';
    } catch (e) {
      debugPrint('[DailyQuestionSeedService] ❌ Error checking bloom readiness: $e');
      return false;
    }
  }

  /// Get the current watering progress for a daily question seed
  static Future<int> getWateringProgress(int plotX, int plotY, String farmId) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return 0;

      final seedResponse = await SupabaseConfig.client
          .from('farm_seeds')
          .select('water_count')
          .eq('farm_id', farmId)
          .eq('user_id', userId)
          .eq('x', plotX)
          .eq('y', plotY)
          .maybeSingle();

      if (seedResponse == null) return 0;

      return (seedResponse['water_count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[DailyQuestionSeedService] ❌ Error getting watering progress: $e');
      return 0;
    }
  }

  /// Get remaining hours until next watering is allowed
  static Future<int?> getRemainingHoursUntilWatering(int plotX, int plotY, String farmId) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return null;

      final seedResponse = await SupabaseConfig.client
          .from('farm_seeds')
          .select('last_watered_at')
          .eq('farm_id', farmId)
          .eq('user_id', userId)
          .eq('x', plotX)
          .eq('y', plotY)
          .maybeSingle();

      if (seedResponse == null) {
        return null; // No watering record, can water immediately
      }

      final lastWateredAt = seedResponse['last_watered_at'] as String?;
      if (lastWateredAt == null) {
        return null; // Never watered, can water immediately
      }

      final lastWatered = DateTime.parse(lastWateredAt);
      final now = DateTime.now();
      final hoursSinceLastWater = now.difference(lastWatered).inHours;
      
      if (hoursSinceLastWater >= 24) {
        return 0; // Can water now
      } else {
        return 24 - hoursSinceLastWater; // Hours remaining
      }
    } catch (e) {
      debugPrint('[DailyQuestionSeedService] ❌ Error getting remaining hours: $e');
      return null;
    }
  }

  /// Check if a seed has a generated sprite available (for testing)
  static Future<bool> hasGeneratedSprite(int plotX, int plotY) async {
    try {
      final seedResponse = await SupabaseConfig.client
          .from('seeds')
          .select('bloom_variant_seed')
          .eq('plot_x', plotX.toDouble())
          .eq('plot_y', plotY.toDouble())
          .maybeSingle();

      if (seedResponse == null || seedResponse['bloom_variant_seed'] == null) {
        return false;
      }

      final generationJobId = seedResponse['bloom_variant_seed'] as String?;
      if (generationJobId == null) return false;

      // Check if the generation job is completed
      final jobResponse = await SupabaseConfig.client
          .from('generation_jobs')
          .select('status')
          .eq('id', generationJobId)
          .maybeSingle();

      return jobResponse != null && jobResponse['status'] == 'completed';
    } catch (e) {
      debugPrint('[DailyQuestionSeedService] ❌ Error checking for generated sprite: $e');
      return false;
    }
  }

  /// Get the question and answer data for a seed at a specific location
  static Future<Map<String, String>?> getSeedQuestionAndAnswer(int plotX, int plotY) async {
    try {
      // Get the most recent seed record for this location
      final seedResponse = await SupabaseConfig.client
          .from('seeds')
          .select('text_content, question_id')
          .eq('plot_x', plotX.toDouble())
          .eq('plot_y', plotY.toDouble())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (seedResponse == null) {
        debugPrint('[DailyQuestionSeedService] ❌ No seed found at ($plotX, $plotY)');
        return null;
      }

      final answer = seedResponse['text_content'] as String?;
      final questionId = seedResponse['question_id'] as String?;

      if (answer == null || questionId == null) {
        debugPrint('[DailyQuestionSeedService] ❌ Missing answer or question ID');
        return null;
      }

      // Get the question text
      final questionResponse = await SupabaseConfig.client
          .from('questions')
          .select('text')
          .eq('id', questionId)
          .maybeSingle();

      final questionText = questionResponse?['text'] as String? ?? 'Daily Question';

      return {
        'question': questionText,
        'answer': answer,
      };
    } catch (e) {
      debugPrint('[DailyQuestionSeedService] ❌ Error getting seed question and answer: $e');
      return null;
    }
  }
} 
