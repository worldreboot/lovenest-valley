import 'package:flutter/material.dart';
import 'package:lovenest/screens/menu_screen.dart';
import 'package:lovenest/screens/link_partner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onOnboardingComplete;
  
  const OnboardingScreen({
    super.key,
    this.onOnboardingComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Grow closer, one day at a time',
      description: 'Small daily moments—not grand gestures—build the strongest bonds. Lovenest turns 5 joyful minutes into a habit of connection.',
      icon: Icons.favorite,
      color: const Color(0xFF8B4513),
      backgroundColor: const Color(0xFFF4E4BC),
      micro: 'Private by design. Just you and your partner.',
    ),
    OnboardingPage(
      title: 'Prompts that deepen intimacy',
      description: 'Guided questions based on relationship science help you share, listen, and respond with warmth—habits shown to strengthen closeness.',
      icon: Icons.psychology,
      color: const Color(0xFF4169E1),
      backgroundColor: const Color(0xFFE6F3FF),
      micro: '5 minutes a day. Big difference.',
    ),
    OnboardingPage(
      title: 'Turn moments into lasting meaning',
      description: 'Plant “seeds” for meaningful moments and watch them bloom over time. Savoring and revisiting positives builds a stronger bond.',
      icon: Icons.eco,
      color: const Color(0xFF228B22),
      backgroundColor: const Color(0xFFE8F5E8),
    ),
    OnboardingPage(
      title: 'Feel seen, feel safe',
      description: 'Share how you feel; your farm’s weather mirrors your combined mood. Emotional attunement builds security and trust.',
      icon: Icons.wb_sunny,
      color: const Color(0xFFFFD700),
      backgroundColor: const Color(0xFFFFFACD),
      micro: 'You control what you share, always.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
    } catch (_) {}
    widget.onOnboardingComplete?.call();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MenuScreen(),
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  // Back navigation between pages can be added if needed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFB6C1), // Light pink
              Color(0xFFFFC0CB), // Pink
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              
              
                             // Page content
               Expanded(
                 child: PageView.builder(
                   controller: _pageController,
                   onPageChanged: (index) {
                     setState(() {
                       _currentPage = index;
                     });
                   },
                   itemCount: _pages.length,
                   itemBuilder: (context, index) {
                     final page = _pages[index];
                     return SingleChildScrollView(
                       padding: const EdgeInsets.all(24.0),
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         children: [
                           const SizedBox(height: 20),
                           
                           // Icon container with Stardew Valley style
                           Container(
                             width: 120,
                             height: 120,
                             decoration: BoxDecoration(
                               color: page.backgroundColor,
                               borderRadius: BorderRadius.circular(20),
                               border: Border.all(
                                 color: page.color,
                                 width: 4,
                               ),
                               boxShadow: [
                                 BoxShadow(
                                   color: page.color.withOpacity(0.3),
                                   blurRadius: 15,
                                   offset: const Offset(0, 5),
                                 ),
                               ],
                             ),
                             child: Icon(
                               page.icon,
                               size: 60,
                               color: page.color,
                             ),
                           ),
                           
                           const SizedBox(height: 30),
                           
                           // Title with rustic style
                           Container(
                             padding: const EdgeInsets.symmetric(
                               horizontal: 16,
                               vertical: 8,
                             ),
                             decoration: BoxDecoration(
                               color: Colors.white.withOpacity(0.9),
                               borderRadius: BorderRadius.circular(15),
                               border: Border.all(
                                 color: page.color,
                                 width: 2,
                               ),
                             ),
                             child: Text(
                               page.title,
                               style: TextStyle(
                                 color: page.color,
                                 fontSize: 22,
                                 fontWeight: FontWeight.bold,
                                 fontFamily: 'monospace',
                               ),
                               textAlign: TextAlign.center,
                             ),
                           ),
                           
                           const SizedBox(height: 20),
                           
                            // Description with rustic background
                           Container(
                             padding: const EdgeInsets.all(16),
                             decoration: BoxDecoration(
                               color: Colors.white.withOpacity(0.8),
                               borderRadius: BorderRadius.circular(15),
                               border: Border.all(
                                 color: page.color.withOpacity(0.5),
                                 width: 1,
                               ),
                             ),
                             child: Text(
                               page.description,
                               style: const TextStyle(
                                 color: Color(0xFF4A4A4A),
                                 fontSize: 16,
                                 height: 1.5,
                                 fontFamily: 'monospace',
                               ),
                               textAlign: TextAlign.center,
                             ),
                           ),
                            
                            const SizedBox(height: 12),

                            if (page.micro != null && page.micro!.isNotEmpty)
                              Text(
                                page.micro!,
                                style: TextStyle(
                                  color: page.color,
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                                textAlign: TextAlign.center,
                              ),

                            const SizedBox(height: 20),
                         ],
                       ),
                     );
                   },
                 ),
               ),
              
              
              
                             // Centered Next button
               Padding(
                 padding: const EdgeInsets.all(24.0),
                 child: Center(
                   child: Container(
                     decoration: BoxDecoration(
                       color: _pages[_currentPage].color,
                       borderRadius: BorderRadius.circular(25),
                       boxShadow: [
                         BoxShadow(
                           color: _pages[_currentPage].color.withOpacity(0.3),
                           blurRadius: 8,
                           offset: const Offset(0, 3),
                         ),
                       ],
                     ),
                     child: ElevatedButton(
                       onPressed: _nextPage,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.transparent,
                         shadowColor: Colors.transparent,
                         padding: const EdgeInsets.symmetric(
                           horizontal: 32,
                           vertical: 16,
                         ),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(25),
                         ),
                       ),
                       child: Text(
                         _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                         style: const TextStyle(
                           color: Colors.white,
                           fontSize: 18,
                           fontWeight: FontWeight.bold,
                           fontFamily: 'monospace',
                         ),
                       ),
                     ),
                   ),
                 ),
               ),

               if (_currentPage == 0)
                 Padding(
                   padding: const EdgeInsets.only(bottom: 24.0),
                   child: TextButton(
                     onPressed: () {
                       Navigator.of(context).push(
                         MaterialPageRoute(
                           builder: (_) => const LinkPartnerScreen(),
                         ),
                       );
                     },
                     child: const Text(
                       'I have an invite code',
                       style: TextStyle(
                         color: Colors.white,
                         fontFamily: 'monospace',
                       ),
                     ),
                   ),
                 ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String? micro;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    this.micro,
  });
} 