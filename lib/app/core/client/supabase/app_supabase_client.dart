import 'package:aco_plus/app/core/client/supabase/collections/cliente/cliente_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/fabricante/fabricante_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/materia_prima/materia_prima_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/ordem/ordem_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_arquivo_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/produto/produto_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/step/step_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/usuario/usuario_supabase_collection.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';
import 'package:aco_plus/app/core/client/firestore/collections/version/version_collection.dart';

class AppSupabaseClient {
  static OrdemSupabaseCollection ordens = OrdemSupabaseCollection();
  static PedidoSupabaseCollection pedidos = PedidoSupabaseCollection();
  static PedidoArquivoSupabaseCollection pedidoArquivos = PedidoArquivoSupabaseCollection();
  static UsuarioSupabaseCollection usuarios = UsuarioSupabaseCollection();
  static ClienteSupabaseCollection clientes = ClienteSupabaseCollection();
  static StepSupabaseCollection steps = StepSupabaseCollection();
  static ProdutoSupabaseCollection produtos = ProdutoSupabaseCollection();
  static FabricanteSupabaseCollection fabricantes = FabricanteSupabaseCollection();
  static MateriaPrimaSupabaseCollection materiaPrima = MateriaPrimaSupabaseCollection();

  static Future<void> init() async {
    // Start all collections in parallel for better performance
    await Future.wait([
      usuarios.start(),
      clientes.start(),
      steps.start(),
      ordens.start(),
      produtos.start(),
      fabricantes.start(),
      materiaPrima.start(),
      pedidoArquivos.start(),
      BackendClient.tags.start(),
      BackendClient.checklists.start(),
      BackendClient.automatizacao.start(),
      BackendClient.notificacoes.start(),
      VersionCollection().start(),
    ]);

    // Pedidos depends on clientes/steps for mapping, so start it after
    await pedidos.start();

    // Start real-time listeners
    usuarios.listen();
    clientes.listen();
    steps.listen();
    pedidos.listen();
    ordens.listen();
    materiaPrima.listen();
    pedidoArquivos.listen();
    BackendClient.tags.listen();
    BackendClient.checklists.listen();
    BackendClient.automatizacao.listen();
    BackendClient.notificacoes.listen();
    VersionCollection().listen();
  }
}
