import 'package:flutter/material.dart';
import 'package:lovenest_valley/services/superwall_service.dart';

class SuperwallPaywallScreen extends StatefulWidget {
  final VoidCallback? onEntitled;
  final VoidCallback? onClose;
  final String placement;
  
  const SuperwallPaywallScreen({
    super.key, 
    this.onEntitled, 
    this.onClose,
    this.placement = 'premium',
  });

  @override
  State<SuperwallPaywallScreen> createState() => _SuperwallPaywallScreenState();
}

class _SuperwallPaywallScreenState extends State<SuperwallPaywallScreen> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _presentPaywall();
  }

  Future<void> _presentPaywall() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      await SuperwallService.initialize();
      await SuperwallService.presentPaywall(widget.placement);
      
      // Check if user became entitled after paywall presentation
      final entitled = await SuperwallService.isEntitled();
      if (entitled) {
        widget.onEntitled?.call();
        if (mounted) Navigator.of(context).pop();
      }
      
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load subscription options. Please try again later.';
        _loading = false;
      });
    }
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      await SuperwallService.restorePurchases();
      
      // Check if user became entitled after restore
      final entitled = await SuperwallService.isEntitled();
      if (entitled) {
        widget.onEntitled?.call();
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _error = 'No previous purchases found to restore.';
        });
      }
      
      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to restore purchases. Please try again later.';
        _loading = false;
      });
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
            colors: [Color(0xFFFFE1E9), Color(0xFFFFC0CB)],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Lovenest Premium',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B4513),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              widget.onClose?.call();
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.close, color: Colors.brown),
                          ),
                        ],
                      ),
                    ),

                    // Selling points
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: const [
                          _Bullet(text: 'Science-backed daily prompts that deepen intimacy'),
                          _Bullet(text: 'Plant and nurture shared memories in your garden'),
                          _Bullet(text: 'Mood-weather reflections to stay emotionally attuned'),
                          _Bullet(text: 'Exclusive events and blooms for committed couples'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Retry button if there's an error
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton(
                          onPressed: _presentPaywall,
                          child: const Text('Try Again'),
                        ),
                      ),

                    const Spacer(),

                    // Restore purchases button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _restore,
                            child: const Text('Restore purchases'),
                          ),
                          const Text(
                            'Cancel anytime',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B4513),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF8B4513),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
