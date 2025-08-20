import 'package:lovenest/config/supabase_config.dart';
import 'package:lovenest/models/memory_garden/question.dart';
import 'package:lovenest/services/couple_daily_prompt_service.dart';
import 'package:lovenest/services/garden_repository.dart';

class QuestionService {
  /// Fetches a daily question the user hasn't seen yet, or null if all have been seen.
  static Future<Question?> fetchDailyQuestion() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return null;

    // Resolve couple
    final couple = await GardenRepository().getUserCouple();
    if (couple == null) return null;

    // Get or assign today's question for the couple via RPC
    final rpc = CoupleDailyPromptService();
    final result = await rpc.getOrAssignToday(couple.id);

    // Fetch created_at for the question to satisfy the model
    final meta = await SupabaseConfig.client
        .from('questions')
        .select('created_at')
        .eq('id', result['questionId']!)
        .maybeSingle();

    final createdAtStr = meta != null ? (meta['created_at'] as String?) : null;
    final createdAt = createdAtStr != null
        ? DateTime.parse(createdAtStr)
        : DateTime.now();

    return Question(
      id: result['questionId']!,
      text: result['text']!,
      createdAt: createdAt,
    );
  }

  /// Mark a question as received by the user (insert into user_questions)
  static Future<void> markQuestionReceived(String questionId) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return;
    await SupabaseConfig.client.from('user_questions').insert({
      'user_id': userId,
      'question_id': questionId,
    });
  }

  /// Save a daily question answer for the current user (not yet planted)
  static Future<void> saveDailyQuestionAnswer(String questionId, String answer) async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return;
    // Submit via RPC; ignore returned status here to keep signature
    await CoupleDailyPromptService().submitAnswer(questionId, answer);
  }

  /// Get the current user's unplanted daily question answer (if any)
  static Future<Map<String, dynamic>?> getUnplantedDailyQuestionAnswer() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return null;
    final response = await SupabaseConfig.client
        .from('user_daily_question_answers')
        .select()
        .eq('user_id', userId)
        .eq('is_planted', false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return response;
  }

  /// Mark a daily question answer as planted, linking it to the created seed
  static Future<void> markDailyQuestionAnswerPlanted(String answerId, String seedId) async {
    await SupabaseConfig.client
        .from('user_daily_question_answers')
        .update({
          'is_planted': true,
          'planted_seed_id': seedId,
        })
        .eq('id', answerId);
  }

  /// Check if the partner has answered the given question
  static Future<bool> hasPartnerAnswered(String questionId) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return false;
      final couple = await GardenRepository().getUserCouple();
      if (couple == null) return false;
      final partnerId = couple.user1Id == userId ? couple.user2Id : couple.user1Id;

      final res = await SupabaseConfig.client
          .from('user_daily_question_answers')
          .select('id')
          .eq('question_id', questionId)
          .eq('user_id', partnerId)
          .limit(1);
      // Supabase returns a List for selects
      return res.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Check if the current user has answered the given question
  static Future<bool> hasCurrentUserAnswered(String questionId) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return false;
      final res = await SupabaseConfig.client
          .from('user_daily_question_answers')
          .select('id')
          .eq('question_id', questionId)
          .eq('user_id', userId)
          .limit(1);
      return res.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
} 