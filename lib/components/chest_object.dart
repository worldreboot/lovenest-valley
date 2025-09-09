import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/sprite.dart';
import 'package:flame/flame.dart';
import '../models/chest_storage.dart';

class ChestObject extends SpriteAnimationComponent with TapCallbacks {
  final String examineText;
  final void Function(String, ChestStorage?)? onExamineRequested;
  final ChestStorage? chestStorage;
  Future<void> Function(String chestId)? onPickUp; // Changed from final to allow setting after creation
  bool isOpen = false;

  // Long press detection
  int? _downEpochMs;
  static const double longPressThresholdMs = 500;

  ChestObject({
    required Vector2 position,
    required Vector2 size,
    required this.examineText,
    this.onExamineRequested,
    this.chestStorage,
    this.onPickUp, // Optional pick-up callback
  }) : super(position: position, size: size) {
    print('[ChestObject] 🏗️ ChestObject created at $position, size $size');
    print('[ChestObject] 🔧 Callbacks: onExamineRequested=${onExamineRequested != null}, onPickUp=${onPickUp != null}');
    print('[ChestObject] 📦 chestStorage: ${chestStorage != null ? 'exists (ID: ${chestStorage!.id})' : 'null'}');
  }

  late SpriteAnimation _idleAnimation;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    print('[ChestObject] 📥 onLoad called for chest at $position');
    print('[ChestObject] 🔧 Callbacks after onLoad: onExamineRequested=${onExamineRequested != null}, onPickUp=${onPickUp != null}');
    
    // Load single-frame chest sprite (20x17) and scale to component size
    final image = await Flame.images.load('Chests/1.png');
    final chestSprite = Sprite(image);
    _idleAnimation = SpriteAnimation.spriteList([
      chestSprite,
    ], stepTime: double.infinity);
    animation = _idleAnimation;
    print('[ChestObject] 🖼️ Chest sprite loaded and animation set');
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Dynamic Y-sort based on baseline so player appears in front/behind properly
    final baselineY = position.y + size.y;
    priority = 1000 + baselineY.toInt();
  }

  @override
  void onTapDown(TapDownEvent event) {
    _downEpochMs = DateTime.now().millisecondsSinceEpoch;
    print('[ChestObject] 👆 onTapDown detected at ${DateTime.now()} - _downEpochMs set to $_downEpochMs');
    print('[ChestObject] 📍 Tap position: ${event.canvasPosition}, Chest position: $position, size: $size');
    print('[ChestObject] 🔧 onPickUp callback exists: ${onPickUp != null}, chestStorage exists: ${chestStorage != null}');
  }

  @override
  void onTapUp(TapUpEvent event) {
    final up = DateTime.now().millisecondsSinceEpoch;
    final duration = _downEpochMs != null ? (up - _downEpochMs!) : 0;
    
    print('[ChestObject] 👆 onTapUp detected at ${DateTime.now()}');
    print('[ChestObject] ⏱️ Press duration: ${duration}ms, threshold: ${longPressThresholdMs}ms');
    print('[ChestObject] 📊 _downEpochMs: $_downEpochMs, up time: $up');

    if (duration >= longPressThresholdMs) {
      print('[ChestObject] 🎯 LONG PRESS DETECTED! Duration: ${duration}ms >= ${longPressThresholdMs}ms');
      // Long press: pick up chest if callback is provided
      if (onPickUp != null && chestStorage != null) {
        print('[ChestObject] ✅ Calling onPickUp callback with chest ID: ${chestStorage!.id}');
        onPickUp!(chestStorage!.id);
      } else {
        print('[ChestObject] ❌ Cannot pick up chest:');
        print('[ChestObject]   - onPickUp callback exists: ${onPickUp != null}');
        print('[ChestObject]   - chestStorage exists: ${chestStorage != null}');
        if (chestStorage != null) {
          print('[ChestObject]   - chestStorage ID: ${chestStorage!.id}');
        }
      }
      return;
    }

    print('[ChestObject] 👆 SHORT TAP detected - opening/closing chest UI');
    // Short tap: open/close chest UI
    if (!isOpen) {
      isOpen = true;
      print('[ChestObject] 🔓 Opening chest UI');
      if (onExamineRequested != null) {
        print('[ChestObject] 📞 Calling onExamineRequested callback');
        onExamineRequested!(examineText, chestStorage);
      } else {
        print('[ChestObject] ❌ onExamineRequested callback is null');
      }
    } else {
      // If already open, close state toggles without UI
      isOpen = false;
      print('[ChestObject] 🔒 Closing chest state (no UI)');
    }
  }
} 
