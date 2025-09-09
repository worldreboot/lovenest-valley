import 'package:flutter/material.dart';
// removed unused imports
import 'package:lovenest_valley/screens/menu_screen.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'services/farm_repository.dart';
import 'package:lovenest_valley/screens/splash_screen.dart';
import 'services/farm_tile_service.dart';
import 'package:flame/flame.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:lovenest_valley/screens/auth_flow_screen.dart';
import 'package:lovenest_valley/screens/offline_screen.dart';
import 'package:lovenest_valley/screens/debug_auth_screen.dart';

import 'services/push_service.dart';
import 'services/revenuecat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:ui';

// Global navigator key for debug button access
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up comprehensive error handling for all Supabase auth errors
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isSupabaseAuthError(details.exception)) {
      print('[Main] Caught Supabase auth error: ${details.exception}');
      // Don't crash the app for network errors
      return;
    }
    // Let other errors be handled normally
    FlutterError.presentError(details);
  };
  
  // Also catch unhandled async errors
  PlatformDispatcher.instance.onError = (error, stack) {
    if (_isSupabaseAuthError(error)) {
      print('[Main] Caught async Supabase auth error: $error');
      return true; // Prevent the error from being re-thrown
    }
    return false; // Let other errors be handled normally
  };
  
  // Initialize Supabase with network connectivity handling
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    print('[Main] Supabase initialization failed, continuing in offline mode: $e');
    // Continue app startup even if Supabase fails
  }
  
  // Preload critical game assets
  await _preloadGameAssets();

  // Initialize push notifications and register token
  await PushService.initializeAndRegister();

  // Initialize RevenueCat (no user yet; will set user after auth)
  await RevenueCatService.initialize();
  
  runApp(const MyApp());
}

bool _isSupabaseAuthError(dynamic error) {
  final errorString = error.toString();
  return errorString.contains('AuthRetryableFetchException') ||
         errorString.contains('Network is unreachable') ||
         errorString.contains('Connection failed') ||
         errorString.contains('SocketException') ||
         errorString.contains('ClientException');
}

Future<void> _testNetworkConnectivity() async {
  try {
    debugPrint('[Main] Testing network connectivity...');
    
    // Test basic internet connectivity
    final response = await http.get(Uri.parse('https://www.google.com'))
        .timeout(const Duration(seconds: 10));
    debugPrint('[Main] Basic internet connectivity: ${response.statusCode == 200 ? 'OK' : 'FAILED'}');
    
    // Test Supabase connectivity
    final supabaseResponse = await http.get(Uri.parse('https://lxmjpdmqzblpsdhmlfrt.supabase.co'))
        .timeout(const Duration(seconds: 10));
    debugPrint('[Main] Supabase connectivity: ${supabaseResponse.statusCode == 200 ? 'OK' : 'FAILED'}');
    
    // Test DNS resolution
    try {
      final addresses = await InternetAddress.lookup('lxmjpdmqzblpsdhmlfrt.supabase.co');
      debugPrint('[Main] DNS resolution: OK (${addresses.length} addresses found)');
      for (final address in addresses) {
        debugPrint('[Main]   - ${address.address}');
      }
    } catch (e) {
      debugPrint('[Main] DNS resolution: FAILED - $e');
      debugPrint('[Main] 💡 This is a common emulator issue - try restarting the emulator');
    }
    
    // Test HTTPS connectivity specifically
    try {
      final httpsResponse = await http.get(
        Uri.parse('https://lxmjpdmqzblpsdhmlfrt.supabase.co/auth/v1/health'),
        headers: {'User-Agent': 'Flutter/1.0'},
      ).timeout(const Duration(seconds: 15));
      debugPrint('[Main] HTTPS connectivity: ${httpsResponse.statusCode == 200 ? 'OK' : 'FAILED (${httpsResponse.statusCode})'}');
    } catch (e) {
      debugPrint('[Main] HTTPS connectivity: FAILED - $e');
      debugPrint('[Main] 💡 Emulator might have SSL/TLS issues');
    }
    
  } catch (e) {
    debugPrint('[Main] Network connectivity test failed: $e');
    debugPrint('[Main] This might explain why the emulator has issues but physical device works');
  }
}

Future<void> _preloadGameAssets() async {
  try {
    debugPrint('[Main] Preloading game assets...');
    await Flame.images.loadAll([
      'ground.png',
      'wood.png',
      'user.png',
      'seashell.png',
      'gift_1.png',
    ]);
    debugPrint('[Main] Game assets preloaded successfully');
  } catch (e) {
    debugPrint('[Main] Error preloading assets: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Use the global navigator key
      title: 'Lovenest Valley',
      theme: ThemeData(
        primarySwatch: Colors.pink,
      ),
      home: const AuthFlowScreen(), // Show authentication flow instead of direct test screen
      routes: {
        '/offline': (context) => const OfflineScreen(),
        '/debug': (context) => const DebugAuthScreen(),

      },
      builder: (context, child) {
        // Debug button removed - return child directly
        return child!;
      },
    );
  }
}

class FarmLoader extends StatefulWidget {
  const FarmLoader({super.key});

  @override
  State<FarmLoader> createState() => _FarmLoaderState();
}

class _FarmLoaderState extends State<FarmLoader> {
  late Future<String> _farmIdFuture;
  bool _checkingProfile = true;

