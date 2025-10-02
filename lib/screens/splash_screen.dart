import 'package:flutter/material.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:lovenest_valley/screens/avatar_creation_screen.dart';
import 'package:lovenest_valley/screens/game_screen.dart';
import 'package:lovenest_valley/screens/menu_screen.dart';
import 'package:lovenest_valley/screens/superwall_paywall_screen.dart';
import 'package:lovenest_valley/services/superwall_service.dart';
import 'package:lovenest_valley/config/feature_flags.dart';

class SplashScreen extends StatefulWidget {
  final String farmId;

  const SplashScreen({
    Key? key,
    required this.farmId,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isChecking = true;
  bool _hasCustomSpritesheet = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAvatarStatus();
  }

  Future<void> _checkAvatarStatus() async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        // User not logged in, go to menu
        if (!mounted) return;
        _navigateToMenu();
        return;
      }

      // Hard paywall: ensure entitlement before proceeding to avatar or game
      if (kPaywallEnabled) {
        final entitled = await _checkEntitlement(userId);
        if (!entitled) {
          if (!mounted) return;
          _showPaywall();
          return;
        }
      }

      // Check if user has a custom spritesheet
      final hasSpritesheet = await _userHasCustomSpritesheet(userId);
      
      if (!mounted) return;
      setState(() {
        _hasCustomSpritesheet = hasSpritesheet;
        _isChecking = false;
      });

      if (hasSpritesheet) {
        // User has spritesheet, go to game
        if (!mounted) return;
        _navigateToGame();
      } else {
        // User needs to create avatar, show onboarding
        if (!mounted) return;
        _showAvatarCreation();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error checking avatar status: $e';
        _isChecking = false;
      });
    }
  }

  Future<bool> _checkEntitlement(String appUserId) async {
    await SuperwallService.initialize(appUserId: appUserId);
    return SuperwallService.isEntitled();
  }

  Future<bool> _userHasCustomSpritesheet(String userId) async {
    try {
      final profile = await SupabaseConfig.client
          .from('profiles')
          .select('spritesheet_url, avatar_generation_status')
          .eq('id', userId)
          .single();

      return profile['avatar_generation_status'] == 'completed' &&
             profile['spritesheet_url'] != null &&
             profile['spritesheet_url'].toString().isNotEmpty;
    } catch (e) {
      debugPrint('[SplashScreen] Error checking spritesheet: $e');
      return false;
    }
  }

  void _navigateToGame() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(farmId: widget.farmId),
      ),
    );
  }

  void _navigateToMenu() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const MenuScreen(),
      ),
    );
  }

  void _showAvatarCreation() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AvatarCreationScreen(
          farmId: widget.farmId,
        ),
      ),
    );
  }

  void _showPaywall() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SuperwallPaywallScreen(
          onEntitled: _checkAvatarStatus,
          onClose: _navigateToMenu,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF87CEEB), // Sky blue
              Color(0xFF98FB98), // Pale green
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 60,
                  color: Colors.pink,
                ),
              ),
              
              const SizedBox(height: 30),
              
              // App title
              const Text(
                'Lovenest Valley',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Subtitle
              const Text(
                'Your Love Story Awaits',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 50),
              
              // Loading indicator or status
              if (_isChecking) ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Preparing your adventure...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ] else if (_errorMessage != null) ...[
                Icon(
                  Icons.error_outline,
                  color: Colors.red[300],
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _checkAvatarStatus,
                  child: const Text('Retry'),
                ),
              ] else if (!_hasCustomSpritesheet) ...[
                const Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Creating your character...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 
