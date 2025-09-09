import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import '../../models/memory_garden/seed.dart';
import '../../providers/garden_providers.dart';

class PlantingSheet extends ConsumerStatefulWidget {
  final PlotPosition plotPosition;
  final VoidCallback? onPlant;
  final bool showVoiceAndLinkOptions;

  const PlantingSheet({
    super.key,
    required this.plotPosition,
    this.onPlant,
    this.showVoiceAndLinkOptions = true,
  });

  @override
  ConsumerState<PlantingSheet> createState() => _PlantingSheetState();
}

class _PlantingSheetState extends ConsumerState<PlantingSheet> {
  final _textController = TextEditingController();
  final _secretHopeController = TextEditingController();
  final _linkController = TextEditingController();
  
  MediaType _selectedMediaType = MediaType.text; // Default to text
  File? _selectedFile;
  String? _recordingPath;
  bool _isRecording = false;
  bool _isPlanting = false;
  String? _validationError;
  
  final AudioRecorder _audioRecorder = AudioRecorder();

  @override
  void dispose() {
    _textController.dispose();
    _secretHopeController.dispose();
    _linkController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8E7C9),
          border: Border.all(color: const Color(0xFF8B6F3A), width: 8),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Scrollable content
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // Title and close button row
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Color(0xFF8B6F3A), size: 28),
                      tooltip: 'Close',
                    ),
                  ),
                  Center(
                    child: Text(
                      'Plant a Memory',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade700,
                        letterSpacing: 2,
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
                  const SizedBox(height: 16),
                  if (_validationError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        _validationError!,
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Main content container (soft inner background)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E1B6),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.brown.shade200, width: 2),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Section: Memory Type
                        Text(
                          'Memory Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.brown.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildMediaTypeSelector(),
                        const SizedBox(height: 20),
                        // Section: Media Content
                        _buildMediaInput(),
                        const SizedBox(height: 20),
                        // Divider
                        Divider(color: Colors.brown.shade200, thickness: 1.2, height: 24),
                        // Section: Secret Hope
                        Text(
                          'Secret Hope',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.brown.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _secretHopeController,
                          decoration: InputDecoration(
                            hintText: 'A secret wish that will be revealed when your memory blooms...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.brown.shade200, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 30),
                        // Plant button
                        ElevatedButton(
                          onPressed: _isPlanting ? null : _handlePlant,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          child: _isPlanting
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Planting...'),
                                  ],
                                )
                              : const Text('Plant Memory'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTypeSelector() {
    return Row(
      children: [
        _buildMediaTypeChip(MediaType.photo, Icons.photo_camera, 'Photo'),
        const SizedBox(width: 8),
        if (widget.showVoiceAndLinkOptions) ...[
          _buildMediaTypeChip(MediaType.voice, Icons.mic, 'Voice'),
          const SizedBox(width: 8),
        ],
        _buildMediaTypeChip(MediaType.text, Icons.text_fields, 'Text'),
        if (widget.showVoiceAndLinkOptions) ...[
          const SizedBox(width: 8),
          _buildMediaTypeChip(MediaType.link, Icons.link, 'Link'),
        ],
      ],
    );
  }

  Widget _buildMediaTypeChip(MediaType type, IconData icon, String label) {
    final isSelected = _selectedMediaType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedMediaType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaInput() {
    switch (_selectedMediaType) {
      case MediaType.photo:
        return _buildPhotoInput();
      case MediaType.voice:
        return _buildVoiceInput();
      case MediaType.text:
        return _buildTextInput();
      case MediaType.link:
        return _buildLinkInput();
    }
  }

  Widget _buildPhotoInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedFile != null) ...[
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(_selectedFile!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Take Photo'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('From Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoiceInput() {
    return Column(
      children: [
        if (_recordingPath != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.audiotrack, color: Colors.green),
                const SizedBox(width: 8),
                const Expanded(child: Text('Voice recording ready')),
                IconButton(
                  onPressed: () => setState(() => _recordingPath = null),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        ElevatedButton.icon(
          onPressed: _isRecording ? _stopRecording : _startRecording,
          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
          label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRecording ? Colors.red : Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return TextField(
      controller: _textController,
      decoration: const InputDecoration(
        hintText: 'Write your memory...',
        border: OutlineInputBorder(),
      ),
      maxLines: 5,
    );
  }

  Widget _buildLinkInput() {
    return TextField(
      controller: _linkController,
      decoration: const InputDecoration(
        hintText: 'Paste a link to your memory...',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.link),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    
    if (pickedFile != null) {
      setState(() {
        _selectedFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(const RecordConfig(), path: 'recording.m4a');
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
          _selectedFile = File(path);
        });
      }
    } catch (e) {
      _showError('Failed to stop recording: $e');
    }
  }

  Future<void> _handlePlant() async {
    setState(() {
      _validationError = null;
    });
    // Validate memory input
    bool valid = false;
    switch (_selectedMediaType) {
      case MediaType.text:
        valid = _textController.text.trim().isNotEmpty;
        break;
      case MediaType.photo:
        valid = _selectedFile != null;
        break;
      case MediaType.voice:
        valid = _recordingPath != null;
        break;
      case MediaType.link:
        valid = _linkController.text.trim().isNotEmpty;
        break;
    }
    if (!valid) {
      setState(() {
        _validationError = 'Please enter a memory before planting.';
      });
      return;
    }
    setState(() {
      _isPlanting = true;
    });
    // Call the onPlant callback
    widget.onPlant?.call();
    setState(() {
      _isPlanting = false;
    });
    Navigator.of(context).pop();
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
