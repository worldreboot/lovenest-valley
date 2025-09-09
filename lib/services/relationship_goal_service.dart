import 'package:lovenest_valley/models/relationship_goal.dart';
import 'package:lovenest_valley/services/garden_repository.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:uuid/uuid.dart';

/// In-memory placeholder service for relationship goals.
/// Replace with Supabase persistence later.
class RelationshipGoalService {
  static final RelationshipGoalService _instance = RelationshipGoalService._internal();
  factory RelationshipGoalService() => _instance;
  RelationshipGoalService._internal();

  final Map<String, List<RelationshipGoal>> _farmIdToGoals = {};

  static const String _table = 'relationship_goals';

  Future<String?> _getCoupleId() async {
    final couple = await const GardenRepository().getUserCouple();
    return couple?.id;
  }

  Future<List<RelationshipGoal>> getGoals(String farmId) async {
    // Prefer backend; fallback to in-memory
    try {
      final coupleId = await _getCoupleId();
      if (coupleId == null) return List<RelationshipGoal>.unmodifiable(_farmIdToGoals[farmId] ?? const []);
      final rows = await SupabaseConfig.client
          .from(_table)
          .select()
          .eq('couple_id', coupleId)
          .order('created_at');
      final goals = rows.map<RelationshipGoal>((e) => RelationshipGoal.fromJson(e)).toList();
      _farmIdToGoals[farmId] = goals;
      return List<RelationshipGoal>.unmodifiable(goals);
    } catch (_) {
      return List<RelationshipGoal>.unmodifiable(_farmIdToGoals[farmId] ?? const []);
    }
  }

  Future<RelationshipGoal> addGoal({
    required String farmId,
    required String text,
    required RelationshipGoalCategory category,
  }) async {
    final id = _generateId();
    final goal = RelationshipGoal(
      id: id,
      text: text,
      category: category,
      createdAt: DateTime.now(),
    );
    final goals = List<RelationshipGoal>.from(_farmIdToGoals[farmId] ?? const []);
    goals.add(goal);
    _farmIdToGoals[farmId] = goals;
    try {
      final coupleId = await _getCoupleId();
      if (coupleId != null) {
        await SupabaseConfig.client.from(_table).insert(goal.toJson(coupleId: coupleId));
      }
    } catch (_) {}
    return goal;
  }

  Future<void> completeGoal({required String farmId, required String goalId}) async {
    final goals = List<RelationshipGoal>.from(_farmIdToGoals[farmId] ?? const []);
    final index = goals.indexWhere((g) => g.id == goalId);
    if (index >= 0) {
      final g = goals[index];
      final updated = g.copyWith(completed: true, completedAt: DateTime.now());
      goals[index] = updated;
      _farmIdToGoals[farmId] = goals;
      try {
        await SupabaseConfig.client
            .from(_table)
            .update({
              'completed': true,
              'completed_at': updated.completedAt!.toIso8601String(),
            })
            .eq('id', goalId);
      } catch (_) {}
    }
  }

  String _generateId() => const Uuid().v4();
}


