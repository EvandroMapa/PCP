import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/models/pedido_step_model.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/models/step_model.dart';
import 'package:aco_plus/app/core/dialogs/confirm_dialog.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class MigracaoController {
  static final MigracaoController _instance = MigracaoController._();
  MigracaoController._();
  factory MigracaoController() => _instance;

  final AppStream<bool> isLoading = AppStream<bool>.seed(false);
  final AppStream<double> progress = AppStream<double>.seed(0);
  final AppStream<String> statusText = AppStream<String>.seed('');
  final AppStream<bool> importacaoConcluida = AppStream<bool>.seed(false);

  // Estados para Pedidos
  final AppStream<List<PedidoModel>> pedidosLegados = AppStream<List<PedidoModel>>.seed([]);
  final AppStream<List<PedidoModel>> pedidosSelecionados = AppStream<List<PedidoModel>>.seed([]);
  final AppStream<String> logMatchIds = AppStream<String>.seed('');
  final AppStream<List<StepModel>> etapasLegadas = AppStream<List<StepModel>>.seed([]);
  StepModel? etapaOrigemSelecionada;
  StepModel? etapaDestinoSelecionada;

  void init() {
    pedidosLegados.add(<PedidoModel>[]);
    pedidosSelecionados.add(<PedidoModel>[]);
    logMatchIds.add('');
    progress.add(0);
    statusText.add('');
    buscarEtapasLegadas();
  }

  Future<void> buscarEtapasLegadas() async {
    try {
      await _garantirFirebase();
      final snapshot = await FirebaseFirestore.instance.collection('steps').get();
      final steps = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return StepModel.fromMap(data);
      }).toList();
      steps.sort((a, b) => a.index.compareTo(b.index));
      etapasLegadas.add(steps);
    } catch (e) {
      debugPrint('Erro ao buscar etapas legadas: $e');
    }
  }

  bool _firebaseIniciado = false;
  Future<void> _garantirFirebase() async {
    if (_firebaseIniciado) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseIniciado = true;
    } on FirebaseException {
      // já estava inicializado
      _firebaseIniciado = true;
    } catch (_) {
      _firebaseIniciado = true;
    }
  }

  Future<void> buscarPedidosLegados(StepModel etapaOrigem) async {
    try {
      await _garantirFirebase();
      isLoading.add(true);
      pedidosLegados.add(<PedidoModel>[]);
      pedidosSelecionados.add(<PedidoModel>[]);
      statusText.add('Buscando pedidos da etapa ${etapaOrigem.name} no Firebase...');

      final snapshot = await FirebaseFirestore.instance
          .collection('pedidos')
          .get();

      List<PedidoModel> encontrados = [];
      debugPrint('=== MIGRAÇÃO: total docs Firebase = ${snapshot.docs.length} ===');
      if (snapshot.docs.isNotEmpty) {
        // Exibe os campos do primeiro doc para inspeção
        final primeiroDoc = snapshot.docs.first.data();
        debugPrint('=== CAMPOS DO 1º PEDIDO: ${primeiroDoc.keys.toList()} ===');
        debugPrint('=== STEPS FIELD: ${primeiroDoc["steps"]} ===');
        debugPrint('=== ETAPA BUSCADA ID: ${etapaOrigem.id} ===');
      }
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          final pedido = PedidoModel.fromMap(data);
          
          // Verifica se a última etapa bate pelo ID bruto (stepId)
          // O step resolvido pode ser 'step-not-found' porque FirestoreClient
          // aponta para o Supabase. Por isso usamos o stepId bruto.
          if (pedido.steps.isNotEmpty) {
            final ultimoStepId = pedido.steps.last.stepId;
            if (ultimoStepId == etapaOrigem.id) {
              encontrados.add(pedido);
            }
          }
        } catch (e) {
          debugPrint('Erro parse pedido legado ${doc.id}: $e');
        }
      }

      encontrados.sort((PedidoModel a, PedidoModel b) =>
          a.localizador.compareTo(b.localizador));
      pedidosLegados.add(encontrados);
      statusText.add('${encontrados.length} pedidos encontrados para esta etapa.');
      _verificarIntegridade(encontrados);
    } catch (e) {
      toast('Erro ao buscar pedidos legados: $e');
    } finally {
      isLoading.add(false);
    }
  }

  void togglePedido(PedidoModel pedido) {
    final list = pedidosSelecionados.value;
    if (list.contains(pedido)) {
      list.remove(pedido);
    } else {
      list.add(pedido);
    }
    pedidosSelecionados.update();
  }

  void toggleTodos() {
    if (pedidosSelecionados.value.length == pedidosLegados.value.length) {
      pedidosSelecionados.add(<PedidoModel>[]);
    } else {
      pedidosSelecionados.add(List.from(pedidosLegados.value));
    }
  }

  void _verificarIntegridade(List<PedidoModel> legados) {
    int produtosSemId = 0;
    int clientesSemId = 0;
    
    for (var pedido in legados) {
      // Verifica Cliente
      final clienteNoSupabase = BackendClient.clientes.getById(pedido.cliente.id);
      if (clienteNoSupabase.id.isEmpty) {
        clientesSemId++;
      }

      // Verifica Produtos
      for (var p in pedido.produtos) {
        final prodSupabase = BackendClient.produtos.getById(p.produto.id);
        if (prodSupabase.id == 'NOTFOUND' || prodSupabase.id.isEmpty) {
          produtosSemId++;
        }
      }
    }

    if (produtosSemId == 0 && clientesSemId == 0) {
      logMatchIds.add('✅ As chaves de Produtos e Clientes são IDÊNTICAS entre Firebase e Supabase.');
    } else {
      logMatchIds.add('⚠️ AVISO: $clientesSemId clientes e $produtosSemId produtos desse lote não foram encontrados no Supabase pelos IDs. Teremos que adaptar o importador para buscar por NOME.');
    }
  }

  Future<void> importarPedidosSelecionados(StepModel etapaDestino) async {
    final list = pedidosSelecionados.value;
    if (list.isEmpty) {
      toast('Selecione ao menos um pedido.');
      return;
    }

    final confirm = await showConfirmDialog(
      'Importar Pedidos',
      'Deseja importar ${list.length} pedidos para a etapa ${etapaDestino.name}?',
    );

    if (!confirm) return;

    try {
      isLoading.add(true);
      int salvos = 0;
      for (var i = 0; i < list.length; i++) {
        final pedido = list[i];
        pedido.isImportado = true;
        
        // Adiciona a etapa destino como novo step (garante stepId correto no Supabase)
        pedido.steps.add(PedidoStepModel.create(etapaDestino));

        statusText.add('Importando pedido ${pedido.localizador} (${i + 1} de ${list.length})...');
        
        // No supabase precisaremos garantir que Cliente, Obra e Produtos existem
        // A lógica do BackendClient.pedidos.add já lida com o save das relations de forma transparente no backend se o backend suportar,
        // mas idealmente os IDs do Firebase devem ser mantidos.
        await BackendClient.pedidos.add(pedido);
        salvos++;
        progress.add(salvos / list.length);
      }
      final salvosCount = salvos;
      toast('✅ Importação concluída! $salvosCount pedidos importados com sucesso.');
      statusText.add('✅ Importação concluída! $salvosCount pedidos importados.');
      importacaoConcluida.add(true);
      
      // Limpa seleções
      pedidosLegados.value.removeWhere((p) => list.contains(p));
      pedidosLegados.update();
      pedidosSelecionados.add(<PedidoModel>[]);
      
    } catch (e) {
      toast('Erro ao importar pedidos: $e');
    } finally {
      isLoading.add(false);
    }
  }
}
