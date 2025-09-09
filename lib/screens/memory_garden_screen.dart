import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import '../game/memory_garden_game.dart';
import '../models/memory_garden/seed.dart';
import '../providers/garden_providers.dart';
import '../config/supabase_config.dart';
import 'memory_garden/planting_sheet.dart';
import 'memory_garden/nurturing_sheet.dart';
import 'memory_garden/bloom_viewer_sheet.dart';

class MemoryGardenScreen extends ConsumerStatefulWidget {
  const MemoryGardenScreen({super.key});

  @override
  ConsumerState<MemoryGardenScreen> createState() => _MemoryGardenScreenState();
}

class _MemoryGardenScreenState extends ConsumerState<MemoryGardenScreen> {
  late MemoryGardenGame game;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
    _initializeGame();
  }

  void _checkAuthentication() {
    // TODO: Remove this bypass when ready for production
    // For testing purposes, bypass authentication
    _isAuthenticated = true;
    
    // Original authentication check:
    // _isAuthenticated = SupabaseConfig.currentUser != null;
  }

  void _initializeGame() {
    game = MemoryGardenGame(
      ref: ref,
      onPlotTapped: _handlePlotTapped,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildAuthenticationScreen();
    }

    return Consumer(
      builder: (context, ref, child) {
        final plantingMode = ref.watch(plantingModeProvider);
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Memory Garden'),
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                onPressed: _showGardenInfo,
                icon: const Icon(Icons.info_outline),
              ),
              IconButton(
                onPressed: _showSettings,
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
          body: Column(
            children: [
              // Garden stats bar
              _buildStatsBar(),
              
              // Game view
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final gardenAsync = ref.watch(gardenSeedsProvider);
                    
                    // Update game when seeds change
                    gardenAsync.whenData((seeds) {
                      game.updateSeeds(seeds);
                    });
                    
                    return GameWidget(game: game);
                  },
                ),
              ),
              
              // Bottom controls
              _buildBottomControls(),
            ],
          ),
          floatingActionButton: plantingMode ? FloatingActionButton(
            onPressed: _exitPlantingMode,
            backgroundColor: Colors.red,
            child: const Icon(Icons.close, color: Colors.white),
          ) : null,
        );
      },
    );
  }

  Widget _buildAuthenticationScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.eco,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 20),
              const Text(
                'Memory Garden',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Plant and nurture your precious memories together',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _handleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Sign In to Start'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Consumer(
      builder: (context, ref, child) {
        final gardenAsync = ref.watch(gardenSeedsProvider);
        final coupleAsync = ref.watch(userCoupleProvider);
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green[50],
            border: Border(bottom: BorderSide(color: Colors.green[200]!)),
          ),
          child: Row(
            children: [
              // Garden stats
              Expanded(
                child: gardenAsync.when(
                  data: (seeds) {
                    final sproutCount = seeds.where((s) => s.state == SeedState.sprout).length;
                    final bloomCount = seeds.where((s) => s.isBloom).length;
                    
                    return Row(
                      children: [
                        _buildStatItem(Icons.eco, '$sproutCount', 'Sprouts'),
                        const SizedBox(width: 16),
                        _buildStatItem(Icons.local_florist, '$bloomCount', 'Blooms'),
                        const SizedBox(width: 16),
                        _buildStatItem(Icons.grid_on, '${seeds.length}/100', 'Total'),
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading stats'),
                ),
              ),
              
              // Partner status
              coupleAsync.when(
                data: (couple) {
                  if (couple == null) {
                    return TextButton.icon(
                      onPressed: _invitePartner,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Invite Partner'),
                    );
                  }
                  return const Icon(Icons.favorite, color: Colors.pink);
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.green[700]),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _enterPlantingMode,
              icon: const Icon(Icons.add),
              label: const Text('Plant Memory'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _centerOnGarden,
            icon: const Icon(Icons.center_focus_strong),
            label: const Text('Center'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }



  void _handlePlotTapped(PlotPosition position, Seed? seed) {
    if (seed == null) {
      // Empty plot - show planting UI
      _showPlantingSheet(position);
    } else {
      // Existing seed - show appropriate interaction
      _handleSeedTapped(seed);
    }
  }

  void _handleSeedTapped(Seed seed) {
    if (seed.isBloom) {
      _showBloomViewer(seed);
    } else {
      _showNurturingSheet(seed);
    }
  }

  void _showPlantingSheet(PlotPosition position) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: PlantingSheet(plotPosition: position),
      ),
    );
  }

  void _showNurturingSheet(Seed seed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: NurturingSheet(seed: seed),
      ),
    );
  }

  void _showBloomViewer(Seed seed) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BloomViewerSheet(seed: seed),
    );
  }

  void _enterPlantingMode() {
    game.enterPlantingMode();
  }

  void _exitPlantingMode() {
    game.exitPlantingMode();
  }

  void _centerOnGarden() {
    game.centerOnGarden();
    game.zoomToGarden();
  }

  void _showGardenInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Colors.green),
            SizedBox(width: 8),
            Text('How Memory Garden Works'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🌱 Plant Memories',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Tap empty plots to plant photos, voice recordings, text, or links with a secret hope.'),
              SizedBox(height: 12),
              Text(
                '💧 Nurture Together',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Water and reply to memories to help them grow. Both partners must participate.'),
              SizedBox(height: 12),
              Text(
                '🌸 Watch Them Bloom',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('When both partners have cared for a memory, it blooms beautifully overnight.'),
              SizedBox(height: 12),
              Text(
                '✨ Discover Secrets',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Advanced blooms reveal the secret hopes that were planted with each memory.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign Out'),
              onTap: _handleSignOut,
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever),
              title: const Text('Clear Garden'),
              onTap: _confirmClearGarden,
            ),
          ],
        ),
      ),
    );
  }

  void _invitePartner() {
    // TODO: Implement partner invitation flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Partner invitation feature coming soon!'),
      ),
    );
  }

  Future<void> _handleSignIn() async {
    // TODO: Implement proper authentication flow
    // For now, we'll use a simple demo user
    try {
      // This would be replaced with actual Supabase auth
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure Supabase authentication'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign in failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await SupabaseConfig.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pop(); // Close settings
        setState(() => _isAuthenticated = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign out failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _confirmClearGarden() {
    Navigator.of(context).pop(); // Close settings
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Garden?'),
        content: const Text(
          'This will permanently delete all memories in your garden. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _clearGarden,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _clearGarden() {
    Navigator.of(context).pop();
    // TODO: Implement garden clearing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Garden clearing feature coming soon!'),
      ),
    );
  }
} 
