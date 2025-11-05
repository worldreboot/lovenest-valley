import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
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

      // Request Apple ID credentials with hashed nonce
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      debugPrint('[AuthService] ✅ Apple credentials obtained');
      DebugLogService().addLog('✅ Apple credentials obtained');

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

    } catch (e, stackTrace) {
      final errorMsg = '[AuthService] ❌ Apple sign-in failed: $e';
      debugPrint(errorMsg);
      DebugLogService().addError('Apple sign-in failed', e, stackTrace);
      rethrow; // Re-throw to let the calling code handle the error
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
