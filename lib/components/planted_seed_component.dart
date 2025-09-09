import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:lovenest_valley/services/farm_tile_service.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:lovenest_valley/screens/seed_details_dialog.dart';
import 'package:flame/events.dart';
import 'package:flame/flame.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:lovenest_valley/services/question_service.dart';
import 'package:lovenest_valley/services/seed_info_service.dart';

// A simple in-memory cache for generated sprites to avoid re-downloading.
final _generatedSpriteCache = <String, ui.Image>{};

class PlantedSeedComponent extends SpriteComponent with TapCallbacks {
  final String seedId;
  final int gridX;
  final int gridY;
  String growthStage; // 'planted', 'growing', 'fully_grown'
  final Color? seedColor; // For colored seeds like daily question seeds
  final String farmId; // For fetching generated sprites
  // DEBUG: when true, bypass sprite rendering and draw a placeholder rect instead
  final bool usePlaceholderRect;
  // Overlay indicator when partner answer is pending
  bool _showPartnerNeeded = false;
  Sprite? _notificationSprite;
  
  PlantedSeedComponent({
    required this.seedId,
    required this.gridX,
    required this.gridY,
    required this.growthStage,
    required Sprite sprite,
    required Vector2 position,
    this.seedColor,
    required this.farmId,
    this.usePlaceholderRect = false,
  }) : super(
    sprite: sprite,
    position: position,
    size: Vector2.all(16.0), // tileSize - matches crop tile size
    priority: 1, // Render above ground tile layer
  );
  
  @override
  void render(Canvas canvas) {
    if (usePlaceholderRect) {
      // Draw a simple magenta square to confirm rendering path without sprites
      final paint = Paint()..color = const Color(0xFFFF00FF);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
      if (_showPartnerNeeded) {
        _drawPartnerOverlay(canvas);
      }
      return;
    }

    try {
      if (sprite == null) {
        debugPrint('[PlantedSeedComponent] ⚠️ render called with null sprite at ($gridX,$gridY), stage=$growthStage');
      }
    } catch (_) {}
    // Temporarily disable color tinting to test if it's causing rendering issues
    // if (seedColor != null) {
    //   // Apply color tint for colored seeds using a simpler approach
    //   canvas.save();
    //   final paint = Paint()
    //     ..colorFilter = ColorFilter.mode(seedColor!, BlendMode.modulate);
    //   canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), paint);
    // }
    
    try {
      super.render(canvas);
    } catch (e, st) {
      debugPrint('[PlantedSeedComponent] ❌ Exception in render: $e\n$st');
    }
    if (_showPartnerNeeded) {
      _drawPartnerOverlay(canvas);
    }
    
    // if (seedColor != null) {
    //   canvas.restore();
    // }
  }
  
  @override
  void onMount() {
    super.onMount();
    debugPrint('[PlantedSeedComponent] 🌱 Planted seed component mounted at ($gridX, $gridY)');
    // Lazy-load owl notification sprite for overlay
    Flame.images.load('owl_noti.png').then((image) {
      _notificationSprite = Sprite(image);
    }).catchError((_) {});
  }

  /// Update the sprite and growth stage
  void updateGrowth(String newGrowthStage, Sprite newSprite) {
    growthStage = newGrowthStage;
    sprite = newSprite;
    debugPrint('[PlantedSeedComponent] 🔄 updateGrowth -> $newGrowthStage at ($gridX,$gridY)');
  }

  /// Toggle overlay to indicate partner answer is needed
  void setPartnerNeeded(bool needed) {
    _showPartnerNeeded = needed;
  }

