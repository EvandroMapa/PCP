import 'dart:developer';
import 'dart:ui';
import 'package:aco_plus/app/app_controller.dart';
import 'package:aco_plus/app/app_widget.dart';
import 'package:aco_plus/app/core/models/service_model.dart';
import 'package:aco_plus/app/core/router/route_config.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    const buildHash = String.fromEnvironment('BUILD_HASH', defaultValue: 'local');
    const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    
    // Log do início
    debugPrint('=== STARTING APP ===');
    debugPrint('BUILD_HASH: $buildHash');
    debugPrint('APP_ENV: $appEnv');

    setWebTitle('AçoPlus - Planejamento e controle de Produção');
    RouteConfig.setConfig();
    await initializeDateFormatting('pt_BR');

    // Interceptar todos os erros do Flutter na tela
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Crash no Widget (Build: $buildHash)\n\n${details.exception}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    };

    // Interceptar erros globais/assíncronos que escapam do try-catch
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Unhandled Async Error: $error');
      runApp(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Unhandled Async Crash (Build: $buildHash)\n\n$error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ));
      return true;
    };

    // Inicializa apenas o Supabase (obrigatório antes do runApp)
    await Service.initCoreServices();

    // Sobe o app imediatamente
    runApp(const App());

    // Carrega dados do banco em background
    Service.initAplicationServices()
        .then((_) => appCtrl.onInit())
        .catchError((e) => debugPrint('Init background error: $e'));
  } catch (e, stack) {
    debugPrint('Critical Error during main: $e');
    log('Stack Trace', stackTrace: stack);
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Erro ao iniciar o AçoPlus (Build: const String.fromEnvironment(\'BUILD_HASH\'))\n\n$e',
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
