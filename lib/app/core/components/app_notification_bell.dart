import 'dart:convert';

import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/notificacao/notificacao_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/components/h.dart';
import 'package:aco_plus/app/core/components/w.dart';
import 'package:aco_plus/app/core/extensions/date_ext.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/core/utils/app_css.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/notificacao/notificacao_controller.dart';
import 'package:aco_plus/app/modules/notificacao/ui/notificacoes_page.dart';
import 'package:aco_plus/app/modules/pedido/ui/pedido_page.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/material.dart';

/// Botão de notificações global (Sino com badge de contador) para ser usado nas barras superiores.
class AppNotificationBell extends StatelessWidget {
  final Color? iconColor;

  const AppNotificationBell({super.key, this.iconColor});

  @override
  Widget build(BuildContext context) {
    if (usuarioCtrl.usuario == null) return const SizedBox.shrink();

    return StreamBuilder<List<NotificacaoModel>>(
      stream: FirestoreClient.notificacoes.dataStream.listen,
      builder: (context, snapshot) {
        final List<NotificacaoModel> todas = snapshot.data ?? FirestoreClient.notificacoes.data;
        final nomeUsuario = usuarioCtrl.usuario?.nome ?? '';

        final List<NotificacaoModel> minhasNotificacoes = todas.where((e) {
          try {
            return e.description.toCompare.contains(nomeUsuario.toCompare);
          } catch (_) {
            return false;
          }
        }).toList();

        final naoLidas = minhasNotificacoes.where((e) => !e.viewed).toList();
        final int countNaoLidas = naoLidas.length;

        return Tooltip(
          message: countNaoLidas > 0
              ? 'Notificações ($countNaoLidas não lida${countNaoLidas > 1 ? 's' : ''})'
              : 'Notificações',
          preferBelow: false,
          waitDuration: const Duration(milliseconds: 300),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _abrirPainelNotificacoes(context, minhasNotificacoes, countNaoLidas),
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    countNaoLidas > 0
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_outlined,
                    color: iconColor ?? Colors.white,
                    size: 20,
                  ),
                  if (countNaoLidas > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: iconColor != null ? Colors.white : AppColors.primaryMain,
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          countNaoLidas > 99 ? '99+' : '$countNaoLidas',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _abrirPainelNotificacoes(
    BuildContext context,
    List<NotificacaoModel> notificacoes,
    int countNaoLidas,
  ) {
    notificacoes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final displayList = notificacoes.take(15).toList();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (dialogCtx) => Stack(
        children: [
          Positioned(
            top: 55,
            right: 16,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              child: Container(
                width: 390,
                constraints: const BoxConstraints(maxHeight: 520),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Cabeçalho do Popover ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.notifications, color: AppColors.primaryMain, size: 20),
                          const W(8),
                          Text('Notificações', style: AppCss.mediumBold),
                          if (countNaoLidas > 0) ...[
                            const W(8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$countNaoLidas nova${countNaoLidas > 1 ? 's' : ''}',
                                style: AppCss.minimumBold.setColor(Colors.red[700]!),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (countNaoLidas > 0)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                await notificacaoCtrl.setViewed();
                                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              },
                              child: Text(
                                'Ler todas',
                                style: AppCss.minimumBold.setColor(AppColors.primaryMain),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),

                    // ── Lista de Notificações ──
                    Flexible(
                      child: displayList.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_none_rounded,
                                      size: 40, color: Colors.grey[400]),
                                  const H(8),
                                  Text(
                                    'Nenhuma notificação por enquanto',
                                    style: AppCss.minimumRegular.setColor(Colors.grey[600]!),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              itemCount: displayList.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                final notif = displayList[index];
                                return InkWell(
                                  onTap: () => _aoClicarNotificacao(dialogCtx, notif),
                                  child: Container(
                                    color: notif.viewed
                                        ? Colors.transparent
                                        : AppColors.primaryMain.withValues(alpha: 0.04),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Ponto de não lida
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4, right: 10),
                                          child: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: notif.viewed
                                                  ? Colors.transparent
                                                  : AppColors.primaryMain,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                notif.title,
                                                style: AppCss.minimumBold.setColor(
                                                  notif.viewed
                                                      ? const Color(0xFF334155)
                                                      : const Color(0xFF0F172A),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const H(3),
                                              Text(
                                                notif.description,
                                                style: AppCss.minimumRegular
                                                    .setColor(const Color(0xFF64748B)),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const H(4),
                                              Text(
                                                notif.createdAt.textHour(),
                                                style: AppCss.minimumRegular
                                                    .setSize(10)
                                                    .setColor(const Color(0xFF94A3B8)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // ── Rodapé do Popover ──
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    InkWell(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                      onTap: () {
                        Navigator.pop(dialogCtx);
                        push(context, const NotificacoesPage());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Text(
                          'Ver histórico completo',
                          style: AppCss.minimumBold.setColor(AppColors.primaryMain),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _aoClicarNotificacao(BuildContext context, NotificacaoModel notif) {
    Navigator.pop(context);

    // Marca como lida
    if (!notif.viewed) {
      notif.viewed = true;
      FirestoreClient.notificacoes.update(notif);
    }

    // Tenta abrir o pedido vinculado
    try {
      final payload = jsonDecode(notif.payload);
      final pedidoId = payload['id']?.toString() ?? '';
      if (pedidoId.isNotEmpty) {
        final pedido = BackendClient.pedidos.getById(pedidoId);
        if (!pedido.localizador.startsWith('NOTFOUND')) {
          push(context, PedidoPage(pedido: pedido, reason: PedidoInitReason.page));
        }
      }
    } catch (_) {}
  }
}
