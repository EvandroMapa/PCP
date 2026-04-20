import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/services/keyboard_visible_service.dart';
import 'package:aco_plus/app/core/services/supabase_service.dart';
import 'package:aco_plus/app/core/services/preferences_service.dart';

abstract class Service {
  Future<void> initialize();

  static bool isInitialized = false;
  static bool isCoreInitialized = false;

  // Apenas conexão SDK Supabase — obrigatório antes do runApp (< 1s)
  static final List<Service> _coreServices = [
    KeyboardVisibleService(),
    SupabaseService(),
  ];

  // Serviços pesados (17+ queries ao banco) — rodados em background após runApp
  static final List<Service> _heavyServices = [
    PreferencesService(),
  ];

  /// Conecta ao Supabase — chamado antes do runApp (rápido)
  static Future<void> initCoreServices() async {
    if (isCoreInitialized) return;
    isCoreInitialized = true;
    for (final service in _coreServices) {
      await service.initialize();
    }
  }

  /// Inicializa dados (queries ao banco) — chamado em background após runApp
  static Future<void> initAplicationServices() async {
    if (!isCoreInitialized) await initCoreServices();
    if (isInitialized) return;
    isInitialized = true;

    // Carrega todas as coleções do Supabase (queries pesadas)
    await AppSupabaseClient.init();

    // Carrega configs (logo, kanban width, etc.)
    for (final service in _heavyServices) {
      await service.initialize();
    }
  }
}
