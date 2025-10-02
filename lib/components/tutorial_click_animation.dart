import 'package:flame/components.dart';
import 'package:flame_lottie/flame_lottie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A Lottie animation component that shows a click/tap animation for tutorial purposes
class TutorialClickAnimation extends Component with HasGameRef {
  final Vector2 targetPosition;
  final Vector2 targetSize;
  final Duration duration;
  final void Function()? onAnimationComplete;
  
  LottieComponent? _lottieComponent;
  Timer? _durationTimer;
  
  TutorialClickAnimation({
    required this.targetPosition,
    required this.targetSize,
    this.duration = const Duration(seconds: 3),
    this.onAnimationComplete,
  }) : super(priority: 5000);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    try {
      // First, test if the asset can be loaded as a string
      debugPrint('[TutorialClickAnimation] 🔍 Testing asset availability...');
      try {
        final String assetContent = await rootBundle.loadString('assets/lottie/tutorial/click.json');
        debugPrint('[TutorialClickAnimation] ✅ Asset string loaded, length: ${assetContent.length}');
      } catch (e) {
        debugPrint('[TutorialClickAnimation] ❌ Asset string loading failed: $e');
        throw Exception('Asset not found: $e');
      }
      
      // Load the click animation from assets
      final asset = Lottie.asset('assets/lottie/tutorial/click.json');
      final animation = await loadLottie(asset);
      
      // Create the Lottie component
      _lottieComponent = LottieComponent(
        animation,
        repeating: true, // Loop the animation
        size: targetSize, // Use the target size passed to the component
      )
        ..priority = 2000; // Ensure it renders above the owl
      
      // Position the animation at the target location
      _lottieComponent!.position = targetPosition;
      add(_lottieComponent!);
      
      // Set up timer to remove animation after duration
      _durationTimer = Timer(duration.inSeconds.toDouble(), onTick: () {
        onAnimationComplete?.call();
        removeFromParent();
      });
      
      debugPrint('[TutorialClickAnimation] ✅ Click animation loaded and positioned at $targetPosition');
      
    } catch (e) {
      debugPrint('[TutorialClickAnimation] ❌ Failed to load click animation: $e');
      debugPrint('[TutorialClickAnimation] 🔄 Attempting fallback approach...');
      
      // Try alternative asset loading approach
      try {
        final ByteData assetData = await rootBundle.load('assets/lottie/tutorial/click.json');
        debugPrint('[TutorialClickAnimation] ✅ Asset loaded as ByteData, length: ${assetData.lengthInBytes}');
        
        // Convert ByteData to String and try again
        final String assetString = String.fromCharCodes(assetData.buffer.asUint8List());
        debugPrint('[TutorialClickAnimation] ✅ Asset converted to string, length: ${assetString.length}');
        
        // Try loading with the string content
        final asset = Lottie.asset('assets/lottie/tutorial/click.json');
        final animation = await loadLottie(asset);
        
        _lottieComponent = LottieComponent(
          animation,
          repeating: true,
          size: targetSize,
        )
          ..priority = 2000;
        
        _lottieComponent!.position = targetPosition;
        add(_lottieComponent!);
        
        _durationTimer = Timer(duration.inSeconds.toDouble(), onTick: () {
          onAnimationComplete?.call();
          removeFromParent();
        });
        
        debugPrint('[TutorialClickAnimation] ✅ Fallback animation loaded successfully');
        
      } catch (fallbackError) {
        debugPrint('[TutorialClickAnimation] ❌ Fallback also failed: $fallbackError');
        // Remove this component if all attempts fail
        removeFromParent();
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _durationTimer?.update(dt);
  }

  @override
  void onRemove() {
    _durationTimer?.stop();
    super.onRemove();
  }

  /// Manually stop the animation
  void stop() {
    _durationTimer?.stop();
    removeFromParent();
  }

  /// Update the target position (useful if the target moves)
  void updateTargetPosition(Vector2 newPosition) {
    targetPosition.setFrom(newPosition);
    if (_lottieComponent != null) {
      _lottieComponent!.position = newPosition;
    }
  }
}
