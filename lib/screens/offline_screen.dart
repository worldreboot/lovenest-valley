import 'package:flutter/material.dart';
import 'package:lovenest/config/supabase_config.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _isRetrying = false;

  Future<void> _retryConnection() async {
    setState(() => _isRetrying = true);
    
    try {
      final success = await SupabaseConfig.retryConnection();
      if (success && mounted) {
        // Navigate back to main app
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wifi_off,
                size: 80,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 24),
              Text(
                'No Internet Connection',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Lovenest Valley requires an internet connection to sync your progress and connect with your partner.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _retryConnection,
                icon: _isRetrying 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
                label: Text(_isRetrying ? 'Retrying...' : 'Retry Connection'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Show troubleshooting tips
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Troubleshooting Tips'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• Check your internet connection'),
                          Text('• Try switching between WiFi and mobile data'),
                          Text('• Restart the app'),
                          Text('• If using an emulator, try restarting it'),
                          Text('• Check if your firewall is blocking the connection'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Need Help?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
