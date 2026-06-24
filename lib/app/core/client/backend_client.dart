import 'package:aco_plus/app/core/client/supabase/collections/usuario/usuario_tipo_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido/pedido_bitola_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/app_supabase_client.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/estoque/estoque_movimentacao_supabase_collection.dart';
import 'package:aco_plus/app/core/client/supabase/collections/pedido_compra/pedido_compra_supabase_collection.dart';

// Original Firestore collection imports to avoid recursion via FirestoreClient.
import 'package:aco_plus/app/core/client/firestore/collections/cliente/cliente_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido/pedido_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/step/step_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/usuario/usuario_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/tag/tag_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/patio/patio_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/box/box_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/pedido_box/pedido_box_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/ordem/ordem_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/automatizacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/notificacao/notificacao_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/checklist/checklist_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/fabricante/fabricante_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/materia_prima/materia_prima_collection.dart';
import 'package:aco_plus/app/core/client/firestore/collections/equipamento/equipamento_collection.dart';

enum BackendType { firestore, supabase }

class BackendClient {
  static BackendType type = BackendType.supabase;

  static UsuarioCollection get usuarios => type == BackendType.firestore
      ? UsuarioCollection()
      : AppSupabaseClient.usuarios;

  static UsuarioTipoSupabaseCollection get usuarioTipos =>
      AppSupabaseClient.usuarioTipos;

  static ClienteCollection get clientes => type == BackendType.firestore
      ? ClienteCollection()
      : AppSupabaseClient.clientes;

  static StepCollection get steps => type == BackendType.firestore
      ? StepCollection()
      : AppSupabaseClient.steps;

  static PedidoCollection get pedidos => type == BackendType.firestore
      ? PedidoCollection()
      : AppSupabaseClient.pedidos;

  static PedidoBitolaSupabaseCollection get pedidoBitolas =>
      AppSupabaseClient.pedidoBitolas;

  static TagCollection get tags =>
      type == BackendType.firestore ? TagCollection() : AppSupabaseClient.tags;

  static PatioCollection get patios =>
      type == BackendType.firestore ? PatioCollection() : AppSupabaseClient.patios;

  static BoxCollection get boxes =>
      type == BackendType.firestore ? BoxCollection() : AppSupabaseClient.boxes;

  static PedidoBoxCollection get pedidoBoxes =>
      type == BackendType.firestore
          ? PedidoBoxCollection()
          : AppSupabaseClient.pedidoBoxes;

  static BitolaCollection get bitolas => type == BackendType.firestore
      ? BitolaCollection()
      : AppSupabaseClient.bitolas;

  static FabricanteCollection get fabricantes => type == BackendType.firestore
      ? FabricanteCollection()
      : AppSupabaseClient.fabricantes;

  static MateriaPrimaCollection get materiaPrima =>
      type == BackendType.firestore
          ? MateriaPrimaCollection()
          : AppSupabaseClient.materiaPrima;

  static ChecklistCollection get checklists => type == BackendType.firestore
      ? ChecklistCollection()
      : AppSupabaseClient.checklists;

  static AutomatizacaoCollection get automatizacao =>
      type == BackendType.firestore
          ? AutomatizacaoCollection()
          : AppSupabaseClient.automatizacao;

  static NotificacaoCollection get notificacoes => type == BackendType.firestore
      ? NotificacaoCollection()
      : AppSupabaseClient.notificacoes;

  static OrdemCollection get ordens => type == BackendType.firestore
      ? OrdemCollection()
      : AppSupabaseClient.ordens;

  static EstoqueSupabaseCollection get estoques =>
      AppSupabaseClient.estoques;

  static EstoqueMovimentacaoSupabaseCollection get estoquesMovimentacao =>
      AppSupabaseClient.estoquesMovimentacao;

  static PedidoCompraSupabaseCollection get pedidosCompra =>
      AppSupabaseClient.pedidosCompra;

  static EquipamentoCollection get equipamentos =>
      type == BackendType.firestore
          ? EquipamentoCollection()
          : AppSupabaseClient.equipamentos;
}
