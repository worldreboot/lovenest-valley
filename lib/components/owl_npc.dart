import 'package:flame/components.dart';
import 'package:flame/events.dart';

class OwlNpcComponent extends SpriteComponent with TapCallbacks {
  final void Function()? onTapOwl;
  final Sprite idleSprite;
  final Sprite notificationSprite;
  bool _showNotification = false;

  OwlNpcComponent({
    required this.idleSprite,
    required this.notificationSprite,
    required Vector2 position,
    required Vector2 size,
    this.onTapOwl,
  }) : super(sprite: idleSprite, position: position, size: size);

  void showNotification(bool show) {
    _showNotification = show;
    sprite = _showNotification ? notificationSprite : idleSprite;
  }

  @override
  bool onTapDown(TapDownEvent event) {
    onTapOwl?.call();
    return true;
  }
} 