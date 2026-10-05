import 'package:aco_plus/app/core/client/firestore/collections/notificacao/notificacao_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/user_permission_type.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/enums/usuario_role.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/enums/app_module.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/base/base_controller.dart';
import 'package:aco_plus/app/modules/config/config_page.dart';
import 'package:aco_plus/app/modules/notificacao/notificacao_controller.dart';
import 'package:aco_plus/app/modules/notificacao/ui/notificacoes_page.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:aco_plus/app/core/utils/app_env.dart';
import 'package:aco_plus/app/core/utils/logo_helper.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: StreamOut<AppModule>(
        stream: baseCtrl.moduleStream.listen,
        builder: (_, module) {
          // Use StreamBuilder directly so we can fall back to empty list
          return StreamBuilder(
            stream: FirestoreClient.notificacoes.dataStream.listen,
            builder: (context, snapshot) {
              final List<NotificacaoModel> notificacoes;
              if (snapshot.hasData &&
                  snapshot.data != null &&
                  usuarioCtrl.usuario != null) {
                notificacoes = notificacaoCtrl.getNotificaoByUsuario(
                  snapshot.data!,
                  usuarioCtrl.usuario!,
                );
              } else {
                notificacoes = [];
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        AppDrawerHeader(notificacoes: notificacoes),
                        AppDrawerNotOperatorList(
                          module: module,
                          notificacoes: notificacoes,
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    onTap: () => usuarioCtrl.clearCurrentUser(),
                    leading: Icon(Icons.exit_to_app, color: AppColors.error),
                    title:
                        Text('Sair', style: TextStyle(color: AppColors.error)),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class AppDrawerArmadorList extends StatelessWidget {
  final AppModule module;
  final List<NotificacaoModel> notificacoes;
  const AppDrawerArmadorList({
    super.key,
    required this.module,
    required this.notificacoes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppDrawerItem(
          item: AppModule.armacao,
          module: module,
          notificacoes: notificacoes,
        ),
      ],
    );
  }
}

class AppDrawerOperatorList extends StatelessWidget {
  final AppModule module;
  final List<NotificacaoModel> notificacoes;
  const AppDrawerOperatorList({
    super.key,
    required this.module,
    required this.notificacoes,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppDrawerItem(
          item: AppModule.ordens,
          module: module,
          notificacoes: notificacoes,
        ),
        AppDrawerItem(
          item: AppModule.materiaPrima,
          module: module,
          notificacoes: notificacoes,
        ),
      ],
    );
  }
}

class AppDrawerNotOperatorList extends StatefulWidget {
  final AppModule module;
  final List<NotificacaoModel> notificacoes;

  const AppDrawerNotOperatorList({
    super.key,
    required this.module,
    required this.notificacoes,
  });

  @override
  State<AppDrawerNotOperatorList> createState() =>
      _AppDrawerNotOperatorListState();
}

class _AppDrawerNotOperatorListState extends State<AppDrawerNotOperatorList> {
  static const _pedidos = 'Pedidos';
  static const _producao = 'Produção';
  static const _estoque = 'Estoque';
  static const _cadastros = 'Cadastros';

  static const _grupos = {
    _pedidos: [AppModule.kanban, AppModule.pedidos],
    _producao: [
      AppModule.ordens,
      AppModule.planoCorte,
      AppModule.pontas,
      AppModule.materiaPrima,
      AppModule.relatoriosProducao,
    ],
    _estoque: [
      AppModule.estoqueSaldo,
      AppModule.pedidoCompra,
    ],
    _cadastros: [
      AppModule.cliente,
      AppModule.produtos,
      AppModule.fabricantes,
      AppModule.equipamentos
    ],
  };

  String? _expandedTitle;

  String? _grupoAtivo(AppModule m) {
    for (final e in _grupos.entries) {
      if (e.value.contains(m)) return e.key;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _expandedTitle = _grupoAtivo(widget.module);
  }

  @override
  void didUpdateWidget(AppDrawerNotOperatorList old) {
    super.didUpdateWidget(old);
    if (old.module != widget.module) {
      final grupo = _grupoAtivo(widget.module);
      if (grupo != null) setState(() => _expandedTitle = grupo);
    }
  }

  void _onExpand(String title, bool expanded) {
    setState(() => _expandedTitle = expanded ? title : null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Gestão à Vista
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.black.withValues(alpha: 0.1)),
            ),
          ),
          child: AppDrawerItem(
            item: AppModule.dashboard,
            module: widget.module,
            notificacoes: widget.notificacoes,
          ),
        ),

        // 2. Pedidos (Kanban + Listagem)
        AppDrawerDropdown(
          key: ValueKey('$_pedidos-${_expandedTitle == _pedidos}'),
          icon: Symbols.receipt_long,
          title: _pedidos,
          items: _grupos[_pedidos]!,
          module: widget.module,
          notificacoes: widget.notificacoes,
          isExpanded: _expandedTitle == _pedidos,
          onExpansionChanged: (v) => _onExpand(_pedidos, v),
        ),
        // 3. Produção
        AppDrawerDropdown(
          key: ValueKey('$_producao-${_expandedTitle == _producao}'),
          icon: Symbols.factory,
          title: _producao,
          items: _grupos[_producao]!,
          module: widget.module,
          notificacoes: widget.notificacoes,
          isExpanded: _expandedTitle == _producao,
          onExpansionChanged: (v) => _onExpand(_producao, v),
        ),
        // 4. Estoque
        AppDrawerDropdown(
          key: ValueKey('$_estoque-${_expandedTitle == _estoque}'),
          icon: Symbols.warehouse,
          title: _estoque,
          items: _grupos[_estoque]!,
          module: widget.module,
          notificacoes: widget.notificacoes,
          isExpanded: _expandedTitle == _estoque,
          onExpansionChanged: (v) => _onExpand(_estoque, v),
        ),
        // 5. Cadastros
        AppDrawerDropdown(
          key: ValueKey('$_cadastros-${_expandedTitle == _cadastros}'),
          icon: Symbols.folder_open,
          title: _cadastros,
          items: _grupos[_cadastros]!,
          module: widget.module,
          notificacoes: widget.notificacoes,
          isExpanded: _expandedTitle == _cadastros,
          onExpansionChanged: (v) => _onExpand(_cadastros, v),
        ),
      ],
    );
  }
}

