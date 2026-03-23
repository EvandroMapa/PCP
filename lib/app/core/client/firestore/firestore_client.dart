import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/automatizacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/checklist/checklist_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/materia_prima_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/notificacao/notificacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/ordem_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/pedido_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/produto/produto_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/step_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/tag_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/usuario_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/version/version_collection.dart';
import 'package:aco_plus/app/core/client/backend_client.dart';

class FirestoreClient {
  static VersionCollection get version => VersionCollection(); // Keep for now
  static UsuarioCollection get usuarios => BackendClient.usuarios;
  static ClienteCollection get clientes => BackendClient.clientes;
  static StepCollection get steps => BackendClient.steps;
  static TagCollection get tags => BackendClient.tags;
  static ChecklistCollection get checklists => BackendClient.checklists;
  static FabricanteCollection get fabricantes => BackendClient.fabricantes;
  static MateriaPrimaCollection get materiaPrimas => BackendClient.materiaPrima;
  static ProdutoCollection get produtos => BackendClient.produtos;
  static PedidoCollection get pedidos => BackendClient.pedidos;
  static OrdemCollection get ordens => BackendClient.ordens;
  static AutomatizacaoCollection get automatizacao => BackendClient.automatizacao;
  static NotificacaoCollection get notificacoes => BackendClient.notificacoes;

  static init() async {
    if (BackendClient.type == BackendType.supabase) return;
    
    await VersionCollection().start();
    await UsuarioCollection().start();
    await StepCollection().start();
    await FabricanteCollection().start();
    await ProdutoCollection().start();
    await MateriaPrimaCollection().start();
    await TagCollection().start();
    await ChecklistCollection().start();
    await ClienteCollection().start();
    await PedidoCollection().startOnlyArquivadas();
    await PedidoCollection().start();
    await OrdemCollection().startOnlyArquivadas();
    await OrdemCollection().start();
    await AutomatizacaoCollection().start();
    await NotificacaoCollection().start();

    // Listeners
    await VersionCollection().listen();
    await UsuarioCollection().listen();
    await StepCollection().listen();
    await FabricanteCollection().listen();
    await ProdutoCollection().listen();
    await MateriaPrimaCollection().listen();
    await TagCollection().listen();
    await ChecklistCollection().listen();
    await ClienteCollection().listen();
    await PedidoCollection().listen();
    await OrdemCollection().listen();
    await AutomatizacaoCollection().listen();
    await NotificacaoCollection().listen();
  }
}
