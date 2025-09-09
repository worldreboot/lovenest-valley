import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import 'package:intl/intl.dart';
import '../game/memory_garden_game.dart';
import '../models/memory_garden/seed.dart';
import '../providers/enhanced_garden_providers.dart';
import '../services/garden_sync_service.dart';
import '../services/garden_repository.dart';
import '../config/supabase_config.dart';
import '../services/auth_service.dart';
import 'memory_garden/planting_sheet.dart';
import 'memory_garden/nurturing_sheet.dart';
import 'memory_garden/bloom_viewer_sheet.dart';
import 'memory_garden/conflict_resolution_sheet.dart';

class EnhancedMemoryGardenScreen extends ConsumerStatefulWidget {
  const EnhancedMemoryGardenScreen({super.key});

  @override
  ConsumerState<EnhancedMemoryGardenScreen> createState() => _EnhancedMemoryGardenScreenState();
}

class _EnhancedMemoryGardenScreenState extends ConsumerState<EnhancedMemoryGardenScreen> {
  late MemoryGardenGame game;
  bool _isAuthenticated = false;
  bool _syncInitialized = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
    _initializeGame();
    _initializeSync();
  }

  void _checkAuthentication() {
    _isAuthenticated = true; // TODO: Remove bypass in production
  }

  void _initializeGame() {
    game = MemoryGardenGame(
      ref: ref,
      onPlotTapped: _handlePlotTapped,
    );
  }

  Future<void> _initializeSync() async {
    if (!_syncInitialized) {
      final syncService = ref.read(gardenSyncServiceProvider);
      final couple = await ref.read(userCoupleProvider.future);
      
      if (couple != null) {
        await syncService.initialize(couple.id);
        setState(() {
          _syncInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildAuthenticationScreen();
    }

    return Consumer(
      builder: (context, ref, child) {
        final plantingMode = ref.watch(plantingModeProvider);
        final gardenState = ref.watch(gardenStateProvider);
        final conflicts = ref.watch(gardenConflictsProvider);
        final pendingActions = ref.watch(pendingSyncActionsProvider);
        final isOnline = ref.watch(networkConnectivityProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Memory Garden'),
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              // Sync status indicator
              _buildSyncStatusIndicator(gardenState, isOnline),
              
              // Conflict indicator
              conflicts.when(
                data: (conflict) => _buildConflictIndicator(conflict),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              
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
              // Enhanced stats bar with sync info
              _buildEnhancedStatsBar(gardenState, pendingActions),
              
              // Conflict alert banner
              conflicts.when(
                data: (conflict) => _buildConflictBanner(conflict),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              
              // Offline indicator
              isOnline.when(
                data: (online) => online ? const SizedBox.shrink() : _buildOfflineBanner(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              
              // Game view
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final gardenAsync = ref.watch(enhancedGardenSeedsProvider);
                    
                    // Update game when seeds change
                    gardenAsync.whenData((seeds) {
                      game.updateSeeds(seeds);
                    });
                    
                    return Stack(
                      children: [
                        GameWidget(game: game),
                        
                        // Sync overlay
                        if (gardenState.isSyncing)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: _buildSyncOverlay(),
                          ),
                      ],
                    );
                  },
                ),
              ),
              
              // Enhanced bottom controls
              _buildEnhancedBottomControls(pendingActions),
            ],
          ),
          floatingActionButton: plantingMode 
            ? FloatingActionButton(
                onPressed: _exitPlantingMode,
                backgroundColor: Colors.red,
                child: const Icon(Icons.close, color: Colors.white),
              )
            : null,
        );
      },
    );
  }

  Widget _buildAuthenticationScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Garden'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_florist, size: 100, color: Colors.green),
            SizedBox(height: 24),
            Text(
              'Welcome to Memory Garden',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Please authenticate to access your garden',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: null, // TODO: Implement authentication
              child: Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusIndicator(GardenState gardenState, AsyncValue<bool> isOnline) {
    return IconButton(
      onPressed: () => _showSyncStatus(gardenState),
      icon: Stack(
        children: [
          Icon(
            gardenState.isSyncing 
              ? Icons.sync 
              : Icons.sync_alt,
            color: gardenState.syncError != null 
              ? Colors.red 
              : Colors.white,
          ),
          if (gardenState.isSyncing)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConflictIndicator(GardenConflict? conflict) {
    if (conflict == null) return const SizedBox.shrink();
    
    return IconButton(
      onPressed: () => _showConflictResolution(conflict),
      icon: Stack(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedStatsBar(GardenState gardenState, List<SyncAction> pendingActions) {
    return Consumer(
      builder: (context, ref, child) {
        final gardenAsync = ref.watch(enhancedGardenSeedsProvider);
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
                    final conflictCount = seeds.where((s) => s.state == SeedState.sprout).length; // TODO: Add conflict status
                    
                    return Row(
                      children: [
                        _buildStatItem(Icons.eco, '$sproutCount', 'Sprouts'),
                        const SizedBox(width: 12),
                        _buildStatItem(Icons.local_florist, '$bloomCount', 'Blooms'),
                        const SizedBox(width: 12),
                        _buildStatItem(Icons.grid_on, '${seeds.length}/100', 'Total'),
                        if (conflictCount > 0) ...[
                          const SizedBox(width: 12),
                          _buildStatItem(Icons.warning, '$conflictCount', 'Conflicts', Colors.red),
                        ],
                      ],
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading stats'),
                ),
              ),
              
              // Sync status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    gardenState.lastSyncTime != null 
                      ? 'Last sync: ${_formatTime(gardenState.lastSyncTime!)}'
                      : 'Never synced',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (pendingActions.isNotEmpty)
                    Text(
                      '${pendingActions.length} pending',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[600],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConflictBanner(GardenConflict? conflict) {
    if (conflict == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border.all(color: Colors.red[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.red[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conflict Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                Text(
                  'Multiple memories planted at position (${conflict.plotPosition.x}, ${conflict.plotPosition.y})',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _showConflictResolution(conflict),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.orange[600]),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'You\'re offline. Changes will sync when connection is restored.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncOverlay() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Syncing...',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedBottomControls(List<SyncAction> pendingActions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pending actions indicator
          if (pendingActions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange[200]!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sync_problem, size: 16, color: Colors.orange[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${pendingActions.length} actions pending sync',
                    style: TextStyle(fontSize: 12, color: Colors.orange[600]),
                  ),
                ],
              ),
            ),
          
          // Main controls
          Row(
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
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _forceSyncNow,
                icon: const Icon(Icons.sync),
                label: const Text('Sync'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, [Color? color]) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.green),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  void _handlePlotTapped(PlotPosition position, Seed? seed) {
    if (seed == null) {
      _showPlantingSheet(position);
    } else {
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

  void _showConflictResolution(GardenConflict conflict) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ConflictResolutionSheet(conflict: conflict),
    );
  }

  void _showSyncStatus(GardenState gardenState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${gardenState.isSyncing ? 'Syncing' : 'Idle'}'),
            const SizedBox(height: 8),
            Text('Last sync: ${gardenState.lastSyncTime?.toString() ?? 'Never'}'),
            const SizedBox(height: 8),
            if (gardenState.syncError != null)
              Text('Error: ${gardenState.syncError}', style: const TextStyle(color: Colors.red)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showGardenInfo() {
    // TODO: Implement garden info dialog
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _showLogoutConfirmation();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
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

  void _enterPlantingMode() {
    ref.read(plantingModeProvider.notifier).state = true;
    game.enterPlantingMode();
  }

  void _exitPlantingMode() {
    ref.read(plantingModeProvider.notifier).state = false;
    game.exitPlantingMode();
  }

  void _centerOnGarden() {
    game.centerOnGarden();
  }

  void _forceSyncNow() {
    final gardenState = ref.read(gardenStateProvider.notifier);
    gardenState.startSync();
    
    // TODO: Implement force sync logic
    Future.delayed(const Duration(seconds: 2), () {
      gardenState.stopSync();
    });
  }
} 