class AppDrawerHeader extends StatelessWidget {
  const AppDrawerHeader({super.key, required this.notificacoes});

  final List<NotificacaoModel> notificacoes;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.all(16),
          width: double.maxFinite,
          height: 200,
          decoration: BoxDecoration(color: AppColors.primaryMain),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo inteiro em quadrado (o círculo cortava parte do "2")
              Container(
                width: 64,
                height: 64,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: LogoHelper.logoWidget(width: 52, height: 52),
              ),
              Spacer(),
              Text(
                usuario.nome,
                style: AppCss.minimumRegular.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              H(2),
              Text(
                usuario.tipo?.nome ?? usuario.role.label ?? usuario.email,
                style: AppCss.minimumRegular.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (usuario.isAdmin) ...[
                if (kIsDev)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      kBuildHash,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (kIsDev) const W(4),
                // Versão sempre visível para admin
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    kVersaoLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const W(4),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    push(context, const ConfigPage());
                  },
                  child: const Icon(Icons.settings, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
        if (!usuario.isOperador)
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: () => push(context, NotificacoesPage()),
              child: Padding(
                padding: EdgeInsets.all(16).add(EdgeInsets.only(bottom: 16)),
                child: Stack(
                  children: [
                    Icon(Icons.notifications, color: Colors.white),
                    if (notificacoes.isNotEmpty)
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AppDrawerDropdown extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<AppModule> items;
  final AppModule module;
  final List<NotificacaoModel> notificacoes;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;

  const AppDrawerDropdown({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    required this.module,
    required this.notificacoes,
    required this.isExpanded,
    required this.onExpansionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ativo = items.contains(module);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.black.withValues(alpha: 0.1)),
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        onExpansionChanged: onExpansionChanged,
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColors.neutralDark,
        collapsedIconColor: AppColors.neutralDark,
        leading: Icon(icon, color: AppColors.neutralDark),
        title: Text(
          title,
          style: TextStyle(
            color: AppColors.black,
            fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        children: items
            .map((e) => AppDrawerItem(
                  item: e,
                  module: module,
                  notificacoes: notificacoes,
                  recuado: true,
                ))
            .toList(),
      ),
    );
  }
}

class AppDrawerItem extends StatelessWidget {
  const AppDrawerItem({
    super.key,
    required this.item,
    required this.module,
    required this.notificacoes,
    this.recuado = false,
  });

  final AppModule item;
  final AppModule module;
  final List<NotificacaoModel> notificacoes;

  /// Itens dentro de um grupo ficam recuados, para separar grupo de item
  final bool recuado;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        bool isEnabled = true;
        if (usuario.isArmador) {
          isEnabled = item == AppModule.armacao;
        } else if (usuario.isOperador) {
          isEnabled =
              item == AppModule.ordens || item == AppModule.materiaPrima;
        } else {
          switch (item) {
            case AppModule.cliente:
              isEnabled = usuario.permission.cliente.contains(
                UserPermissionType.read,
              );

              break;
            case AppModule.pedidos:
              isEnabled = usuario.permission.pedido.contains(
                UserPermissionType.read,
              );

              break;
            case AppModule.ordens:
              isEnabled = usuario.permission.ordem.contains(
                UserPermissionType.read,
              );

              break;
            case AppModule.steps:
              isEnabled = usuario.isAdmin;

              break;
            case AppModule.tags:
              isEnabled = usuario.isAdmin;
              break;
            default:
          }
        }
        if (!isEnabled) return const SizedBox();
        final ativo = item == module;
        // Item ativo: fundo vermelho-claro, faixa e ícone no vermelho da marca
        return Container(
          decoration: BoxDecoration(
            color: ativo ? AppColors.brandSoft : null,
            border: Border(
              left: BorderSide(
                color: ativo ? AppColors.brand : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: ListTile(
            dense: recuado,
            contentPadding: EdgeInsets.only(left: recuado ? 36 : 13, right: 16),
            onTap: () {
              pop(context);
              baseCtrl.moduleStream.add(item);
            },
            leading: Icon(
              item.icon,
              size: recuado ? 20 : 24,
              color: ativo ? AppColors.brand : AppColors.neutralDark,
            ),
            title: Text(
              item.label,
              style: TextStyle(
                fontSize: recuado ? 14 : 15,
                color: AppColors.black,
                fontWeight: ativo ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            trailing: item.standalonePath != null
                ? IconButton(
                    onPressed: () {
                      pop(context);
                      openInNewTab(item.standalonePath!);
                    },
                    icon: Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: ativo ? AppColors.brand : Colors.grey[400],
                    ),
                    tooltip: 'Abrir em nova janela',
                  )
                : null,
          ),
        );
      },
    );
  }
}
