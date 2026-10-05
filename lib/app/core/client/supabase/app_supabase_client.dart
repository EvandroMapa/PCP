import 'dart:async';
import 'dart:developer';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/client/supabase/collections/cliente/cliente_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/fabricante/fabricante_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/materia_prima/materia_prima_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/ordem/ordem_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_bitola_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_arquivo_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/bitola/bitola_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/step/step_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/usuario/usuario_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/usuario/usuario_tipo_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/tag/tag_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/checklist/checklist_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/automatizacao/automatizacao_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/notificacao/notificacao_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/elemento/elemento_arquivo_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/elemento/elemento_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/patio/patio_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/box/box_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_box/pedido_box_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_movimentacao_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/equipamento/equipamento_supabase_collection.dart';

class AppSupabaseClient {
  static OrdemSupabaseCollection ordens = OrdemSupabaseCollection();
  static PedidoSupabaseCollection pedidos = PedidoSupabaseCollection();
  static PedidoBitolaSupabaseCollection pedidoBitolas =
      PedidoBitolaSupabaseCollection();
  static PedidoArquivoSupabaseCollection pedidoArquivos =
      PedidoArquivoSupabaseCollection();
  static UsuarioSupabaseCollection usuarios = UsuarioSupabaseCollection();
  static UsuarioTipoSupabaseCollection usuarioTipos =
      UsuarioTipoSupabaseCollection();
  static ClienteSupabaseCollection clientes = ClienteSupabaseCollection();
  static StepSupabaseCollection steps = StepSupabaseCollection();
  static BitolaSupabaseCollection bitolas = BitolaSupabaseCollection();
  static FabricanteSupabaseCollection fabricantes =
      FabricanteSupabaseCollection();
  static MateriaPrimaSupabaseCollection materiaPrima =
      MateriaPrimaSupabaseCollection();
  static TagSupabaseCollection tags = TagSupabaseCollection();
  static ChecklistSupabaseCollection checklists = ChecklistSupabaseCollection();
  static AutomatizacaoSupabaseCollection automatizacao =
      AutomatizacaoSupabaseCollection();
  static NotificacaoSupabaseCollection notificacoes =
      NotificacaoSupabaseCollection();
  static ElementoArquivoSupabaseCollection elementoArquivos =
      ElementoArquivoSupabaseCollection();
  static ElementoSupabaseCollection elementos = ElementoSupabaseCollection();
  static PatioSupabaseCollection patios = PatioSupabaseCollection();
  static BoxSupabaseCollection boxes = BoxSupabaseCollection();
  static PedidoBoxSupabaseCollection pedidoBoxes =
      PedidoBoxSupabaseCollection();
  static EstoqueSupabaseCollection estoques = EstoqueSupabaseCollection();
  static EstoqueMovimentacaoSupabaseCollection estoquesMovimentacao =
      EstoqueMovimentacaoSupabaseCollection();
  static PedidoCompraSupabaseCollection pedidosCompra =
      PedidoCompraSupabaseCollection();
  static EquipamentoSupabaseCollection equipamentos =
      EquipamentoSupabaseCollection();

  /// Carga inicial. As tabelas independentes são buscadas em PARALELO, em
  /// fases que respeitam as dependências de mapeamento:
  ///   1. cadastros base + elementos + estoque (independentes entre si)
  ///   2. matéria-prima e ordens (usam bitolas/fabricantes)
  ///   3. pedidos (usam clientes, steps, ordens e o índice de elementos)
  /// Antes era tudo sequencial (~22 s de rede); em paralelo fica ~5 s.
  /// true quando a carga inicial terminou. Telas que mostram totais (ex.:
  /// dashboard) esperam por ele para não exibir números parciais.
  static final AppStream<bool> carregadoStream = AppStream<bool>.seed(false);
  static final Completer<void> _carga = Completer<void>();

  /// Completa quando a carga inicial termina (com ou sem erros).
  static Future<void> get aguardarCarga => _carga.future;

  static Future<void> init() async {
    try {
      // ── 1. Realtime primeiro ────────────────────────────────────────────
      // Configura os canais de Realtime ANTES dos fetches pesados,
      // para que qualquer mudança no banco seja recebida imediatamente
      usuarioTipos.listen();
      usuarios.listen();
      clientes.listen();
      steps.listen();
      pedidos.listen();
      ordens.listen();
      materiaPrima.listen();
      // pedidoArquivos.listen() removido — arquivos do pedido são salvos no campo JSON archives
      // pedidoBitolas.listen()/start() removidos — nenhum módulo lê esse cache
      // (os itens chegam junto com os pedidos) e a tabela inteira tinha 11 MB
      tags.listen();
      checklists.listen();
      automatizacao.listen();
      notificacoes.listen();
      // elementoArquivos.listen(); — removido: causava cascata de re-fetches durante importação
      elementos.listen();
      patios.listen();
      boxes.listen();
      pedidoBoxes.listen();
      estoques.listen();
      estoquesMovimentacao.listen();
      pedidosCompra.listen();
      equipamentos.listen();

      // ── 2. Fetches iniciais em fases paralelas ──────────────────────────
      await Future.wait([
        _safeStart('usuarios', () async {
          await usuarioTipos.start();
          await usuarios.start();
        }),
        _safeStart('clientes', () => clientes.start()),
        _safeStart('steps', () => steps.start()),
        _safeStart('bitolas', () => bitolas.start()),
        _safeStart('fabricantes', () => fabricantes.start()),
        _safeStart('tags', () => tags.start()),
        _safeStart('checklists', () => checklists.start()),
        _safeStart('automatizacao', () => automatizacao.start()),
        _safeStart('notificacoes', () => notificacoes.start()),
        _safeStart('elementos', () => elementos.start()),
        _safeStart('patios', () => patios.start()),
        _safeStart('boxes', () => boxes.start()),
        _safeStart('pedidoBoxes', () => pedidoBoxes.start()),
        _safeStart('estoques', () => estoques.start()),
        _safeStart('estoquesMovimentacao', () => estoquesMovimentacao.start()),
        _safeStart('pedidosCompra', () => pedidosCompra.start()),
        _safeStart('equipamentos', () => equipamentos.start()),
      ]);

      await Future.wait([
        _safeStart('materiaPrima', () => materiaPrima.start()),
        _safeStart('ordens', () => ordens.start()),
      ]);

      // Pedidos depende de clientes/steps/ordens/elementos para mapeamento.
      // fetch() (e não start()) garante o mapeamento com os elementos já
      // carregados, mesmo que algo tenha disparado uma carga antecipada.
      await _safeStart('pedidos', () => pedidos.fetch());
      // Arquivados (pedidos e ordens) são carregados sob demanda ao abrir suas respectivas páginas
    } catch (e) {
      log('AppSupabaseClient: Critical error during init: $e');
    } finally {
      carregadoStream.add(true);
      if (!_carga.isCompleted) _carga.complete();
    }
  }

  static Future<void> _safeStart(
      String nome, Future<void> Function() start) async {
    try {
      await start();
    } catch (e) {
      log('Error starting $nome: $e');
    }
  }
}
