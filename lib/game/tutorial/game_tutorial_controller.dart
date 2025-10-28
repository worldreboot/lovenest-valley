import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:lovenest_valley/game/simple_enhanced_farm_game.dart';
import 'package:lovenest_valley/models/inventory.dart';
import 'package:lovenest_valley/models/memory_garden/question.dart';
import 'package:lovenest_valley/components/tutorial_click_animation.dart';
import 'package:lovenest_valley/components/world/hoe_animation.dart';

typedef TutorialCaptionCallback = void Function(String? caption);

class GameTutorialController {
  GameTutorialController({
    required this.game,
    required this.inventoryManager,
    required this.context,
    required this.isMounted,
    required this.onCaptionChanged,
    required this.onFinished,
  });

  final SimpleEnhancedFarmGame game;
  final InventoryManager inventoryManager;
  final BuildContext context;
  final bool Function() isMounted;
  final TutorialCaptionCallback onCaptionChanged;
  final VoidCallback onFinished;

  Future<void>? _runFuture;

  Future<void> start() {
    _runFuture ??= _run();
    return _runFuture!;
  }

  Future<void> _run() async {
    await game.waitUntilReady();
    if (!isMounted()) {
      return;
    }

    game.setUserInputEnabled(false);
    game.player.disableKeyboardInput();

    final originalSlots = List<InventoryItem?>.from(inventoryManager.slots);
    final originalSelection = inventoryManager.selectedSlotIndex;
    
      // Store original tile state for cleanup
      int originalTileGid = 0;
      final plantingX = 32;
      final plantingY = 8;

    final question = Question(
      id: 'tutorial-daily-question',
      text: 'What moment made your partner smile today?',
      createdAt: DateTime.now(),
    );
    const answer = 'We laughed over pancakes together this morning.';

    try {
      await _narrate(
        "Welcome to Lovenest Valley! Let's walk through your daily rituals.",
        const Duration(seconds: 3),
      );

      // Debug: Log current player position and target
      debugPrint('[Tutorial] 🎯 Attempting to move player to owl area (39, 7)');
      debugPrint('[Tutorial] 📍 Current player position: ${game.player.position}');
      
      await game.movePlayerToGrid(39, 7);
      
      // Debug: Check if pathfinding worked
      debugPrint('[Tutorial] 📍 Player position after move attempt: ${game.player.position}');
      debugPrint('[Tutorial] 🛤️ Player current path: ${game.player.currentPath}');
      debugPrint('[Tutorial] 🎯 Player path index: ${game.player.currentPathIndex}');
      
      await _narrate(
        "Meet the Owl! Each day it shares a prompt to spark conversation.",
        const Duration(seconds: 3),
      );

      // Show click animation on the owl
      await _showClickAnimationOnOwl();

      await _narrate(
        'Today\'s question: "${question.text}"',
        const Duration(seconds: 3),
      );

      final tutorialSeed = InventoryItem(
        id: 'daily_question_seed_tutorial',
        name: 'Daily Question Seed',
        iconPath: 'assets/images/items/seeds.png',
        quantity: 1,
        itemColor: Colors.pinkAccent.shade200,
      );
      _injectSeed(tutorialSeed);
      
      // Debug: Try moving to a different nearby position
      debugPrint('[Tutorial] 🎯 Attempting to move player to owl area (39, 7)');
      debugPrint('[Tutorial] 📍 Current player position: ${game.player.position}');
      
      await game.movePlayerToGrid(39, 7);
      
      // Debug: Check if pathfinding worked
      debugPrint('[Tutorial] 📍 Player position after move attempt: ${game.player.position}');
      debugPrint('[Tutorial] 🛤️ Player current path: ${game.player.currentPath}');
      debugPrint('[Tutorial] 🎯 Player path index: ${game.player.currentPathIndex}');
      
      await _narrate(
        "The Owl hands you a memory seed ready to plant together.",
        const Duration(seconds: 3),
      );

      // Move to a good planting area (grass tiles around spawn area)
      await game.movePlayerToGrid(plantingX, plantingY);
      
      // Store the original tile state before any modifications
      originalTileGid = game.getGidAt(plantingX, plantingY);
      debugPrint('[Tutorial] 📝 Stored original tile GID: $originalTileGid at ($plantingX, $plantingY)');
      
      await _narrate(
        "Stand beside a cozy patch so we can plant your answer together.",
        const Duration(seconds: 3),
      );

      // First, give the player a hoe to prepare the ground
      await _narrate(
        "Let's get a hoe to prepare the ground for planting.",
        const Duration(seconds: 2),
      );

      // Give player a hoe temporarily
      final hoe = InventoryItem(
        id: 'hoe',
        name: 'Hoe',
        iconPath: 'assets/images/items/hoe.png',
        quantity: 1,
        itemColor: Colors.brown,
      );
      _injectSeed(hoe);

      await _narrate(
        "Now let's hoe the ground to prepare it for planting.",
        const Duration(seconds: 2),
      );

      // Create and show a simple hoe animation
      debugPrint('[Tutorial] 🚜 Creating hoe animation at (32, 8)');
      await _showHoeAnimation(32, 8);
      
      // Wait for the hoe animation to complete
      await Future.delayed(const Duration(milliseconds: 1500));

      await _narrate(
        "Perfect! Now the ground is ready for planting.",
        const Duration(seconds: 2),
      );

      await _showAutoAnswerSheet(question.text, answer);
      if (!isMounted()) {
        return;
      }

      await game.addPlantedSeed(
        plantingX,
        plantingY,
        tutorialSeed.id,
        'planted',
        seedColor: tutorialSeed.itemColor,
        skipBackend: true,
      );

      await _narrate(
        "Beautiful! Water it later to watch this memory grow into a bloom.",
        const Duration(seconds: 3),
      );

      await Future.delayed(const Duration(seconds: 1));

      await _narrate(
        "Let's stroll to the shoreline to leave a seashell voice note.",
        const Duration(seconds: 3),
      );

      // Move to first beach location
      debugPrint('[Tutorial] 🏖️ Moving player to first beach location (34, 17)');
      await game.movePlayerToGrid(34, 17);
      debugPrint('[Tutorial] 🏖️ Player moved to first beach location, current position: ${game.player.position}');

      // Move to second beach location
      debugPrint('[Tutorial] 🏖️ Moving player to second beach location (34, 21)');
      await game.movePlayerToGrid(34, 21);
      debugPrint('[Tutorial] 🏖️ Player moved to second beach location, current position: ${game.player.position}');
      
      await _narrate(
        "Here's a perfect spot on the beach for your seashell.",
        const Duration(seconds: 2),
      );
      
      await _showSeashellDemo();
      if (!isMounted()) {
        return;
      }

      await _narrate(
        "Seashells hold little voice messages so your partner can listen whenever they miss you.",
        const Duration(seconds: 3),
      );

      await _narrate(
        "Now let's peek at the shop for a surprise gift.",
        const Duration(seconds: 3),
      );

      // Move to shop area (near bonfire spawn)
      await game.movePlayerToGrid(34, 12);
      await _showShopPreview();
      if (!isMounted()) {
        return;
      }

      await _narrate(
        "Planting memories earns coins you can spend on heartfelt gifts that appear at your partner's door.",
        const Duration(seconds: 3),
      );

      await _narrate(
        "That's the tour! Explore, create, and keep surprising each other.",
        const Duration(seconds: 3),
      );

      game.removePlantedSeed(plantingX, plantingY);
      
      // Clear any tile overrides from the tutorial tilling and refresh visual state
      debugPrint('[Tutorial] 🧹 Clearing tile overrides from tutorial tilling and refreshing visual state');
      await game.clearTileOverridesAndRefresh();
      
      // Restore the original tile state
      if (originalTileGid > 0) {
        debugPrint('[Tutorial] 🔄 Restoring original tile GID: $originalTileGid at ($plantingX, $plantingY)');
        await game.updateTileWithAutoTiling(plantingX, plantingY, originalTileGid);
        debugPrint('[Tutorial] ✅ Original tile state restored');
      } else {
        debugPrint('[Tutorial] ⚠️ No original tile state to restore');
      }
    } finally {
      for (var i = 0; i < InventoryManager.maxSlots; i++) {
        inventoryManager.setItem(i, originalSlots[i]);
      }
      inventoryManager.selectSlot(originalSelection);
      game.setUserInputEnabled(true);
      game.player.enableKeyboardInput();
      onCaptionChanged(null);
      if (isMounted()) {
        onFinished();
      }
    }
  }

