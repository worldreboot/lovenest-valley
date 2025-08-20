import 'package:flutter/material.dart';
// Removed unused imports for clean build
import 'package:lovenest/main.dart' show FarmLoader; // Use FarmLoader to route into SimpleEnhanced game flow
import 'package:lovenest/screens/dev_test_screen.dart';
import 'package:lovenest/screens/map_test_screen.dart';
import 'package:lovenest/services/auth_service.dart';
import 'package:lovenest/config/supabase_config.dart';
// Removed unused import

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
      debugPrint('[MenuScreen] 🔐 Starting Google sign-in...');
      
      // Clear any re-auth flags before signing in
      SupabaseConfig.clearReauthFlag();
      
      await AuthService.signInWithGoogleNative();
      
      debugPrint('[MenuScreen] ✅ Google sign-in completed');
      
      // Add a small delay to ensure Supabase session is established
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Force refresh the authentication state
      await SupabaseConfig.refreshAuthState();
      
      // Check authentication status
      _checkAuth();
      
    } catch (e) {
      debugPrint('[MenuScreen] ❌ Google sign-in failed: $e');
      
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF1493), // Deep pink
              Color(0xFFFF69B4), // Hot pink
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Game Title
              const Text(
                'LoveNest',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 4,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Subtitle
              const Text(
                'Plant & Nurture Your Precious Memories Together',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 2,
                      color: Colors.black54,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60),
              
              // Test button (always visible for development)
              ElevatedButton.icon(
                icon: Icon(Icons.science),
                label: Text('🧪 Sprite Generation Tests'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DevTestScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              
              // Map Test button (always visible for development)
              ElevatedButton.icon(
                icon: Icon(Icons.map),
                label: Text('🗺️ Map Test Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const MapTestScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              
              // Authentication buttons
              if (!_isSignedIn)
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
                    : Icon(Icons.login),
                  label: Text(_isSigningIn ? 'Signing in...' : 'Sign in with Google'),
                  onPressed: _isSigningIn ? null : _handleGoogleSignIn,
                ),
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