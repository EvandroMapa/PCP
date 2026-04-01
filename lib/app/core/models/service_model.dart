import 'package:aco_plus/app/core/services/firebase_service.dart';
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
      // Initialize Firebase first to ensure Firestore-dependent services work
      await FirebaseService().initialize();
      // Initialize remaining services in parallel
      await Future.wait(
          _applicationServices.map((service) => service.initialize()));
    }
  }
}
