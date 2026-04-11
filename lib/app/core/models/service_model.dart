
import 'package:aco_plus/app/core/services/keyboard_visible_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';

abstract class Service {
  Future<void> initialize();

  static bool isInitialized = false;

  static final List<Service> _applicationServices = [
    KeyboardVisibleService(),
    SupabaseService(),
    PreferencesService(),
  ];

  static Future<void> initAplicationServices() async {
    if (!isInitialized) {
      isInitialized = true;
      // Firebase decoupled - using Supabase only
      // await FirebaseService().initialize();
      // Initialize services in sequential order to avoid deadlock
      // Supabase MUST initialize before PreferencesService
      for (final service in _applicationServices) {
        await service.initialize();
      }
    }
  }
}
