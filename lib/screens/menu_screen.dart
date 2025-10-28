import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:math';
// Removed unused imports for clean build
import 'package:lovenest_valley/main.dart' show FarmLoader; // Use FarmLoader to route into SimpleEnhanced game flow
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';
import 'package:flame/components.dart';

import 'package:lovenest_valley/services/auth_service.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
// Removed unused import

/// Custom animated text widget with growing and shrinking effect
class GrowShrinkAnimatedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final Duration duration;

  GrowShrinkAnimatedText({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.center,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<GrowShrinkAnimatedText> createState() => _GrowShrinkAnimatedTextState();
}

class _GrowShrinkAnimatedTextState extends State<GrowShrinkAnimatedText>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    // Create a scale animation that goes from 0.8 to 1.2 and back to 0.8
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    // Reverse the animation to create a growing then shrinking effect
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    });
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Text(
            widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
          ),
        );
      },
    );
  }
}

/// Custom widget that renders grass tiles using the same approach as the game
class GrassTileBackground extends StatefulWidget {
  final Widget child;
  
  const GrassTileBackground({super.key, required this.child});

  @override
  State<GrassTileBackground> createState() => _GrassTileBackgroundState();
}

class _GrassTileBackgroundState extends State<GrassTileBackground> with TickerProviderStateMixin {
  SpriteSheet? _grassTileSheet;
  ui.Image? _houseImage;
  ui.Image? _treeImage;
  ui.Image? _cloudShadowImage;
  ui.Image? _coupleImage;
  List<ui.Image> _smokeImages = [];
  int _smokeFrameIndex = 0;
  AnimationController? _smokeAnimationController;
  bool _isLoading = true;
  
  AnimationController? _shadowAnimationController;
  Animation<double>? _shadowAnimation;
  @override
  void initState() {
    super.initState();
    _loadGrassTiles();
    _startSmokeAnimation();
    _initShadowAnimation();
  }
  
  void _initShadowAnimation() {
    _shadowAnimationController = AnimationController(
      duration: const Duration(seconds: 45), // Even slower cloud movement
      vsync: this,
    );
    
    _shadowAnimation = Tween<double>(
      begin: 0.0, // Start position (animation progress 0)
      end: 1.0,   // End position (animation progress 1)
    ).animate(CurvedAnimation(
      parent: _shadowAnimationController!,
      curve: Curves.linear, // Linear movement for consistent speed
    ));
    
    // Repeat the animation infinitely in one direction only
    _shadowAnimationController!.repeat();
    // Listen to animation changes to trigger repaints
    _shadowAnimation!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _startSmokeAnimation() {
    _smokeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1400), // 14 frames * 100ms = 1.4 seconds
      vsync: this,
    );

    _smokeAnimationController!.addListener(() {
      if (mounted && _smokeImages.isNotEmpty) {
        setState(() {
          _smokeFrameIndex = ((_smokeAnimationController!.value * _smokeImages.length).floor()) % _smokeImages.length;
        });
      }
    });

    _smokeAnimationController!.repeat();
  }
  
  @override
  void dispose() {
    _shadowAnimationController?.dispose();
    _smokeAnimationController?.dispose();
    super.dispose();
  }

  Future<void> _loadGrassTiles() async {
    try {
      // Load the same spritesheet used by the game's tilemaps
      // Dynamic tilemaps use assets/images/Tiles/Tile.png with 16x16 tiles
      final image = await Flame.images.load('Tiles/Tile.png');
      _grassTileSheet = SpriteSheet(image: image, srcSize: Vector2(16, 16));

      // Load the second house sprite from the spritesheet (Houses/Houses/1.png)
      _houseImage = await Flame.images.load('Houses/Houses/1.png');
      
      // Load a tree sprite (Tree1.png from the trees tileset)
      _treeImage = await Flame.images.load('Trees/Tree1.png');
      
      // Load couple image from images directory
      try {
        _coupleImage = await Flame.images.load('couple.png');
      } catch (e) {
        // Try alternative approach - use a known working image
        try {
          _coupleImage = await Flame.images.load('owl.png');
        } catch (e2) {
          _coupleImage = null;
        }
      }
      
      // Load cloud shadow sprite (corrected paths)
      try {
        _cloudShadowImage = await Flame.images.load('clouds.png');
      } catch (e) {
        // Try original path with space
        try {
          _cloudShadowImage = await Flame.images.load('Cute_Fantasy/Weather effects/Clouds.png');
        } catch (e2) {
          // Cloud shadows will not be displayed
        }
      }
      
      // Load smoke animation frames
      _smokeImages = [];
      for (int i = 1; i <= 14; i++) {
        try {
          final smokeImage = await Flame.images.load('V1.1/Smoke/Smoke$i.png');
          _smokeImages.add(smokeImage);
        } catch (e) {
          // Failed to load smoke frame
        }
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _grassTileSheet == null) {
      // Fallback to solid color while loading
      return Container(
        color: const Color(0xFF4A7C59), // Forest green fallback
        child: widget.child,
      );
    }

    return CustomPaint(
      painter: GrassTilePainter(_grassTileSheet!, _houseImage, _treeImage, _cloudShadowImage, _coupleImage, _smokeImages, _smokeFrameIndex, _shadowAnimation?.value ?? 0.0),
      child: widget.child,
    );
  }
}

