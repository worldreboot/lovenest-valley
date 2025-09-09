import 'package:flutter/material.dart';

class DailyQuestionProgressIndicator extends StatelessWidget {
  final int currentProgress;
  final int maxProgress;
  final bool isReadyToBloom;

  const DailyQuestionProgressIndicator({
    super.key,
    required this.currentProgress,
    required this.maxProgress,
    this.isReadyToBloom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReadyToBloom ? Colors.purple : Colors.blue,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isReadyToBloom ? Icons.local_florist : Icons.water_drop,
                color: isReadyToBloom ? Colors.purple : Colors.blue,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                isReadyToBloom ? 'Ready to Bloom!' : 'Daily Question Seed',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isReadyToBloom ? Colors.purple : Colors.blue,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$currentProgress/$maxProgress days',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(width: 8),
              ...List.generate(maxProgress, (index) {
                final isWatered = index < currentProgress;
                final isReady = isReadyToBloom && index == maxProgress - 1;
                
                return Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.only(right: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isReady 
                        ? Colors.purple 
                        : isWatered 
                            ? Colors.blue 
                            : Colors.grey[300],
                    border: isReady 
                        ? Border.all(color: Colors.purple, width: 1)
                        : null,
                  ),
                  child: isReady 
                      ? Icon(
                          Icons.local_florist,
                          size: 6,
                          color: Colors.white,
                        )
                      : null,
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
} 
