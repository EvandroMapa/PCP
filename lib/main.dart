import 'dart:developer';

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
    setWebTitle('AçoPlus - Planejamento e controle de Produção');
    RouteConfig.setConfig();
    await initializeDateFormatting('pt_BR');

    // Inicializa apenas rererero Supabase (obrigatório antes do runApp)
    await Service.initCoreServices();

    // Sobe o app imediatamente — sem esperar queries ...lentas
    runApp(const App());

    // Carrega dados do banco em background e inicia o controller após teste
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
              'Erro ao iniciar o AçoPlus: $e',
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
