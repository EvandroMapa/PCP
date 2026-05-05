import 'dart:developer';
import 'package:aco_plus/app/app_controller.dart';
import 'package:aco_plus/app/core/models/service_model.dart';
import 'package:aco_plus/app/core/router/route_config.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/totem/ui/totem_box_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:overlay_support/overlay_support.dart';

/// Entry point dedicado para APK do Totem.
/// Gerar com: flutter build apk -t lib/main_totem.dart
void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    setWebTitle('AçoPlus - Totem');
    RouteConfig.setConfig();
    await initializeDateFormatting('pt_BR');

    // Forçar landscape e tela cheia imersiva
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Inicializa Supabase
    await Service.initCoreServices();

    // Sobe o app do totem
    runApp(const TotemApp());

    // Carrega dados em background
    Service.initAplicationServices()
        .then((_) => appCtrl.onInit())
        .catchError((e) => debugPrint('Init background error: $e'));
  } catch (e, stack) {
    debugPrint('Critical Error during main_totem: $e');
    log('Stack Trace', stackTrace: stack);
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Erro ao iniciar o Totem: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ));
  }
}

class TotemApp extends StatelessWidget {
  const TotemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return OverlaySupport.global(
      child: MaterialApp(
        title: 'AçoPlus Totem',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0F172A),
        ),
        home: const TotemBoxPage(),
      ),
    );
  }
}