  @override
  void initState() {
    super.initState();
    // Skip username prompt initially - let user experience the game first
    setState(() {
      _farmIdFuture = _getOrCreateFarmId();
      _checkingProfile = false;
    });
  }



  Future<String> _getOrCreateFarmId() async {
    final repo = FarmRepository();
    final farmTileService = FarmTileService();
    
    // Check couple status and log details (no longer gates entry to game)
    await _logCoupleStatus();
    
    // Get the appropriate farm (shared farm for couples, individual farm otherwise)
    final farm = await repo.getCurrentUserFarm();
    
    if (farm != null) {
      final farmId = farm['id'] as String;
      final ownerId = farm['owner_id'] as String;
      final partnerId = farm['partner_id'] as String?;
      final currentUserId = SupabaseConfig.currentUserId;
      
      debugPrint('[Main] App starting - Farm details (shared or individual):');
      debugPrint('[Main]   Farm ID: $farmId');
      debugPrint('[Main]   Owner ID: $ownerId');
      debugPrint('[Main]   Partner ID: $partnerId');
      debugPrint('[Main]   Current User ID: $currentUserId');
      
      if (ownerId == currentUserId) {
        debugPrint('[Main]   User is the FARM OWNER');
      } else {
        debugPrint('[Main]   User is the FARM PARTNER');
      }
      
      return farmId;
    } else {
      debugPrint('[Main] No farm found - creating new farm');
      final newFarm = await repo.createFarmForCurrentUser();
      if (newFarm == null) {
        throw Exception('Failed to create farm - offline mode or network error');
      }
      final farmId = newFarm['id'] as String;
      
      // Generate and save the complete farm map with standard layout
      await farmTileService.generateAndSaveFarmMap(farmId);
      debugPrint('[Main] ✅ New farm created with complete map layout');
      return farmId;
    }
  }

  Future<Map<String, dynamic>?> _logCoupleStatus() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) {
      debugPrint('[Main] No user ID available for couple status check');
      return null;
    }

    debugPrint('[Main] Checking couple status for user: $userId');

    final client = SupabaseConfig.client;
    final couple = await client
        .from('couples')
        .select()
        .or('user1_id.eq.$userId,user2_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (couple == null) {
      debugPrint('[Main] COUPLE STATUS: User is NOT in a couple');
      return null;
    }

    final coupleId = couple['id'] as String;
    final user1Id = couple['user1_id'] as String;
    final user2Id = couple['user2_id'] as String;
    final createdAt = couple['created_at'] as String;

    debugPrint('[Main] COUPLE STATUS: User is in a couple');
    debugPrint('[Main]   Couple ID: $coupleId');
    debugPrint('[Main]   User 1 ID: $user1Id');
    debugPrint('[Main]   User 2 ID: $user2Id');
    debugPrint('[Main]   Created: $createdAt');

    final partnerId = user1Id == userId ? user2Id : user1Id;
    debugPrint('[Main]   Partner ID: $partnerId');

    // Ancillary logging, never fail the method
    try {
      final partnerProfile = await client
          .from('profiles')
          .select('username')
          .eq('id', partnerId)
          .limit(1)
          .maybeSingle();
      if (partnerProfile != null) {
        final partnerUsername = partnerProfile['username'] as String?;
        debugPrint('[Main]   Partner Username: $partnerUsername');
      }
    } catch (e) {
      debugPrint('[Main] Partner profile lookup error (non-fatal): $e');
    }

    try {
      final partnerFarm = await client
          .from('farms')
          .select('id, owner_id, partner_id, created_at')
          .or('owner_id.eq.$partnerId,partner_id.eq.$partnerId')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (partnerFarm != null) {
        final partnerFarmId = partnerFarm['id'] as String;
        final partnerFarmOwnerId = partnerFarm['owner_id'] as String;
        final partnerFarmPartnerId = partnerFarm['partner_id'] as String?;
        debugPrint("[Main]   Partner's Farm Details:");
        debugPrint('[Main]     Farm ID: $partnerFarmId');
        debugPrint('[Main]     Owner ID: $partnerFarmOwnerId');
        debugPrint('[Main]     Partner ID: $partnerFarmPartnerId');
      }
    } catch (e) {
      debugPrint('[Main] Partner farm lookup error (non-fatal): $e');
    }

    return couple;
  }

  @override
  Widget build(BuildContext context) {
    // Check if Supabase is available
    if (!SupabaseConfig.isOnline) {
      return const OfflineScreen();
    }
    
    // Check if re-authentication is needed
    if (SupabaseConfig.needsReauth) {
      print('[Main] Re-authentication required - showing auth flow');
      return const AuthFlowScreen();
    }
    
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        // User not logged in, show main menu for sign in
        return const MenuScreen();
      }
    } catch (e) {
      print('[Main] Error getting current user, showing offline screen: $e');
      return const OfflineScreen();
    }
    if (_checkingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return FutureBuilder<String>(
      future: _farmIdFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          // Handle offline mode errors gracefully
          if (snapshot.error.toString().contains('offline mode') || 
              snapshot.error.toString().contains('not available')) {
            return const OfflineScreen();
          }
          return Scaffold(
            body: Center(child: Text('Error: \\${snapshot.error}')),
          );
        }
        final farmId = snapshot.data!;
        // Show splash screen to check for avatar onboarding
        return SplashScreen(farmId: farmId);
      },
    );
  }
}


