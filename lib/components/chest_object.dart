import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/sprite.dart';
import 'package:flame/flame.dart';
import '../models/chest_storage.dart';

class ChestObject extends SpriteAnimationComponent with TapCallbacks {
  final String examineText;
  final void Function(String, ChestStorage?)? onExamineRequested;
  final ChestStorage? chestStorage;
  bool isOpen = false;

  ChestObject({
    required Vector2 position,
    required Vector2 size,
    required this.examineText,
    this.onExamineRequested,
    this.chestStorage,
  }) : super(position: position, size: size) {
    print('ChestObject created at $position, size $size');
  }

  late SpriteAnimation _idleAnimation;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Load single-frame chest sprite (20x17) and scale to component size
    final image = await Flame.images.load('Chests/1.png');
    final chestSprite = Sprite(image);
    _idleAnimation = SpriteAnimation.spriteList([
      chestSprite,
    ], stepTime: double.infinity);
    animation = _idleAnimation;
  }

  @override
  void update(double dt) {
    super.update(dt);
    // No animation cycle required for single-frame sprite
  }

  @override
  bool onTapDown(TapDownEvent event) {
    // Open chest UI immediately
    if (!isOpen) {
      isOpen = true;
      if (onExamineRequested != null) {
        onExamineRequested!(examineText, chestStorage);
      }
      return true;
    }
    // If already open, close state toggles without UI
    isOpen = false;
    return true;
  }
} 