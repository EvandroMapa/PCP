import 'dart:html' as html;

import 'package:aco_plus/app/core/components/app_bottom_nav.dart';
import 'package:aco_plus/app/core/components/drawer/app_drawer.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/enums/app_module.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/kanban/kanban_controller.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BasePage extends StatefulWidget {
  const BasePage({super.key});

  @override
  State<BasePage> createState() => _BasePageState();
}

class _BasePageState extends State<BasePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    baseCtrl.onInit().then((_) {
      kanbanCtrl.onInit();
    });
    // Fullscreen automático para operadores (somente web)
    if (kIsWeb && usuario.isOperador) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _entrarFullscreen();
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    if (kIsWeb && usuario.isOperador) {
      _sairFullscreen();
    }
    super.dispose();
  }

  void _entrarFullscreen() {
    try {
      html.document.documentElement?.requestFullscreen();
    } catch (_) {}
  }

  void _sairFullscreen() {
    try {
      html.document.exitFullscreen();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamOut<AppModule>(
      stream: baseCtrl.moduleStream.listen,
      builder: (context, module) => Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        bottomNavigationBar: usuario.isOperador ? const AppBottomNav() : null,
        appBar: module.appBar(context) ??
            AppBar(
              iconTheme: const IconThemeData(color: Colors.white, size: 20),
              // Botão de sair do fullscreen para operadores
              leading: usuario.isOperador
                  ? IconButton(
                      tooltip: 'Sair do modo tela cheia',
                      onPressed: _sairFullscreen,
                      icon: const Icon(Icons.fullscreen_exit_rounded,
                          color: Colors.white, size: 22),
                    )
                  : null,
              title: Text(
                module.label,
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                StreamOut<List<Widget>>(
                  stream: baseCtrl.appBarActionsStream.listen,
                  builder: (_, actions) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < actions.length; i++) ...[
                        actions[i],
                        if (i < actions.length - 1) const W(8),
                      ],
                      const W(8),
                    ],
                  ),
                ),
              ],
              backgroundColor: Theme.of(context).primaryColor,
            ),
        body: module.widget,
      ),
    );
  }
}
