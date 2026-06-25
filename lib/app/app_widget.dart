import 'package:aco_plus/app/core/client/firestore/collections/usuario/models/usuario_model.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/router/route_config.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_theme.dart';
import 'package:aco_plus/app/modules/base/base_page.dart';
import 'package:aco_plus/app/modules/sign/ui/sign_up_page.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mentions/flutter_mentions.dart';
import 'package:overlay_support/overlay_support.dart';

import 'app_controller.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AppController _appController = AppController();

  @override
  void initState() {
    _appController.onInit();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Portal(
      child: OverlaySupport(
        child: MaterialApp.router(
          color: AppColors.primaryMain,
          theme: AppTheme.theme,
          debugShowCheckedModeBanner: false,
          title: 'AçoPlus - Planejamento e controle de Produção',
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('pt', 'BR'),
            Locale('en', 'US'),
          ],
          locale: const Locale('pt', 'BR'),
          routeInformationParser: RouteConfig.config.routeInformationParser,
          routeInformationProvider: RouteConfig.config.routeInformationProvider,
          routerDelegate: RouteConfig.config.routerDelegate,
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamOutNull<UsuarioModel?>(
      stream: usuarioCtrl.usuarioStream.listen,
      loading: const Center(child: CircularProgressIndicator()),
      child: (_, data) {
        if (data == null) return const SignUpPage();

        // Perfil exclusivo → bloqueia acesso ao app principal
        if (data.isExclusivo) {
          // Monta lista de rotas permitidas
          final rotas = <String>[];
          if (data.temAcessoOperador) rotas.add('/operador');
          if (data.temAcessoArmador) rotas.add('/armador');
          if (data.temAcessoGerencial) rotas.add('/gerencial');

          return _TelaAcessoExclusivo(
            nomeUsuario: data.nome,
            rotas: rotas,
          );
        }

        return const BasePage();
      },
    );
  }
}

/// Tela exibida quando um perfil exclusivo tenta acessar a rota principal.
/// Mostra as rotas dedicadas disponíveis e botão de logout.
class _TelaAcessoExclusivo extends StatelessWidget {
  final String nomeUsuario;
  final List<String> rotas;

  const _TelaAcessoExclusivo({
    required this.nomeUsuario,
    required this.rotas,
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
                  color: AppColors.primaryMain.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions, size: 48, color: AppColors.primaryMain),
              ),
              const SizedBox(height: 24),
              const Text(
                'Acesso Exclusivo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Olá, $nomeUsuario!\n\n'
                'Seu perfil possui acesso exclusivo.\n'
                'Utilize uma das rotas abaixo:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha(150),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ...rotas.map((rota) => Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withAlpha(20)),
                    ),
                    child: SelectableText(
                      rota,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )),
              const SizedBox(height: 24),
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