/// Custom painter that renders the grass tiles
class GrassTilePainter extends CustomPainter {
  final SpriteSheet grassTileSheet;
  final ui.Image? houseImage;
  final ui.Image? treeImage;
  final ui.Image? cloudShadowImage;
  final ui.Image? coupleImage;
  final List<ui.Image> smokeImages;
  final int smokeFrameIndex;
  final double shadowAnimationValue;
  // Screen tile size for the menu background; underlying atlas tiles are 16x16
  static const double tileSize = 64.0;

  GrassTilePainter(this.grassTileSheet, this.houseImage, this.treeImage, this.cloudShadowImage, this.coupleImage, this.smokeImages, this.smokeFrameIndex, this.shadowAnimationValue);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background at larger sprite scale without canvas transforms to preserve crisp pixels
    
    // Access the underlying spritesheet image
    final ui.Image atlas = grassTileSheet.image;

    // In Tile.png, the solid grass tile is GID 25 (firstGid=1) -> tileId 24.
    // With 16x16 tiles, that is row = 24 ~/ cols, col = 24 % cols.
    final int atlasWidth = atlas.width; // in pixels
    final int cols = atlasWidth ~/ 16;
    const int grassTileId = 24; // 0-based index for GID 25
    final int col = grassTileId % cols;
    final int row = grassTileId ~/ cols;

    // Source rect with small inset to avoid bleeding from neighbors
    const double srcTileSize = 16.0;
    const double inset = 0.25; // small inset (can tweak)
    final double sx = col * srcTileSize + inset;
    final double sy = row * srcTileSize + inset;
    final Rect src = Rect.fromLTWH(
      sx,
      sy,
      srcTileSize - inset * 2,
      srcTileSize - inset * 2,
    );

    // Paint without filtering/antialiasing to prevent seams
    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;

    // Calculate how many tiles we need to fill the screen
    final int tilesX = (size.width / tileSize).ceil();
    final int tilesY = (size.height / tileSize).ceil();

    // Render grass tiles snapped to integer logical pixels
    for (int x = 0; x < tilesX; x++) {
      for (int y = 0; y < tilesY; y++) {
        final double xPos = (x * tileSize).roundToDouble();
        final double yPos = (y * tileSize).roundToDouble();

        final Rect dst = Rect.fromLTWH(xPos, yPos, tileSize, tileSize);
        canvas.drawImageRect(atlas, src, dst, paint);
      }
    }
    
