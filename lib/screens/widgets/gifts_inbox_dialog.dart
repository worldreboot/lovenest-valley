import 'package:flutter/material.dart';
import 'package:lovenest_valley/models/inventory.dart';
import 'package:lovenest_valley/services/pending_gift_service.dart';

class GiftsInboxDialog extends StatefulWidget {
  final InventoryManager inventoryManager;
  final BuildContext parentContext; // to show SnackBars above the dialog's barrier
  const GiftsInboxDialog({super.key, required this.inventoryManager, required this.parentContext});

  @override
  State<GiftsInboxDialog> createState() => _GiftsInboxDialogState();
}

class _GiftsInboxDialogState extends State<GiftsInboxDialog> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    await PendingGiftService.syncDueGifts();
    return PendingGiftService.fetchCollectibleGifts();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8E7C9), // parchment-style
          border: Border.all(color: const Color(0xFF8B6F3A), width: 8), // wood frame
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Gifts Received',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade700,
                  letterSpacing: 1.5,
                  shadows: [
                    Shadow(
                      color: Colors.brown.shade200,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Content
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final gifts = snapshot.data ?? [];
                  if (gifts.isEmpty) {
                    return Center(
                      child: Text(
                        'No gifts ready to collect.',
                        style: TextStyle(color: Colors.brown.shade600, fontSize: 16),
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      children: gifts.map((gift) {
                        final spriteUrl = gift['sprite_url'] as String?;
                        final prompt = (gift['prompt'] as String?) ?? 'A special gift';
                        final deliverOn = (gift['deliver_on'] as String?) ?? '';
                        return _GiftCard(
                          spriteUrl: spriteUrl,
                          prompt: prompt,
                          deliverOn: deliverOn,
                          onCollect: () async {
                            final ok = await PendingGiftService.collectGift(
                              giftId: gift['id'] as String,
                              spriteUrl: spriteUrl,
                              inventoryManager: widget.inventoryManager,
                            );
                            if (!mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                                const SnackBar(content: Text('Gift collected!'), backgroundColor: Colors.green),
                              );
                              setState(() {
                                _future = _load();
                              });
                            } else {
                              ScaffoldMessenger.of(widget.parentContext).showSnackBar(
                                const SnackBar(content: Text('No space in inventory. Please free a slot.'), backgroundColor: Colors.orange),
                              );
                            }
                          },
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftCard extends StatelessWidget {
  final String? spriteUrl;
  final String prompt;
  final String deliverOn;
  final VoidCallback onCollect;

  const _GiftCard({
    required this.spriteUrl,
    required this.prompt,
    required this.deliverOn,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E1B6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.brown.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Big centered sprite
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.brown.shade300, width: 2),
            ),
            child: spriteUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      spriteUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.card_giftcard, size: 48),
                    ),
                  )
                : const Center(child: Icon(Icons.card_giftcard, size: 48)),
          ),
          const SizedBox(height: 12),
          // Prompt / description
          Text(
            prompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.brown.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ready since: $deliverOn',
            style: TextStyle(color: Colors.brown.shade500),
          ),
          const SizedBox(height: 16),
          // Collect button at bottom
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onCollect,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Collect', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}


