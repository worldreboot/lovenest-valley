import 'package:flutter/material.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:lovenest_valley/screens/onboarding_screen.dart';
import 'package:lovenest_valley/screens/menu_screen.dart';
import 'package:lovenest_valley/main.dart' show FarmLoader; // Use FarmLoader to resolve shared farm and route to game
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovenest_valley/services/superwall_service.dart';
import 'package:lovenest_valley/screens/superwall_paywall_screen.dart';
import 'package:lovenest_valley/config/feature_flags.dart';
// LinkPartnerScreen is pushed from FarmLoader; no direct import needed here

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  bool _hasSeenOnboarding = false;
  bool _isLoading = true;
  bool _isValidatingUser = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // First check if there's a current user that needs validation
    final currentUser = SupabaseConfig.currentUser;
    if (currentUser != null) {
      // User exists in local session, validate them
      await _validateAndCheckAuth();
    }
    
    // Only check onboarding status if user is authenticated and valid
    // If no user is authenticated, we'll always show onboarding
    if (currentUser != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        _hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      } catch (_) {
        _hasSeenOnboarding = false;
      }
    } else {
      // No authenticated user, always show onboarding
      _hasSeenOnboarding = false;
    }
    
    setState(() {
      _isLoading = false;
    });
  }
  
  Future<void> _validateAndCheckAuth() async {
    setState(() {
      _isValidatingUser = true;
    });
    
    try {
      // Validate current user exists in backend
      final isValid = await SupabaseConfig.validateCurrentUser();
      
      if (!isValid) {
        // User validation failed, treat as not authenticated
        // Re-read onboarding status since it might have been cleared
        try {
          final prefs = await SharedPreferences.getInstance();
          _hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
        } catch (_) {
          _hasSeenOnboarding = false;
        }
        
        if (mounted) {
          setState(() {
            _isValidatingUser = false;
          });
        }
        return;
      }
      
      // User is valid, proceed with authenticated flow
      debugPrint('[AuthFlowScreen] ✅ User validated, proceeding to game');
      
      // Clear re-auth flag since user is now properly authenticated
      SupabaseConfig.clearReauthFlag();
      
      if (!kPaywallEnabled) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const FarmLoader()),
          );
        }
      } else {
        // After auth, hard paywall gate before continuing
        final userId = SupabaseConfig.currentUserId;
        final entitled = await _checkEntitlement(userId);
        if (entitled) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const FarmLoader()),
            );
          }
        } else {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => SuperwallPaywallScreen(
                  onEntitled: () {
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthFlowScreen] ❌ Error validating user: $e');
    }
    
    if (mounted) {
      setState(() {
        _isValidatingUser = false;
      });
    }
  }

  void _onOnboardingComplete() {
    setState(() {
      _hasSeenOnboarding = true;
    });
    // Persist flag for future sessions
    SharedPreferences.getInstance().then((p) => p.setBool('has_seen_onboarding', true));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isValidatingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Check if user is authenticated based on real Supabase session
    final currentUser = SupabaseConfig.currentUser;
    final userId = currentUser?.id;
    debugPrint('[AuthFlowScreen] 🔍 Current user ID: $userId');
    debugPrint('[AuthFlowScreen] 🔍 Has seen onboarding: $_hasSeenOnboarding');
    
    if (currentUser == null) {
      debugPrint('[AuthFlowScreen] ❌ User not authenticated, showing menu');
      // User not authenticated
      if (!_hasSeenOnboarding) {
        // Show onboarding first
        debugPrint('[AuthFlowScreen] 📱 Showing onboarding screen');
        return OnboardingScreen(onOnboardingComplete: _onOnboardingComplete);
      } else {
        // Show sign-in screen
        debugPrint('[AuthFlowScreen] 🍽️ Showing menu screen');
        return const MenuScreen();
      }
    } else {
      // User has a session, but we need to validate they exist in backend
      // Trigger validation on first build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isValidatingUser) {
          _validateAndCheckAuth();
        }
      });
      
      debugPrint('[AuthFlowScreen] ✅ User authenticated - validating in backend');
      
      // Show loading while validating
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Validating user...'),
            ],
          ),
        ),
      );
    }
  }

  Future<bool> _checkEntitlement(String? appUserId) async {
    await SuperwallService.initialize(appUserId: appUserId);
    return SuperwallService.isEntitled();
  }
} 
