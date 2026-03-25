import 'package:aco_plus/app/core/client/supabase/collections/cliente/cliente_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/step/step_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_produto_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/usuario/usuario_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';

// Original Firestore collection imports to avoid recursion via FirestoreClient
import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/pedido_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/step_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/usuario_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/tag_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/ordem_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/automatizacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/notificacao/notificacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/checklist/checklist_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/materia_prima_collection.dart';

enum BackendType { firestore, supabase }

class BackendClient {
  static BackendType type = BackendType.supabase;

  static UsuarioCollection get usuarios => type == BackendType.firestore 
      ? UsuarioCollection() 
      : AppSupabaseClient.usuarios;

  static ClienteCollection get clientes => type == BackendType.firestore 
      ? ClienteCollection() 
      : AppSupabaseClient.clientes;

  static StepCollection get steps => type == BackendType.firestore 
      ? StepCollection() 
      : AppSupabaseClient.steps;

  static PedidoCollection get pedidos => type == BackendType.firestore 
      ? PedidoCollection() 
      : AppSupabaseClient.pedidos;

  static PedidoProdutoSupabaseCollection get pedidoProdutos => AppSupabaseClient.pedidoProdutos;

  static TagCollection get tags => TagCollection(); // Still firestore for now

  static ProdutoCollection get produtos => type == BackendType.firestore
      ? ProdutoCollection()
      : AppSupabaseClient.produtos;

  static FabricanteCollection get fabricantes => type == BackendType.firestore
      ? FabricanteCollection()
      : AppSupabaseClient.fabricantes;

  static MateriaPrimaCollection get materiaPrima => type == BackendType.firestore
      ? MateriaPrimaCollection()
      : AppSupabaseClient.materiaPrima;

  static ChecklistCollection get checklists => ChecklistCollection(); // Still firestore for now

  static AutomatizacaoCollection get automatizacao => AutomatizacaoCollection(); // Still firestore for now

  static NotificacaoCollection get notificacoes => NotificacaoCollection(); // Still firestore for now

  static OrdemCollection get ordens => type == BackendType.firestore
      ? OrdemCollection()
      : AppSupabaseClient.ordens;
}
