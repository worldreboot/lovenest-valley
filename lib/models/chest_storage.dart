import 'package:flutter/foundation.dart';

/// Represents an item stored in a chest
class ChestItem {
  final String id;
  final String name;
  final String? iconPath;
  final int quantity;
  final String? description;
  final Map<String, dynamic>? metadata;

  const ChestItem({
    required this.id,
    required this.name,
    this.iconPath,
    this.quantity = 1,
    this.description,
    this.metadata,
  });

  ChestItem copyWith({
    String? id,
    String? name,
    String? iconPath,
    int? quantity,
    String? description,
    Map<String, dynamic>? metadata,
  }) {
    return ChestItem(
      id: id ?? this.id,
      name: name ?? this.name,
      iconPath: iconPath ?? this.iconPath,
      quantity: quantity ?? this.quantity,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconPath': iconPath,
      'quantity': quantity,
      'description': description,
      'metadata': metadata,
    };
  }

  factory ChestItem.fromJson(Map<String, dynamic> json) {
    return ChestItem(
      id: json['id'] as String,
      name: json['name'] as String,
      iconPath: json['iconPath'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Represents a chest storage container
class ChestStorage {
  final String id;
  final String coupleId;
  final Position position;
  final List<ChestItem> items;
  final int maxCapacity;
  final String? name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final String syncStatus;

  const ChestStorage({
    required this.id,
    required this.coupleId,
    required this.position,
    required this.items,
    this.maxCapacity = 20,
    this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.syncStatus,
  });

  ChestStorage copyWith({
    String? id,
    String? coupleId,
    Position? position,
    List<ChestItem>? items,
    int? maxCapacity,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    String? syncStatus,
  }) {
    return ChestStorage(
      id: id ?? this.id,
      coupleId: coupleId ?? this.coupleId,
      position: position ?? this.position,
      items: items ?? this.items,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Get total number of items (including quantities)
  int get totalItemCount {
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Check if chest has available space
  bool get hasSpace => totalItemCount < maxCapacity;

  /// Add an item to the chest
  ChestStorage addItem(ChestItem item) {
    if (!hasSpace) {
      throw Exception('Chest is full');
    }

    // Try to stack with existing items
    final existingIndex = items.indexWhere((existing) => existing.id == item.id);
    if (existingIndex != -1) {
      final updatedItems = List<ChestItem>.from(items);
      updatedItems[existingIndex] = updatedItems[existingIndex].copyWith(
        quantity: updatedItems[existingIndex].quantity + item.quantity,
      );
      return copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );
    } else {
      return copyWith(
        items: [...items, item],
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Remove an item from the chest
  ChestStorage removeItem(String itemId, {int quantity = 1}) {
    final itemIndex = items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) {
      throw Exception('Item not found in chest');
    }

    final item = items[itemIndex];
    if (item.quantity < quantity) {
      throw Exception('Not enough items in chest');
    }

    final updatedItems = List<ChestItem>.from(items);
    if (item.quantity == quantity) {
      updatedItems.removeAt(itemIndex);
    } else {
      updatedItems[itemIndex] = item.copyWith(quantity: item.quantity - quantity);
    }

    return copyWith(
      items: updatedItems,
      updatedAt: DateTime.now(),
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'couple_id': coupleId,
      'type': 'chest',
      'position': '(${position.x},${position.y})',
      'properties': {
        'items': items.map((item) => item.toJson()).toList(),
        'maxCapacity': maxCapacity,
        'name': name,
      },
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'version': version,
      'sync_status': syncStatus,
    };
  }

  /// Create from JSON from database
  factory ChestStorage.fromJson(Map<String, dynamic> json) {
    final positionStr = json['position'] as String;
    final positionMatch = RegExp(r'\(([^,]+),([^)]+)\)').firstMatch(positionStr);
    final position = Position(
      double.parse(positionMatch!.group(1)!),
      double.parse(positionMatch.group(2)!),
    );

    final properties = json['properties'] as Map<String, dynamic>;
    final itemsJson = properties['items'] as List<dynamic>? ?? [];
    final items = itemsJson.map((itemJson) => ChestItem.fromJson(itemJson as Map<String, dynamic>)).toList();

    return ChestStorage(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      position: position,
      items: items,
      maxCapacity: properties['maxCapacity'] as int? ?? 20,
      name: properties['name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      version: json['version'] as int? ?? 1,
      syncStatus: json['sync_status'] as String? ?? 'synced',
    );
  }
}

/// Simple Position class for chest coordinates
class Position {
  final double x;
  final double y;

  const Position(this.x, this.y);

  @override
  String toString() => 'Position($x, $y)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
} 