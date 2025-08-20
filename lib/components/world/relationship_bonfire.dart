import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:lovenest/components/world/bonfire.dart';
import 'package:lovenest/models/relationship_goal.dart';
import 'package:lovenest/services/relationship_goal_service.dart';
import 'package:flame/collisions.dart';
import 'package:lovenest/services/garden_repository.dart';
import 'package:lovenest/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lovenest/screens/relationship_goals_dialog.dart';

/// A wrapper around the visual Bonfire that grows with relationship goals
class RelationshipBonfire extends PositionComponent with TapCallbacks, HasGameRef {
  final String farmId;

  // Visual bonfire reused
  late final Bonfire _bonfire;

  // Scaling config
  final double baseSize; // visual size for 0 goals
  final double sizePerCompletedGoal; // extra size per completed goal
  final double woodPerGoal; // how much wood to add per completed goal

  RelationshipBonfire({
    required this.farmId,
    required Vector2 position,
    required Vector2 size,
    this.baseSize = 32,
    this.sizePerCompletedGoal = 4,
    this.woodPerGoal = 1.0,
  }) {
    this.position = position;
    this.size = size;
    anchor = Anchor.topLeft;
    // Ensure this captures taps before the game-level handler (same as Owl)
    priority = 10;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox());
    _bonfire = Bonfire(
      position: Vector2.zero(),
      size: size,
      maxWoodCapacity: 100,
      woodBurnRate: 0.2,
      maxFlameSize: 64,
      maxIntensity: 1.0,
    );
    _bonfire.setInteractionCallback(_showGoalsDialog);
    add(_bonfire);
    await _syncWithGoals();
    await _subscribeRealtime();
  }

  Future<void> _subscribeRealtime() async {
    try {
      final couple = await const GardenRepository().getUserCouple();
      if (couple == null) return;
      final cid = couple.id;
      SupabaseConfig.client
          .channel('relationship_goals_$cid')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'relationship_goals',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'couple_id', value: cid),
            callback: (payload) async => await _syncWithGoals(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'relationship_goals',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'couple_id', value: cid),
            callback: (payload) async => await _syncWithGoals(),
          )
          .subscribe();
    } catch (_) {}
  }

  Future<void> _syncWithGoals() async {
    final goals = await RelationshipGoalService().getGoals(farmId);
    final completedCount = goals.where((g) => g.completed).length;
    final woodToAdd = completedCount * woodPerGoal;
    if (woodToAdd > 0) {
      _bonfire.addWood(woodToAdd);
    }

    // Adjust visual scale based on total goals
    final totalGoals = goals.length;
    final extra = totalGoals * sizePerCompletedGoal;
    final target = baseSize + extra;
    final scaleFactorX = target / size.x;
    final scaleFactorY = target / size.y;
    _bonfire.scale = Vector2(scaleFactorX, scaleFactorY);
  }

  @override
  bool onTapDown(TapDownEvent event) {
    _showGoalsDialog();
    return true;
  }

  void _showGoalsDialog() {
    final game = findGame();
    if (game == null || game.buildContext == null) return;

    // Defer to after the frame to avoid context timing issues
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final goals = await RelationshipGoalService().getGoals(farmId);
    final Map<RelationshipGoalCategory, List<RelationshipGoal>> byCat = {
      for (final c in RelationshipGoalCategory.values) c: [],
    };
      for (final g in goals) {
      byCat[g.category]!.add(g);
    }

      showDialog(
        context: game.buildContext!,
        builder: (context) {
          return RelationshipGoalsDialog(
            goalsByCategory: byCat,
            onAddGoal: (text, category) async {
              await RelationshipGoalService().addGoal(
                farmId: farmId,
                text: text,
                category: category,
              );
              await _syncWithGoals();
            },
            onToggleComplete: (id) async {
              await RelationshipGoalService().completeGoal(farmId: farmId, goalId: id);
              await _syncWithGoals();
            },
          );
        },
      );
    });
  }

  // Removed unused helper _categoryLabel (now provided by dialog widget)
}

class _AddGoalForm extends StatefulWidget {
  final void Function(String text, RelationshipGoalCategory category) onSubmit;
  const _AddGoalForm({required this.onSubmit});

  @override
  State<_AddGoalForm> createState() => _AddGoalFormState();
}

class _AddGoalFormState extends State<_AddGoalForm> {
  final _controller = TextEditingController();
  RelationshipGoalCategory _selected = RelationshipGoalCategory.romantic;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: "Add a shared goal",
            hintText: "e.g. Plan a picnic",
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: RelationshipGoalCategory.values
              .map((c) => ChoiceChip(
                    label: Text(_label(c)),
                    selected: _selected == c,
                    onSelected: (_) => setState(() => _selected = c),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () {
              if (_controller.text.trim().isEmpty) return;
              widget.onSubmit(_controller.text.trim(), _selected);
              _controller.clear();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Goal'),
          ),
        ),
      ],
    );
  }

  String _label(RelationshipGoalCategory c) {
    switch (c) {
      case RelationshipGoalCategory.romantic:
        return 'Romantic';
      case RelationshipGoalCategory.fun:
        return 'Fun';
      case RelationshipGoalCategory.silly:
        return 'Silly';
      case RelationshipGoalCategory.serious:
        return 'Serious';
    }
  }
}


