import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:lovenest/services/revenuecat_service.dart';

class PaywallScreen extends StatefulWidget {
  final VoidCallback? onEntitled;
  final VoidCallback? onClose;
  const PaywallScreen({super.key, this.onEntitled, this.onClose});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RevenueCatService.initialize();
      final offerings = await RevenueCatService.getOfferings();
      setState(() {
        _offerings = offerings;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load plans. Please try again later.';
        _loading = false;
      });
    }
  }

  Future<void> _purchase(Package package) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final info = await RevenueCatService.purchase(package);
    setState(() {
      _loading = false;
    });
    if (info != null) {
      final entitled = await RevenueCatService.isEntitled();
      if (entitled) {
        widget.onEntitled?.call();
        if (mounted) Navigator.of(context).pop();
      }
    }
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await RevenueCatService.restore();
    setState(() {
      _loading = false;
    });
    final entitled = await RevenueCatService.isEntitled();
    if (entitled) {
      widget.onEntitled?.call();
      if (mounted) Navigator.of(context).pop();
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

                    // Plans
                    Expanded(
                      child: _offerings?.current == null
                          ? const Center(child: Text('No plans available right now.'))
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: _offerings!.current!.availablePackages
                                  .map((pkg) => _PackageTile(
                                        package: pkg,
                                        onTap: () => _purchase(pkg),
                                      ))
                                  .toList(),
                            ),
                    ),

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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF27AE60)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF4A4A4A),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  final Package package;
  final VoidCallback onTap;
  const _PackageTile({required this.package, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final product = package.storeProduct;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ListTile(
        title: Text(product.title),
        subtitle: Text(product.description),
        trailing: Text(product.priceString, style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: onTap,
      ),
    );
  }
}


