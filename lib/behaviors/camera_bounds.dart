import 'package:flame/components.dart';
import 'package:lovenest/game/farm_game.dart';

class CameraBoundsBehavior extends Component with HasGameRef<FarmGame> {
  @override
  void update(double dt) {
    final viewfinder = game.camera.viewfinder;
    final camera = game.camera;

    final worldWidth = 30 * 32.0;
    final worldHeight = 20 * 32.0;

    // Use the camera's visible world rectangle to calculate clamping bounds.
    // This is more robust than using hardcoded values.
    final visibleRect = camera.visibleWorldRect;
    final halfViewportWidth = visibleRect.width / 2;
    final halfViewportHeight = visibleRect.height / 2;

    final clampedX = viewfinder.position.x.clamp(
      halfViewportWidth,
      worldWidth - halfViewportWidth,
    );
    final clampedY = viewfinder.position.y.clamp(
      halfViewportHeight,
      worldHeight - halfViewportHeight,
    );

    viewfinder.position = Vector2(clampedX, clampedY);
  }
} 