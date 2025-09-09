import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/memory_garden/seed.dart';
import '../../models/memory_garden/water_reply.dart';
import '../../providers/garden_providers.dart';

class BloomViewerSheet extends ConsumerStatefulWidget {
  final Seed seed;

  const BloomViewerSheet({
    super.key,
    required this.seed,
  });

  @override
  ConsumerState<BloomViewerSheet> createState() => _BloomViewerSheetState();
}

class _BloomViewerSheetState extends ConsumerState<BloomViewerSheet> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _showSecretHope = false;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.local_florist, color: Colors.pink, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Memory Bloom',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getBloomStageDescription(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Bloom visualization
          _buildBloomVisualization(),
          const SizedBox(height: 20),
          
          // Memory content
          _buildMemoryContent(),
          const SizedBox(height: 20),
          
          // Interaction timeline
          _buildInteractionTimeline(),
          const SizedBox(height: 20),
          
          // Secret hope revelation (if available)
          if (widget.seed.canRevealSecret) _buildSecretHopeSection(),
        ],
      ),
    );
  }

  String _getBloomStageDescription() {
    switch (widget.seed.state) {
      case SeedState.bloomStage1:
        return 'A beautiful new bloom ✨';
      case SeedState.bloomStage2:
        return 'A magnificent, evolved bloom 🌟';
      case SeedState.bloomStage3:
        return 'A perfect, radiant bloom 💫';
      default:
        return 'A special memory bloom';
    }
  }

  Widget _buildBloomVisualization() {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getBloomColors(),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getBloomEmoji(),
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 8),
            Text(
              'Stage ${widget.seed.state.index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Color> _getBloomColors() {
    switch (widget.seed.state) {
      case SeedState.bloomStage1:
        return [Colors.pink[200]!, Colors.pink[400]!];
      case SeedState.bloomStage2:
        return [Colors.purple[200]!, Colors.purple[400]!];
      case SeedState.bloomStage3:
        return [Colors.amber[200]!, Colors.amber[400]!];
      default:
        return [Colors.green[200]!, Colors.green[400]!];
    }
  }

  String _getBloomEmoji() {
    switch (widget.seed.mediaType) {
      case MediaType.photo:
        return ['🌸', '🌺', '🌻'][widget.seed.state.index % 3];
      case MediaType.voice:
        return ['🎵', '🎶', '🎼'][widget.seed.state.index % 3];
      case MediaType.text:
        return ['📝', '📖', '✨'][widget.seed.state.index % 3];
      case MediaType.link:
        return ['🔗', '🌐', '💫'][widget.seed.state.index % 3];
    }
  }

  Widget _buildMemoryContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getMediaTypeIcon(), color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                'Original Memory',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (widget.seed.textContent != null)
            Text(
              widget.seed.textContent!,
              style: const TextStyle(fontSize: 16),
            ),
          
          if (widget.seed.mediaType == MediaType.voice && widget.seed.mediaUrl != null)
            _buildAudioPlayer(),
          
          if (widget.seed.mediaType == MediaType.photo && widget.seed.mediaUrl != null)
            _buildImageViewer(),
          
          if (widget.seed.mediaType == MediaType.link && widget.seed.textContent != null)
            _buildLinkViewer(),
            
          const SizedBox(height: 8),
          Text(
            'Planted ${_formatDateTime(widget.seed.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMediaTypeIcon() {
    switch (widget.seed.mediaType) {
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

  Widget _buildAudioPlayer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _toggleAudioPlayback,
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            color: Colors.blue[700],
          ),
          const Expanded(
            child: Text('Voice recording'),
          ),
          const Icon(Icons.audiotrack, color: Colors.blue),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[200],
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text('Photo memory'),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkViewer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.seed.textContent!,
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionTimeline() {
    return Consumer(
      builder: (context, ref, child) {
        final interactionsAsync = ref.watch(seedInteractionsProvider(widget.seed.id));
        
        return interactionsAsync.when(
          data: (interactions) {
            if (interactions.isEmpty) {
              return const SizedBox.shrink();
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Journey to Bloom',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ...interactions.take(5).map((interaction) => _buildTimelineItem(interaction)),
                if (interactions.length > 5)
                  Text(
                    'and ${interactions.length - 5} more interactions...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildTimelineItem(WaterReply interaction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_getInteractionLabel(interaction.type)} • ${_formatDateTime(interaction.createdAt)}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _getInteractionLabel(InteractionType type) {
    switch (type) {
      case InteractionType.water:
        return 'Watered with love';
      case InteractionType.replyVoice:
        return 'Voice reply added';
      case InteractionType.replyText:
        return 'Text reply added';
      case InteractionType.reaction:
        return 'Reaction added';
    }
  }

  Widget _buildSecretHopeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber[50]!, Colors.amber[100]!],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Secret Hope Revealed',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (!_showSecretHope)
            ElevatedButton.icon(
              onPressed: () => setState(() => _showSecretHope = true),
              icon: const Icon(Icons.visibility),
              label: const Text('Reveal Secret Hope'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.white,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.seed.secretHope ?? 'No secret hope recorded',
                style: const TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _toggleAudioPlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // This would play the actual audio file from storage
        // For now, just toggle the state
        setState(() => _isPlaying = true);
        // Simulate playing for 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _isPlaying = false);
          }
        });
      }
    } catch (e) {
      // Handle audio playback errors
    }
  }
} 
