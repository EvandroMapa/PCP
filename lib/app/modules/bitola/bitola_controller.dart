import 'package:aco_plus/app/core/client/firestore/collections/bitola/bitola_model.dart';
import 'package:aco_plus/app/core/client/firestore/firestore_client.dart';
import 'package:aco_plus/app/core/extensions/string_ext.dart';
import 'package:aco_plus/app/core/models/app_stream.dart';
import 'package:aco_plus/app/core/services/audit_service.dart';
import 'package:aco_plus/app/core/services/notification_service.dart';
import 'package:aco_plus/app/core/utils/global_resource.dart';
import 'package:aco_plus/app/modules/bitola/bitola_view_model.dart';
import 'package:overlay_support/overlay_support.dart';

final bitolaCtrl = BitolaController();
BitolaModel get produto => bitolaCtrl.produto!;

class BitolaController {
  static final BitolaController _instance = BitolaController._();

  BitolaController._();

  factory BitolaController() => _instance;

  final AppStream<BitolaModel?> produtoStream = AppStream<BitolaModel?>.seed(
    null,
  );
  BitolaModel? get produto => produtoStream.value;

  final AppStream<BitolaUtils> utilsStream = AppStream<BitolaUtils>.seed(
    BitolaUtils(),
  );
  BitolaUtils get utils => utilsStream.value;

  void onInit() {
    utilsStream.add(BitolaUtils());
    FirestoreClient.bitolas.listen();
  }

  final AppStream<BitolaCreateModel> formStream =
      AppStream<BitolaCreateModel>();
  BitolaCreateModel get form => formStream.value;

  void init(BitolaModel? produto) {
    formStream.add(
      produto != null ? BitolaCreateModel.edit(produto) : BitolaCreateModel(),
    );
  }

  List<BitolaModel> getProdutoesFiltered(
    String search,
    List<BitolaModel> produtos,
  ) {
    if (search.length < 3) return produtos;
    List<BitolaModel> filtered = [];
    for (final produto in produtos) {
      if (produto.toString().toCompare.contains(search.toCompare)) {
        filtered.add(produto);
      }
    }
    return filtered;
  }

  Future<void> onConfirm(value, BitolaModel? produto) async {
    try {
      onValid(produto);
      if (form.isEdit) {
        final edit = form.toBitolaModel();
        await FirestoreClient.bitolas.update(edit);
      } else {
        await FirestoreClient.bitolas.add(form.toBitolaModel());
      }
      await FirestoreClient.bitolas.fetch();
      pop(value);
      NotificationService.showPositive(
        'Produto ${form.isEdit ? 'Editado' : 'Adicionado'}',
        'Operação realizada com sucesso',
        position: NotificationPosition.bottom,
      );
    } catch (e) {
      NotificationService.showNegative(
        'Erro',
        e.toString(),
        position: NotificationPosition.bottom,
      );
    }
  }

  Future<void> onDelete(value, BitolaModel produto) async {
    if (await _isDeleteUnavailable(produto)) return;
    await FirestoreClient.bitolas.delete(produto);
    pop(value);
    NotificationService.showPositive(
      'Produto Excluido',
      'Operação realizada com sucesso',
      position: NotificationPosition.bottom,
    );

    // Audit
    AuditService.registrar(
      acao: 'excluir_bitola',
      modulo: 'produto',
      entidadeId: produto.id,
      entidadeLabel: produto.descricao,
    );
  }

  Future<bool> _isDeleteUnavailable(
    BitolaModel produto,
  ) async =>
      !await onDeleteProcess(
        deleteTitle: 'Deseja excluir o produto?',
        deleteMessage: 'Todos seus dados serão apagados do sistema',
        infoMessage:
            'Não é possível excluir o produto, pois ele está vinculado a outras partes do sistema.',
        conditional: FirestoreClient.pedidos.data.any(
          (e) => e.produtos.any((p) => p.produto.id == produto.id),
        ),
      );

  void onValid(BitolaModel? produto) {
    String nomeForm = form.nome.text.trim();
    if (nomeForm.length < 2) {
      throw Exception('Nome deve conter no mínimo 3 caracteres');
    }
    if (form.isEdit) {
      if (FirestoreClient.bitolas.data.any((e) =>
          e.nome.trim().toLowerCase() == nomeForm.toLowerCase() &&
          e.id.toString().trim() != form.id.toString().trim())) {
        throw Exception('Já existe um produto com esse nome');
      }
    } else {
      if (FirestoreClient.bitolas.data
          .any((e) => e.nome.trim().toLowerCase() == nomeForm.toLowerCase())) {
        throw Exception('Já existe um produto com esse nome');
      }
    }
  }

  /// Persiste a nova ordem de classificação dos produtos após o usuário arrastar
  Future<void> onReorder(List<BitolaModel> reordered) async {
    for (int i = 0; i < reordered.length; i++) {
      final updated = reordered[i].copyWith(sortIndex: i);
      await FirestoreClient.bitolas.update(updated);
    }
    await FirestoreClient.bitolas.fetch();
  }
}
