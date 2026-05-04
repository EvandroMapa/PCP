import 'dart:developer';
import 'package:aco_plus/app/core/client/supabase/collections/cliente/cliente_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/fabricante/fabricante_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/materia_prima/materia_prima_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/ordem/ordem_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_produto_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_arquivo_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/produto/produto_supabase_collection.dart';
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

class AppSupabaseClient {
  static OrdemSupabaseCollection ordens = OrdemSupabaseCollection();
  static PedidoSupabaseCollection pedidos = PedidoSupabaseCollection();
  static PedidoProdutoSupabaseCollection pedidoProdutos =
      PedidoProdutoSupabaseCollection();
  static PedidoArquivoSupabaseCollection pedidoArquivos =
      PedidoArquivoSupabaseCollection();
  static UsuarioSupabaseCollection usuarios = UsuarioSupabaseCollection();
  static UsuarioTipoSupabaseCollection usuarioTipos =
      UsuarioTipoSupabaseCollection();
  static ClienteSupabaseCollection clientes = ClienteSupabaseCollection();
  static StepSupabaseCollection steps = StepSupabaseCollection();
  static ProdutoSupabaseCollection produtos = ProdutoSupabaseCollection();
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
      pedidoArquivos.listen();
      pedidoProdutos.listen();
      tags.listen();
      checklists.listen();
      automatizacao.listen();
      notificacoes.listen();
      elementoArquivos.listen();
      elementos.listen();
      patios.listen();
      boxes.listen();
      pedidoBoxes.listen();

      // ── 2. Fetches sequenciais (dados iniciais) ─────────────────────────
      await usuarioTipos
          .start()
          .catchError((e) => log('Error starting usuarioTipos: $e'));
      await usuarios
          .start()
          .catchError((e) => log('Error starting usuarios: $e'));
      await clientes
          .start()
          .catchError((e) => log('Error starting clientes: $e'));
      await steps.start().catchError((e) => log('Error starting steps: $e'));
      await ordens.start().catchError((e) => log('Error starting ordens: $e'));
      await produtos
          .start()
          .catchError((e) => log('Error starting produtos: $e'));
      await fabricantes
          .start()
          .catchError((e) => log('Error starting fabricantes: $e'));
      await materiaPrima
          .start()
          .catchError((e) => log('Error starting materiaPrima: $e'));
      await pedidoArquivos
          .start()
          .catchError((e) => log('Error starting pedidoArquivos: $e'));
      await pedidoProdutos
          .start()
          .catchError((e) => log('Error starting pedidoProdutos: $e'));
      await tags.start().catchError((e) => log('Error starting tags: $e'));
      await checklists
          .start()
          .catchError((e) => log('Error starting checklists: $e'));
      await automatizacao
          .start()
          .catchError((e) => log('Error starting automatizacao: $e'));
      await notificacoes
          .start()
          .catchError((e) => log('Error starting notificacoes: $e'));
      await elementoArquivos
          .start()
          .catchError((e) => log('Error starting elementoArquivos: $e'));
      await elementos
          .start()
          .catchError((e) => log('Error starting elementos: $e'));
      await patios
          .start()
          .catchError((e) => log('Error starting patios: $e'));
      await boxes
          .start()
          .catchError((e) => log('Error starting boxes: $e'));
      await pedidoBoxes
          .start()
          .catchError((e) => log('Error starting pedidoBoxes: $e'));
      await ordens.startOnlyArquivadas();

      // Pedidos depende de clientes/steps para mapeamento
      await pedidos
          .start()
          .catchError((e) => log('Error starting pedidos: $e'));
      await pedidos.startOnlyArquivadas();
    } catch (e) {
      log('AppSupabaseClient: Critical error during init: $e');
    }
  }
}
