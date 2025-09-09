import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:lovenest_valley/game/simple_enhanced_farm_game.dart';
import '../models/inventory.dart';
import '../components/ui/inventory_bar.dart';
import 'package:lovenest_valley/game/farmhouse_interior_game.dart';
import 'package:lovenest_valley/screens/memory_garden/daily_question_letter_sheet.dart';
import 'package:lovenest_valley/models/memory_garden/question.dart';
import 'package:lovenest_valley/models/memory_garden/seed.dart';
import 'package:lovenest_valley/services/question_service.dart';
import 'package:lovenest_valley/services/farm_tile_service.dart';
import 'package:lovenest_valley/services/daily_question_seed_collection_service.dart';
import 'package:lovenest_valley/services/garden_repository.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:lovenest_valley/services/mood_weather_service.dart';
import 'package:lovenest_valley/models/mood_weather_model.dart';
import 'package:lovenest_valley/services/auth_service.dart';

import 'package:lovenest_valley/screens/daily_mood_prompt_screen.dart';
import 'package:lovenest_valley/screens/shop_screen.dart';
import 'package:lovenest_valley/screens/stardew_dialogue_box.dart';
import 'package:lovenest_valley/screens/link_partner_screen.dart';
import 'package:lovenest_valley/screens/audio_record_dialog.dart';
import 'package:lovenest_valley/screens/onboarding_screen.dart';
import 'package:lovenest_valley/components/ui/chest_storage_ui.dart';
import 'package:lovenest_valley/services/pending_gift_service.dart';
import 'package:lovenest_valley/screens/widgets/gifts_inbox_dialog.dart';
import '../models/chest_storage.dart';
import '../utils/seed_color_generator.dart';
import 'package:lovenest_valley/widgets/coin_indicator.dart';
import 'package:lovenest_valley/services/inventory_service.dart';
import 'package:lovenest_valley/services/daily_question_seed_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lovenest_valley/screens/feature_tour_overlay.dart';
import 'package:lovenest_valley/screens/memory_garden/planting_sheet.dart';
import 'package:lovenest_valley/models/relationship_goal.dart';
import 'package:lovenest_valley/screens/relationship_goals_dialog.dart';
import 'package:lovenest_valley/services/relationship_goal_service.dart';
import 'package:lovenest_valley/components/ui/seed_sprite_preview.dart';


class GameScreen extends StatefulWidget {
  final String farmId;
  const GameScreen({super.key, required this.farmId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // DEBUG: Render a minimal, harmless UI instead of the Flame game to isolate black screen issues
  static const bool kDebugMinimalUI = false;
  // DEBUG: Replace planting prompt to submit answer only (no visuals/inventory/world changes)
  static const bool kSubmitOnlyNoVisuals = true;
  late final InventoryManager inventoryManager;
  // Switch to SimpleEnhancedFarmGame for unified terrain system
  late final SimpleEnhancedFarmGame _farmGameInstance;
  late final FarmhouseInteriorGame _interiorGameInstance;
  bool _inInterior = false;
  // Feature tour
  bool _showFeatureTour = false;
  int _tourIndex = 0;

  // Store pending daily question answer info
  Map<String, dynamic>? _pendingDailyQuestionAnswer;

  // Couple state
  bool _checkingCouple = true;
  bool _hasCouple = true;
  
  // Mood and weather state
  WeatherCondition? _currentWeather;
  String? _coupleId;
  final MoodWeatherService _moodWeatherService = MoodWeatherService();
  
  // Rain effect state - disabled for now
  double _rainIntensity = 0.0; // Rain disabled

  @override
  void initState() {
    super.initState();
    inventoryManager = InventoryManager();
    
    _farmGameInstance = SimpleEnhancedFarmGame(
      farmId: widget.farmId,
      inventoryManager: inventoryManager,
      // Owl only assigns and lets you collect the seed now; answering happens at planting
      onOwlTapped: _handleOwlTap,
      onExamine: _handleExamine,
      onPlantSeed: (gridX, gridY, selectedItem) {
        _handlePlant(gridX, gridY);
      },
    );

    _interiorGameInstance = FarmhouseInteriorGame(
      onExitHouse: () {
        setState(() {
          _inInterior = false;
        });
        // Place player near farmhouse door (approximate coordinates for SimpleEnhanced map)
        const int doorX = 19;
        const int doorY = 5;
        _farmGameInstance.player.position = Vector2(
          (doorX * SimpleEnhancedFarmGame.tileSize) + (SimpleEnhancedFarmGame.tileSize / 2),
          ((doorY + 1) * SimpleEnhancedFarmGame.tileSize) + (SimpleEnhancedFarmGame.tileSize / 2),
        );
      },
      onItemUsed: (String itemId) {
        if (itemId == 'wood') {
          final woodItem = inventoryManager.slots.firstWhere(
            (item) => item?.id == 'wood',
            orElse: () => null,
          );
          if (woodItem != null && woodItem.quantity > 0) {
            inventoryManager.removeItem(inventoryManager.slots.indexOf(woodItem));
          }
        }
      },
    );

    // Initialize inventory from backend (FIXED: was missing this call)
    _initializeInventory();
    
    // Game now handles starter items for new users
    _checkForUnplantedDailyQuestionSeed();
    _checkAndPromptCouple();
    _initializeMoodWeatherSystem();
    _checkPendingGiftDeliveries();
    _maybeStartFeatureTour();
    _checkAndPromptName();
  }

  /// Initialize inventory from backend (FIXED: was missing this method)
  Future<void> _initializeInventory() async {
    debugPrint('[GameScreen] 🔄 Initializing inventory from backend');
    await inventoryManager.initialize();
    debugPrint('[GameScreen] 📊 Inventory after backend load: ${inventoryManager.slots.map((item) => item?.name ?? 'null').toList()}');
  }

  Future<void> _maybeStartFeatureTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('has_seen_feature_tour') ?? false;
      if (!seen) {
        setState(() {
          _showFeatureTour = true;
          _tourIndex = 0;
        });
      }
    } catch (_) {}
  }

