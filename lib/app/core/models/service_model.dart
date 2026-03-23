import 'package:aco_plus/app/core/services/firebase_service.dart';
import 'package:aco_plus/app/core/services/keyboard_visible_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';

abstract class Service {
  Future<void> initialize();

  static bool isInitialized = false;

  static final List<Service> _applicationServices = [
    FirebaseService(),
    KeyboardVisibleService(),
    SupabaseService(),
    // DateService(),
    // SharedPreferencesService(),
    // LogManagerService(),
    // AdManagerService(),
  ];

  static Future<void> initAplicationServices() async {
    if (!isInitialized) {
      isInitialized = true;
      // Initialize all services in parallel
      await Future.wait(_applicationServices.map((service) => service.initialize()));
    }
  }
}
