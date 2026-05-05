import 'package:aco_plus/app/app_controller.dart';
import 'package:aco_plus/app/app_widget.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/modules/sign/ui/sign_up_page.dart';
import 'package:aco_plus/app/core/router/flutter_web_plugins_shim.dart'
    if (dart.library.html) 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:aco_plus/app/modules/kanban/ui/kanban_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordens_page.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedidos_page.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_acompanhamento_page.dart';
import 'package:aco_plus/app/modules/totem/ui/totem_box_page.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// if (dart.library.html) 'package:flutter_web_plugins/flutter_web_plugins.dart';

///acompanhamento/pedidos/aJo8pjTvyoplGQkmRjda8NT1H
class RouteConfig {
  static late RouterConfig<Object> config;
  static void setConfig() {
    usePathUrlStrategy();
    config = GoRouter(
      initialLocation: '/',
      navigatorKey: appCtrl.key,
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomePage()),
        ),
        GoRoute(
          path: '/kanban',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GlobalLoadingWrapper(child: KanbanPage(standalone: true)),
          ),
        ),
        GoRoute(
          path: '/pedidos',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GlobalLoadingWrapper(child: PedidosPage(standalone: true)),
          ),
        ),
        GoRoute(
          path: '/ordens',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GlobalLoadingWrapper(child: OrdensPage(standalone: true)),
          ),
        ),
        GoRoute(
          path: '/acompanhamento/pedidos/:id',
          pageBuilder: (context, state) => NoTransitionPage(
            child: PedidoAcompanhamentoPage(id: state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/totem',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GlobalLoadingWrapper(child: TotemBoxPage()),
          ),
        ),

      ],
    );
  }
}

class GlobalLoadingWrapper extends StatelessWidget {
  final Widget child;
  const GlobalLoadingWrapper({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UsuarioModel?>(
      stream: usuarioCtrl.usuarioStream.listen,
      initialData: usuarioCtrl.usuarioStream.valueOrNull,
      builder: (context, snapshot) {
        // Se já temos um usuário (seja via initialData ou via stream)
        if (snapshot.hasData && snapshot.data != null) {
          return child;
        }

        // Se a conexão ainda tá esperando (stream não emitiu nada)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Usuário é null → mostra login
        return const SignUpPage();
      },
    );
  }
}
