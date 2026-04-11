enum AutomatizacaoItemType {
  criacaoPedido,
  produtoPedidoSeparado,
  produzindoCDPedido,
  prontoCDPedido,
  aguardandoArmacaoPedido,
  produzindoArmacaoPedido,
  prontoArmacaoPedido,
  naoMostrarNoCalendario,
  removerListaPrioridade,
}

extension AutomatizacaoItemTypeExtension on AutomatizacaoItemType {
  String get label {
    switch (this) {
      case AutomatizacaoItemType.criacaoPedido:
        return 'Criação do pedido';
      case AutomatizacaoItemType.produtoPedidoSeparado:
        return 'Produto do pedido separado';
      case AutomatizacaoItemType.produzindoCDPedido:
        return 'Produzindo CD do pedido';
      case AutomatizacaoItemType.prontoCDPedido:
        return 'CD do pedido pronto';
      case AutomatizacaoItemType.aguardandoArmacaoPedido:
        return 'Aguardando armação do pedido';
      case AutomatizacaoItemType.produzindoArmacaoPedido:
        return 'Produzindo armação do pedido';
      case AutomatizacaoItemType.prontoArmacaoPedido:
        return 'Armação do pedido pronta';
      case AutomatizacaoItemType.naoMostrarNoCalendario:
        return 'Não mostrar no calendário';
      case AutomatizacaoItemType.removerListaPrioridade:
        return 'Remover da lista de prioridade';
    }
  }

  String get desc {
    switch (this) {
      case AutomatizacaoItemType.criacaoPedido:
        return 'Pedido é inserido no sistema';
      case AutomatizacaoItemType.produtoPedidoSeparado:
        return 'Bitolas separadas em uma ordem de produção';
      case AutomatizacaoItemType.produzindoCDPedido:
        return 'Primeiro vergalhão é separado para produção';
      case AutomatizacaoItemType.prontoCDPedido:
        return 'Pedido apenas de Corte e Dobra pronto';
      case AutomatizacaoItemType.aguardandoArmacaoPedido:
        return 'Armação é solicitada';
      case AutomatizacaoItemType.produzindoArmacaoPedido:
        return 'Armação começa a ser produzida';
      case AutomatizacaoItemType.prontoArmacaoPedido:
        return 'Armação está pronta';
      case AutomatizacaoItemType.naoMostrarNoCalendario:
        return 'Ao cair em alguma das etapas na lista, não será exibido no calendário';
      case AutomatizacaoItemType.removerListaPrioridade:
        return 'Ao cair em alguma das etapas na lista, será removido da lista de prioridade';
    }
  }
}
