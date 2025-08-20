import 'package:flutter/material.dart';

class BonfireInteractionDialog extends StatelessWidget {
  final bool isLit;
  final double woodLevel;
  final double maxWoodCapacity;
  final double intensity;
  final VoidCallback? onAddWood;

  const BonfireInteractionDialog({
    super.key,
    required this.isLit,
    required this.woodLevel,
    required this.maxWoodCapacity,
    required this.intensity,
    this.onAddWood,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.brown.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Icon(
            isLit ? Icons.local_fire_department : Icons.local_fire_department_outlined,
            color: isLit ? Colors.orange : Colors.grey,
            size: 32,
          ),
          const SizedBox(width: 12),
          const Text(
            'Bonfire',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLit ? Colors.orange.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLit ? Colors.orange.shade300 : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isLit ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                  color: isLit ? Colors.orange : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  isLit ? 'Fire is burning' : 'Fire is out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isLit ? Colors.orange.shade800 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Wood level
          Text(
            'Wood Level',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.brown.shade700,
            ),
          ),
          const SizedBox(height: 8),
          
          // Wood progress bar
          Container(
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (woodLevel / maxWoodCapacity).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.brown.shade400,
                      Colors.brown.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            '${woodLevel.toInt()}/${maxWoodCapacity.toInt()} logs',
            style: TextStyle(
              fontSize: 12,
              color: Colors.brown.shade600,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Intensity indicator
          if (isLit) ...[
            Text(
              'Fire Intensity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 8),
            
            Row(
              children: List.generate(5, (index) {
                final isLit = index < (intensity * 5).round();
                return Icon(
                  Icons.local_fire_department,
                  color: isLit ? Colors.orange : Colors.grey.shade300,
                  size: 20,
                );
              }),
            ),
            
            const SizedBox(height: 16),
          ],
          
          // Add wood button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAddWood,
              icon: const Icon(Icons.add),
              label: const Text('Add Wood'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
} 