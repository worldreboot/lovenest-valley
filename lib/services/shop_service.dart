import 'package:lovenest_valley/models/shop_item.dart';

class ShopService {
  static final List<ShopItem> _allItems = [
    const ShopItem(
      id: 'gift',
      name: 'Gift',
      description: 'Create a custom, AI-generated gift sprite from your description or image.',
      type: ShopItemType.gift,
      rarity: ShopItemRarity.common,
      price: 100,
      iconEmoji: '🎁',
      properties: {'romance_bonus': 2, 'happiness_bonus': 1},
    ),
    const ShopItem(
      id: 'pet',
      name: 'Pet',
      description: 'A loyal companion that will follow you around and bring joy to your farm.',
      type: ShopItemType.animal,
      rarity: ShopItemRarity.rare,
      price: 250,
      iconEmoji: '🐕',
      properties: {'companionship': true, 'happiness_bonus': 3, 'loyalty': true},
    ),
    const ShopItem(
      id: 'wedding_ring',
      name: 'Wedding Ring',
      description: 'A symbol of eternal love and commitment. The ultimate expression of your devotion.',
      type: ShopItemType.decoration,
      rarity: ShopItemRarity.legendary,
      price: 10000,
      iconEmoji: '💍',
      properties: {'eternal_love': true, 'romance_bonus': 10, 'commitment': true, 'prestige': true},
    ),
  ];

  static List<ShopCategory> getCategories() {
    return [
      ShopCategory(
        name: 'Gifts',
        icon: '🎁',
        type: ShopItemType.gift,
        items: _allItems.where((item) => item.type == ShopItemType.gift).toList(),
      ),
      ShopCategory(
        name: 'Tools',
        icon: '🔧',
        type: ShopItemType.tool,
        items: _allItems.where((item) => item.type == ShopItemType.tool).toList(),
      ),
      ShopCategory(
        name: 'Seeds',
        icon: '🌱',
        type: ShopItemType.seed,
        items: _allItems.where((item) => item.type == ShopItemType.seed).toList(),
      ),
      ShopCategory(
        name: 'Decorations',
        icon: '🎨',
        type: ShopItemType.decoration,
        items: _allItems.where((item) => item.type == ShopItemType.decoration).toList(),
      ),
      ShopCategory(
        name: 'Buildings',
        icon: '🏗️',
        type: ShopItemType.building,
        items: _allItems.where((item) => item.type == ShopItemType.building).toList(),
      ),
      ShopCategory(
        name: 'Animals',
        icon: '🐾',
        type: ShopItemType.animal,
        items: _allItems.where((item) => item.type == ShopItemType.animal).toList(),
      ),
    ];
  }

  static List<ShopItem> getAllItems() {
    return _allItems;
  }

  static ShopItem? getItemById(String id) {
    try {
      return _allItems.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  static List<ShopItem> getItemsByType(ShopItemType type) {
    return _allItems.where((item) => item.type == type).toList();
  }

  static List<ShopItem> getItemsByRarity(ShopItemRarity rarity) {
    return _allItems.where((item) => item.rarity == rarity).toList();
  }

  static List<ShopItem> searchItems(String query) {
    final lowercaseQuery = query.toLowerCase();
    return _allItems.where((item) =>
        item.name.toLowerCase().contains(lowercaseQuery) ||
        item.description.toLowerCase().contains(lowercaseQuery) ||
        item.typeName.toLowerCase().contains(lowercaseQuery) ||
        item.rarityName.toLowerCase().contains(lowercaseQuery)
    ).toList();
  }
} 