  Future<void> _narrate(String text, Duration delay) async {
    if (!isMounted()) {
      return;
    }
    onCaptionChanged(text);
    await Future.delayed(delay);
  }

  int _injectSeed(InventoryItem seed) {
    final slots = inventoryManager.slots;
    int index = slots.indexWhere((item) => item == null);
    if (index == -1) {
      index = 0;
    }
    inventoryManager.setItem(index, seed);
    inventoryManager.selectSlot(index);
    return index;
  }

  Future<void> _showAutoAnswerSheet(
      String questionText, String answerText) async {
    if (!isMounted()) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _TutorialAutoPlantSheet(
        questionText: questionText,
        answerText: answerText,
      ),
    );
  }

  Future<void> _showSeashellDemo() async {
    if (!isMounted()) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final navigator = Navigator.of(dialogContext);
        Future.delayed(const Duration(seconds: 3), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        });
        return const _TutorialSeashellDialog();
      },
    );
  }

  Future<void> _showShopPreview() async {
    if (!isMounted()) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final navigator = Navigator.of(sheetContext);
        Future.delayed(const Duration(seconds: 3), () {
          if (navigator.mounted && navigator.canPop()) {
            navigator.pop();
          }
        });
        return const _TutorialShopSheet();
      },
    );
  }

  Future<void> _showClickAnimationOnOwl() async {
    if (!isMounted()) {
      return;
    }

    try {
      // Get the owl's position from the game
      // The owl is typically at grid position (39, 7) or similar
      // We need to convert this to world coordinates
      final owlGridX = 39;
      final owlGridY = 7;
      final tileSize = 16.0; // Standard tile size
      
      // Calculate owl's world position (center of the tile)
      final owlWorldX = owlGridX * tileSize + tileSize / 2;
      final owlWorldY = owlGridY * tileSize + tileSize / 2;
      
      // Offset the animation upward to be visible above the owl
      final animationOffsetY = -60.0; // Move up by 60 pixels (increased for better visibility)
      final animationX = owlWorldX;
      final animationY = owlWorldY + animationOffsetY;
      
      debugPrint('[Tutorial] 🎯 Showing click animation at owl position ($owlWorldX, $owlWorldY)');
      debugPrint('[Tutorial] 🎯 Animation positioned at ($animationX, $animationY)');
      
      // Create and add the click animation
      final clickAnimation = TutorialClickAnimation(
        targetPosition: Vector2(animationX, animationY),
        targetSize: Vector2(80, 80), // Larger animation size for better visibility
        duration: const Duration(seconds: 4), // Show for 4 seconds
        onAnimationComplete: () {
          debugPrint('[Tutorial] ✅ Click animation completed');
        },
      );
      
      // Add the animation to the game world
      game.world.add(clickAnimation);
      
      // Wait for the animation to complete
      await Future.delayed(const Duration(seconds: 4));
      
      debugPrint('[Tutorial] 🎯 Click animation finished');
      
    } catch (e) {
      debugPrint('[Tutorial] ❌ Failed to show click animation: $e');
      // Continue with tutorial even if animation fails
    }
  }

  Future<void> _showHoeAnimation(int gridX, int gridY) async {
    if (!isMounted()) {
      return;
    }

    try {
      final tileSize = 16.0; // Standard tile size
      
      // Calculate world position for the hoe animation
      final worldX = gridX * tileSize;
      final worldY = gridY * tileSize;
      
      debugPrint('[Tutorial] 🚜 Showing hoe animation at grid ($gridX, $gridY) -> world ($worldX, $worldY)');
      
      // Create a simple hoe animation component
      final hoeAnimation = HoeAnimation(
        position: Vector2(worldX, worldY),
        size: Vector2(tileSize, tileSize),
        swingDirection: 1, // Front swing
        shouldFlip: false,
        onAnimationComplete: () async {
          debugPrint('[Tutorial] ✅ Hoe animation completed');
          // After animation, till the tile
          await _tillTileAt(gridX, gridY);
        },
      );
      
      // Add the animation to the game world
      game.world.add(hoeAnimation);
      
      debugPrint('[Tutorial] 🚜 Hoe animation started');
      
    } catch (e) {
      debugPrint('[Tutorial] ❌ Failed to show hoe animation: $e');
      // Continue with tutorial even if animation fails
    }
  }

  Future<void> _tillTileAt(int gridX, int gridY) async {
    try {
      debugPrint('[Tutorial] 🚜 Tilling tile at ($gridX, $gridY) using terrain system (tutorial mode)');
      // Use the game's public method to till the tile using the proper terrain system
      // skipBackend: true ensures this is only a visual change and won't persist
      await game.tillTile(gridX, gridY, skipBackend: true);
      debugPrint('[Tutorial] ✅ Tile tilled successfully with proper terrain system (no backend save)');
    } catch (e) {
      debugPrint('[Tutorial] ❌ Failed to till tile: $e');
    }
  }
}

