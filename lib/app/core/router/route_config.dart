import 'package:aco_plus/app/app_controller.dart';
import 'package:aco_plus/app/app_widget.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/modules/sign/ui/sign_up_page.dart';
import 'package:aco_plus/app/core/router/flutter_web_plugins_shim.dart'
    if (dart.library.html) 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:aco_plus/app/modules/armacao/ui/armacao_page.dart';
import 'package:aco_plus/app/modules/kanban/ui/kanban_page.dart';
import 'package:aco_plus/app/modules/ordem/ui/ordens_page.dart';
import 'package:aco_plus/app/modules/painel_gerencial/ui/painel_gerencial_page.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedidos_page.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_acompanhamento_page.dart';
import 'package:aco_plus/app/modules/totem/ui/totem_box_page.dart';
import 'package:aco_plus/app/core/components/standalone/standalone_scaffold.dart';

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
            child: GlobalLoadingWrapper(subtitulo: 'Kanban', child: KanbanPage(standalone: true)),
          ),
        ),
        GoRoute(
          path: '/pedidos',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GlobalLoadingWrapper(subtitulo: 'Pedidos', child: PedidosPage(standalone: true)),
          ),
        ),
        GoRoute(
          path: '/ordens',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GlobalLoadingWrapper(subtitulo: 'Ordens de Produção', child: OrdensPage(standalone: true)),
          ),
        ),
        GoRoute(
          path: '/gerencial',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GlobalLoadingWrapper(
              subtitulo: 'Gerencial',
              validarAcesso: _validarAdmin,
              mensagemAcessoNegado: 'Apenas administradores podem acessar o Painel Gerencial.',
              child: PainelGerencialPage(standalone: true),
            ),
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
            child: GlobalLoadingWrapper(subtitulo: 'Totem', child: TotemBoxPage()),
          ),
        ),
        GoRoute(
          path: '/operador',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GlobalLoadingWrapper(
              subtitulo: 'Operador',
              validarAcesso: _validarOperador,
              mensagemAcessoNegado: 'Apenas operadores podem acessar esta tela.',
              child: OrdensPage(standalone: true),
            ),
          ),
        ),
        GoRoute(
          path: '/armador',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: GlobalLoadingWrapper(
              subtitulo: 'Armador',
              validarAcesso: _validarArmador,
              mensagemAcessoNegado: 'Apenas armadores podem acessar esta tela.',
              child: StandaloneScaffold(
                titulo: 'Armação',
                icone: Icons.iron_rounded,
                child: ArmacaoPage(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Funções de validação de acesso (top-level para usar em const) ──

bool _validarOperador(UsuarioModel u) => u.temAcessoOperador;
bool _validarArmador(UsuarioModel u) => u.temAcessoArmador;
bool _validarAdmin(UsuarioModel u) => u.temAcessoGerencial;

class GlobalLoadingWrapper extends StatelessWidget {
  final Widget child;
  final String subtitulo;

  /// Função que valida se o usuário logado pode acessar esta rota.
  /// Se null, qualquer usuário logado tem acesso.
  final bool Function(UsuarioModel)? validarAcesso;

  /// Mensagem exibida quando o acesso é negado.
  final String mensagemAcessoNegado;

  const GlobalLoadingWrapper({
    required this.child,
    this.subtitulo = 'Controle de Produção',
    this.validarAcesso,
    this.mensagemAcessoNegado = 'Você não tem permissão para acessar esta tela.',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UsuarioModel?>(
      stream: usuarioCtrl.usuarioStream.listen,
      initialData: usuarioCtrl.usuarioStream.valueOrNull,
      builder: (context, snapshot) {
        // Se já temos um usuário (seja via initialData ou via stream)
        if (snapshot.hasData && snapshot.data != null) {
          final usuario = snapshot.data!;

          // Validar acesso se a rota exige
          if (validarAcesso != null && !validarAcesso!(usuario)) {
            return _TelaAcessoNegado(
              mensagem: mensagemAcessoNegado,
              subtitulo: subtitulo,
            );
          }

          return child;
        }

        // Se o app ainda não terminou de inicializar, mostra loading
        if (!appCtrl.isInitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Se a conexão ainda tá esperando (stream não emitiu nada)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Usuário é null → mostra login com subtítulo da rota
        return SignUpPage(subtitulo: subtitulo);
      },
    );
  }
}

/// Tela exibida quando o usuário não tem permissão para acessar a rota.
class _TelaAcessoNegado extends StatelessWidget {
  final String mensagem;
  final String subtitulo;

  const _TelaAcessoNegado({
    required this.mensagem,
    required this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Colors.orange[700],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Acesso Restrito',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha(150),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Usuário logado: ${usuarioCtrl.usuario?.nome ?? ""}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withAlpha(100),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => usuarioCtrl.clearCurrentUser(),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(
                    'Trocar de conta',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryMain,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
