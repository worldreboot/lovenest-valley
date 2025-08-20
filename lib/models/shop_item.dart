import 'package:flutter/material.dart';

enum ShopItemType {
  tool,
  seed,
  decoration,
  building,
  animal,
  gift,
}

enum ShopItemRarity {
  common,
  uncommon,
  rare,
  epic,
  legendary,
}

class ShopItem {
  final String id;
  final String name;
  final String description;
  final ShopItemType type;
  final ShopItemRarity rarity;
  final int price;
  final String? imageAsset;
  final String? iconEmoji;
  final Map<String, dynamic>? properties;
  final bool isAvailable;

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.rarity,
    required this.price,
    this.imageAsset,
    this.iconEmoji,
    this.properties,
    this.isAvailable = true,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      type: ShopItemType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ShopItemType.tool,
      ),
      rarity: ShopItemRarity.values.firstWhere(
        (e) => e.name == json['rarity'],
        orElse: () => ShopItemRarity.common,
      ),
      price: json['price'] as int,
      imageAsset: json['image_asset'] as String?,
      iconEmoji: json['icon_emoji'] as String?,
      properties: json['properties'] as Map<String, dynamic>?,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.name,
    'rarity': rarity.name,
    'price': price,
    'image_asset': imageAsset,
    'icon_emoji': iconEmoji,
    'properties': properties,
    'is_available': isAvailable,
  };

  Color get rarityColor {
    switch (rarity) {
      case ShopItemRarity.common:
        return Colors.grey;
      case ShopItemRarity.uncommon:
        return Colors.green;
      case ShopItemRarity.rare:
        return Colors.blue;
      case ShopItemRarity.epic:
        return Colors.purple;
      case ShopItemRarity.legendary:
        return Colors.orange;
    }
  }

  String get rarityName {
    switch (rarity) {
      case ShopItemRarity.common:
        return 'Common';
      case ShopItemRarity.uncommon:
        return 'Uncommon';
      case ShopItemRarity.rare:
        return 'Rare';
      case ShopItemRarity.epic:
        return 'Epic';
      case ShopItemRarity.legendary:
        return 'Legendary';
    }
  }

  String get typeName {
    switch (type) {
      case ShopItemType.tool:
        return 'Tool';
      case ShopItemType.seed:
        return 'Seed';
      case ShopItemType.decoration:
        return 'Decoration';
      case ShopItemType.building:
        return 'Building';
      case ShopItemType.animal:
        return 'Animal';
      case ShopItemType.gift:
        return 'Gift';
    }
  }
}

class ShopCategory {
  final String name;
  final String icon;
  final ShopItemType type;
  final List<ShopItem> items;

  const ShopCategory({
    required this.name,
    required this.icon,
    required this.type,
    required this.items,
  });
} 