  void _drawPartnerOverlay(Canvas canvas) {
    // Hover animation: slower vertical bobbing (≈2.4s period) with gentle amplitude
    const periodMs = 2400;
    final t = (DateTime.now().millisecondsSinceEpoch % periodMs) / periodMs; // 0..1
    final bob = math.sin(t * 2 * math.pi) * 2.5; // ±2.5 px
    final overlaySize = Vector2(22, 22); // much bigger icon
    final overlayPos = Vector2((size.x - overlaySize.x) / 2, -overlaySize.y - 6 + bob);
    if (_notificationSprite != null) {
      _notificationSprite!.render(canvas, position: overlayPos, size: overlaySize);
    } else {
      // Fallback amber badge while sprite loads
      final badgePaint = Paint()..color = const Color(0xFFFFA000);
      const r = 6.0;
      final center = Offset(size.x / 2, -r - 6 + bob);
      canvas.drawCircle(center, r, badgePaint);
      final outline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0xFF3E2723);
      canvas.drawCircle(center, r, outline);
    }
  }

  @override
  Future<void> onTapDown(TapDownEvent event) async {
    debugPrint('[PlantedSeedComponent] 👆 Tap detected on seed at ($gridX, $gridY)');
    
    // Log seed watering and planting information
    _logSeedInfo();
    
    // If partner-needed overlay is shown, allow user to submit their answer directly
    if (_showPartnerNeeded) {
      event.handled = true; // consume so game doesn't treat as watering tap
      _promptSubmitAnswer();
      return;
    }

    // Only show details dialog if the plant is fully grown
    if (growthStage == 'fully_grown') {
      debugPrint('[PlantedSeedComponent] 🌸 Showing seed details dialog for fully grown plant');
      
      // Get the game's context to show the dialog
      final game = findGame();
      if (game != null) {
        // Use a post-frame callback to ensure the context is available
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: game.buildContext!,
            builder: (context) => SeedDetailsDialog(
              plotX: gridX,
              plotY: gridY,
              farmId: farmId,
            ),
          );
        });
      } else {
        debugPrint('[PlantedSeedComponent] ❌ Game instance not found, cannot show dialog');
      }
      event.handled = true; // consume
      return;
    }
    
    debugPrint('[PlantedSeedComponent] 🌱 Plant not fully grown yet (stage: $growthStage)');
    // If the player has a watering can selected and is adjacent, trigger watering directly
    final game = findGame();
    if (game != null) {
      try {
        final dynamic dynGame = game;
        final watered = await dynGame.tryWaterAt(gridX, gridY) as bool?;
        if (watered == true) {
          event.handled = true; // consume to avoid duplicate handling
          return;
        }
      } catch (_) {}
    }
    // Otherwise, do not consume: let game handle input
    return;
  }

  /// Log seed watering and planting information
  Future<void> _logSeedInfo() async {
    try {
      final seedInfo = await SeedInfoService.getSeedInfo(gridX, gridY, farmId);
      
      if (seedInfo != null) {
        final source = seedInfo['source'] as String? ?? 'unknown';
        
        debugPrint('🌱 === SEED TAP INFO ===');
        debugPrint('📍 Location: ($gridX, $gridY)');
        debugPrint('📊 Data Source: $source');
        
        if (source == 'farm_seeds' || source == 'farm_tiles') {
          // Farm seed data (has watering info)
          final waterCount = seedInfo['water_count'] as int? ?? 0;
          final lastWateredAt = seedInfo['last_watered_at'] as String?;
          final plantedAt = seedInfo['planted_at'] as String?;
          final plantType = seedInfo['plant_type'] as String? ?? 'unknown';
          
          debugPrint('🌿 Plant Type: $plantType');
          debugPrint('💧 Times Watered: $waterCount');
          debugPrint('⏰ Last Watered: ${SeedInfoService.formatTimestamp(lastWateredAt)}');
          debugPrint('🌱 Planted: ${SeedInfoService.formatTimestamp(plantedAt)}');
        } else if (source == 'seeds') {
          // Memory garden seed data (different fields)
          final state = seedInfo['state'] as String? ?? 'unknown';
          final growthScore = seedInfo['growth_score'] as int? ?? 0;
          final createdAt = seedInfo['created_at'] as String?;
          final lastUpdatedAt = seedInfo['last_updated_at'] as String?;
          final textContent = seedInfo['text_content'] as String?;
          final mediaType = seedInfo['media_type'] as String? ?? 'unknown';
          
          debugPrint('🌿 State: $state');
          debugPrint('📈 Growth Score: $growthScore');
          debugPrint('📝 Media Type: $mediaType');
          debugPrint('⏰ Created: ${SeedInfoService.formatTimestamp(createdAt)}');
          debugPrint('🔄 Last Updated: ${SeedInfoService.formatTimestamp(lastUpdatedAt)}');
          if (textContent != null && textContent.isNotEmpty) {
            debugPrint('💭 Content: ${textContent.length > 50 ? '${textContent.substring(0, 50)}...' : textContent}');
          }
        }
        
        debugPrint('🌱 === END SEED INFO ===');
      } else {
        debugPrint('🌱 === SEED TAP INFO ===');
        debugPrint('📍 Location: ($gridX, $gridY)');
        debugPrint('❌ No seed data found in backend');
        debugPrint('🌱 === END SEED INFO ===');
      }
    } catch (e) {
      debugPrint('[PlantedSeedComponent] ❌ Error logging seed info: $e');
    }
  }

  Future<void> _promptSubmitAnswer() async {
    final game = findGame();
    if (game == null) return;
    try {
      // Get question id from farm_seeds.properties for this tile
      final fs = await SupabaseConfig.client
          .from('farm_seeds')
          .select('properties')
          .eq('farm_id', farmId)
          .eq('x', gridX)
          .eq('y', gridY)
          .maybeSingle();
      final props = (fs != null ? fs['properties'] as Map<String, dynamic>? : null) ?? {};
      final String? questionId = props['question_id'] as String?;
      if (questionId == null) {
        debugPrint('[PlantedSeedComponent] ❌ No question_id found for farm seed at ($gridX,$gridY)');
        return;
      }

      // Fetch question text
      final q = await SupabaseConfig.client
          .from('questions')
          .select('text')
          .eq('id', questionId)
          .maybeSingle();
      final questionText = (q != null ? q['text'] as String? : null) ?? 'Daily Question';

      // Show simple input dialog
      final controller = TextEditingController();
      await showDialog(
        context: game.buildContext!,
        barrierDismissible: true,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Answer to plant'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(questionText),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: null,
                  decoration: const InputDecoration(
                    labelText: 'Your answer',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final answer = controller.text.trim();
                  try {
                    // Save answer for current user
                    await QuestionService.saveDailyQuestionAnswer(questionId, answer);
                    // Mark tile-specific answered state
                    final userId = SupabaseConfig.currentUserId;
                    if (userId != null) {
                      await SupabaseConfig.client.from('farm_seed_answers').upsert({
                        'farm_id': farmId,
                        'x': gridX,
                        'y': gridY,
                        'question_id': questionId,
                        'user_id': userId,
                        'answered_at': DateTime.now().toIso8601String(),
                      }, onConflict: 'farm_id,x,y,user_id');
                    }
                    // Hide overlay locally
                    setPartnerNeeded(false);
                  } catch (e) {
                    debugPrint('[PlantedSeedComponent] ❌ Failed to submit answer: $e');
                  } finally {
                    Navigator.of(ctx).pop();
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      debugPrint('[PlantedSeedComponent] ❌ Error prompting answer: $e');
    }
  }
  
  /// Check if this seed has a generated sprite and load it
  Future<void> checkAndLoadGeneratedSprite() async {
    debugPrint('[PlantedSeedComponent] 🔍 Checking for generated sprite at ($gridX, $gridY)');
    debugPrint('[PlantedSeedComponent] 📊 Current growth stage: $growthStage');
    
    if (growthStage == 'fully_grown') {
      debugPrint('[PlantedSeedComponent] ✅ Growth stage is fully_grown, checking for sprite...');
      try {
        final farmTileService = FarmTileService();
        final spriteUrl = await farmTileService.getSeedSpriteUrl(farmId, gridX, gridY);
        
        debugPrint('[PlantedSeedComponent] 🖼️ Sprite URL: ${spriteUrl ?? 'NULL'}');
        
        if (spriteUrl != null) {
          debugPrint('[PlantedSeedComponent] 🎨 Attempting to load generated sprite from URL: $spriteUrl');
          final game = findGame();
          if (game != null) {
            try {
              ui.Image image;
              // Check if the image is already in our private cache
              if (_generatedSpriteCache.containsKey(spriteUrl)) {
                image = _generatedSpriteCache[spriteUrl]!;
                debugPrint('[PlantedSeedComponent] 🌸 Loaded sprite from custom cache for seed at ($gridX, $gridY)');
              } else {
                // If not in cache, download it
                final response = await http.get(Uri.parse(spriteUrl));
                if (response.statusCode == 200) {
                  final imageBytes = response.bodyBytes;
                  image = await decodeImageFromList(imageBytes);
                  // Add the decoded image to our cache
                  _generatedSpriteCache[spriteUrl] = image;
                  debugPrint('[PlantedSeedComponent] 🌸 Downloaded and cached sprite for seed at ($gridX, $gridY)');
                } else {
                  debugPrint('[PlantedSeedComponent] ❌ Failed to download image. Status code: ${response.statusCode}');
                  // Return early if download fails
                  return;
                }
              }
              // Create the sprite and enlarge the component
              sprite = Sprite(image);
              size = Vector2.all(32.0);
              position -= Vector2.all(8.0);
            } catch (e) {
              debugPrint('[PlantedSeedComponent] ❌ Error loading sprite: $e');
            }
          } else {
            debugPrint('[PlantedSeedComponent] ❌ Game instance not found, cannot load sprite.');
          }
        } else {
          debugPrint('[PlantedSeedComponent] ❌ No sprite URL found, cannot load generated sprite.');
        }
      } catch (e) {
        debugPrint('[PlantedSeedComponent] ❌ Error loading generated sprite: $e');
      }
    } else {
      debugPrint('[PlantedSeedComponent] ❌ Growth stage is not fully_grown: $growthStage');
    }
  }
  
  /// Get a string representation for debugging
  @override
  String toString() {
    return 'PlantedSeedComponent(seedId: $seedId, gridX: $gridX, gridY: $gridY, growthStage: $growthStage)';
  }
} 
