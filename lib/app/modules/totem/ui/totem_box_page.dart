import 'package:aco_plus/app/core/client/firestore/collections/box/models/box_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/patio/models/patio_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/components/stream_out.dart';
import 'package:aco_plus/app/core/utils/app_colors.dart';
import 'package:aco_plus/app/modules/usuario/usuario_controller.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aco_plus/app/modules/totem/utils/totem_fullscreen.dart';

class TotemBoxPage extends StatefulWidget {
  const TotemBoxPage({super.key});

  @override
  State<TotemBoxPage> createState() => _TotemBoxPageState();
}

class _TotemBoxPageState extends State<TotemBoxPage> {
  String? _boxId;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarBoxSalvo();
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Future<void> _carregarBoxSalvo() async {
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString('totem_box_id');
    if (salvo != null && salvo.isNotEmpty) {
      // Verificar se o box ainda existe
      final existe = FirestoreClient.boxes.data.any((b) => b.id == salvo);
      if (existe) {
        TotemFullscreen.entrar();
        setState(() {
          _boxId = salvo;
          _carregando = false;
        });
        return;
      }
    }
    setState(() => _carregando = false);
  }

  Future<void> _selecionarBox(String boxId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('totem_box_id', boxId);
    TotemFullscreen.entrar();
    setState(() => _boxId = boxId);
  }



