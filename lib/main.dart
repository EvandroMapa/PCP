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
    setWebTitle('AçoPlus');
    RouteConfig.setConfig();
    await initializeDateFormatting('pt_BR');
    await Service.initAplicationServices();
    await appCtrl.onInit();
    runApp(const App());
  } catch (e, stack) {
    print('Critical Error during main: $e');
    print(stack);
    // Fallback para não deixar a tela branca e mostrar o erro
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Erro ao iniciar o AçoPlus: $e', 
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    ));
  }
}
