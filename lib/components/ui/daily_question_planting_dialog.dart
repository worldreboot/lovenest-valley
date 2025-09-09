import 'package:flutter/material.dart';
import 'package:lovenest_valley/models/memory_garden/question.dart';

class DailyQuestionPlantingDialog extends StatefulWidget {
  final Question question;
  final Function(String answer) onPlant;

  const DailyQuestionPlantingDialog({
    super.key,
    required this.question,
    required this.onPlant,
  });

  @override
  State<DailyQuestionPlantingDialog> createState() => _DailyQuestionPlantingDialogState();
}

class _DailyQuestionPlantingDialogState extends State<DailyQuestionPlantingDialog> {
  final TextEditingController _answerController = TextEditingController();
  bool _isPlanting = false;

  @override
  void initState() {
    super.initState();
    // Add listener to update button state when text changes
    _answerController.addListener(() {
      setState(() {
        // This will rebuild the widget when text changes
      });
    });
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.psychology, color: Colors.orange),
          SizedBox(width: 8),
          Text('Daily Question'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The owl has given you a special seed!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  widget.question.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Your answer will be planted as a seed that needs to be watered for 3 days to bloom into a beautiful flower!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _answerController,
            decoration: InputDecoration(
              labelText: 'Your Answer',
              hintText: 'Write your answer here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            maxLines: 3,
            maxLength: 200,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isPlanting ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isPlanting || _answerController.text.trim().isEmpty
              ? null
              : () async {
                  setState(() {
                    _isPlanting = true;
                  });
                  
                  try {
                    await widget.onPlant(_answerController.text.trim());
                    if (mounted) {
                      Navigator.of(context).pop(_answerController.text.trim());
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to plant seed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isPlanting = false;
                      });
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isPlanting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text('Plant Seed'),
        ),
      ],
    );
  }
} 
