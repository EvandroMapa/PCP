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



class AppSupabaseClient {
  static OrdemSupabaseCollection ordens = OrdemSupabaseCollection();
  static PedidoSupabaseCollection pedidos = PedidoSupabaseCollection();
  static PedidoProdutoSupabaseCollection pedidoProdutos = PedidoProdutoSupabaseCollection();
  static PedidoArquivoSupabaseCollection pedidoArquivos = PedidoArquivoSupabaseCollection();
  static UsuarioSupabaseCollection usuarios = UsuarioSupabaseCollection();
  static UsuarioTipoSupabaseCollection usuarioTipos = UsuarioTipoSupabaseCollection();
  static ClienteSupabaseCollection clientes = ClienteSupabaseCollection();
  static StepSupabaseCollection steps = StepSupabaseCollection();
  static ProdutoSupabaseCollection produtos = ProdutoSupabaseCollection();
  static FabricanteSupabaseCollection fabricantes = FabricanteSupabaseCollection();
  static MateriaPrimaSupabaseCollection materiaPrima = MateriaPrimaSupabaseCollection();
  static TagSupabaseCollection tags = TagSupabaseCollection();
  static ChecklistSupabaseCollection checklists = ChecklistSupabaseCollection();
  static AutomatizacaoSupabaseCollection automatizacao = AutomatizacaoSupabaseCollection();
  static NotificacaoSupabaseCollection notificacoes = NotificacaoSupabaseCollection();

  static Future<void> init() async {
    try {
      // Start all collections with individual error handling to be resilient
      final futures = [
        usuarioTipos.start().catchError((e) => print('Error starting usuarioTipos: $e')),
        usuarios.start().catchError((e) => print('Error starting usuarios: $e')),
        clientes.start().catchError((e) => print('Error starting clientes: $e')),
        steps.start().catchError((e) => print('Error starting steps: $e')),
        ordens.start().catchError((e) => print('Error starting ordens: $e')),
        produtos.start().catchError((e) => print('Error starting produtos: $e')),
        fabricantes.start().catchError((e) => print('Error starting fabricantes: $e')),
        materiaPrima.start().catchError((e) => print('Error starting materiaPrima: $e')),
        pedidoArquivos.start().catchError((e) => print('Error starting pedidoArquivos: $e')),
        pedidoProdutos.start().catchError((e) => print('Error starting pedidoProdutos: $e')),
        tags.start().catchError((e) => print('Error starting tags: $e')),
        checklists.start().catchError((e) => print('Error starting checklists: $e')),
        automatizacao.start().catchError((e) => print('Error starting automatizacao: $e')),
        notificacoes.start().catchError((e) => print('Error starting notificacoes: $e')),
      ];

      await Future.wait(futures);

      // Pedidos depends on clientes/steps for mapping, so start it after
      await pedidos.start().catchError((e) => print('Error starting pedidos: $e'));

      // Start real-time listeners
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
    } catch (e) {
      print('AppSupabaseClient: Critical error during init: $e');
    }
  }
}