  // Starter items are now handled by the game's _ensureStarterChest() method

  Future<void> _checkForUnplantedDailyQuestionSeed() async {
    final answer = await QuestionService.getUnplantedDailyQuestionAnswer();
    if (answer != null) {
      // Add seed to inventory if not already present
      final hasSeed = inventoryManager.slots.any((item) => item?.id == 'daily_question_seed');
      if (!hasSeed) {
        inventoryManager.addItem(
          InventoryItem(
            id: 'daily_question_seed',
            name: 'Daily Question Seed',
            quantity: 1,
          ),
        );
      }
      setState(() {
        _pendingDailyQuestionAnswer = answer;
      });
    }
  }

  Future<void> _checkAndPromptCouple() async {
    final couple = await GardenRepository().getUserCouple();
    if (couple == null) {
      setState(() {
        _hasCouple = false;
        _checkingCouple = false;
      });
      await Future.delayed(Duration.zero);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LinkPartnerScreen()),
      );
      // Re-evaluate couple status on return
      final after = await GardenRepository().getUserCouple();
      if (mounted) {
        setState(() {
          _hasCouple = after != null;
        });
      }
    } else {
      setState(() {
        _hasCouple = true;
        _checkingCouple = false;
      });
    }
  }

  Future<void> _checkAndPromptName() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return;
    
    final client = SupabaseConfig.client;
    final profile = await client
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle();
    String? name = profile != null ? profile['username'] as String? : null;
    
    if (name == null || name.trim().isEmpty) {
      // Delay the prompt to let the game load first
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      
      final newName = await _showNameDialog();
      if (newName != null && newName.trim().isNotEmpty) {
        await client.from('profiles').upsert({
          'id': userId,
          'username': newName.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  Future<String?> _showNameDialog() async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('What is your name?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Welcome to Lovenest Valley!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tell us your name to personalize your experience:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your name',
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (controller.text.trim().length >= 2) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  /* Legacy invite UI (replaced by LinkPartnerScreen). Keeping code commented for reference.
  Future<void> _promptInvitePartner() async {
    String? partnerUsername;
    String? errorText;
    bool searching = false;
    bool inviting = false;
    bool closed = false;
    List<Map<String, dynamic>> searchResults = [];
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Invite Your Partner'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Search for your partner by username to invite them!'),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Partner Username',
                      errorText: errorText,
                    ),
                    onChanged: (value) async {
                      setState(() {
                        partnerUsername = value;
                        errorText = null;
                        searching = true;
                        searchResults = [];
                      });
                      if (value.trim().length >= 3) {
                        final client = SupabaseConfig.client;
                        final results = await client
                            .from('profiles')
                            .select('id, username')
                            .ilike('username', '%${value.trim()}%')
                            .limit(10);
                        setState(() {
                          searchResults = List<Map<String, dynamic>>.from(results);
                          searching = false;
                        });
                      } else {
                        setState(() {
                          searchResults = [];
                          searching = false;
                        });
                      }
                    },
                  ),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: CircularProgressIndicator(),
                    ),
                  if (!searching && searchResults.isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: ListView.builder(
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final user = searchResults[index];
                          return ListTile(
                            title: Text(user['username'] ?? ''),
                            trailing: Icon(Icons.person_add_alt_1, color: Colors.pinkAccent),
                            onTap: inviting
                                ? null
                                : () async {
                                    setState(() {
                                      inviting = true;
                                    });
                                    try {
                                      await GardenRepository().sendCoupleInvite(
                                        partnerUserId: user['id'] as String,
                                        partnerUsername: user['username'] as String,
                                      );
                                      setState(() {
                                        errorText = 'Invite sent!';
                                      });
                                      await Future.delayed(const Duration(seconds: 1));
                                      Navigator.of(context).pop();
                                    } catch (e) {
                                      setState(() {
                                        errorText = 'Failed to send invite: $e';
                                      });
                                    } finally {
                                      setState(() {
                                        inviting = false;
                                      });
                                    }
                                  },
                          );
                        },
                      ),
                    ),
                  if (!searching && partnerUsername != null && partnerUsername!.trim().length >= 3 && searchResults.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('No users found with that username.'),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    closed = true;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: (searching || inviting)
                      ? null
                      : () async {
                          if (partnerUsername == null || partnerUsername!.length < 3) {
                            setState(() {
                              errorText = 'Enter at least 3 characters.';
                            });
                            return;
                          }
                          setState(() {
                            searching = true;
                            errorText = null;
                          });
                          final client = SupabaseConfig.client;
                          final results = await client
                              .from('profiles')
                              .select('id, username')
                              .eq('username', partnerUsername!.trim())
                              .limit(1);
                          setState(() {
                            searching = false;
                          });
                          if (results.isEmpty) {
                            setState(() {
                              errorText = 'No user found with that username.';
                            });
                            return;
                          }
                          final partnerProfile = results.first;
                          setState(() {
                            inviting = true;
                          });
                          try {
                            await GardenRepository().sendCoupleInvite(
                              partnerUserId: partnerProfile['id'] as String,
                              partnerUsername: partnerProfile['username'] as String,
                            );
                            setState(() {
                              errorText = 'Invite sent!';
                            });
                            await Future.delayed(const Duration(seconds: 1));
                            Navigator.of(context).pop();
                          } catch (e) {
                            setState(() {
                              errorText = 'Failed to send invite: $e';
                            });
                          } finally {
                            setState(() {
                              inviting = false;
                            });
                          }
                        },
                  child: const Text('Invite'),
                ),
              ],
            );
          },
        );
      },
    );
    setState(() {
      _checkingCouple = false;
      if (closed) {
        _hasCouple = false;
      }
    });
  }
  */

  Future<void> _initializeMoodWeatherSystem() async {
    if (!_hasCouple) return;
    
    try {
      // Get couple ID
      final couple = await GardenRepository().getUserCouple();
      if (couple != null) {
        _coupleId = couple.id;
        
        // Check if user has responded to today's mood prompt
        final userId = SupabaseConfig.currentUserId;
        if (userId != null && _coupleId != null) {
          final hasResponded = await _moodWeatherService.hasUserRespondedToday(userId, _coupleId!);
          
          if (!hasResponded) {
            // Show mood prompt after a short delay
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) {
              _showMoodPrompt();
            }
          }
        }
        
        // Load current weather
        if (_coupleId != null) {
          final weather = await _moodWeatherService.getTodayWeather(_coupleId!);
          if (mounted) {
            setState(() {
              _currentWeather = weather;
            });
          }
        }
      }
    } catch (e) {
      print('[GameScreen] Error initializing mood weather system: $e');
    }
  }

  void _showMoodPrompt() {
    if (_coupleId == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DailyMoodPromptScreen(
        coupleId: _coupleId!,
        onMoodSubmitted: () {
          // Refresh weather after mood submission
          _refreshWeather();
        },
      ),
    );
  }

  Future<void> _checkPendingGiftDeliveries() async {
    // Runs at init; UI snackbar will display when delivery occurs
    try {
      // We cannot show a snackbar here yet because context may not be laid out; do in build microtask
      await Future.delayed(const Duration(milliseconds: 10));
    } catch (_) {}
  }

  Future<void> _refreshWeather() async {
    if (_coupleId == null) return;
    
    try {
      final weather = await _moodWeatherService.getTodayWeather(_coupleId!);
      if (mounted) {
        setState(() {
          _currentWeather = weather;
        });
      }
    } catch (e) {
      print('[GameScreen] Error refreshing weather: $e');
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ListTile(
              leading: const Icon(Icons.school),
              title: const Text('Onboarding'),
              subtitle: const Text('Learn about the game'),
              onTap: () {
                Navigator.of(context).pop();
                _showOnboarding();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tour),
              title: const Text('Feature Tour'),
              subtitle: const Text('Highlights: Questions, Blooms, Seashells, Bonfire'),
              onTap: () async {
                Navigator.of(context).pop();
                setState(() {
                  _tourIndex = 0;
                  _showFeatureTour = true;
                });
              },
            ),

            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Set Name'),
              subtitle: const Text('Change your display name'),
              onTap: () async {
                Navigator.of(context).pop();
                final newName = await _showNameDialog();
                if (newName != null && newName.trim().isNotEmpty) {
                  final userId = SupabaseConfig.currentUserId;
                  if (userId != null) {
                    final client = SupabaseConfig.client;
                    await client.from('profiles').upsert({
                      'id': userId,
                      'username': newName.trim(),
                      'updated_at': DateTime.now().toIso8601String(),
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Name updated to: ${newName.trim()}')),
                    );
                  }
                }
              },
            ),
            // Partner information section
            if (_hasCouple) ...[
              FutureBuilder<Map<String, dynamic>?>(
                future: GardenRepository().getPartnerProfile(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      leading: Icon(Icons.favorite, color: Colors.pink),
                      title: Text('Partner'),
                      subtitle: Text('Loading...'),
                    );
                  }
                  
                  final partnerProfile = snapshot.data;
                  if (partnerProfile != null) {
                    final partnerName = partnerProfile['username'] as String? ?? 'Unknown';
                    final partnerAvatar = partnerProfile['avatar_url'] as String?;
                    final partnerCreatedAt = partnerProfile['created_at'] as String?;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.pink.shade100,
                        child: partnerAvatar != null
                            ? ClipOval(
                                child: Image.network(
                                  partnerAvatar,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.favorite, color: Colors.pink),
                                ),
                              )
                            : const Icon(Icons.favorite, color: Colors.pink),
                      ),
                      title: Text('Partner: $partnerName'),
                      subtitle: partnerCreatedAt != null
                          ? Text('Connected since ${_formatDate(partnerCreatedAt)}')
                          : const Text('Connected'),
                      onTap: () {
                        // Could show more partner details here
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Partner: $partnerName'),
                            backgroundColor: Colors.pink.shade100,
                          ),
                        );
                      },
                    );
                  } else {
                    return const ListTile(
                      leading: Icon(Icons.favorite, color: Colors.pink),
                      title: Text('Partner'),
                      subtitle: Text('Unable to load partner info'),
                    );
                  }
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () {
                Navigator.of(context).pop();
                _showAboutDialog();
              },
            ),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _showLogoutConfirmation();
              },
            ),
          ],
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Format date string for display
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks week${weeks == 1 ? '' : 's'} ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Lovenest Valley'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text('A cozy farming game for couples to grow memories together.'),
            SizedBox(height: 8),
            Text('Build memories, plant seeds of love, and watch your relationship bloom!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out? You will be returned to the sign-in screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await AuthService.signOut();
                if (mounted) {
                  Navigator.of(context).pop(); // Close confirmation dialog
                  // Navigate back to auth flow
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context).pop(); // Close confirmation dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
  


  void _showOnboarding() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const OnboardingScreen(),
      ),
    );
  }

  /* Legacy farm_invites flow (replaced by couple_invites + RPCs)
  Future<void> _checkForPendingInvites() async {
    final userId = SupabaseConfig.currentUserId;
    if (userId == null) return;
    final client = SupabaseConfig.client;
    // Get current user's username
    final profile = await client
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle();
    final username = profile != null ? profile['username'] as String? : null;
    if (username == null || username.trim().isEmpty) return;
    // Check for pending invites
    final invite = await client
        .from('farm_invites')
        .select()
        .eq('invitee_username', username)
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (invite != null) {
      _showInviteDialog(invite, username);
    }
  }
  */
  Future<void> _showInviteDialog(Map<String, dynamic> invite, String username) async {
    final client = SupabaseConfig.client;
    final inviterId = invite['inviter_id'] as String?;
    String inviterName = 'Your Partner';
    if (inviterId != null) {
      final inviterProfile = await client
          .from('profiles')
          .select('username')
          .eq('id', inviterId)
          .maybeSingle();
      if (inviterProfile != null && inviterProfile['username'] != null) {
        inviterName = inviterProfile['username'] as String;
      }
    }
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Couple Invite'),
          content: Text('$inviterName has invited you to be their partner!'),
          actions: [
            TextButton(
              onPressed: () async {
                // Decline: update invite status
                await client
                    .from('farm_invites')
                    .update({'status': 'declined', 'responded_at': DateTime.now().toIso8601String()})
                    .eq('id', invite['id']);
                Navigator.of(context).pop();
              },
              child: const Text('Decline'),
            ),
            TextButton(
              onPressed: () async {
                // Accept: use acceptCoupleInvite
                if (inviterId == null) {
                  Navigator.of(context).pop();
                  return;
                }
                
                try {
                  // Accept the couple invite (this will also connect to partner's farm)
                  final couple = await GardenRepository().acceptCoupleInvite(
                    inviterId: inviterId,
                    inviteId: invite['id'] as String,
                  );
                  
                  debugPrint('[GameScreen] Couple created successfully: ${couple.id}');
                  
                  // Get the inviter's farm ID (the farm we should connect to)
                  final inviterFarm = await client
                      .from('farms')
                      .select('id')
                      .eq('owner_id', inviterId)
                      .maybeSingle();
                  
                  if (inviterFarm != null) {
                    final inviterFarmId = inviterFarm['id'] as String;
                    debugPrint('[GameScreen] Redirecting to partner farm: $inviterFarmId');
                    
                    // Close the dialog and redirect to the partner's farm
                    if (mounted) {
                      Navigator.of(context).pop();
                      
                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Welcome to your shared farm! You can now see each other moving around in real-time.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      
                      // Redirect to the partner's farm with real-time multiplayer enabled
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => GameScreen(farmId: inviterFarmId),
                        ),
                      );
                    }
                  } else {
                    // Fallback: just close dialog and refresh
                    if (mounted) {
                      Navigator.of(context).pop();
                      setState(() {
                        _hasCouple = true;
                      });
                    }
                  }
                } catch (e) {
                  debugPrint('[GameScreen] Error accepting invite: $e');
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to accept invite: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _chestOverlay?.remove();
    _chestOverlay = null;
    inventoryManager.dispose();
    super.dispose();
  }

  void _handlePlant(int gridX, int gridY) async {
    final selectedItem = inventoryManager.selectedItem;
    if (selectedItem != null && selectedItem.id.startsWith('daily_question_seed')) {
      // If we already have an unplanted answer stored, plant it directly
      if (_pendingDailyQuestionAnswer != null) {
        final plotPosition = PlotPosition(gridX.toDouble(), gridY.toDouble());
        final answer = _pendingDailyQuestionAnswer!;
        final questionId = answer['question_id'] as String;
        final answerText = answer['answer'] as String;
        final seed = await GardenRepository().plantSeed(
          mediaType: MediaType.text,
          plotPosition: plotPosition,
          textContent: answerText,
          secretHope: '',
          questionId: questionId,
        );
        await QuestionService.markDailyQuestionAnswerPlanted(answer['id'] as String, seed.id);
        inventoryManager.removeItem(inventoryManager.selectedSlotIndex);
        setState(() {
          _pendingDailyQuestionAnswer = null;
        });
        final seedColor = SeedColorGenerator.generateSeedColor(questionId);
        await _farmGameInstance.addPlantedSeed(
          gridX,
          gridY,
          'daily_question_seed_$questionId',
          'planted',
          seedColor: seedColor,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily Question Seed planted! Water it to help it grow.'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      // Otherwise, prompt the user to answer now, then plant using the new seed system
      final question = await QuestionService.fetchDailyQuestion();
      if (question == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No daily question found. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Use a bottom sheet for planting; reintroduce post-plant visuals and inventory updates
      final planted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        builder: (sheetCtx) {
          final controller = TextEditingController();
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Text('Daily Question', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(question.text),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Your answer',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {},
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetCtx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final answerText = controller.text.trim();
                        debugPrint('[GameScreen] 🧪 onPlant (sheet) for ${question.id} at ($gridX,$gridY)');
                        // Reintroduce full planting flow
                        try {
                          // 1) Create seed in backend and link
                          final ok = await DailyQuestionSeedService.plantDailyQuestionSeed(
                            questionId: question.id,
                            answer: answerText,
                            plotX: gridX,
                            plotY: gridY,
                            farmId: widget.farmId,
                          );
                          debugPrint('[GameScreen] 🧪 plantDailyQuestionSeed result (sheet): $ok');
                          if (!ok) {
                            Navigator.of(sheetCtx).pop(false);
                            return;
                          }
                          // 2) Consume the inventory seed
                          try {
                            debugPrint('[GameScreen] 🧪 Removing inventory item for planted daily seed');
                            inventoryManager.removeItem(inventoryManager.selectedSlotIndex);
                          } catch (e, st) {
                            debugPrint('[GameScreen] ❌ Error removing inventory item: $e\n$st');
                          }
                          // 3) Add planted seed visuals
                          try {
                            final seedColor = SeedColorGenerator.generateSeedColor(question.id);
                            debugPrint('[GameScreen] 🧪 Calling addPlantedSeed for daily_question_seed_${question.id}');
                            await _farmGameInstance.addPlantedSeed(
                              gridX, gridY, 'daily_question_seed_${question.id}', 'planted', seedColor: seedColor,
                            );
                            debugPrint('[GameScreen] ✅ addPlantedSeed completed');
                          } catch (e, st) {
                            debugPrint('[GameScreen] ❌ addPlantedSeed failed (sheet): $e\n$st');
                          }
                          // Close sheet
                          FocusScope.of(sheetCtx).unfocus();
                          await Future.delayed(const Duration(milliseconds: 50));
                          Navigator.of(sheetCtx).pop(true);
                        } catch (e, st) {
                          debugPrint('[GameScreen] ❌ Plant flow failed: $e\n$st');
                          Navigator.of(sheetCtx).pop(false);
                        }
                      },
                      child: const Text('Plant'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );

      debugPrint('[GameScreen] 🧪 showDialog returned: $planted');
      if (planted == true) {
        final msg = kSubmitOnlyNoVisuals
            ? 'Answer submitted. Visuals unchanged (debug mode).'
            : 'Daily Question Seed planted! Water it to help it grow.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }
    try {
      // Persist seed to backend using farm_seeds system
      await FarmTileService().plantSeed(widget.farmId, gridX, gridY, 'regular_seed');
      await _farmGameInstance.addPlantedSeed(gridX, gridY, 'regular_seed', 'planted');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memory planted! Water it to help it grow.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to plant memory. Make sure you are next to tilled soil and have seeds selected.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // _handlePlotTap removed (unused)

  void _handleOwlTap(Question question) async {
    debugPrint('[GameScreen] 🦉 Owl tapped for question: ${question.id}');
    
    // Check if user has already collected this seed
    final hasCollected = await DailyQuestionSeedCollectionService.hasUserCollectedSeed(question.id);
    debugPrint('[GameScreen] 📊 Collection check result: $hasCollected');
    
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DailyQuestionLetterSheet(
        question: question,
        onCollectSeed: hasCollected ? null : () async {
          debugPrint('[GameScreen] 🌱 Collecting seed for question: ${question.id}');
          
          // Generate a unique color for this seed
          final seedColor = SeedColorGenerator.generateSeedColor(question.id);
          debugPrint('[GameScreen] 🎨 Generated seed color: $seedColor');
          
          // Check inventory capacity BEFORE backend collection
          final uniqueSeedId = 'daily_question_seed_${question.id}';
          final canAccept = inventoryManager.canAcceptItemId(uniqueSeedId);
          if (!canAccept) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Inventory full! Free a slot before collecting.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // Collect the seed in the backend only if inventory can accept it
          final success = await DailyQuestionSeedCollectionService.collectDailyQuestionSeed(
            questionId: question.id,
            questionText: question.text,
            answer: '', // Will be filled when user submits answer
            seedColor: seedColor,
          );

          debugPrint('[GameScreen] 📦 Collection result: $success');

          if (!success) {
            debugPrint('[GameScreen] ❌ Failed to collect seed');
            return;
          }

          // Add or stack the seed (no const to satisfy runtime value)
          await inventoryManager.addItem(
            InventoryItem(
              id: uniqueSeedId,
              name: 'Daily Question Seed',
              iconPath: 'assets/images/items/seeds.png',
              itemColor: SeedColorGenerator.generateSeedColor(question.id),
              quantity: 1,
            ),
          );
          // Persist icon/tint in backend so reloads keep the same appearance
          await InventoryService.updateItemAppearance(
            itemId: uniqueSeedId,
            iconPath: 'assets/images/items/seeds.png',
            itemColor: SeedColorGenerator.generateSeedColor(question.id),
          );
          
          // Close the modal bottom sheet after successful collection
          Navigator.of(context).pop();
          
          // Update owl notification to hide it
          _updateOwlNotification(question.id);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Daily Question Seed collected!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  /// Update owl notification based on seed collection status
  void _updateOwlNotification(String questionId) async {
    try {
      // Check if user has collected this seed
      final hasCollected = await DailyQuestionSeedCollectionService.hasUserCollectedSeed(questionId);
      
      // Update owl notification in the game instance
      if (_farmGameInstance != null) {
        await _farmGameInstance.updateOwlNotification(!hasCollected);
        debugPrint('[GameScreen] 🦉 Updated owl notification: ${!hasCollected ? 'ON' : 'OFF'}');
      }
    } catch (e) {
      debugPrint('[GameScreen] ❌ Error updating owl notification: $e');
    }
  }

  OverlayEntry? _chestOverlay;

  void _handleExamine(String examineText, [ChestStorage? chestStorage]) {
    print('onExamine called with: ' + examineText);
    Future.delayed(Duration.zero, () {
      if (chestStorage != null) {
        _showChestOverlay(chestStorage);
      } else {
        showDialog(
          context: context,
          builder: (context) => StardewDialogueBox(text: examineText),
        );
      }
    });
  }

  void _showChestOverlay(ChestStorage chest) {
    _chestOverlay?.remove();
    _chestOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Only the chest panel should capture taps; outside taps go through to the game/inventory
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              type: MaterialType.transparency,
              child: ChestStorageUI(
                chest: chest,
                inventoryManager: inventoryManager,
                onClose: () {
                  _chestOverlay?.remove();
                  _chestOverlay = null;
                },
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_chestOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingCouple && !kDebugMinimalUI) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (kDebugMinimalUI) {
      debugPrint('[GameScreen] 🧪 DEBUG MINIMAL UI ACTIVE');
      return Scaffold(
        appBar: AppBar(title: const Text('Lovenest (Debug UI)')),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('Debug Minimal UI is active'),
                SizedBox(height: 8),
                Text('If this screen stays visible after planting, the issue is in game rendering.'),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
            // Sync due gifts (DB -> completed) on first build after init
            Builder(builder: (ctx) {
              Future.microtask(() => PendingGiftService.syncDueGifts());
              return const SizedBox.shrink();
            }),
            // The game widget (swap between farm and interior)
            if (!_inInterior)
              GameWidget<SimpleEnhancedFarmGame>.controlled(
                gameFactory: () => _farmGameInstance,
              )
            else
              GameWidget<FarmhouseInteriorGame>.controlled(
                gameFactory: () => _interiorGameInstance,
              ),
                         // Coin indicator (top-right)
             const Positioned(
               top: 12,
               right: 12,
               child: CoinIndicator(),
             ),
           
           // Settings button overlay
           Positioned(
             top: 40,
             left: 16,
             child: SafeArea(
               child: IconButton(
                 onPressed: () {
                   _showSettingsDialog();
                 },
                                   icon: const Text(
                    '⚙️',
                    style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                    ),
                  ),
                 style: IconButton.styleFrom(
                   backgroundColor: Colors.black54,
                   shape: const CircleBorder(),
                   padding: const EdgeInsets.all(8),
                 ),
               ),
             ),
           ),
           
           // Weather display removed
           // Right side buttons
           Positioned(
             top: 60,
             right: 16,
            child: SafeArea(
              child: Column(
                children: [
                  // Shop button
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ShopScreen(
                            inventoryManager: inventoryManager,
                            onItemPurchased: () {
                              // Refresh inventory display
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                                         icon: const Text(
                       '🛍️',
                       style: TextStyle(
                         fontSize: 24,
                         color: Colors.white,
                       ),
                     ),
                    tooltip: 'Shop',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Mic button
                  IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AudioRecordDialog(
                          onUploadComplete: (audioUrl) {
                            print('Audio uploaded: $audioUrl');
                            // The seashell will be automatically loaded from the database
                            // when the game starts or when the user refreshes the game
                          },
                        ),
                      );
                    },
                                         icon: const Stack(
                       alignment: Alignment.center,
                       children: [
                         Text(
                           '🎤',
                           style: TextStyle(
                             fontSize: 20,
                             color: Colors.white,
                           ),
                         ),
                         Positioned(
                           right: -2,
                           bottom: -2,
                           child: Text(
                             '➕',
                             style: TextStyle(
                               fontSize: 12,
                               color: Colors.white,
                             ),
                           ),
                         ),
                       ],
                     ),
                    tooltip: 'Record Audio Message',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Gifts Inbox button (shows only if gifts available)
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: PendingGiftService.fetchCollectibleGifts(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      final badgeText = count > 9 ? '9+' : '$count';
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () async {
                              await showDialog(
                                context: context,
                            builder: (context) => GiftsInboxDialog(
                              inventoryManager: inventoryManager,
                              parentContext: context,
                            ),
                              );
                              setState(() {}); // refresh buttons
                            },
                                                         icon: const Text(
                               '🎁',
                               style: TextStyle(
                                 fontSize: 24,
                                 color: Colors.white,
                               ),
                             ),
                            tooltip: 'Gifts Received',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.purple,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Text(
                                badgeText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Add spacing after Gifts Inbox button (only if it's shown)
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: PendingGiftService.fetchCollectibleGifts(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.length ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return const SizedBox(height: 12);
                    },
                  ),

                                     // Invite Partner button (if no couple) -> opens new LinkPartnerScreen
                   if (!_hasCouple) ...[
                     IconButton(
                       onPressed: () async {
                         if (!mounted) return;
                         await Navigator.of(context).push(
                           MaterialPageRoute(builder: (_) => const LinkPartnerScreen()),
                         );
                         // Re-check couple status when returning
                         final after = await GardenRepository().getUserCouple();
                         if (mounted) {
                           setState(() {
                             _hasCouple = after != null;
                           });
                         }
                       },
                                               icon: const Icon(
                          Icons.person_add_alt_1,
                          color: Colors.white,
                          size: 24,
                        ),
                       tooltip: 'Invite Partner',
                       style: IconButton.styleFrom(
                         backgroundColor: Colors.pinkAccent,
                         shape: const CircleBorder(),
                         padding: const EdgeInsets.all(8),
                       ),
                     ),
                   ],

                ],
              ),
            ),
          ),
          // Inventory bar at the bottom (only show in farm)
          if (!_inInterior)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: InventoryBar(
                    inventoryManager: inventoryManager,
                  ),
                ),
              ),
            ),

          if (_showFeatureTour)
            FeatureTourOverlay(
              steps: _buildTourSteps(),
              currentIndex: _tourIndex,
              onNext: () async {
                final isLast = _tourIndex >= _buildTourSteps().length - 1;
                if (isLast) {
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('has_seen_feature_tour', true);
                  } catch (_) {}
                  setState(() {
                    _showFeatureTour = false;
                  });
                } else {
                  setState(() {
                    _tourIndex += 1;
                  });
                }
              },
              onSkip: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('has_seen_feature_tour', true);
                } catch (_) {}
                setState(() {
                  _showFeatureTour = false;
                });
              },
              onTryNow: _handleTryNowForCurrentStep,
            ),
        ],
      ),

    );
  }

  List<FeatureTourStep> _buildTourSteps() {
    Widget sandTileWithSeashell() {
      return Container(
        padding: const EdgeInsets.all(16),
        color: Colors.transparent,
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 160,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0C6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE6D8A8), width: 2),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/Beach/Tiles/Tiles.png'),
                    fit: BoxFit.cover,
                    opacity: 0.25,
                  ),
                ),
              ),
              Image.asset('assets/images/seashell.png', width: 56, height: 56),
            ],
          ),
        ),
      );
    }

    Widget owlWithNoti() {
      return Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Image.asset('assets/images/owl.png', width: 72, height: 72),
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.mail, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    Widget plantedSeedVisual() {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SeedSpritePreview(growthStage: 'planted', scale: 3.0),
            SizedBox(width: 12),
            SeedSpritePreview(growthStage: 'growing', scale: 3.0),
            SizedBox(width: 12),
            SeedSpritePreview(growthStage: 'fully_grown', scale: 3.0),
          ],
        ),
      );
    }

    Widget bonfireVisual() {
      return Center(
        child: Image.asset('assets/images/bonfire.png', width: 80, height: 80),
      );
    }

    return [
      FeatureTourStep(
        icon: Icons.psychology,
        title: 'Daily Questions',
        description: 'Answer a short prompt from the Owl to spark meaningful conversation. Plant your answer as a seed and watch it grow into a bloom.',
        visual: owlWithNoti(),
        tryNowLabel: 'Meet the Owl',
      ),
      FeatureTourStep(
        icon: Icons.local_florist,
        title: 'Memory Blooms',
        description: 'Plant memories (text, voice, photo, or link). Water them together over days to grow beautiful blooms that reveal "secret hopes".',
        visual: plantedSeedVisual(),
        tryNowLabel: 'Plant a Memory',
      ),
      FeatureTourStep(
        icon: Icons.mic,
        title: 'Voice Notes (Seashells)',
        description: 'Leave each other voice notes as seashells on the shore. Tap a shell to listen and feel closer, even when apart.',
        visual: sandTileWithSeashell(),
        tryNowLabel: 'Record a Voice Note',
      ),
      FeatureTourStep(
        icon: Icons.local_fire_department,
        title: 'Relationship Goals (Bonfire)',
        description: 'Add shared goals to feed your bonfire. Every completed goal adds wood and makes the fire burn brighter.',
        visual: bonfireVisual(),
        tryNowLabel: 'Open Bonfire',
      ),
    ];
  }

  void _handleTryNowForCurrentStep() {
    final step = _tourIndex;
    switch (step) {
      case 0:
        // Daily Questions: tap Owl flow
        QuestionService.fetchDailyQuestion().then((q) {
          if (q != null) {
            _handleOwlTap(q);
          }
        });
        break;
      case 1:
        // Memory Blooms: open planting sheet at a safe default tile near player
        final pos = PlotPosition(18, 8);
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => PlantingSheet(
            plotPosition: pos,
            onPlant: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Memory planted! Water it to help it grow.'), backgroundColor: Colors.green),
              );
            },
          ),
        );
        break;
      case 2:
        // Voice Notes: open the audio record dialog
        showDialog(
          context: context,
          builder: (_) => AudioRecordDialog(
            onUploadComplete: (url) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice note uploaded! Look for a seashell.'), backgroundColor: Colors.green),
              );
            },
          ),
        );
        break;
      case 3:
        // Relationship Goals: open bonfire goals dialog via component helper
        RelationshipGoalService().getGoals(widget.farmId).then((goals) async {
          final Map<RelationshipGoalCategory, List<RelationshipGoal>> byCat = {
            for (final c in RelationshipGoalCategory.values) c: [],
          };
          for (final g in goals) {
            byCat[g.category]!.add(g);
          }
          showDialog(
            context: context,
            builder: (_) => RelationshipGoalsDialog(
              goalsByCategory: byCat,
              onAddGoal: (text, category) async {
                await RelationshipGoalService().addGoal(
                  farmId: widget.farmId,
                  text: text,
                  category: category,
                );
              },
              onToggleComplete: (id) async {
                await RelationshipGoalService().completeGoal(
                  farmId: widget.farmId,
                  goalId: id,
                );
              },
            ),
          );
        });
        break;
    }
  }
} 
