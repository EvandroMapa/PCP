import 'dart:convert';

import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/enums/automatizacao_enum.dart';
import 'package:aco_plus/app/core/client/firestore/collections/automatizacao/models/automatizacao_item_model.dart';

class AutomatizacaoModel {
  final AutomatizacaoItemModel criacaoPedido;
  final AutomatizacaoItemModel produtoPedidoSeparado;
  final AutomatizacaoItemModel produzindoCDPedido;
  final AutomatizacaoItemModel prontoCDPedido;
  final AutomatizacaoItemModel aguardandoArmacaoPedido;
  final AutomatizacaoItemModel produzindoArmacaoPedido;
  final AutomatizacaoItemModel prontoArmacaoPedido;
  final AutomatizacaoItemModel naoMostrarNoCalendario;
  final AutomatizacaoItemModel removerListaPrioridade;


  List<AutomatizacaoItemModel> get itens => [
    criacaoPedido,
    produtoPedidoSeparado,
    produzindoCDPedido,
    prontoCDPedido,
    aguardandoArmacaoPedido,
    produzindoArmacaoPedido,
    prontoArmacaoPedido,
    naoMostrarNoCalendario,
    removerListaPrioridade,
  ];

  AutomatizacaoModel({
    required this.criacaoPedido,
    required this.produtoPedidoSeparado,
    required this.produzindoCDPedido,
    required this.prontoCDPedido,
    required this.aguardandoArmacaoPedido,
    required this.produzindoArmacaoPedido,
    required this.prontoArmacaoPedido,
    required this.naoMostrarNoCalendario,
    required this.removerListaPrioridade,
  });

