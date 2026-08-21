-- ============================================================================
-- SCRIPT DE OTIMIZAÇÃO DE ÍNDICES - PCP SUPABASE (DEFINITIVO)
-- Executar no SQL Editor do Supabase Dashboard
-- ============================================================================

-- 1. Tabela de Pedidos e relacionamentos (acelera Kanban e boot)
CREATE INDEX IF NOT EXISTS idx_pedidos_is_archived ON public.pedidos (is_archived);
CREATE INDEX IF NOT EXISTS idx_pedido_bitolas_pedido_id ON public.pedido_bitolas (pedido_id);
CREATE INDEX IF NOT EXISTS idx_pedido_status_history_pedido_id ON public.pedido_status_history (pedido_id);
CREATE INDEX IF NOT EXISTS idx_pedido_steps_history_pedido_id ON public.pedido_steps_history (pedido_id);
CREATE INDEX IF NOT EXISTS idx_pedido_tags_pedido_id ON public.pedido_tags (pedido_id);

-- 2. Estoque e Movimentações (elimina Seq Scan de 26s no estoque)
CREATE INDEX IF NOT EXISTS idx_estoque_movimentacao_data_hora ON public.estoque_movimentacao (data_hora DESC);
CREATE INDEX IF NOT EXISTS idx_estoque_bitola_id ON public.estoque (bitola_id);

-- 3. Elementos e Posições (acelera detalhamento técnico SPE/TQS)
CREATE INDEX IF NOT EXISTS idx_elementos_pedido_id ON public.elementos (pedido_id);
CREATE INDEX IF NOT EXISTS idx_elementos_nome ON public.elementos (nome);
CREATE INDEX IF NOT EXISTS idx_elemento_posicoes_elemento_id ON public.elemento_posicoes (elemento_id);
CREATE INDEX IF NOT EXISTS idx_elemento_posicoes_bitola_id ON public.elemento_posicoes (bitola_id);
CREATE INDEX IF NOT EXISTS idx_elemento_arquivos_elemento_id ON public.elemento_arquivos (elemento_id);

-- 4. Ordens de Produção
CREATE INDEX IF NOT EXISTS idx_ordens_is_archived ON public.ordens (is_archived);

-- 5. Box e Pátios
CREATE INDEX IF NOT EXISTS idx_boxes_patio_id ON public.boxes (patio_id);
CREATE INDEX IF NOT EXISTS idx_pedido_boxes_pedido_id ON public.pedido_boxes (pedido_id);
CREATE INDEX IF NOT EXISTS idx_pedido_boxes_box_id ON public.pedido_boxes (box_id);

-- 6. Pontas e Planos de Corte
CREATE INDEX IF NOT EXISTS idx_pontas_bitola_id ON public.pontas (bitola_id);
CREATE INDEX IF NOT EXISTS idx_planos_corte_ordem_id ON public.planos_corte (ordem_id);
