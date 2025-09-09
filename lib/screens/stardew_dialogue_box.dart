import 'package:flutter/material.dart';
import 'dart:async';

class StardewDialogueBox extends StatefulWidget {
  final String text;
  final VoidCallback? onClose;

  const StardewDialogueBox({
    Key? key,
    required this.text,
    this.onClose,
  }) : super(key: key);

  @override
  State<StardewDialogueBox> createState() => _StardewDialogueBoxState();
}

class _StardewDialogueBoxState extends State<StardewDialogueBox> {
  String _visibleText = '';
  Timer? _timer;
  int _charIndex = 0;
  bool _fullyRevealed = false;

  static const Duration charDelay = Duration(milliseconds: 50);

  @override
  void initState() {
    super.initState();
    _startTextAnimation();
  }

  void _startTextAnimation() {
    _visibleText = '';
    _charIndex = 0;
    _fullyRevealed = false;
    _timer?.cancel();
    _timer = Timer.periodic(charDelay, (timer) {
      if (_charIndex < widget.text.length) {
        setState(() {
          _visibleText += widget.text[_charIndex];
          _charIndex++;
        });
      } else {
        _fullyRevealed = true;
        _timer?.cancel();
      }
    });
  }

  void _revealAll() {
    setState(() {
      _visibleText = widget.text;
      _fullyRevealed = true;
    });
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Semi-transparent overlay to dim the background
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose ?? () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
        // Bottom-aligned dialog box
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 32, left: 16, right: 16),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {
                  if (!_fullyRevealed) {
                    _revealAll();
                  }
                },
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 600),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8E7C1), // Parchment-like
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFB48A5A),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.brown.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _visibleText,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFF5B4636),
                          fontFamily: 'Georgia',
                          height: 1.4,
                          shadows: [
                            Shadow(
                              color: Colors.white,
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFB48A5A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Close',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
} 