  AutomatizacaoModel copyWith({
    AutomatizacaoItemModel? criacaoPedido,
    AutomatizacaoItemModel? produtoPedidoSeparado,
    AutomatizacaoItemModel? produzindoCDPedido,
    AutomatizacaoItemModel? prontoCDPedido,
    AutomatizacaoItemModel? aguardandoArmacaoPedido,
    AutomatizacaoItemModel? produzindoArmacaoPedido,
    AutomatizacaoItemModel? prontoArmacaoPedido,
    AutomatizacaoItemModel? naoMostrarNoCalendario,
    AutomatizacaoItemModel? removerListaPrioridade,
  }) {
    return AutomatizacaoModel(
      criacaoPedido: criacaoPedido ?? this.criacaoPedido,
      produtoPedidoSeparado:
          produtoPedidoSeparado ?? this.produtoPedidoSeparado,
      produzindoCDPedido: produzindoCDPedido ?? this.produzindoCDPedido,
      prontoCDPedido: prontoCDPedido ?? this.prontoCDPedido,
      aguardandoArmacaoPedido:
          aguardandoArmacaoPedido ?? this.aguardandoArmacaoPedido,
      produzindoArmacaoPedido:
          produzindoArmacaoPedido ?? this.produzindoArmacaoPedido,
      prontoArmacaoPedido: prontoArmacaoPedido ?? this.prontoArmacaoPedido,
      naoMostrarNoCalendario: naoMostrarNoCalendario ?? this.naoMostrarNoCalendario,
      removerListaPrioridade: removerListaPrioridade ?? this.removerListaPrioridade,
    );
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'criacao_pedido': criacaoPedido.toMap(),
      'produto_pedido_separado': produtoPedidoSeparado.toMap(),
      'produzindo_cd_pedido': produzindoCDPedido.toMap(),
      'pronto_cd_pedido': prontoCDPedido.toMap(),
      'aguardando_armacao_pedido': aguardandoArmacaoPedido.toMap(),
      'produzindo_armacao_pedido': produzindoArmacaoPedido.toMap(),
      'pronto_armacao_pedido': prontoArmacaoPedido.toMap(),
      'nao_mostrar_no_calendario': naoMostrarNoCalendario.toMap(),
      'remover_lista_prioridade': removerListaPrioridade.toMap(),
    };
  }

  factory AutomatizacaoModel.fromSupabaseMap(Map<String, dynamic> map) {
    final empty = AutomatizacaoModel.empty;
    return AutomatizacaoModel(
      criacaoPedido: map['criacao_pedido'] != null ? AutomatizacaoItemModel.fromMap(map['criacao_pedido'] is String
          ? json.decode(map['criacao_pedido'])
          : map['criacao_pedido']) : empty.criacaoPedido,
      produtoPedidoSeparado: map['produto_pedido_separado'] != null ? AutomatizacaoItemModel.fromMap(
          map['produto_pedido_separado'] is String
              ? json.decode(map['produto_pedido_separado'])
              : map['produto_pedido_separado']) : empty.produtoPedidoSeparado,
      produzindoCDPedido: map['produzindo_cd_pedido'] != null ? AutomatizacaoItemModel.fromMap(
          map['produzindo_cd_pedido'] is String
              ? json.decode(map['produzindo_cd_pedido'])
              : map['produzindo_cd_pedido']) : empty.produzindoCDPedido,
      prontoCDPedido: map['pronto_cd_pedido'] != null ? AutomatizacaoItemModel.fromMap(
          map['pronto_cd_pedido'] is String
              ? json.decode(map['pronto_cd_pedido'])
              : map['pronto_cd_pedido']) : empty.prontoCDPedido,
      aguardandoArmacaoPedido: map['aguardando_armacao_pedido'] != null ? AutomatizacaoItemModel.fromMap(
          map['aguardando_armacao_pedido'] is String
              ? json.decode(map['aguardando_armacao_pedido'])
              : map['aguardando_armacao_pedido']) : empty.aguardandoArmacaoPedido,
      produzindoArmacaoPedido: map['produzindo_armacao_pedido'] != null ? AutomatizacaoItemModel.fromMap(
          map['produzindo_armacao_pedido'] is String
              ? json.decode(map['produzindo_armacao_pedido'])
              : map['produzindo_armacao_pedido']) : empty.produzindoArmacaoPedido,
      prontoArmacaoPedido: map['pronto_armacao_pedido'] != null ? AutomatizacaoItemModel.fromMap(
          map['pronto_armacao_pedido'] is String
              ? json.decode(map['pronto_armacao_pedido'])
              : map['pronto_armacao_pedido']) : empty.prontoArmacaoPedido,
      naoMostrarNoCalendario: map['nao_mostrar_no_calendario'] != null ? AutomatizacaoItemModel.fromMap(
          map['nao_mostrar_no_calendario'] is String
              ? json.decode(map['nao_mostrar_no_calendario'])
              : map['nao_mostrar_no_calendario']) : empty.naoMostrarNoCalendario,
      removerListaPrioridade: map['remover_lista_prioridade'] != null ? AutomatizacaoItemModel.fromMap(
          map['remover_lista_prioridade'] is String
              ? json.decode(map['remover_lista_prioridade'])
              : map['remover_lista_prioridade']) : empty.removerListaPrioridade,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'criacaoPedido': criacaoPedido.toMap(),
      'produtoPedidoSeparado': produtoPedidoSeparado.toMap(),
      'produzindoCDPedido': produzindoCDPedido.toMap(),
      'prontoCDPedido': prontoCDPedido.toMap(),
      'aguardandoArmacaoPedido': aguardandoArmacaoPedido.toMap(),
      'produzindoArmacaoPedido': produzindoArmacaoPedido.toMap(),
      'prontoArmacaoPedido': prontoArmacaoPedido.toMap(),
      'naoMostrarNoCalendario': naoMostrarNoCalendario.toMap(),
      'removerListaPrioridade': removerListaPrioridade.toMap(),
    };
  }

  factory AutomatizacaoModel.fromMap(Map<String, dynamic> map) {
    return AutomatizacaoModel(
      criacaoPedido: AutomatizacaoItemModel.fromMap(map['criacaoPedido']),
      produtoPedidoSeparado: AutomatizacaoItemModel.fromMap(
        map['produtoPedidoSeparado'],
      ),
      produzindoCDPedido: AutomatizacaoItemModel.fromMap(
        map['produzindoCDPedido'],
      ),
      prontoCDPedido: AutomatizacaoItemModel.fromMap(map['prontoCDPedido']),
      aguardandoArmacaoPedido: AutomatizacaoItemModel.fromMap(
        map['aguardandoArmacaoPedido'],
      ),
      produzindoArmacaoPedido: AutomatizacaoItemModel.fromMap(
        map['produzindoArmacaoPedido'],
      ),
      prontoArmacaoPedido: AutomatizacaoItemModel.fromMap(
        map['prontoArmacaoPedido'],
      ),
      naoMostrarNoCalendario: AutomatizacaoItemModel.fromMap(
        map['naoMostrarNoCalendario'],
      ),
      removerListaPrioridade: AutomatizacaoItemModel.fromMap(
        map['removerListaPrioridade'],
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory AutomatizacaoModel.fromJson(String source) =>
      AutomatizacaoModel.fromMap(json.decode(source));

  @override
  String toString() {
    return 'AutomatizacaoModel(criacaoPedido: $criacaoPedido, produzindoCDPedido: $produzindoCDPedido, prontoCDPedido: $prontoCDPedido, aguardandoArmacaoPedido: $aguardandoArmacaoPedido, produzindoArmacaoPedido: $produzindoArmacaoPedido, prontoArmacaoPedido: $prontoArmacaoPedido, naoMostrarNoCalendario: $naoMostrarNoCalendario, removerListaPrioridade: $removerListaPrioridade)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AutomatizacaoModel &&
        other.criacaoPedido == criacaoPedido &&
        other.produzindoCDPedido == produzindoCDPedido &&
        other.prontoCDPedido == prontoCDPedido &&
        other.aguardandoArmacaoPedido == aguardandoArmacaoPedido &&
        other.produzindoArmacaoPedido == produzindoArmacaoPedido &&
        other.prontoArmacaoPedido == prontoArmacaoPedido &&
        other.naoMostrarNoCalendario == naoMostrarNoCalendario &&
        other.removerListaPrioridade == removerListaPrioridade;
  }

  @override
  int get hashCode {
    return criacaoPedido.hashCode ^
        produzindoCDPedido.hashCode ^
        prontoCDPedido.hashCode ^
        aguardandoArmacaoPedido.hashCode ^
        produzindoArmacaoPedido.hashCode ^
        prontoArmacaoPedido.hashCode ^
        naoMostrarNoCalendario.hashCode ^
        removerListaPrioridade.hashCode;
  }

  static AutomatizacaoModel get empty => AutomatizacaoModel(
        criacaoPedido: AutomatizacaoItemModel(
          type: AutomatizacaoItemType.criacaoPedido,
          step: null,
          steps: [],
        ),
        produtoPedidoSeparado: AutomatizacaoItemModel(
          type: AutomatizacaoItemType.produtoPedidoSeparado,
          step: null,
          steps: [],
        ),
        produzindoCDPedido: AutomatizacaoItemModel(
          type: AutomatizacaoItemType.produzindoCDPedido,
          step: null,
          steps: [],
        ),
        prontoCDPedido: AutomatizacaoItemModel(
          type: AutomatizacaoItemType.prontoCDPedido,
          step: null,
          steps: [],
        ),
        aguardandoArmacaoPedido: AutomatizacaoItemModel(
          type: AutomatizacaoItemType.aguardandoArmacaoPedido,
          step: null,
          steps: [],
        ),
        produzindoArmacaoPedido: AutomatizacaoItemModel(
          type: AutomatizacaoItemType.produzindoArmacaoPedido,
          step: null,
          steps: [],
        ),
        prontoArmacaoPedido: AutomatizacaoItemModel(
          type: AutomatizacaoItemType.prontoArmacaoPedido,
          step: null,
          steps: [],
        ),
        naoMostrarNoCalendario: AutomatizacaoItemModel(
          type: AutomatizacaoItemType.naoMostrarNoCalendario,
          step: null,
          steps: [],
        ),
        removerListaPrioridade: AutomatizacaoItemModel(
          type: AutomatizacaoItemType.removerListaPrioridade,
          step: null,
          steps: [],
        ),
      );
}
