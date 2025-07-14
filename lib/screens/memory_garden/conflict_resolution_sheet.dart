import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/memory_garden/seed.dart';
import '../../services/garden_sync_service.dart';
import '../../providers/enhanced_garden_providers.dart';

class ConflictResolutionSheet extends ConsumerStatefulWidget {
  final GardenConflict conflict;

  const ConflictResolutionSheet({
    super.key,
    required this.conflict,
  });

  @override
  ConsumerState<ConflictResolutionSheet> createState() => _ConflictResolutionSheetState();
}

class _ConflictResolutionSheetState extends ConsumerState<ConflictResolutionSheet> {
  ConflictResolutionStrategy? _selectedStrategy;
  bool _isResolving = false;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Header
                Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Conflict Resolution',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Conflict description
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Position Conflict',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Multiple memories have been planted at position (${widget.conflict.plotPosition.x}, ${widget.conflict.plotPosition.y}). This happens when both partners plant memories at the same location simultaneously.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Conflicting memories: ${widget.conflict.conflictingSeeds.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Conflicting seeds list
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      const Text(
                        'Conflicting Memories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ...widget.conflict.conflictingSeeds.map((seed) => 
                        _buildSeedCard(seed)
                      ).toList(),
                      
                      const SizedBox(height: 24),
                      
                      // Resolution strategies
                      const Text(
                        'Resolution Options',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildStrategyOption(
                        ConflictResolutionStrategy.firstWins,
                        'First Wins',
                        'Keep the first memory planted, move others to nearby positions',
                        Icons.first_page,
                        Colors.blue,
                      ),
                      
                      _buildStrategyOption(
                        ConflictResolutionStrategy.merge,
                        'Merge Memories',
                        'Combine all memories into a special merged memory',
                        Icons.merge,
                        Colors.purple,
                      ),
                      
                      _buildStrategyOption(
                        ConflictResolutionStrategy.relocate,
                        'Relocate All',
                        'Move all conflicting memories to nearby empty positions',
                        Icons.swap_horiz,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isResolving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _selectedStrategy == null || _isResolving
                          ? null
                          : _resolveConflict,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: _isResolving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Resolve Conflict'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSeedCard(Seed seed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Media type icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getMediaTypeColor(seed.mediaType),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _getMediaTypeIcon(seed.mediaType),
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          
          // Seed info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getMediaTypeLabel(seed.mediaType),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                if (seed.textContent != null && seed.textContent!.isNotEmpty)
                  Text(
                    seed.textContent!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                Text(
                  'Planted ${_formatTime(seed.createdAt)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyOption(
    ConflictResolutionStrategy strategy,
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedStrategy == strategy;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _selectedStrategy = strategy),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.grey[600],
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? color : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: color,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resolveConflict() async {
    if (_selectedStrategy == null) return;
    
    setState(() => _isResolving = true);
    
    try {
      final syncService = ref.read(gardenSyncServiceProvider);
      await syncService.resolveConflict(widget.conflict, _selectedStrategy!);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conflict resolved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve conflict: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  IconData _getMediaTypeIcon(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.photo:
        return Icons.photo;
      case MediaType.voice:
        return Icons.audiotrack;
      case MediaType.text:
        return Icons.text_fields;
      case MediaType.link:
        return Icons.link;
    }
  }

  Color _getMediaTypeColor(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.photo:
        return Colors.blue;
      case MediaType.voice:
        return Colors.green;
      case MediaType.text:
        return Colors.purple;
      case MediaType.link:
        return Colors.orange;
    }
  }

  String _getMediaTypeLabel(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.photo:
        return 'Photo Memory';
      case MediaType.voice:
        return 'Voice Memory';
      case MediaType.text:
        return 'Text Memory';
      case MediaType.link:
        return 'Link Memory';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
} 