  Future<void> _sairDoTotem() async {
    final emailCtrl = TextEditingController();
    final senhaCtrl = TextEditingController();

    void tentarLogin(BuildContext ctx) {
      final valido = _validarLoginAdmin(emailCtrl.text, senhaCtrl.text);
      if (!valido) {
        NotificationService.showNegative(
          'Acesso negado',
          'Usuário ou senha inválidos, ou sem permissão de administrador.',
        );
        return;
      }
      Navigator.pop(ctx, true);
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.lock_outline, size: 36, color: AppColors.primaryMain),
        title: const Text('Login de Administrador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Digite as credenciais de um administrador para sair do modo totem.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              onSubmitted: (_) => FocusScope.of(ctx).nextFocus(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: senhaCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              onSubmitted: (_) => tentarLogin(ctx),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryMain),
            onPressed: () => tentarLogin(ctx),
            child: const Text('Entrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      TotemFullscreen.sair();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('totem_box_id');
      setState(() => _boxId = null);
    }
  }

  bool _validarLoginAdmin(String email, String senha) {
    final admins = BackendClient.usuarios.data.where((u) => u.isAdmin).toList();
    return admins.any((u) =>
        u.email.toLowerCase().trim() == email.toLowerCase().trim() &&
        u.senha.toLowerCase().trim() == senha.toLowerCase().trim());
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(
        backgroundColor: Color(0xFF1E293B),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_boxId == null) {
      return _telaSetup();
    }

    return _telaTotem();
  }

  // ═══════════════════════════════════════════════════
  //  TELA DE SETUP — seleção do box
  // ═══════════════════════════════════════════════════
  Widget _telaSetup() {
    final usuario = usuarioCtrl.usuario;
    if (usuario == null || !usuario.isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E293B),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                'Acesso restrito a administradores',
                style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 8),
              Text(
                'Faça login com uma conta de administrador para configurar o totem.',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.4)),
              ),
            ],
          ),
        ),
      );
    }

    final patios = FirestoreClient.patios.data.toList();
    patios.sort((a, b) => a.nome.compareTo(b.nome));

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: Stack(
        children: [
          // Botão tela cheia
          Positioned(
            top: 16, right: 16,
            child: IconButton(
              onPressed: TotemFullscreen.entrar,
              icon: const Icon(Icons.fullscreen, color: Colors.white38, size: 32),
              tooltip: 'Tela cheia',
            ),
          ),
          Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tv, size: 48, color: AppColors.primaryMain),
              const SizedBox(height: 16),
              const Text(
                'Configurar Totem',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Selecione o box que este tablet representará',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 32),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: patios.map((patio) {
                    final boxes = FirestoreClient.boxes.data
                        .where((b) => b.patioId == patio.id)
                        .toList();
                    boxes.sort((a, b) => a.nome.compareTo(b.nome));
                    if (boxes.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            patio.nome.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.4),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: boxes.map((box) {
                            return GestureDetector(
                              onTap: () => _selecionarBox(box.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: box.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color:
                                          box.color.withValues(alpha: 0.4)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Box ${box.nome}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: box.color,
                                      ),
                                    ),
                                    Text(
                                      'até ${box.maxPedidos} pedido${box.maxPedidos > 1 ? 's' : ''}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: box.color
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  TELA TOTEM — exibição dos pedidos
  // ═══════════════════════════════════════════════════
  Widget _telaTotem() {
    return StreamOut(
      stream: FirestoreClient.pedidos.pedidosUnarchivedsStream.listen,
      builder: (_, __) => StreamOut(
        stream: FirestoreClient.pedidoBoxes.dataStream.listen,
        builder: (_, __) => _buildTotemContent(),
      ),
    );
  }

  Widget _buildTotemContent() {
    final box = FirestoreClient.boxes.data
        .where((b) => b.id == _boxId)
        .firstOrNull;

    if (box == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1E293B),
        body: GestureDetector(
          onTap: _sairDoTotem,
          child: const Center(
            child: Text('Box não encontrado.',
                style: TextStyle(color: Colors.white54, fontSize: 18)),
          ),
        ),
      );
    }

    final patio = FirestoreClient.patios.data
        .where((p) => p.id == box.patioId)
        .firstOrNull;

    // Pedidos alocados neste box
    final alocacoes = FirestoreClient.pedidoBoxes.data
        .where((pb) => pb.boxId == box.id)
        .toList();

    final pedidos = alocacoes
        .map((pb) => FirestoreClient.pedidos.data
            .where((p) => p.id == pb.pedidoId && !p.isArchived)
            .firstOrNull)
        .where((p) => p != null)
        .cast<PedidoModel>()
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: GestureDetector(
        onTap: _sairDoTotem,
        child: Column(
          children: [
            // Header do box
            _headerBox(box, patio, pedidos.length),
            // Conteúdo: pedidos
            Expanded(
              child: pedidos.isEmpty
                  ? _slotVazio(box)
                  : _gridPedidos(pedidos, box),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerBox(BoxModel box, PatioModel? patio, int qtdPedidos) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: BoxDecoration(
        color: box.color.withValues(alpha: 0.12),
        border: Border(
          bottom: BorderSide(color: box.color.withValues(alpha: 0.25), width: 2),
        ),
      ),
      child: Stack(
        children: [
          // Conteúdo centralizado
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BOX ${box.nome}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 75,
                    fontWeight: FontWeight.w900,
                    color: box.color,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (patio != null) ...[
                      Text(
                        patio.nome,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: qtdPedidos > 0
                            ? box.color.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: qtdPedidos > 0
                              ? box.color.withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        '$qtdPedidos / ${box.maxPedidos}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: qtdPedidos > 0
                              ? box.color.withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Botão tela cheia — canto superior direito
          Positioned(
            top: 0, right: 0,
            child: GestureDetector(
              onTap: TotemFullscreen.entrar,
              child: Icon(Icons.fullscreen, size: 24, color: Colors.white.withValues(alpha: 0.15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotVazio(BoxModel box) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined,
              size: 80, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          Text(
            'Disponível',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w300,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridPedidos(List<PedidoModel> pedidos, BoxModel box) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;

        if (pedidos.length == 1) {
          return _pedidoCard(pedidos[0], box, grande: true);
        }

        // Múltiplos pedidos: divide a tela
        if (isLandscape) {
          // Landscape: colunas lado a lado
          return Row(
            children: pedidos.asMap().entries.map((entry) {
              final i = entry.key;
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: i < pedidos.length - 1
                        ? Border(
                            right: BorderSide(
                                color: Colors.white.withValues(alpha: 0.06),
                                width: 1),
                          )
                        : null,
                  ),
                  child: _pedidoCard(entry.value, box, grande: false),
                ),
              );
            }).toList(),
          );
        } else {
          // Portrait: linhas empilhadas
          return Column(
            children: pedidos.asMap().entries.map((entry) {
              final i = entry.key;
              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: i < pedidos.length - 1
                        ? Border(
                            bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.06),
                                width: 1),
                          )
                        : null,
                  ),
                  child: _pedidoCard(entry.value, box, grande: false),
                ),
              );
            }).toList(),
          );
        }
      },
    );
  }

  Widget _pedidoCard(PedidoModel pedido, BoxModel box,
      {required bool grande}) {
    final fontSize = grande ? 120.0 : 60.0;

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            pedido.localizador,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: box.color,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
