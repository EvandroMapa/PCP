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
  finalizacaoArmacaoPedido,
}

extension AutomatizacaoItemTypeExtension on AutomatizacaoItemType {
  String get label {
    switch (this) {
      case AutomatizacaoItemType.criacaoPedido:
        return 'Pedido novo';
      case AutomatizacaoItemType.produtoPedidoSeparado:
        return 'Entrada na produção';
      case AutomatizacaoItemType.produzindoCDPedido:
        return 'Corte e dobra começou';
      case AutomatizacaoItemType.prontoCDPedido:
        return 'Corte e dobra pronto (pedido CD)';
      case AutomatizacaoItemType.aguardandoArmacaoPedido:
        return 'Corte e dobra pronto (pedido CDA)';
      case AutomatizacaoItemType.produzindoArmacaoPedido:
        return 'Produzindo armação (sem uso)';
      case AutomatizacaoItemType.prontoArmacaoPedido:
        return 'Armação pronta (sem uso)';
      case AutomatizacaoItemType.naoMostrarNoCalendario:
        return 'Não mostrar no calendário';
      case AutomatizacaoItemType.removerListaPrioridade:
        return 'Remover da lista de prioridade (sem uso)';
      case AutomatizacaoItemType.finalizacaoArmacaoPedido:
        return 'Armação concluída (pedido CDA)';
    }
  }

  String get desc {
    switch (this) {
      case AutomatizacaoItemType.criacaoPedido:
        return 'Pedido novo começa nesta etapa';
      case AutomatizacaoItemType.produtoPedidoSeparado:
        return 'A partir desta etapa o pedido conta como em produção';
      case AutomatizacaoItemType.produzindoCDPedido:
        return 'A primeira bitola entrou numa ordem de produção';
      case AutomatizacaoItemType.prontoCDPedido:
        return 'Todas as bitolas de um pedido CD ficaram prontas';
      case AutomatizacaoItemType.aguardandoArmacaoPedido:
        return 'Todas as bitolas de um pedido CDA ficaram prontas';
      case AutomatizacaoItemType.produzindoArmacaoPedido:
        return 'Só disparava com troca manual de status; fora da tela';
      case AutomatizacaoItemType.prontoArmacaoPedido:
        return 'Só disparava com troca manual de status; fora da tela';
      case AutomatizacaoItemType.naoMostrarNoCalendario:
        return 'Pedidos nestas etapas não aparecem no calendário';
      case AutomatizacaoItemType.removerListaPrioridade:
        return 'Nenhuma parte do sistema usa esta regra';
      case AutomatizacaoItemType.finalizacaoArmacaoPedido:
        return 'O armador concluiu todos os elementos do pedido';
    }
  }
}