class _TutorialAutoPlantSheet extends StatefulWidget {
  const _TutorialAutoPlantSheet({
    required this.questionText,
    required this.answerText,
  });

  final String questionText;
  final String answerText;

  @override
  State<_TutorialAutoPlantSheet> createState() =>
      _TutorialAutoPlantSheetState();
}

class _TutorialAutoPlantSheetState extends State<_TutorialAutoPlantSheet> {
  String _displayedAnswer = '';

  @override
  void initState() {
    super.initState();
    _typeAnswer();
  }

  Future<void> _typeAnswer() async {
    await Future.delayed(const Duration(milliseconds: 300));
    for (var i = 1; i <= widget.answerText.length; i++) {
      if (!mounted) {
        return;
      }
      setState(() {
        _displayedAnswer = widget.answerText.substring(0, i);
      });
      await Future.delayed(const Duration(milliseconds: 45));
    }
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: bottomPadding + 24,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  const Icon(Icons.psychology, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Text(
                    "Daily Question",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.questionText,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F0FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _displayedAnswer.isEmpty ? "..." : _displayedAnswer,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.pinkAccent),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Planting your reply...",
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialSeashellDialog extends StatelessWidget {
  const _TutorialSeashellDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0C6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset(
                'assets/images/seashell.png',
                width: 72,
                height: 72,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Seashell Voice Notes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Leave a quick voice hug on the beach. Your partner can tap the shell to listen when they miss you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialShopSheet extends StatelessWidget {
  const _TutorialShopSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storefront, color: Colors.pinkAccent),
              SizedBox(width: 12),
              Text(
                'Gift Shop',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Spend coins on thoughtful surprises - flowers, letters, and cozy decor for your shared space.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              _GiftCard(
                icon: Icons.local_florist,
                title: 'Bloom Bouquet',
                description: 'Brighten the garden with a fresh bundle.',
              ),
              SizedBox(width: 12),
              _GiftCard(
                icon: Icons.cake,
                title: 'Sweet Treat',
                description: 'Surprise dessert for your next date night.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  const _GiftCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4FB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x33FF4081)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.pinkAccent, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(fontSize: 12, height: 1.3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
