import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/supabase_config.dart';
import '../services/seashell_service.dart';

class AudioRecordDialog extends StatefulWidget {
  final void Function(String audioUrl)? onUploadComplete;

  const AudioRecordDialog({Key? key, this.onUploadComplete}) : super(key: key);

  @override
  State<AudioRecordDialog> createState() => _AudioRecordDialogState();
}

class _AudioRecordDialogState extends State<AudioRecordDialog> {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _filePath;
  bool _isUploading = false;
  bool _isPlaying = false;
  AudioPlayer? _audioPlayer;

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required to record.')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/seashell_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    setState(() {
      _isRecording = true;
      _filePath = path;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _filePath = path;
    });
  }

  Future<void> _playRecording() async {
    if (_filePath == null) return;
    _audioPlayer ??= AudioPlayer();
    await _audioPlayer!.play(DeviceFileSource(_filePath!));
    setState(() {
      _isPlaying = true;
    });
    _audioPlayer!.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
      });
    });
  }

  Future<void> _uploadRecording() async {
    if (_filePath == null) return;
    setState(() {
      _isUploading = true;
    });
    
    try {
      final file = File(_filePath!);
      final fileName = 'seashells/${DateTime.now().millisecondsSinceEpoch}.m4a';
      final supabase = Supabase.instance.client;
      
      // Upload the file (throws on error)
      await supabase.storage.from('seashell-audio').upload(fileName, file);
      
      // Get the public URL (upload throws on error)
      final publicUrl = supabase.storage.from('seashell-audio').getPublicUrl(fileName);
      
      // Call the callback with the URL
      if (widget.onUploadComplete != null) {
        widget.onUploadComplete!(publicUrl);
      }
      
      // Insert seashell data into database
      try {
          final userId = SupabaseConfig.currentUserId;
          
          if (userId != null) {
            // Fetch the actual couple ID for the current user
            final coupleResponse = await supabase
                .from('couples')
                .select('id')
                .or('user1_id.eq.$userId,user2_id.eq.$userId')
                .single();
            
            final coupleId = coupleResponse['id'];
            
            // Generate a random position on the beach (x >= 16, avoiding water)
            final beachPositions = SeashellService.getValidBeachPositions();
            if (beachPositions.isNotEmpty) {
              final random = Random();
              final position = beachPositions[random.nextInt(beachPositions.length)];
              final x = position.x;
              final y = position.y;
            
              final seashellData = {
                'couple_id': coupleId,
                'user_id': userId,
                'audio_url': publicUrl,
                'position': '($x, $y)', // PostgreSQL POINT format
              };
            
              final response = await supabase
                  .from('seashells')
                  .insert(seashellData)
                  .select()
                  .single();
                  
              print('Seashell created: ${response['id']} at position ($x, $y)');
              // Note: heard receipts are per-listener; the creator doesn't need a heard row
            } else {
              // Fallback to random position if no beach positions available
              final random = Random();
              final x = random.nextDouble() * 3 + 16; // Between 16-19 tiles (beach area)
              final y = random.nextDouble() * 10 + 2; // Between 2-12 tiles
              
              final seashellData = {
                'couple_id': coupleId,
                'user_id': userId,
                'audio_url': publicUrl,
                'position': '($x, $y)', // PostgreSQL POINT format
              };
              
              final response = await supabase
                  .from('seashells')
                  .insert(seashellData)
                  .select()
                  .single();
                  
              print('Seashell created: ${response['id']} at fallback position ($x, $y)');
            }
          }
      } catch (e) {
        print('Error creating seashell: $e');
        // Don't fail the upload if seashell creation fails
        // For now, we'll still spawn the seashell in the game even if DB insert fails
      }
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio uploaded successfully!')),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      print('Upload error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Audio Message'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording)
            const Text('Recording... Tap stop when done.')
          else if (_filePath != null)
            const Text('Recording complete. You can play or upload.'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isRecording ? _stopRecording : _startRecording,
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                label: Text(_isRecording ? 'Stop' : 'Record'),
              ),
              const SizedBox(width: 12),
              if (_filePath != null)
                ElevatedButton.icon(
                  onPressed: _isPlaying ? null : _playRecording,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
            ],
          ),
        ],
      ),
      actions: [
        if (_filePath != null)
          ElevatedButton(
            onPressed: _isUploading ? null : _uploadRecording,
            child: _isUploading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Upload'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
} 