import 'dart:html' as html;

import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Scaffold para rotas standalone (/operador, /armador, /gerencial, etc.)
/// Adiciona um header com título, nome do usuário, botão de fullscreen e logout.
class StandaloneScaffold extends StatefulWidget {
  final String titulo;
  final IconData icone;
  final Widget child;
  final VoidCallback? onRefresh;

  const StandaloneScaffold({
    super.key,
    required this.titulo,
    required this.icone,
    required this.child,
    this.onRefresh,
  });

  @override
  State<StandaloneScaffold> createState() => _StandaloneScaffoldState();
}

class _StandaloneScaffoldState extends State<StandaloneScaffold> {
  bool _emFullscreen = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      html.document.onFullscreenChange.listen((_) {
        final estaFullscreen = html.document.fullscreenElement != null;
        if (mounted) setState(() => _emFullscreen = estaFullscreen);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _entrarFullscreen();
      });
    }
  }

  @override
  void dispose() {
    if (kIsWeb) _sairFullscreen();
    super.dispose();
  }

  void _entrarFullscreen() {
    try {
      final el = html.document.documentElement ?? html.document.body;
      el?.requestFullscreen();
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
    _emFullscreen ? _sairFullscreen() : _entrarFullscreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutralLightest,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final usuario = usuarioCtrl.usuario;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 8,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryMain,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
          Icon(widget.icone, color: Colors.white.withAlpha(200), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.titulo,
                  style: AppCss.mediumBold.setSize(16).setColor(Colors.white),
                ),
                if (usuario != null)
                  Text(
                    usuario.nome,
                    style: AppCss.minimumRegular
                        .setSize(11)
                        .setColor(Colors.white.withAlpha(180)),
                  ),
              ],
            ),
          ),
          if (widget.onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
              onPressed: widget.onRefresh,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Atualizar dados',
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white, size: 20),
            onPressed: () => _onLogout(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Sair',
          ),
        ],
      ),
    );
  }

  Future<void> _onLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair da conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await usuarioCtrl.clearCurrentUser();
    }
  }
}
