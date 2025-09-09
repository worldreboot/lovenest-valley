import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/memory_garden/seed.dart';
import '../../models/memory_garden/water_reply.dart';
import '../../providers/garden_providers.dart';

class NurturingSheet extends ConsumerStatefulWidget {
  final Seed seed;

  const NurturingSheet({
    super.key,
    required this.seed,
  });

  @override
  ConsumerState<NurturingSheet> createState() => _NurturingSheetState();
}

class _NurturingSheetState extends ConsumerState<NurturingSheet> {
  final _textController = TextEditingController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  File? _selectedFile;
  String? _recordingPath;
  bool _isRecording = false;
  bool _isNurturing = false;
  bool _showInteractions = false;

  @override
  void dispose() {
    _textController.dispose();
    _audioRecorder.dispose();
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
              _getSeedIcon(),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nurture Memory',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getSeedDescription(),
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
          
          // Show memory content preview
          _buildMemoryPreview(),
          const SizedBox(height: 20),
          
          // Show past interactions button
          _buildInteractionsButton(),
          const SizedBox(height: 20),
          
          // Show interactions if expanded
          if (_showInteractions) _buildInteractionsList(),
          
          // Nurturing actions
          if (!_showInteractions) _buildNurturingActions(),
        ],
      ),
    );
  }

  Widget _getSeedIcon() {
    switch (widget.seed.state) {
      case SeedState.sprout:
        return const Icon(Icons.eco, color: Colors.green, size: 24);
      case SeedState.wilted:
        return const Icon(Icons.eco, color: Colors.grey, size: 24);
      case SeedState.bloomStage1:
      case SeedState.bloomStage2:
      case SeedState.bloomStage3:
        return const Icon(Icons.local_florist, color: Colors.pink, size: 24);
      case SeedState.archived:
        return const Icon(Icons.archive, color: Colors.grey, size: 24);
    }
  }

  String _getSeedDescription() {
    switch (widget.seed.state) {
      case SeedState.sprout:
        return 'A young sprout waiting to bloom';
      case SeedState.wilted:
        return 'A wilted memory that needs care';
      case SeedState.bloomStage1:
        return 'A beautiful bloom - stage 1';
      case SeedState.bloomStage2:
        return 'A magnificent bloom - stage 2';
      case SeedState.bloomStage3:
        return 'A perfect bloom - stage 3';
      case SeedState.archived:
        return 'An archived memory';
    }
  }

  Widget _buildMemoryPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getMediaTypeIcon(), color: Colors.green),
              const SizedBox(width: 8),
              Text(
                _getMediaTypeLabel(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.seed.textContent != null)
            Text(
              widget.seed.textContent!,
              style: const TextStyle(fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          if (widget.seed.mediaUrl != null && widget.seed.mediaType == MediaType.photo)
            Container(
              height: 100,
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: const Center(
                child: Icon(Icons.image, size: 40, color: Colors.grey),
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

  String _getMediaTypeLabel() {
    switch (widget.seed.mediaType) {
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

  Widget _buildInteractionsButton() {
    return OutlinedButton.icon(
      onPressed: () {
        setState(() => _showInteractions = !_showInteractions);
      },
      icon: Icon(_showInteractions ? Icons.expand_less : Icons.expand_more),
      label: Text(_showInteractions ? 'Hide History' : 'View Interaction History'),
    );
  }

  Widget _buildInteractionsList() {
    return Consumer(
      builder: (context, ref, child) {
        final interactionsAsync = ref.watch(seedInteractionsProvider(widget.seed.id));
        
        return interactionsAsync.when(
          data: (interactions) {
            if (interactions.isEmpty) {
              return const Text(
                'No interactions yet. Be the first to water this memory!',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              );
            }
            
            return Column(
              children: [
                const Text(
                  'Interaction History',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...interactions.map((interaction) => _buildInteractionTile(interaction)),
                const SizedBox(height: 20),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Error loading interactions: $error'),
        );
      },
    );
  }

  Widget _buildInteractionTile(WaterReply interaction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(_getInteractionIcon(interaction.type), 
               color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getInteractionLabel(interaction.type),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (interaction.textContent != null)
                  Text(
                    interaction.textContent!,
                    style: const TextStyle(fontSize: 12),
                  ),
                Text(
                  _formatDateTime(interaction.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getInteractionIcon(InteractionType type) {
    switch (type) {
      case InteractionType.water:
        return Icons.water_drop;
      case InteractionType.replyVoice:
        return Icons.mic;
      case InteractionType.replyText:
        return Icons.message;
      case InteractionType.reaction:
        return Icons.favorite;
    }
  }

  String _getInteractionLabel(InteractionType type) {
    switch (type) {
      case InteractionType.water:
        return 'Watered';
      case InteractionType.replyVoice:
        return 'Voice Reply';
      case InteractionType.replyText:
        return 'Text Reply';
      case InteractionType.reaction:
        return 'Reaction';
    }
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

  Widget _buildNurturingActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Water button
        ElevatedButton.icon(
          onPressed: _isNurturing ? null : () => _handleWater(),
          icon: const Icon(Icons.water_drop),
          label: const Text('Water Memory'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        
        // Reply section
        const Text('Add a Reply', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        
        // Text reply
        TextField(
          controller: _textController,
          decoration: InputDecoration(
            hintText: 'Write a reply...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: _textController.text.trim().isEmpty || _isNurturing 
                  ? null 
                  : () => _handleReply(InteractionType.replyText),
              icon: const Icon(Icons.send),
            ),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 8),
        
        // Voice reply
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isNurturing 
                    ? null 
                    : (_isRecording ? _stopRecording : _startRecording),
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? 'Stop Recording' : 'Voice Reply'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecording ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (_recordingPath != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isNurturing 
                    ? null 
                    : () => _handleReply(InteractionType.replyVoice),
                icon: const Icon(Icons.send, color: Colors.green),
              ),
            ],
          ],
        ),
        
        if (_isNurturing)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Future<void> _handleWater() async {
    setState(() => _isNurturing = true);
    
    try {
      await ref.read(gardenRepositoryProvider).waterSprout(
        seedId: widget.seed.id,
        type: InteractionType.water,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Memory watered! ✨'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to water memory: $e');
    } finally {
      if (mounted) {
        setState(() => _isNurturing = false);
      }
    }
  }

  Future<void> _handleReply(InteractionType type) async {
    setState(() => _isNurturing = true);
    
    try {
      String? textContent;
      File? mediaFile;
      
      if (type == InteractionType.replyText) {
        textContent = _textController.text.trim();
        if (textContent.isEmpty) {
          _showError('Please enter a reply');
          return;
        }
      } else if (type == InteractionType.replyVoice) {
        if (_recordingPath == null) {
          _showError('Please record a voice message');
          return;
        }
        mediaFile = File(_recordingPath!);
      }
      
      await ref.read(gardenRepositoryProvider).waterSprout(
        seedId: widget.seed.id,
        type: type,
        mediaFile: mediaFile,
        textContent: textContent,
      );
      
      // Clear input
      _textController.clear();
      setState(() => _recordingPath = null);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply added! 💬'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to add reply: $e');
    } finally {
      if (mounted) {
        setState(() => _isNurturing = false);
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(const RecordConfig(), path: 'reply.m4a');
        setState(() => _isRecording = true);
      }
    } catch (e) {
      _showError('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        setState(() {
          _isRecording = false;
          _recordingPath = path;
        });
      }
    } catch (e) {
      _showError('Failed to stop recording: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
} 
