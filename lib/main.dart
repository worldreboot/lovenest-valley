import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lovenest/screens/menu_screen.dart';
import 'package:lovenest/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  runApp(
    ProviderScope(
      child: MaterialApp(
        title: 'LoveNest - Memory Garden',
        home: const MenuScreen(),
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
      ),
    ),
  );
}


