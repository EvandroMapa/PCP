import 'dart:html' as html;

import 'package:aco_plus/app/core/components/app_bottom_nav.dart';
import 'package:aco_plus/app/core/components/drawer/app_drawer.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/enums/app_module.dart';
import 'package:aco_plus/app/modules/backup/backup_scheduler_service.dart';
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
  bool _emFullscreen = false;

  @override
  void initState() {
    baseCtrl.onInit().then((_) {
      kanbanCtrl.onInit();
    });
    // Inicia o agendador de backup para QUALQUER usuário logado,
    // independentemente de visitar a tela de Backups.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BackupSchedulerService().start(context);
    });
    if (kIsWeb && usuario.isOperador) {
      // Escuta mudanças de fullscreen (inclusive saída por ESC)
      html.document.onFullscreenChange.listen((_) {
        final estaFullscreen = html.document.fullscreenElement != null;
        if (mounted) setState(() => _emFullscreen = estaFullscreen);
      });
      // Entra em fullscreen automaticamente
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _entrarFullscreen();
      });
    }
    super.initState();
  }

  @override
  void dispose() {
    BackupSchedulerService().stop();
    if (kIsWeb && usuario.isOperador) {
      _sairFullscreen();
    }
    super.dispose();
  }

  void _entrarFullscreen() {
    try {
      final el = html.document.documentElement ?? html.document.body;
      el?.requestFullscreen();
      // Atualiza estado otimisticamente (o listener cobre o ESC)
      if (mounted) setState(() => _emFullscreen = true);
    } catch (e) {
      debugPrint('Fullscreen error: $e');
    }
  }

  void _sairFullscreen() {
    try {
      html.document.exitFullscreen();
      if (mounted) setState(() => _emFullscreen = false);
    } catch (e) {
      debugPrint('Exit fullscreen error: $e');
    }
  }

  void _toggleFullscreen() {
    if (_emFullscreen) {
      _sairFullscreen();
    } else {
      _entrarFullscreen();
    }
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
              // Botão toggle fullscreen para operadores
              leading: usuario.isOperador
                  ? IconButton(
                      tooltip: _emFullscreen
                          ? 'Sair do modo tela cheia'
                          : 'Entrar em tela cheia',
                      onPressed: _toggleFullscreen,
                      icon: Icon(
                        _emFullscreen
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
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
