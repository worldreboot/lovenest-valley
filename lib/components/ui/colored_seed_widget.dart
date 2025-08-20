import 'package:flutter/material.dart';
import '../../utils/seed_color_generator.dart';

class ColoredSeedWidget extends StatelessWidget {
  final String questionId;
  final double size;
  final bool showGlow;
  final String? tooltip;

  const ColoredSeedWidget({
    super.key,
    required this.questionId,
    this.size = 50.0,
    this.showGlow = true,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final seedColor = SeedColorGenerator.generateSeedColor(questionId);
    final colorName = SeedColorGenerator.getColorName(seedColor);
    
    Widget seedImage = Image.asset(
      'assets/images/items/seeds.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: seedColor,
      colorBlendMode: BlendMode.modulate,
    );

    // Add glow effect if enabled
    if (showGlow) {
      seedImage = Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: seedColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: seedImage,
      );
    }

    // Add tooltip if provided
    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: seedImage,
      );
    }

    return seedImage;
  }
}

/// A specialized widget for daily question seeds with enhanced styling
class DailyQuestionSeedWidget extends StatelessWidget {
  final String questionId;
  final String questionText;
  final VoidCallback? onTap;
  final bool isCollected;

  const DailyQuestionSeedWidget({
    super.key,
    required this.questionId,
    required this.questionText,
    this.onTap,
    this.isCollected = false,
  });

  @override
  Widget build(BuildContext context) {
    final seedColor = SeedColorGenerator.generateSeedColor(questionId);
    final colorName = SeedColorGenerator.getColorName(seedColor);

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.brown.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCollected ? seedColor : Colors.brown.shade300,
          width: isCollected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Colored seed
          Center(
            child: ColoredSeedWidget(
              questionId: questionId,
              size: 50,
              showGlow: isCollected,
              tooltip: '$colorName Daily Question Seed',
            ),
          ),
          // Collection indicator
          if (isCollected)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: seedColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          // Quantity indicator
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: seedColor,
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
      ),
    );
  }
} 