    // Draw cloud shadow sprites first (overhead for realistic shadow effect)
    if (cloudShadowImage != null) {
      final ui.Image cloudShadow = cloudShadowImage!;
      final Paint cloudShadowPaint = Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none // nearest-neighbor for crisp pixels
        ..colorFilter = const ColorFilter.mode(
          Color.fromARGB(160, 255, 255, 255), // Darker overlay
          BlendMode.modulate,
        );
      
      // Cloud spritesheet is 128x128 with 2x2 grid, so each individual cloud is 64x64
      const double individualCloudSize = 64.0;
      final double cloudShadowTargetWidth = size.width * 0.5; // Even bigger cloud size
      final double cloudShadowScale = cloudShadowTargetWidth / individualCloudSize;
      final double cloudShadowTargetHeight = individualCloudSize * cloudShadowScale;
      
      // Define cloud shadow positions (overhead scattered shadows)
      final List<Offset> cloudShadowPositions = [];
      
      // Calculate continuous cloud movement - ensure clouds are visible most of the time
      final double animationProgress = shadowAnimationValue; // Already 0.0 to 1.0
      final double startOffset = -cloudShadowTargetWidth; // Start just off-screen left
      final double endOffset = size.width + cloudShadowTargetWidth; // End just off-screen right
      final double totalDistance = endOffset - startOffset;
      
      
      // Create clouds with randomized placements
      final int totalClouds = 12; // Increased number of clouds for more frequency
      final double minY = size.height * 0.1; // Minimum Y position (top of screen)
      final double maxY = size.height * 0.9; // Maximum Y position (bottom of screen)
      
      for (int i = 0; i < totalClouds; i++) {
        // Use cloud index as seed for consistent randomization per cloud
        final int seed = i;
        final Random cloudRandom = Random(seed);
        
        // Randomize Y position for each cloud
        final double randomY = minY + (cloudRandom.nextDouble() * (maxY - minY));
        
        // Stagger the animation start time for each cloud
        final double staggerProgress = cloudRandom.nextDouble(); // Random stagger between 0 and 1
        
        // Calculate position: start position + animation progress + random stagger
        final double currentProgress = (animationProgress + staggerProgress) % 1.0;
        final double currentX = startOffset + (currentProgress * totalDistance);
        
        cloudShadowPositions.add(Offset(currentX, randomY));
      }
      
      // Render cloud shadows from asset (individual clouds from 2x2 spritesheet)
      for (int i = 0; i < cloudShadowPositions.length; i++) {
        final position = cloudShadowPositions[i];

        // Select which cloud from the 2x2 grid to use (cycle through all 4)
        final int cloudIndex = i % 4; // 0, 1, 2, 3 for the 4 clouds in the spritesheet
        final double srcX = (cloudIndex % 2) * individualCloudSize; // 0 or 64 (left or right column)
        final double srcY = (cloudIndex ~/ 2) * individualCloudSize; // 0 or 64 (top or bottom row)

        final Rect cloudShadowSrc = Rect.fromLTWH(srcX, srcY, individualCloudSize, individualCloudSize);
        final Rect cloudShadowDst = Rect.fromLTWH(
          position.dx,
          position.dy,
          cloudShadowTargetWidth,
          cloudShadowTargetHeight,
        );

        canvas.drawImageRect(cloudShadow, cloudShadowSrc, cloudShadowDst, cloudShadowPaint);
      }
    }

    // Draw tree sprites around the background (on top of shadows)
    if (treeImage != null) {
      final ui.Image tree = treeImage!;
      final Paint treePaint = Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none; // nearest-neighbor for crisp pixels
      
      // Scale tree to appropriate size proportionally with house (much larger)
      final double treeTargetWidth = size.width * 0.30;
      final double treeScale = treeTargetWidth / tree.width;
      final double treeTargetHeight = tree.height * treeScale;
      
      // Define tree positions uniformly around the perimeter using screen coordinates
      final List<Offset> treePositions = [];
      
      // Calculate uniform spacing around the perimeter
      const double borderOffset = 0.05; // Distance from edge (5% of screen size)
      
      // Additional back row trees extending to the left (drawn first)
      for (int i = -2; i < 0; i++) {
        final double x = (i / 4.0) * (size.width - 2 * borderOffset * size.width) + borderOffset * size.width;
        treePositions.add(Offset(x, -borderOffset * size.height * 0.5)); // Same Y position as back row
      }
      
      // Back row of trees (slightly higher and offset) - drawn first so they appear behind
      for (int i = 0; i < 5; i++) {
        final double x = (i / 4.0) * (size.width - 2 * borderOffset * size.width) + borderOffset * size.width;
        treePositions.add(Offset(x, -borderOffset * size.height * 0.5)); // Even further back (more negative Y position)
      }
      
      // Additional back row trees extending to the right
      for (int i = 5; i < 7; i++) {
        final double x = (i / 4.0) * (size.width - 2 * borderOffset * size.width) + borderOffset * size.width;
        treePositions.add(Offset(x, -borderOffset * size.height * 0.5)); // Same Y position as back row
      }
      
      // Additional front row trees extending to the left
      for (int i = -1; i < 0; i++) {
        final double x = (i / 4.0) * (size.width - 2 * borderOffset * size.width) + borderOffset * size.width;
        treePositions.add(Offset(x, borderOffset * size.height)); // Same Y position as front row
      }
      
      // Front row of trees (top border) - drawn last so they appear in front
      for (int i = 0; i < 4; i++) {
        final double x = (i / 4.0) * (size.width - 2 * borderOffset * size.width) + borderOffset * size.width;
        treePositions.add(Offset(x, borderOffset * size.height));
      }
      
      
      for (final position in treePositions) {
        final Rect treeSrc = Rect.fromLTWH(0, 0, tree.width.toDouble(), tree.height.toDouble());
        final Rect treeDst = Rect.fromLTWH(
          position.dx,
          position.dy,
          treeTargetWidth,
          treeTargetHeight,
        );
        
        canvas.drawImageRect(tree, treeSrc, treeDst, treePaint);
      }
    }
    
