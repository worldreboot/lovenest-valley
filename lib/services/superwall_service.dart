import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

class SuperwallService {
  static bool _initialized = false;
  
  // Superwall API keys from the dashboard
  static const String _androidApiKey = 'pk_zjHO4R0Fld3e1tXIbVLgV';
  static const String _iosApiKey = 'pk_BdDDDSCh5un6KIdE-18fJ';
  
  static String get _apiKey {
    if (Platform.isIOS) {
      return _iosApiKey;
    } else {
      return _androidApiKey;
    }
  }
  
  static Future<void> initialize({String? appUserId}) async {
    if (_initialized) return;
    try {
      Superwall.configure(_apiKey);
      if (appUserId != null) {
        Superwall.shared.identify(appUserId);
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[SuperwallService] Initialization error: $e');
    }
  }

  static Future<bool> isEntitled() async {
    try {
      final subscriptionStatus = await Superwall.shared.subscriptionStatus.first;
      // Check if user has active subscription
      return subscriptionStatus.toString().contains('active') || 
             subscriptionStatus.toString().contains('Active');
    } catch (e) {
      debugPrint('[SuperwallService] isEntitled error: $e');
      return false;
    }
  }

  static Future<void> presentPaywall(String placement) async {
    try {
      Superwall.shared.registerPlacement(placement);
    } catch (e) {
      debugPrint('[SuperwallService] presentPaywall error: $e');
    }
  }

  /// Register a placement with feature gating - this is the recommended approach
  /// The feature closure will only execute if the user is entitled or if the paywall is non-gated
  static Future<void> registerPlacement(
    String placement, {
    required Function feature,
  }) async {
    try {
      Superwall.shared.registerPlacement(placement, feature: feature);
    } catch (e) {
      debugPrint('[SuperwallService] registerPlacement error: $e');
    }
  }

  /// Get presentation result without actually showing paywall
  /// Useful for adapting UI (like showing lock icons) based on paywall outcome
  static Future<dynamic> getPresentationResult(String placement) async {
    try {
      return await Superwall.shared.getPresentationResult(placement);
    } catch (e) {
      debugPrint('[SuperwallService] getPresentationResult error: $e');
      return null;
    }
  }

  /// Test method to trigger a specific placement for testing purposes
  static Future<void> testPlacement(String placement) async {
    try {
      debugPrint('[SuperwallService] 🧪 Testing placement: $placement');
      Superwall.shared.registerPlacement(placement, feature: () {
        debugPrint('[SuperwallService] ✅ Feature executed for placement: $placement');
        // You can add any test logic here
      });
    } catch (e) {
      debugPrint('[SuperwallService] ❌ Test placement error: $e');
    }
  }


  /// Check if Superwall is ready and has latest data
  static Future<bool> isReady() async {
    try {
      // Simple check - try to get subscription status
      await Superwall.shared.subscriptionStatus.first;
      return true;
    } catch (e) {
      debugPrint('[SuperwallService] ❌ Superwall not ready: $e');
      return false;
    }
  }

  static Future<void> setUserAttributes(Map<String, Object> attributes) async {
    try {
      Superwall.shared.setUserAttributes(attributes);
    } catch (e) {
      debugPrint('[SuperwallService] setUserAttributes error: $e');
    }
  }

  static Future<String?> getUserId() async {
    try {
      return await Superwall.shared.getUserId();
    } catch (e) {
      debugPrint('[SuperwallService] getUserId error: $e');
      return null;
    }
  }

  static Future<void> restorePurchases() async {
    try {
      // Superwall handles restore internally through the delegate
      // This is mainly for compatibility with existing code
      debugPrint('[SuperwallService] Restore purchases handled by Superwall delegate');
    } catch (e) {
      debugPrint('[SuperwallService] restorePurchases error: $e');
    }
  }

  static Future<void> handleDeepLink(String url) async {
    try {
      await Superwall.shared.handleDeepLink(Uri.parse(url));
    } catch (e) {
      debugPrint('[SuperwallService] handleDeepLink error: $e');
    }
  }
}
