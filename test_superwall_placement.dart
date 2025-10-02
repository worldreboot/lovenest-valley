import 'package:flutter/material.dart';
import 'lib/services/superwall_service.dart';

/// Test script to trigger Superwall placements
/// This can be run from the debug console or integrated into the app
class SuperwallPlacementTester {
  
  /// Test the campaign_trigger placement
  static Future<void> testCampaignTrigger() async {
    print('🧪 Testing campaign_trigger placement...');
    await SuperwallService.testPlacement('campaign_trigger');
  }
  
  /// Test all implemented placements
  static Future<void> testAllPlacements() async {
    print('🧪 Testing all Superwall placements...');
    
    final placements = [
      'campaign_trigger',
      'shop_access',
      'daily_questions_access',
      'plant_daily_question_seed',
    ];
    
    for (final placement in placements) {
      print('Testing placement: $placement');
      await SuperwallService.testPlacement(placement);
      await Future.delayed(const Duration(seconds: 1)); // Small delay between tests
    }
    
    print('✅ All placement tests completed!');
  }
  
  /// Test a custom placement
  static Future<void> testCustomPlacement(String placementName) async {
    print('🧪 Testing custom placement: $placementName');
    await SuperwallService.testPlacement(placementName);
  }
}

/// Usage examples:
/// 
/// From debug console:
/// ```dart
/// import 'test_superwall_placement.dart';
/// await SuperwallPlacementTester.testCampaignTrigger();
/// ```
/// 
/// From app code:
/// ```dart
/// await SuperwallPlacementTester.testAllPlacements();
/// ```
/// 
/// Test custom placement:
/// ```dart
/// await SuperwallPlacementTester.testCustomPlacement('your_placement_name');
/// ```
