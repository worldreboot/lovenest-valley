import 'package:flutter/material.dart';
import 'package:lovenest/models/mood_weather_model.dart';
import 'package:lovenest/services/mood_weather_service.dart';

class DailyMoodPromptScreen extends StatefulWidget {
  final String coupleId;
  final VoidCallback? onMoodSubmitted;

  const DailyMoodPromptScreen({
    super.key,
    required this.coupleId,
    this.onMoodSubmitted,
  });

  @override
  State<DailyMoodPromptScreen> createState() => _DailyMoodPromptScreenState();
}

class _DailyMoodPromptScreenState extends State<DailyMoodPromptScreen>
    with TickerProviderStateMixin {
  MoodType? selectedMood;
  bool isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submitMood() async {
    if (selectedMood == null) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      await MoodWeatherService().submitMoodResponse(widget.coupleId, selectedMood!);
      
      if (mounted) {
        widget.onMoodSubmitted?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit mood: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.pink.shade100,
                          Colors.purple.shade100,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.pink.shade600,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Mood Check',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.pink.shade700,
                                ),
                              ),
                              Text(
                                'How are you feeling today?',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.pink.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Mood Options
                  Text(
                    'Choose your mood:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Mood Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: MoodType.values.length,
                    itemBuilder: (context, index) {
                      final mood = MoodType.values[index];
                      final isSelected = selectedMood == mood;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedMood = mood;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.pink.shade50 
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? Colors.pink.shade300 
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: Colors.pink.shade200.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 12),
                              Text(
                                MoodWeatherMapping.getMoodDisplayName(mood),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected 
                                      ? FontWeight.w600 
                                      : FontWeight.normal,
                                  color: isSelected 
                                      ? Colors.pink.shade700 
                                      : Colors.grey.shade700,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.pink.shade600,
                                  size: 20,
                                ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: selectedMood != null && !isSubmitting 
                          ? _submitMood 
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Submit Mood',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Info Text
                  Text(
                    'Your mood will affect the weather in your farm!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 