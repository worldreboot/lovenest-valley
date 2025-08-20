import 'package:flutter/material.dart';
import 'package:lovenest/models/relationship_goal.dart';

class RelationshipGoalsDialog extends StatefulWidget {
  final Map<RelationshipGoalCategory, List<RelationshipGoal>> goalsByCategory;
  final Future<void> Function(String text, RelationshipGoalCategory category) onAddGoal;
  final Future<void> Function(String id) onToggleComplete;

  const RelationshipGoalsDialog({
    super.key,
    required this.goalsByCategory,
    required this.onAddGoal,
    required this.onToggleComplete,
  });

  @override
  State<RelationshipGoalsDialog> createState() => _RelationshipGoalsDialogState();
}

class _RelationshipGoalsDialogState extends State<RelationshipGoalsDialog> {
  final TextEditingController _controller = TextEditingController();
  RelationshipGoalCategory _selected = RelationshipGoalCategory.romantic;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [Colors.amber.shade200, Colors.amber.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.brown.shade700, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 6)),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Container(
              decoration: BoxDecoration(
                color: Colors.brown.shade700,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.brown.shade900, width: 2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orangeAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'Relationship Goals',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Prompt
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200, width: 1.5),
              ),
              child: const Text(
                "What's something we want to achieve this month?",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 10),

            // Add goal row
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.brown.shade300),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Plan a picnic',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _CategoryPicker(
                  selected: _selected,
                  onChanged: (c) => setState(() => _selected = c),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    if (_controller.text.trim().isEmpty) return;
                    await widget.onAddGoal(_controller.text.trim(), _selected);
                    _controller.clear();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Goals list
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final category in RelationshipGoalCategory.values)
                      _CategoryPanel(
                        title: _label(category),
                        color: _headerColor(category),
                        goals: widget.goalsByCategory[category] ?? const [],
                        onToggle: widget.onToggleComplete,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

  Color _headerColor(RelationshipGoalCategory c) {
    switch (c) {
      case RelationshipGoalCategory.romantic:
        return Colors.pink.shade300;
      case RelationshipGoalCategory.fun:
        return Colors.purple.shade300;
      case RelationshipGoalCategory.silly:
        return Colors.orange.shade300;
      case RelationshipGoalCategory.serious:
        return Colors.teal.shade400;
    }
  }
}

class _CategoryPicker extends StatelessWidget {
  final RelationshipGoalCategory selected;
  final ValueChanged<RelationshipGoalCategory> onChanged;
  const _CategoryPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = RelationshipGoalCategory.values;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.brown.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<RelationshipGoalCategory>(
          value: selected,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          items: [
            for (final c in items)
              DropdownMenuItem(
                value: c,
                child: Text(_label(c)),
              )
          ],
          onChanged: (c) {
            if (c != null) onChanged(c);
          },
        ),
      ),
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

class _CategoryPanel extends StatelessWidget {
  final String title;
  final Color color;
  final List<RelationshipGoal> goals;
  final Future<void> Function(String id) onToggle;

  const _CategoryPanel({
    required this.title,
    required this.color,
    required this.goals,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade300, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border.all(color: Colors.brown.shade400, width: 1.5),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (goals.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                'No goals yet',
                style: TextStyle(color: Colors.brown.shade400, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...goals.map((g) => _GoalRow(goal: g, onToggle: onToggle)).toList(),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final RelationshipGoal goal;
  final Future<void> Function(String id) onToggle;
  const _GoalRow({required this.goal, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onToggle(goal.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.brown.shade200, width: 1)),
        ),
        child: Row(
          children: [
            Icon(
              goal.completed ? Icons.favorite : Icons.favorite_border,
              color: goal.completed ? Colors.pinkAccent : Colors.brown.shade300,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                goal.text,
                style: TextStyle(
                  decoration: goal.completed ? TextDecoration.lineThrough : TextDecoration.none,
                  color: goal.completed ? Colors.brown.shade400 : Colors.brown.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (goal.completed)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                    SizedBox(width: 4),
                    Text('Fuel', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}


