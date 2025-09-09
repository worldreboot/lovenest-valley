import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../components/ui/chest_storage_ui.dart';
import '../models/chest_storage.dart';
import '../providers/chest_storage_providers.dart';

class ChestStorageExampleScreen extends ConsumerStatefulWidget {
  const ChestStorageExampleScreen({super.key});

  @override
  ConsumerState<ChestStorageExampleScreen> createState() => _ChestStorageExampleScreenState();
}

class _ChestStorageExampleScreenState extends ConsumerState<ChestStorageExampleScreen> {
  ChestStorage? selectedChest;

  @override
  Widget build(BuildContext context) {
    final chestsState = ref.watch(chestsStateProvider);
    final isLoading = ref.watch(isLoadingChestsProvider);
    final error = ref.watch(chestsErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chest Storage System'),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _createTestChest,
            icon: const Icon(Icons.add),
            tooltip: 'Create Test Chest',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.brown[100]!,
              Colors.brown[200]!,
            ],
          ),
        ),
        child: Column(
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.brown[800]!.withOpacity(0.1),
              child: Row(
                children: [
                  if (isLoading)
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Loading chests...'),
                      ],
                    ),
                  if (error != null)
                    Expanded(
                      child: Text(
                        'Error: $error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    'Real-time sync active',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Chests list
            Expanded(
              child: chestsState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading chests',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(error.toString()),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.refresh(chestsStateProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (chests) => chests.isEmpty
                    ? _buildEmptyState()
                    : _buildChestsList(chests),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 128,
            color: Colors.brown[400]!,
          ),
          const SizedBox(height: 24),
          Text(
            'No chests found',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.brown[700]!,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first chest to start storing items!',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.brown[600]!,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createTestChest,
            icon: const Icon(Icons.add),
            label: const Text('Create Test Chest'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700]!,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChestsList(List<ChestStorage> chests) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: chests.length,
      itemBuilder: (context, index) {
        final chest = chests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 4,
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.brown[100]!,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.brown[300]!),
              ),
              child: Icon(
                Icons.inventory_2,
                color: Colors.brown[700]!,
                size: 24,
              ),
            ),
            title: Text(
              chest.name ?? 'Unnamed Chest',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Position: (${chest.position.x.toInt()}, ${chest.position.y.toInt()})'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Items: ${chest.totalItemCount}/${chest.maxCapacity}'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: chest.totalItemCount / chest.maxCapacity,
                        backgroundColor: Colors.brown[200]!,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          chest.hasSpace ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleChestAction(value, chest),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'open',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_new),
                      SizedBox(width: 8),
                      Text('Open'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'add_item',
                  child: Row(
                    children: [
                      Icon(Icons.add),
                      SizedBox(width: 8),
                      Text('Add Test Item'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _openChest(chest),
          ),
        );
      },
    );
  }

  Future<void> _createTestChest() async {
    try {
      final notifier = ref.read(chestStorageNotifierProvider.notifier);
      await notifier.createChest(
        position: const Position(100, 100),
        name: 'Test Chest ${DateTime.now().millisecondsSinceEpoch % 1000}',
        maxCapacity: 20,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test chest created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating chest: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openChest(ChestStorage chest) {
    setState(() {
      selectedChest = chest;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ChestStorageUI(
          chest: chest,
          onClose: () {
            Navigator.of(context).pop();
            setState(() {
              selectedChest = null;
            });
          },
          onItemSelected: (item) {
            _showItemDetails(item);
          },
        ),
      ),
    );
  }

  void _showItemDetails(ChestItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quantity: ${item.quantity}'),
            if (item.description != null) ...[
              const SizedBox(height: 8),
              Text('Description: ${item.description}'),
            ],
            if (item.iconPath != null) ...[
              const SizedBox(height: 8),
              Text('Icon: ${item.iconPath}'),
            ],
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

  Future<void> _handleChestAction(String action, ChestStorage chest) async {
    switch (action) {
      case 'open':
        _openChest(chest);
        break;
      case 'add_item':
        await _addTestItemToChest(chest);
        break;
      case 'delete':
        await _deleteChest(chest);
        break;
    }
  }

  Future<void> _addTestItemToChest(ChestStorage chest) async {
    try {
      final notifier = ref.read(chestStorageNotifierProvider.notifier);
      final testItem = ChestItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Test Item',
        quantity: 1,
        description: 'A test item added at ${DateTime.now()}',
      );
      
      await notifier.addItemToChest(chest.id, testItem);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test item added to chest!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding item: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteChest(ChestStorage chest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chest'),
        content: Text('Are you sure you want to delete "${chest.name ?? 'Unnamed Chest'}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final notifier = ref.read(chestStorageNotifierProvider.notifier);
      await notifier.deleteChest(chest.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chest deleted successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting chest: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 
