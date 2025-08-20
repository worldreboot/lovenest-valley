import 'package:flutter/material.dart';

class FeatureTourStep {
  final IconData icon;
  final String title;
  final String description;
  final Widget visual;
  final String tryNowLabel;

  const FeatureTourStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.visual,
    this.tryNowLabel = 'Try it now',
  });
}

class FeatureTourOverlay extends StatelessWidget {
  final List<FeatureTourStep> steps;
  final int currentIndex;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onTryNow;

  const FeatureTourOverlay({
    super.key,
    required this.steps,
    required this.currentIndex,
    required this.onNext,
    required this.onSkip,
    required this.onTryNow,
  });

  @override
  Widget build(BuildContext context) {
    final step = steps[currentIndex];
    final isLast = currentIndex == steps.length - 1;
    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.5),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.pink.shade200, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(step.icon, color: Colors.pink, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: onSkip,
                        icon: const Icon(Icons.close),
                        tooltip: 'Skip tour',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 140),
                      width: double.infinity,
                      color: Colors.grey.shade100,
                      child: step.visual,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    step.description,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onTryNow,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(step.tryNowLabel),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: onNext,
                        child: Text(isLast ? 'Finish' : 'Next'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${currentIndex + 1}/${steps.length}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


