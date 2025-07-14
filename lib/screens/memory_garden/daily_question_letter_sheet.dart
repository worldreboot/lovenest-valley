import 'package:flutter/material.dart';
import '../../models/memory_garden/question.dart';

class DailyQuestionLetterSheet extends StatefulWidget {
  final Question question;
  final void Function(String answer)? onAnswered;

  const DailyQuestionLetterSheet({
    Key? key,
    required this.question,
    this.onAnswered,
  }) : super(key: key);

  @override
  State<DailyQuestionLetterSheet> createState() => _DailyQuestionLetterSheetState();
}

class _DailyQuestionLetterSheetState extends State<DailyQuestionLetterSheet> {
  final TextEditingController _answerController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // Light paper color
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.brown.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        image: const DecorationImage(
          image: AssetImage('assets/images/wood.png'),
          fit: BoxFit.cover,
          opacity: 0.08,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: Colors.brown, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Letter from the Owl',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown.shade700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.brown),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Decorative divider
          Center(
            child: Container(
              width: 60,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.brown.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Question text
          Text(
            '"${widget.question.text}"',
            style: const TextStyle(
              fontSize: 20,
              fontStyle: FontStyle.italic,
              color: Colors.brown,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Date
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatDate(widget.question.createdAt),
              style: TextStyle(
                fontSize: 14,
                color: Colors.brown.shade400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Answer input
          TextField(
            controller: _answerController,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: 'Your Answer',
              labelStyle: TextStyle(color: Colors.brown.shade700),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.brown.shade200),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.9),
            ),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          // Submit button
          ElevatedButton.icon(
            onPressed: _submitting || _answerController.text.trim().isEmpty
                ? null
                : () async {
                    setState(() => _submitting = true);
                    final answer = _answerController.text.trim();
                    if (widget.onAnswered != null) {
                      widget.onAnswered!(answer);
                    }
                    Navigator.of(context).pop(answer);
                  },
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            label: const Text('Submit Answer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Example: March 14, 2024
    return '${_monthName(date.month)} ${date.day}, ${date.year}';
  }

  String _monthName(int month) {
    const months = [
      '',
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }
} 