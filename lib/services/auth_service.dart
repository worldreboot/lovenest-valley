import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';
import 'package:lovenest_valley/services/debug_log_service.dart';

class AuthService {
  static Future<void> signInWithGoogle() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
    );
  }

  static Future<void> signInWithGoogleNative() async {
    /// TODO: update the Web client ID with your own.
    /// Web Client ID that you registered with Google Cloud.
    const webClientId = '1021335959685-i7mcdsisng25g8ghsan6msa6kkahnfn4.apps.googleusercontent.com';

    /// TODO: update the iOS client ID with your own.
    /// iOS Client ID that you registered with Google Cloud.
    const iosClientId = 'my-ios.apps.googleusercontent.com';

    try {
      debugPrint('[AuthService] 🔐 Starting Google sign-in process...');
      
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: iosClientId,
        serverClientId: webClientId,
      );
      
      // Force account picker every time
      debugPrint('[AuthService] 🔄 Signing out from Google to force account picker...');
      await googleSignIn.signOut();
      
      debugPrint('[AuthService] 📱 Requesting Google sign-in...');
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('[AuthService] ❌ User cancelled Google sign-in');
        return; // User cancelled
      }
      
      debugPrint('[AuthService] ✅ Google user obtained: ${googleUser.email}');
      
      debugPrint('[AuthService] 🔑 Getting Google authentication tokens...');
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw Exception('No Access Token found from Google.');
      }
      if (idToken == null) {
        throw Exception('No ID Token found from Google.');
      }

      debugPrint('[AuthService] ✅ Google tokens obtained successfully');
      debugPrint('[AuthService] 🔐 Signing in to Supabase with Google tokens...');

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      
      debugPrint('[AuthService] ✅ Successfully signed in to Supabase with Google');
      
      // Verify the session was established
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        debugPrint('[AuthService] ✅ Session verified - User ID: ${currentUser.id}');
      } else {
        debugPrint('[AuthService] ⚠️ Session verification failed - no current user');
      }
      
    } catch (e, stackTrace) {
      final errorMsg = '[AuthService] ❌ Google sign-in failed: $e';
      debugPrint(errorMsg);
      DebugLogService().addError('Google sign-in failed', e, stackTrace);
      rethrow; // Re-throw to let the calling code handle the error
    }
  }

  /// Decodes a JWT token part (header or payload)
  /// Handles base64url encoding (used by JWT) which differs from standard base64
  static Map<String, dynamic> _decodeJwtPart(String part) {
    // Base64URL uses - and _ instead of + and /, and may omit padding
    String normalized = part.replaceAll('-', '+').replaceAll('_', '/');
    
    // Add padding if needed (base64 requires length to be multiple of 4)
    switch (normalized.length % 4) {
      case 1:
        normalized += '===';
        break;
      case 2:
        normalized += '==';
        break;
      case 3:
        normalized += '=';
        break;
    }
    
    return json.decode(utf8.decode(base64.decode(normalized)));
  }

  /// Extracts the audience (aud) from an Apple ID token
  /// Returns null if the token cannot be decoded or aud is missing
  static String? getAudienceFromIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) {
        debugPrint('[AuthService] ⚠️ Invalid JWT format (expected 3 parts, got ${parts.length})');
        return null;
      }
      
      final payload = _decodeJwtPart(parts[1]);
      return payload['aud'] as String?;
    } catch (e) {
      debugPrint('[AuthService] ❌ Error extracting audience from JWT: $e');
      return null;
    }
  }

  /// Provides detailed explanation for Apple Sign-In error codes
  /// Handles both numeric codes (1000-1005) and enum names (canceled, failed, etc.)
  static String _getAppleSignInErrorExplanation(String? code, String? message) {
    if (code == null) {
      return 'Unknown error code. Message: ${message ?? "No message provided"}';
    }

    String explanation;
    String possibleCauses;
    String codeDisplay = code;

    // Check if it's a numeric code first
    final codeInt = int.tryParse(code);
    if (codeInt != null) {
      codeDisplay = '$codeInt ($code)';
      switch (codeInt) {
        case 1000: // ASAuthorizationErrorUnknown
          explanation = 'Unknown error occurred during Apple Sign-In';
          possibleCauses = 'Possible causes: Network issues, device configuration problems, or unexpected system error. Check device logs and network connectivity.';
          break;
        case 1001: // ASAuthorizationErrorCanceled
          explanation = 'User cancelled the Apple Sign-In authorization';
          possibleCauses = 'User tapped "Cancel" or dismissed the authorization sheet. This is normal user behavior and not an error.';
          break;
        case 1002: // ASAuthorizationErrorFailed
          explanation = 'Apple Sign-In authorization request failed';
          possibleCauses = 'Possible causes: Invalid request configuration, missing entitlements, or Apple ID service unavailable. Check entitlements and provisioning profile.';
          break;
        case 1003: // ASAuthorizationErrorInvalidResponse
          explanation = 'Invalid response received from Apple Sign-In';
          possibleCauses = 'Possible causes: Corrupted response data, network interruption during authorization, or Apple service error. Check network connection and try again.';
          break;
        case 1004: // ASAuthorizationErrorNotHandled
          explanation = 'Apple Sign-In request was not handled';
          possibleCauses = 'Possible causes: Request not properly configured, missing delegate handling, or platform-specific issue. Check implementation and platform support.';
          break;
        case 1005: // ASAuthorizationErrorNotInteractive (if exists)
          explanation = 'Apple Sign-In authorization cannot be displayed interactively';
          possibleCauses = 'Possible causes: App is in background, authorization sheet already displayed, or device is locked. Ensure app is in foreground and user can interact.';
          break;
        default:
          explanation = 'Unknown error code: $codeInt';
          possibleCauses = 'This error code is not recognized. Check Apple documentation for latest error codes. Message: ${message ?? "No message provided"}';
      }
    } else {
      // Handle enum names (canceled, failed, etc.)
      final codeLower = code.toLowerCase();
      switch (codeLower) {
        case 'canceled':
        case 'cancelled':
          explanation = 'User cancelled the Apple Sign-In authorization';
          possibleCauses = 'User tapped "Cancel" or dismissed the authorization sheet. This is normal user behavior and not an error.';
          break;
        case 'failed':
          explanation = 'Apple Sign-In authorization request failed';
          possibleCauses = 'Possible causes: Invalid request configuration, missing entitlements, or Apple ID service unavailable. Check entitlements and provisioning profile.';
          break;
        case 'invalidresponse':
        case 'invalid_response':
          explanation = 'Invalid response received from Apple Sign-In';
          possibleCauses = 'Possible causes: Corrupted response data, network interruption during authorization, or Apple service error. Check network connection and try again.';
          break;
        case 'nothandled':
        case 'not_handled':
          explanation = 'Apple Sign-In request was not handled';
          possibleCauses = 'Possible causes: Request not properly configured, missing delegate handling, or platform-specific issue. Check implementation and platform support.';
          break;
        case 'notinteractive':
        case 'not_interactive':
          explanation = 'Apple Sign-In authorization cannot be displayed interactively';
          possibleCauses = 'Possible causes: App is in background, authorization sheet already displayed, or device is locked. Ensure app is in foreground and user can interact.';
          break;
        case 'unknown':
          explanation = 'Unknown error occurred during Apple Sign-In';
          possibleCauses = 'Possible causes: Network issues, device configuration problems, or unexpected system error. Check device logs and network connectivity.';
          break;
        default:
          explanation = 'Unknown error code: $code';
          possibleCauses = 'This error code is not recognized. Check Apple documentation for latest error codes. Message: ${message ?? "No message provided"}';
      }
    }

    return '''
Error Code: $codeDisplay
Explanation: $explanation
Possible Causes: $possibleCauses
Original Message: ${message ?? "No message provided"}''';
  }

  /// Debug helper to decode and print Apple ID token information
  static void _debugAppleToken(String? jwt) {
    if (jwt == null) {
      debugPrint('[AuthService] ⚠️ idToken is NULL');
      return;
    }
    
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) {
        debugPrint('[AuthService] ⚠️ Invalid JWT format (expected 3 parts, got ${parts.length})');
        return;
      }
      
      final header = _decodeJwtPart(parts[0]);
      final payload = _decodeJwtPart(parts[1]);
      
      debugPrint('[AuthService] 🔍 JWT Header: $header');
      debugPrint('[AuthService] 🔍 JWT aud (audience): ${payload['aud']}');
      debugPrint('[AuthService] 🔍 JWT iss (issuer): ${payload['iss']}');
      debugPrint('[AuthService] 🔍 JWT iat (issued at): ${payload['iat']}');
      debugPrint('[AuthService] 🔍 JWT exp (expires at): ${payload['exp']}');
      
      // Log to debug service
      DebugLogService().addLog('🔍 JWT aud (audience): ${payload['aud']}');
      DebugLogService().addLog('🔍 JWT iss (issuer): ${payload['iss']}');
      
      // Check if audience matches expected Bundle ID
      final expectedBundleId = 'com.liglius.lovenest';
      final actualAud = payload['aud'] as String?;
      
      if (actualAud == expectedBundleId) {
        debugPrint('[AuthService] ✅ Audience matches Bundle ID: $expectedBundleId');
        DebugLogService().addLog('✅ Audience matches Bundle ID: $expectedBundleId');
      } else {
        final warning = '⚠️ Audience mismatch! Expected: $expectedBundleId, Got: $actualAud\nThis indicates you may be using web OAuth instead of native flow';
        debugPrint('[AuthService] ⚠️ Audience mismatch! Expected: $expectedBundleId, Got: $actualAud');
        debugPrint('[AuthService] ⚠️ This indicates you may be using web OAuth instead of native flow');
        DebugLogService().addLog(warning, level: LogLevel.warning);
      }
    } catch (e) {
      final errorMsg = '[AuthService] ❌ Error decoding JWT: $e';
      debugPrint(errorMsg);
      DebugLogService().addError('JWT decode error', e);
    }
  }

  static Future<void> signInWithApple() async {
    try {
      debugPrint('[AuthService] 🍎 Starting Apple sign-in process...');
      DebugLogService().addLog('🍎 Starting Apple sign-in process...');

      // Generate a raw nonce for security (prevents replay attacks)
      final rawNonce = Supabase.instance.client.auth.generateRawNonce();
      // Hash the nonce for Apple (must be SHA256)
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      debugPrint('[AuthService] 🔐 Generated nonce for Apple sign-in');
      debugPrint('[AuthService] 🔐 Raw nonce length: ${rawNonce.length}');
      debugPrint('[AuthService] 🔐 Hashed nonce (first 20 chars): ${hashedNonce.substring(0, 20)}...');
      DebugLogService().addLog('🔐 Generated nonce (raw length: ${rawNonce.length})');

      // 0) Confirm API is available on this device
      final isAvail = await SignInWithApple.isAvailable();
      debugPrint('[AuthService] 🍏 isAvailable: $isAvail');
      DebugLogService().addLog('🍏 Apple Sign-In available: $isAvail');
      
      if (!isAvail) {
        final error = 'Apple Sign-In not available on this device';
        debugPrint('[AuthService] ❌ $error');
        DebugLogService().addLog('❌ $error', level: LogLevel.error);
        return;
      }

      // Request Apple ID credentials with hashed nonce
      // Wrap in try-catch to get detailed error information
      final appleCredential;
      try {
        debugPrint('[AuthService] 🪟 Presenting Apple sheet...');
        DebugLogService().addLog('🪟 Presenting Apple sheet...');
        
        appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: hashedNonce,
        ).timeout(
          const Duration(seconds: 20), // 1) detect hangs
        );

        debugPrint('[AuthService] ✅ Apple credentials obtained');
        DebugLogService().addLog('✅ Apple credentials obtained');
      } on TimeoutException {
        // 1) detect hangs
        debugPrint('[AuthService] ⏱️ Apple sheet timed out (no response in 20s)');
        DebugLogService().addLog('⏱️ Apple sheet timed out', level: LogLevel.warning);
        return;
      } on SignInWithAppleAuthorizationException catch (e) {
        // 2) log the real code
        final detailedExplanation = _getAppleSignInErrorExplanation(e.code.toString().replaceAll('AuthorizationErrorCode.', ''), e.message);
        debugPrint('[AuthService] ❌ SIWA exception: code=${e.code} message=${e.message}');
        debugPrint('[AuthService] ❌ Detailed explanation:\n$detailedExplanation');
        DebugLogService().addError('SIWA exception: ${e.code} - ${e.message}');
        DebugLogService().addLog(detailedExplanation, level: LogLevel.error);
        
        // Additional context based on error code
        final errorCodeStr = e.code.toString().replaceAll('AuthorizationErrorCode.', '');
        if (errorCodeStr == 'canceled' || errorCodeStr.contains('1001')) {
          debugPrint('[AuthService] ℹ️ User cancelled - this is expected behavior, not an error');
          DebugLogService().addLog('ℹ️ User cancelled - this is expected behavior, not an error');
        } else if (errorCodeStr == 'failed' || errorCodeStr.contains('1002')) {
          debugPrint('[AuthService] ⚠️ Check: iOS version >= 13, entitlements configured, provisioning profile includes Sign in with Apple');
          DebugLogService().addLog('⚠️ Check: iOS version >= 13, entitlements configured, provisioning profile includes Sign in with Apple', level: LogLevel.warning);
        }
        
        return;
      } catch (e, st) {
        // Generic error handler
        final errorDetails = '''
Generic error: $e
Error type: ${e.runtimeType}
Stack trace: ${st.toString().split('\n').take(5).join('\n')}

Possible causes:
- Platform-specific issue (check if running on iOS/macOS)
- Missing dependencies or configuration
- Unexpected exception in Sign in with Apple package
- System-level error

Check the full stack trace for more details.''';
        debugPrint('[AuthService] ❌ Generic error: $e');
        debugPrint('[AuthService] ❌ Error type: ${e.runtimeType}');
        debugPrint('[AuthService] ❌ Details:\n$errorDetails');
        DebugLogService().addError('Generic SIWA error', e, st);
        DebugLogService().addLog(errorDetails, level: LogLevel.error);
        return;
      }

      // Extract the identity token
      final identityToken = appleCredential.identityToken;
      if (identityToken == null) {
        final error = 'No identity token found from Apple sign-in';
        DebugLogService().addError(error);
        throw Exception(error);
      }

      debugPrint('[AuthService] 🔑 Got identity token from Apple');
      DebugLogService().addLog('🔑 Got identity token from Apple');
      
      // Extract and verify audience BEFORE calling Supabase
      final aud = getAudienceFromIdToken(identityToken);
      debugPrint('[AuthService] 🍏 Apple ID token audience: $aud');
      DebugLogService().addLog('🍏 Apple ID token audience: $aud');
      
      const expectedBundleId = 'com.liglius.lovenest';
      if (aud != expectedBundleId) {
        final errorMsg = '⚠️ Incorrect AUD — expected $expectedBundleId, got $aud';
        debugPrint('[AuthService] $errorMsg');
        debugPrint('[AuthService] ⚠️ This indicates you may be using web OAuth instead of native flow');
        debugPrint('[AuthService] ⚠️ Aborting Supabase sign-in to prevent invalid_grant error');
        DebugLogService().addLog(errorMsg, level: LogLevel.warning);
        DebugLogService().addLog('⚠️ Aborting Supabase sign-in to prevent invalid_grant error', level: LogLevel.warning);
        throw Exception('Invalid audience: expected $expectedBundleId, but got $aud. This indicates the token is from web OAuth flow, not native.');
      }
      
      debugPrint('[AuthService] ✅ Audience verified: $aud');
      DebugLogService().addLog('✅ Audience verified: $aud');
      
      // Debug: Decode and verify the token (full details)
      _debugAppleToken(identityToken);

      // ✅ Now safe to sign in to Supabase
      // CRITICAL: Send RAW nonce to Supabase, NOT the hashed one
      debugPrint('[AuthService] 🔐 About to call Supabase signInWithIdToken with aud: $aud');
      DebugLogService().addLog('🔐 About to call Supabase signInWithIdToken with aud: $aud');
      debugPrint('[AuthService] 🔐 Sending to Supabase: raw nonce (length: ${rawNonce.length})');
      DebugLogService().addLog('🔐 Sending to Supabase: raw nonce (length: ${rawNonce.length})');
      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: identityToken,
        nonce: rawNonce, // RAW nonce - Supabase will hash it to verify
      );

      debugPrint('[AuthService] ✅ Successfully signed in to Supabase with Apple');
      DebugLogService().addLog('✅ Successfully signed in to Supabase with Apple');

      // Apple only provides the user's full name on the first sign-in
      // Save it to user metadata if available
      if (appleCredential.givenName != null || appleCredential.familyName != null) {
        final nameParts = <String>[];
        if (appleCredential.givenName != null) {
          nameParts.add(appleCredential.givenName!);
        }
        if (appleCredential.familyName != null) {
          nameParts.add(appleCredential.familyName!);
        }

        final fullName = nameParts.join(' ');

        debugPrint('[AuthService] 📝 Saving user name to metadata: $fullName');

        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'full_name': fullName,
              'given_name': appleCredential.givenName,
              'family_name': appleCredential.familyName,
            },
          ),
        );

        debugPrint('[AuthService] ✅ User name saved to metadata');
      }

      // Verify the session was established
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        debugPrint('[AuthService] ✅ Session verified - User ID: ${currentUser.id}');
      } else {
        debugPrint('[AuthService] ⚠️ Session verification failed - no current user');
      }

    } on TimeoutException {
      final timeoutMsg = '⏱️ Apple sheet timed out (no response in 20s)\n'
          'Possible causes:\n'
          '- User left the app during authorization\n'
          '- Apple Sign-In dialog is stuck or not responding\n'
          '- Network connectivity issues\n'
          '- Device is locked or in background\n'
          'Try ensuring the app stays in foreground and user responds promptly.';
      debugPrint('[AuthService] ⏱️ Apple sheet timed out (no response in 20s)');
      debugPrint('[AuthService] $timeoutMsg');
      DebugLogService().addLog('⏱️ Apple sheet timed out', level: LogLevel.warning);
      DebugLogService().addLog(timeoutMsg, level: LogLevel.warning);
      return;
    } on SignInWithAppleAuthorizationException catch (e) {
      // Log the real code with detailed explanation
      // Convert AuthorizationErrorCode to string for processing
      final errorCodeStr = e.code.toString().replaceAll('AuthorizationErrorCode.', '');
      final detailedExplanation = _getAppleSignInErrorExplanation(errorCodeStr, e.message);
      debugPrint('[AuthService] ❌ SIWA exception: code=$errorCodeStr (${e.code}) message=${e.message}');
      debugPrint('[AuthService] ❌ Detailed explanation:\n$detailedExplanation');
      DebugLogService().addError('SIWA exception: $errorCodeStr - ${e.message}');
      DebugLogService().addLog(detailedExplanation, level: LogLevel.error);
      
      // Additional context based on error code
      if (errorCodeStr == 'canceled' || errorCodeStr.contains('1001')) {
        debugPrint('[AuthService] ℹ️ User cancelled - this is expected behavior, not an error');
        DebugLogService().addLog('ℹ️ User cancelled - this is expected behavior, not an error');
      } else if (errorCodeStr == 'failed' || errorCodeStr.contains('1002')) {
        debugPrint('[AuthService] ⚠️ Check: iOS version >= 13, entitlements configured, provisioning profile includes Sign in with Apple');
        DebugLogService().addLog('⚠️ Check: iOS version >= 13, entitlements configured, provisioning profile includes Sign in with Apple', level: LogLevel.warning);
      }
      
      return;
    } catch (e, stackTrace) {
      final errorDetails = '''
Generic error: $e
Error type: ${e.runtimeType}
Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}

Possible causes:
- Platform-specific issue (check if running on iOS/macOS)
- Missing dependencies or configuration
- Unexpected exception in Sign in with Apple package
- System-level error

Check the full stack trace for more details.''';
      debugPrint('[AuthService] ❌ Generic error: $e');
      debugPrint('[AuthService] ❌ Error type: ${e.runtimeType}');
      debugPrint('[AuthService] ❌ Details:\n$errorDetails');
      DebugLogService().addError('Generic SIWA error', e, stackTrace);
      DebugLogService().addLog(errorDetails, level: LogLevel.error);
      return;
    }
  }

  static Future<void> signOut() async {
    try {
      debugPrint('[AuthService] 🚪 Signing out from Supabase...');
      await Supabase.instance.client.auth.signOut();
      debugPrint('[AuthService] ✅ Successfully signed out from Supabase');
      
      // Also sign out from Google
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
        debugPrint('[AuthService] ✅ Successfully signed out from Google');
      } catch (e) {
        debugPrint('[AuthService] ⚠️ Error signing out from Google: $e');
      }

      // Note: Apple Sign-In doesn't require explicit sign out as it doesn't maintain a persistent session
      // The Supabase session cleanup is sufficient
    } catch (e) {
      debugPrint('[AuthService] ❌ Error signing out: $e');
      rethrow;
    }
  }
} 
