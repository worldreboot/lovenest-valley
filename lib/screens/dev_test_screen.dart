import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_generation_service.dart';
import '../services/avatar_generation_service.dart';
import '../services/farm_tile_service.dart';
import '../services/daily_question_seed_service.dart';
import '../config/supabase_config.dart';
import '../services/farm_service.dart'; // Added import for FarmService
import '../game/simple_enhanced_farm_game.dart'; // Added import for SimpleEnhancedFarmGame

class DevTestScreen extends StatefulWidget {
  const DevTestScreen({Key? key}) : super(key: key);

  @override
  State<DevTestScreen> createState() => _DevTestScreenState();
}

class _DevTestScreenState extends State<DevTestScreen> {
  final ImageGenerationService _imageService = ImageGenerationService();
  final AvatarGenerationService _avatarService = AvatarGenerationService();
  final FarmTileService _farmTileService = FarmTileService();
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _testTextToImage() async {
    setState(() => _isLoading = true);
    try {
      await _imageService.generate(
        presetName: 'GAME_ITEM_SPRITE_V1', // Use your preset name
        userDescription: 'A magic shield with a roaring lion face',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text-to-Image job started!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error:  {e.toString()}'), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _testImageToImage() async {
    // 1. Let the user pick an image from their gallery
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image == null) {
      // User cancelled the picker
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _imageService.generate(
        presetName: 'AVATAR_V1', // Use your preset name
        sourceImage: image,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image-to-Image job started!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error:  {e.toString()}'), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _testAvatarGeneration() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Check if preset exists
      final presetExists = await _avatarService.checkPresetExists();
      if (!presetExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar preset not found'), backgroundColor: Colors.red),
        );
        return;
      }

      final result = await _avatarService.generateUserAvatar(
        userId: userId,
        userPrompt: 'A cute anime girl with pink hair and a friendly smile',
        stylePreferences: {
          'style': 'casual',
          'colors': 'warm',
          'clothing': 'casual',
        },
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avatar generation started! Job ID: ${result['job_id']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _testAvatarPolling() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _avatarService.pollJobCompletion(userId);
      
      if (result['success']) {
        if (result['status'] == 'completed') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Avatar completed! URL: ${result['spritesheet_url']}'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (result['status'] == 'processing') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar still processing...'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _testSpriteGeneration() async {
    setState(() => _isLoading = true);
    try {
      // Get the current user's farm ID
      final farmId = await FarmService.getCurrentUserFarmId();
      if (farmId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No farm found for current user'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Test immediate sprite generation
      await _farmTileService.testImmediateSpriteGeneration(
        farmId, // Use real farm ID
        5, 5, // Test position
        'daily_question_seed',
        {
          'question_text': 'What is your favorite food?',
          'answer': 'Pizza',
        },
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sprite generation test started!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _testDailyQuestionPlanting() async {
    setState(() => _isLoading = true);
    try {
      // Get the current user's farm ID
      final farmId = await FarmService.getCurrentUserFarmId();
      if (farmId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No farm found for current user'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Test planting a daily question seed (which now generates sprite immediately)
      final result = await DailyQuestionSeedService.plantDailyQuestionSeed(
        questionId: '24e95ed5-aef3-45e1-858a-6d3173007ad1', // Use real question ID
        answer: 'Blue',
        plotX: 6,
        plotY: 6,
        farmId: farmId, // Use real farm ID
      );
      
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily question seed planted with immediate sprite generation!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to plant daily question seed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _testComprehensiveSpriteTests() async {
    setState(() => _isLoading = true);
    try {
      // Get the current user's farm ID
      final farmId = await FarmService.getCurrentUserFarmId();
      if (farmId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No farm found for current user'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Run comprehensive sprite generation tests
      await _farmTileService.runSpriteGenerationTests(farmId); // Use real farm ID
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comprehensive sprite generation tests completed!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _isLoading = false);
  }

  /// Debug method to check sprite display conditions
  Future<void> _debugSpriteConditions() async {
    setState(() => _isLoading = true);
    try {
      // Get the current user's farm ID
      final farmId = await FarmService.getCurrentUserFarmId();
      if (farmId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No farm found for current user'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

             // Check for fully grown seeds
       final userId = SupabaseConfig.currentUserId;
       if (userId == null) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('❌ User not authenticated'),
             backgroundColor: Colors.red,
           ),
         );
         return;
       }
       
       final fullyGrownSeeds = await SupabaseConfig.client
           .from('farm_seeds')
           .select('*')
           .eq('farm_id', farmId)
           .eq('user_id', userId)
           .eq('growth_stage', 'fully_grown');

      debugPrint('[Debug] 🔍 Found ${fullyGrownSeeds.length} fully grown seeds');

      for (final seed in fullyGrownSeeds) {
        final x = seed['x'] as int;
        final y = seed['y'] as int;
        final plantType = seed['plant_type'] as String;
        
        debugPrint('[Debug] 🌱 Checking seed at ($x, $y) - Type: $plantType');
        
        // Check 1: Seed exists in seeds table
        final seedRecord = await SupabaseConfig.client
            .from('seeds')
            .select('bloom_variant_seed, state')
            .eq('plot_x', x.toDouble())
            .eq('plot_y', y.toDouble())
            .maybeSingle();
        
        debugPrint('[Debug] 📊 Seeds table record: ${seedRecord != null ? 'EXISTS' : 'MISSING'}');
        if (seedRecord != null) {
          debugPrint('[Debug] 📊 bloom_variant_seed: ${seedRecord['bloom_variant_seed'] ?? 'null'}');
          debugPrint('[Debug] 📊 state: ${seedRecord['state'] ?? 'null'}');
        }
        
        // Check 2: Generation job exists and is completed
        if (seedRecord != null && seedRecord['bloom_variant_seed'] != null) {
          final jobId = seedRecord['bloom_variant_seed'] as String;
          final jobResponse = await SupabaseConfig.client
              .from('generation_jobs')
              .select('status, final_image_url, error_message')
              .eq('id', jobId)
              .maybeSingle();
          
          debugPrint('[Debug] 🎨 Generation job: ${jobResponse != null ? 'EXISTS' : 'MISSING'}');
          if (jobResponse != null) {
                      debugPrint('[Debug] 🎨 Job status: ${jobResponse['status'] ?? 'null'}');
          debugPrint('[Debug] 🎨 Final image URL: ${jobResponse['final_image_url'] ?? 'null'}');
          debugPrint('[Debug] 🎨 Error message: ${jobResponse['error_message'] ?? 'null'}');
          }
        }
        
        // Check 3: Try to get sprite URL
        final spriteUrl = await DailyQuestionSeedService.getSpriteUrl(x, y);
        debugPrint('[Debug] 🖼️ Sprite URL: ${spriteUrl ?? 'NULL'}');
        
        debugPrint('[Debug] ---');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debug completed! Check console for details.'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Debug error: $e'), backgroundColor: Colors.red),
      );
    }
           setState(() => _isLoading = false);
     }
 
   /// Force reload generated sprites for existing components
   Future<void> _forceReloadGeneratedSprites() async {
     setState(() => _isLoading = true);
     try {
       // Get the current user's farm ID
       final farmId = await FarmService.getCurrentUserFarmId();
       if (farmId == null) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('❌ No farm found for current user'),
             backgroundColor: Colors.red,
           ),
         );
         return;
       }
 
       // Find all fully grown seeds and force sprite reload
                final userId = SupabaseConfig.currentUserId;
         if (userId == null) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('❌ User not authenticated'),
               backgroundColor: Colors.red,
             ),
           );
           return;
         }
         
         final fullyGrownSeeds = await SupabaseConfig.client
             .from('farm_seeds')
             .select('*')
             .eq('farm_id', farmId)
             .eq('user_id', userId)
             .eq('growth_stage', 'fully_grown');
 
       debugPrint('[Debug] 🔄 Force reloading sprites for ${fullyGrownSeeds.length} fully grown seeds');
 
                debugPrint('[Debug] 🔄 Found ${fullyGrownSeeds.length} fully grown seeds to reload');
         for (final seed in fullyGrownSeeds) {
           final x = seed['x'] as int;
           final y = seed['y'] as int;
           debugPrint('[Debug] 🔄 Seed at ($x, $y) needs sprite reload');
           
           // Try to directly call the sprite loading method
           try {
             final farmTileService = FarmTileService();
             final spriteUrl = await farmTileService.getSeedSpriteUrl(farmId, x, y);
             debugPrint('[Debug] 🖼️ Direct sprite URL check: ${spriteUrl ?? 'NULL'}');
             
             if (spriteUrl != null) {
               debugPrint('[Debug] ✅ Sprite URL is available: $spriteUrl');
             } else {
               debugPrint('[Debug] ❌ No sprite URL found');
             }
           } catch (e) {
                          debugPrint('[Debug] ❌ Error checking sprite URL: $e');
           }
         }
 
         // Try to force refresh the game components
         debugPrint('[Debug] 🔄 Attempting to force refresh game components...');
         try {
           // Navigate back to the game screen
           Navigator.of(context).pop();
           
           // Wait a moment for navigation to complete
           await Future.delayed(const Duration(milliseconds: 500));
           
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('Force reload completed! Check the game screen for updated sprites.'),
               backgroundColor: Colors.green,
             ),
           );
         } catch (e) {
           debugPrint('[Debug] ❌ Error navigating back to game: $e');
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Force reload completed but navigation failed: $e'), backgroundColor: Colors.orange),
           );
         }
     } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Force reload error: $e'), backgroundColor: Colors.red),
       );
     }
     setState(() => _isLoading = false);
   }
 
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edge Function Test')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _testTextToImage,
                    child: const Text('Test: Generate Item (Text)'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _testImageToImage,
                    child: const Text('Test: Stylize Avatar (Image)'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _testAvatarGeneration,
                    child: const Text('Test: Generate Avatar (Text)'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _testAvatarPolling,
                    child: const Text('Test: Poll Avatar Status'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _testSpriteGeneration,
                    child: const Text('🧪 Test: Immediate Sprite Generation'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _testDailyQuestionPlanting,
                    child: const Text('🌱 Test: Plant Daily Question (Immediate Sprite)'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _testComprehensiveSpriteTests,
                    child: const Text('🎨 Test: Comprehensive Sprite Tests'),
                  ),
                  const SizedBox(height: 20),
                                     ElevatedButton(
                     onPressed: _debugSpriteConditions,
                     child: const Text('🐛 Debug Sprite Conditions'),
                   ),
                   const SizedBox(height: 20),
                   ElevatedButton(
                     onPressed: _forceReloadGeneratedSprites,
                     child: const Text('🔄 Force Reload Generated Sprites'),
                   ),
                ],
              ),
      ),
    );
  }
} 
