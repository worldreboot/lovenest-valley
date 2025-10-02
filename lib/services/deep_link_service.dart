import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;
  static bool _initialized = false;

  /// Initialize deep link handling
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      debugPrint('[DeepLinkService] Initializing deep link handling...');
      
      // Handle incoming links when app is already running
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) {
          debugPrint('[DeepLinkService] Received deep link: $uri');
          _handleDeepLink(uri);
        },
        onError: (Object err) {
          debugPrint('[DeepLinkService] Deep link error: $err');
        },
      );

      // Handle initial link (when app is opened from a link)
      final Uri? initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        debugPrint('[DeepLinkService] Initial deep link: $initialLink');
        _handleDeepLink(initialLink);
      }

      _initialized = true;
      debugPrint('[DeepLinkService] ✅ Deep link handling initialized');
    } catch (e) {
      debugPrint('[DeepLinkService] ❌ Initialization error: $e');
    }
  }

  /// Handle incoming deep links
  static void _handleDeepLink(Uri uri) {
    debugPrint('[DeepLinkService] 🔗 Handling deep link: $uri');
    
    // Check if it's our custom scheme
    if (uri.scheme == 'lovenest') {
      _handleLovenestLink(uri);
    } else {
      debugPrint('[DeepLinkService] ⚠️ Unknown scheme: ${uri.scheme}');
    }
  }

  /// Handle lovenest:// custom scheme links
  static void _handleLovenestLink(Uri uri) {
    debugPrint('[DeepLinkService] 🏠 Handling Lovenest deep link: $uri');
    
    final String path = uri.path;
    final Map<String, String> queryParams = uri.queryParameters;
    
    debugPrint('[DeepLinkService] Path: $path');
    debugPrint('[DeepLinkService] Query params: $queryParams');
    
    switch (path) {
      case '/':
      case '':
        debugPrint('[DeepLinkService] 🏠 Home deep link');
        _handleHomeLink(queryParams);
        break;
        
      case '/game':
        debugPrint('[DeepLinkService] 🎮 Game deep link');
        _handleGameLink(queryParams);
        break;
        
      case '/shop':
        debugPrint('[DeepLinkService] 🛍️ Shop deep link');
        _handleShopLink(queryParams);
        break;
        
      case '/garden':
        debugPrint('[DeepLinkService] 🌱 Garden deep link');
        _handleGardenLink(queryParams);
        break;
        
      case '/partner':
        debugPrint('[DeepLinkService] 💕 Partner deep link');
        _handlePartnerLink(queryParams);
        break;
        
      default:
        debugPrint('[DeepLinkService] ❓ Unknown path: $path');
        _handleUnknownPath(path, queryParams);
    }
  }

  /// Handle home page deep links
  static void _handleHomeLink(Map<String, String> params) {
    debugPrint('[DeepLinkService] 🏠 Navigating to home');
    // Add navigation logic here
    // Example: Navigator.pushNamed(context, '/home');
  }

  /// Handle game deep links
  static void _handleGameLink(Map<String, String> params) {
    debugPrint('[DeepLinkService] 🎮 Navigating to game');
    final farmId = params['farmId'];
    if (farmId != null) {
      debugPrint('[DeepLinkService] Farm ID: $farmId');
      // Add navigation logic here
      // Example: Navigator.pushNamed(context, '/game', arguments: {'farmId': farmId});
    }
  }

  /// Handle shop deep links
  static void _handleShopLink(Map<String, String> params) {
    debugPrint('[DeepLinkService] 🛍️ Navigating to shop');
    final category = params['category'];
    if (category != null) {
      debugPrint('[DeepLinkService] Shop category: $category');
      // Add navigation logic here
      // Example: Navigator.pushNamed(context, '/shop', arguments: {'category': category});
    }
  }

  /// Handle garden deep links
  static void _handleGardenLink(Map<String, String> params) {
    debugPrint('[DeepLinkService] 🌱 Navigating to garden');
    final seedId = params['seedId'];
    if (seedId != null) {
      debugPrint('[DeepLinkService] Seed ID: $seedId');
      // Add navigation logic here
      // Example: Navigator.pushNamed(context, '/garden', arguments: {'seedId': seedId});
    }
  }

  /// Handle partner deep links
  static void _handlePartnerLink(Map<String, String> params) {
    debugPrint('[DeepLinkService] 💕 Navigating to partner');
    final action = params['action'];
    if (action != null) {
      debugPrint('[DeepLinkService] Partner action: $action');
      // Add navigation logic here
      // Example: Navigator.pushNamed(context, '/partner', arguments: {'action': action});
    }
  }

  /// Handle unknown paths
  static void _handleUnknownPath(String path, Map<String, String> params) {
    debugPrint('[DeepLinkService] ❓ Unknown path: $path with params: $params');
    // Default to home or show error
    _handleHomeLink(params);
  }

  /// Generate a deep link URL
  static String generateLink({
    required String path,
    Map<String, String>? queryParams,
  }) {
    final Uri uri = Uri(
      scheme: 'lovenest',
      path: path,
      queryParameters: queryParams,
    );
    return uri.toString();
  }

  /// Test deep link generation
  static void testDeepLinks() {
    debugPrint('[DeepLinkService] 🧪 Testing deep link generation...');
    
    final links = [
      generateLink(path: '/'),
      generateLink(path: '/game', queryParams: {'farmId': 'test123'}),
      generateLink(path: '/shop', queryParams: {'category': 'decorations'}),
      generateLink(path: '/garden', queryParams: {'seedId': 'seed456'}),
      generateLink(path: '/partner', queryParams: {'action': 'invite'}),
    ];
    
    for (final link in links) {
      debugPrint('[DeepLinkService] Generated link: $link');
    }
  }

  /// Dispose resources
  static void dispose() {
    _linkSubscription?.cancel();
    _linkSubscription = null;
    _initialized = false;
    debugPrint('[DeepLinkService] 🗑️ Deep link service disposed');
  }
}

/// Deep link examples:
/// 
/// Home: lovenest://
/// Game: lovenest:///game?farmId=abc123
/// Shop: lovenest:///shop?category=decorations
/// Garden: lovenest:///garden?seedId=seed456
/// Partner: lovenest:///partner?action=invite