    // No canvas transform used
    
    // Draw house sprite on top of trees (scaled up)
    if (houseImage != null) {
      final ui.Image house = houseImage!;
      
      // Scale house sprite up significantly
      const double houseScale = 2.5;
      final double houseWidth = house.width.toDouble() * houseScale;
      final double houseHeight = house.height.toDouble() * houseScale;

      // Center horizontally, position in upper area (use original screen size)
      final double dx = (size.width - houseWidth) / 2;
      final double dy = (size.height * 0.2) - (houseHeight / 2); // Move house down a bit

      final Rect srcHouse = Rect.fromLTWH(0, 0, house.width.toDouble(), house.height.toDouble());
      final Rect dstHouse = Rect.fromLTWH(dx.roundToDouble(), dy.roundToDouble(), houseWidth, houseHeight);

      final Paint housePaint = Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none; // keep pixel art crisp

      canvas.drawImageRect(house, srcHouse, dstHouse, housePaint);
    }
    
    // Draw couple image below the house
    if (coupleImage != null) {
      final ui.Image couple = coupleImage!;
      
      // Scale couple image to fit screen properly
      const double maxWidth = 400.0; // Even larger maximum width for the image
      const double maxHeight = 400.0; // Even larger maximum height for the image
      
      double coupleScale = 1.0;
      if (couple.width > maxWidth || couple.height > maxHeight) {
        // Scale down to fit within max dimensions
        final double scaleX = maxWidth / couple.width;
        final double scaleY = maxHeight / couple.height;
        coupleScale = scaleX < scaleY ? scaleX : scaleY;
      }
      
      final double coupleWidth = couple.width.toDouble() * coupleScale;
      final double coupleHeight = couple.height.toDouble() * coupleScale;

      // Position couple below the house but above the title area
      final double coupleX = (size.width - coupleWidth) / 2; // Center horizontally
      final double coupleY = (size.height * 0.35); // Move it up more, closer to the house
      
      // Ensure the image is not drawn off-screen
      final double clampedX = coupleX.clamp(0.0, size.width - coupleWidth);
      final double clampedY = coupleY.clamp(0.0, size.height - coupleHeight);


      final Rect srcCouple = Rect.fromLTWH(0, 0, couple.width.toDouble(), couple.height.toDouble());
      final Rect dstCouple = Rect.fromLTWH(clampedX.roundToDouble(), clampedY.roundToDouble(), coupleWidth, coupleHeight);

      final Paint couplePaint = Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none; // keep pixel art crisp

      canvas.drawImageRect(couple, srcCouple, dstCouple, couplePaint);
    }
    
