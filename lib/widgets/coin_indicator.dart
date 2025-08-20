import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lovenest/config/supabase_config.dart';
import 'package:lovenest/services/currency_service.dart';

class CoinIndicator extends StatefulWidget {
  const CoinIndicator({super.key});

  @override
  State<CoinIndicator> createState() => _CoinIndicatorState();
}

class _CoinIndicatorState extends State<CoinIndicator> {
  int _coins = 0;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return;

    // Load initial balance
    final balance = await CurrencyService.getBalance();
    if (mounted) setState(() => _coins = balance);

    // Subscribe to profile coin changes
    try {
      _channel = SupabaseConfig.client.channel('coins_${userId}');
      _channel!
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: userId,
            ),
            callback: (payload) {
              try {
                final newCoins = payload.newRecord['coins'] as int?;
                if (newCoins != null && mounted) {
                  setState(() => _coins = newCoins);
                }
              } catch (_) {}
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return const SizedBox.shrink();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, color: Colors.amber, size: 22),
            const SizedBox(width: 6),
            Text(
              '$_coins',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


