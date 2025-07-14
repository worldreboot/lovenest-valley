import 'package:lovenest/config/supabase_config.dart';
import 'package:lovenest/models/memory_garden/question.dart';

class QuestionService {
  /// Fetches a daily question the user hasn't seen yet, or null if all have been seen.
  static Future<Question?> fetchDailyQuestion() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return null;

    // 1. Check if the user has already received a question today
    final todayResponse = await SupabaseConfig.client
        .from('user_questions')
        .select('question_id, received_at')
        .eq('user_id', userId)
        .gte('received_at', DateTime.now().toUtc().toIso8601String().substring(0, 10));

    if ((todayResponse as List).isNotEmpty) {
      // User has already received a question today
      return null;
    }

    // 2. Get IDs of questions the user has already seen
    final seenIdsResponse = await SupabaseConfig.client
        .from('user_questions')
        .select('question_id')
        .eq('user_id', userId);

    final seenIds = (seenIdsResponse as List)
        .map((row) => row['question_id'] as String)
        .toSet();

    // 3. Fetch a batch of questions (e.g., 10)
    final questionsResponse = await SupabaseConfig.client
        .from('questions')
        .select()
        .order('created_at')
        .limit(10);

    // 4. Filter in Dart
    final unseen = (questionsResponse as List)
        .where((q) => !seenIds.contains(q['id']))
        .toList();

    if (unseen.isEmpty) return null;
    return Question.fromJson(unseen.first);
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
    await SupabaseConfig.client.from('user_daily_question_answers').upsert({
      'user_id': userId,
      'question_id': questionId,
      'answer': answer,
      'is_planted': false,
      'planted_seed_id': null,
    }, onConflict: 'user_id,question_id');
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
} 