    // Draw animated smoke on top left of house
    if (smokeImages.isNotEmpty && smokeFrameIndex < smokeImages.length) {
      final ui.Image smoke = smokeImages[smokeFrameIndex];
      
      // Scale smoke to appropriate size (make it more visible)
      const double smokeScale = 2.0;
      final double smokeWidth = smoke.width.toDouble() * smokeScale;
      final double smokeHeight = smoke.height.toDouble() * smokeScale;
      
      // Position smoke at top left of house
      if (houseImage != null) {
        final double houseX = (size.width - houseImage!.width.toDouble() * 2.0) / 2; // Same as house X position
        final double houseY = (size.height * 0.2) - (houseImage!.height.toDouble() * 2.0 / 2); // Same as house Y position
        final double smokeX = houseX + (smokeWidth * 0.05); // Offset slightly to the right of house
        final double smokeY = houseY - (smokeHeight * 0.7); // Offset further above house
        
        
        final Rect srcSmoke = Rect.fromLTWH(0, 0, smoke.width.toDouble(), smoke.height.toDouble());
        final Rect dstSmoke = Rect.fromLTWH(
          smokeX.roundToDouble(),
          smokeY.roundToDouble(),
          smokeWidth,
          smokeHeight,
        );
        
        final Paint smokePaint = Paint()
          ..isAntiAlias = false
          ..filterQuality = FilterQuality.none; // keep pixel art crisp
        
        canvas.drawImageRect(smoke, srcSmoke, dstSmoke, smokePaint);
      }
    }
  }



  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! GrassTilePainter || 
           oldDelegate.smokeFrameIndex != smokeFrameIndex ||
           oldDelegate.shadowAnimationValue != shadowAnimationValue;
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool _isSignedIn = false;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  void _checkAuth() {
    setState(() {
      _isSignedIn = SupabaseConfig.currentUser != null;
    });
    
    // If user is now signed in, navigate to the game
    if (_isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const FarmLoader(),
          ),
        );
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isSigningIn) return; // Prevent multiple sign-in attempts

    setState(() {
      _isSigningIn = true;
    });

    try {

      // Clear any re-auth flags before signing in
      SupabaseConfig.clearReauthFlag();

      await AuthService.signInWithGoogleNative();


      // Add a small delay to ensure Supabase session is established
      await Future.delayed(const Duration(milliseconds: 500));

      // Force refresh the authentication state
      await SupabaseConfig.refreshAuthState();

      // Check authentication status
      _checkAuth();

    } catch (e) {

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isSigningIn) return; // Prevent multiple sign-in attempts

    setState(() {
      _isSigningIn = true;
    });

    try {

      // Clear any re-auth flags before signing in
      SupabaseConfig.clearReauthFlag();

      await AuthService.signInWithApple();


      // Add a small delay to ensure Supabase session is established
      await Future.delayed(const Duration(milliseconds: 500));

      // Force refresh the authentication state
      await SupabaseConfig.refreshAuthState();

      // Check authentication status
      _checkAuth();

    } catch (e) {

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GrassTileBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 200), // Add even more space to push content down further
              // Game Title
              const Text(
                'Lovenest Valley',
                style: TextStyle(
                  fontFamily: 'GUMDROP',
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF69B4), // Pink text color
                  shadows: [
                    // Thicker white outline effect using multiple shadows
                    Shadow(offset: Offset(-2, -2), color: Colors.white),
                    Shadow(offset: Offset(2, -2), color: Colors.white),
                    Shadow(offset: Offset(-2, 2), color: Colors.white),
                    Shadow(offset: Offset(2, 2), color: Colors.white),
                    Shadow(offset: Offset(-1, 0), color: Colors.white),
                    Shadow(offset: Offset(1, 0), color: Colors.white),
                    Shadow(offset: Offset(0, -1), color: Colors.white),
                    Shadow(offset: Offset(0, 1), color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Subtitle with growing/shrinking animation
              GrowShrinkAnimatedText(
                text: 'Grow Your Love Together',
                style: const TextStyle(
                  fontFamily: 'GUMDROP',
                  fontSize: 24,
                  color: Colors.white,
                  shadows: [
                    // Thicker black outline effect using multiple shadows
                    Shadow(offset: Offset(-2, -2), color: Colors.black),
                    Shadow(offset: Offset(2, -2), color: Colors.black),
                    Shadow(offset: Offset(-2, 2), color: Colors.black),
                    Shadow(offset: Offset(2, 2), color: Colors.black),
                    Shadow(offset: Offset(-1, 0), color: Colors.black),
                    Shadow(offset: Offset(1, 0), color: Colors.black),
                    Shadow(offset: Offset(0, -1), color: Colors.black),
                    Shadow(offset: Offset(0, 1), color: Colors.black),
                  ],
                ),
                duration: const Duration(seconds: 5),
              ),
              const SizedBox(height: 60),
              
              

              
              // Authentication buttons
              if (!_isSignedIn) ...[
                // iOS: Apple Sign-In only
                if (Platform.isIOS)
                  ElevatedButton.icon(
                    icon: _isSigningIn
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.apple),
                    label: Text(_isSigningIn ? 'Signing in...' : 'Sign in with Apple'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSigningIn ? null : _handleAppleSignIn,
                  ),

                // Android: Google Sign-In only
                if (Platform.isAndroid)
                  ElevatedButton.icon(
                    icon: _isSigningIn
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.g_mobiledata, size: 28),
                    label: Text(_isSigningIn ? 'Signing in...' : 'Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      minimumSize: const Size(280, 56),
                    ),
                    onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                  ),
              ],
              if (_isSignedIn)
                ElevatedButton.icon(
                  icon: Icon(Icons.logout),
                  label: Text('Log out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await AuthService.signOut();
                    _checkAuth();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
} 
