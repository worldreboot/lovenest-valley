import 'package:flutter/material.dart';
import '../../models/memory_garden/question.dart';
import '../../components/ui/colored_seed_widget.dart';
import '../../utils/seed_color_generator.dart';

class DailyQuestionLetterSheet extends StatefulWidget {
  final Question question;
  final void Function(String answer)? onAnswered;
  final void Function()? onCollectSeed;

  const DailyQuestionLetterSheet({
    Key? key,
    required this.question,
    this.onAnswered,
    this.onCollectSeed,
  }) : super(key: key);

  @override
  State<DailyQuestionLetterSheet> createState() => _DailyQuestionLetterSheetState();
}

class _DailyQuestionLetterSheetState extends State<DailyQuestionLetterSheet> {

  @override
  Widget build(BuildContext context) {
    debugPrint('[DailyQuestionLetterSheet] 🎨 Building letter sheet');
    debugPrint('[DailyQuestionLetterSheet] 📝 Question ID: ${widget.question.id}');
    debugPrint('[DailyQuestionLetterSheet] 🔘 onCollectSeed callback: ${widget.onCollectSeed != null ? 'available' : 'null'}');
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // Light paper color
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.brown.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        image: const DecorationImage(
          image: AssetImage('assets/images/wood.png'),
          fit: BoxFit.cover,
          opacity: 0.08,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: Colors.brown, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Letter from the Owl',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown.shade700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.brown),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Decorative divider
          Center(
            child: Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.brown.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Question text
          Text(
            '"${widget.question.text}"',
            style: const TextStyle(
              fontSize: 20,
              fontStyle: FontStyle.italic,
              color: Colors.brown,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

                       // Seed collection section (always show, but with different content based on collection status)
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.eco, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${SeedColorGenerator.getColorName(SeedColorGenerator.generateSeedColor(widget.question.id))} Daily Question Seed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Inventory slot style container
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.brown.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.brown.shade300,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: widget.onCollectSeed != null
                        ? Stack(
                            children: [
                              // Colored seed widget (only show if not collected)
                              Center(
                                child: ColoredSeedWidget(
                                  questionId: widget.question.id,
                                  size: 50,
                                  showGlow: true,
                                  tooltip: 'Daily Question Seed',
                                ),
                              ),
                              // Quantity indicator
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade600,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '1',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            // Empty slot when already collected
                            child: Icon(
                              Icons.add,
                              color: Colors.grey,
                              size: 24,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.onCollectSeed != null
                        ? 'Plant the seed to answer the question!'
                        : 'You have already collected this seed.',
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.onCollectSeed != null ? Colors.green.shade600 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.onCollectSeed != null
                        ? 'Plant it and water it for 3 days to see it bloom into a unique flower.'
                        : 'Check your inventory to plant and grow it.',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.onCollectSeed != null ? Colors.green.shade500 : Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.onCollectSeed != null) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        debugPrint('[DailyQuestionLetterSheet] 🖱️ Collect button pressed');
                        if (widget.onCollectSeed != null) {
                          debugPrint('[DailyQuestionLetterSheet] 🌱 Calling onCollectSeed callback');
                          widget.onCollectSeed!();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Collect Seed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ],
              ),
            ),

        ],
      ),
    );
  }


} 
