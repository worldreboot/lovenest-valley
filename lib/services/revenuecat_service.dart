import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static bool _initialized = false;
  static const String _publicApiKey = 'REVENUECAT_PUBLIC_API_KEY_PLACEHOLDER';
  static const String _entitlementId = 'premium'; // placeholder

  static Future<void> initialize({String? appUserId}) async {
    if (_initialized) return;
    try {
      await Purchases.setLogLevel(LogLevel.warn);
      await Purchases.configure(
        PurchasesConfiguration(_publicApiKey)
          ..appUserID = appUserId
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[RevenueCatService] Initialization error: $e');
    }
  }

  static Future<bool> isEntitled() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final ent = customerInfo.entitlements.active[_entitlementId];
      return ent != null;
    } catch (e) {
      debugPrint('[RevenueCatService] isEntitled error: $e');
      return false;
    }
  }

  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('[RevenueCatService] getOfferings error: $e');
      return null;
    }
  }

  static Future<CustomerInfo?> purchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo;
    } catch (e) {
      debugPrint('[RevenueCatService] purchase error: $e');
      return null;
    }
  }

  static Future<CustomerInfo?> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      return info;
    } catch (e) {
      debugPrint('[RevenueCatService] restore error: $e');
      return null;
    }
  }
}


