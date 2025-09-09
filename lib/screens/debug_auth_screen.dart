import 'package:flutter/material.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:lovenest_valley/screens/auth_flow_screen.dart';
import 'package:lovenest_valley/services/auth_service.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class DebugAuthScreen extends StatelessWidget {
  const DebugAuthScreen({super.key});

  Future<void> _testNetworkConnectivity(BuildContext context) async {
    final results = <String, bool>{};
    
    try {
      // Test basic internet
      final googleResponse = await http.get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 10));
      results['Google'] = googleResponse.statusCode == 200;
    } catch (e) {
      results['Google'] = false;
    }
    
    try {
      // Test Supabase directly
      final supabaseResponse = await http.get(Uri.parse('https://lxmjpdmqzblpsdhmlfrt.supabase.co'))
          .timeout(const Duration(seconds: 10));
      results['Supabase'] = supabaseResponse.statusCode == 200;
    } catch (e) {
      results['Supabase'] = false;
    }
    
    try {
      // Test DNS resolution
      final addresses = await InternetAddress.lookup('lxmjpdmqzblpsdhmlfrt.supabase.co');
      results['DNS Resolution'] = addresses.isNotEmpty;
    } catch (e) {
      results['DNS Resolution'] = false;
    }
    
    // Test Supabase client connectivity
    try {
      if (SupabaseConfig.isOnline) {
        final client = SupabaseConfig.client;
        // Try to access auth state to test connectivity
        final currentUser = client.auth.currentUser;
        results['Supabase Client'] = true;
      } else {
        results['Supabase Client'] = false;
      }
    } catch (e) {
      results['Supabase Client'] = false;
    }
    
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Network Test Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: results.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      entry.value ? Icons.check_circle : Icons.error,
                      color: entry.value ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text('${entry.key}: ${entry.value ? 'OK' : 'FAILED'}'),
                  ],
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Auth'),
        backgroundColor: Colors.red,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Authentication Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Online: ${SupabaseConfig.isOnline}'),
                    Text('Needs Re-auth: ${SupabaseConfig.needsReauth}'),
                    Text('Current User: ${SupabaseConfig.currentUser?.id ?? 'None'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _testNetworkConnectivity(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Network Connectivity'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SupabaseConfig.client.auth.signOut();
                  SupabaseConfig.clearReauthFlag();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const AuthFlowScreen()),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sign out error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Force Sign Out'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                SupabaseConfig.clearReauthFlag();
                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const AuthFlowScreen()),
                  );
                }
              },
              child: const Text('Clear Re-auth Flag'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  final success = await SupabaseConfig.retryConnection();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Connection restored' : 'Connection failed'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Retry error: $e')),
                    );
                  }
                }
              },
              child: const Text('Retry Connection'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                try {
                  debugPrint('[DebugAuthScreen] 🔐 Testing Google sign-in...');
                  await AuthService.signInWithGoogleNative();
                  debugPrint('[DebugAuthScreen] ✅ Google sign-in test completed');
                  
                  // Refresh auth state
                  await SupabaseConfig.refreshAuthState();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Google sign-in test completed - check logs'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    
                    // Navigate back to auth flow to see the result
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const AuthFlowScreen()),
                    );
                  }
                } catch (e) {
                  debugPrint('[DebugAuthScreen] ❌ Google sign-in test failed: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Google sign-in test failed: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Google Sign-In'),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Info',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Use "Test Network Connectivity" to diagnose network issues'),
                    Text('• Use "Force Sign Out" to clear authentication state'),
                    Text('• Use "Clear Re-auth Flag" to reset re-authentication requirement'),
                    Text('• Use "Retry Connection" to test network connectivity'),
                    Text('• Use "Test Google Sign-In" to test the authentication flow'),
                    Text('• This screen is useful for emulator testing'),
                    SizedBox(height: 8),
                    Text(
                      'Common Emulator Network Issues:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('• Restart the emulator'),
                    Text('• Check emulator network settings'),
                    Text('• Disable VPN/firewall'),
                    Text('• Try different network configuration'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
