-- =============================================================================
-- PROPOSTA (NÃO APLICADA) — Baixa de estoque da produção feita pelo banco
-- =============================================================================
-- Objetivo: a movimentação de estoque nasce na MESMA transação que muda o
-- status da OS (elemento_posicoes) ou do item (pedido_bitolas). Assim:
--   • não existe "status pronto sem baixa" nem "baixa sem status pronto";
--   • duas telas/aparelhos não conseguem baixar a mesma OS duas vezes — o
--     UPDATE trava a linha e o segundo vê OLD.status = 'pronto' (sem travessia);
--   • o estorno devolve exatamente o que foi baixado (lido do histórico), mesmo
--     que o peso da OS tenha sido editado depois.
--
-- ⚠️ ORDEM DE IMPLANTAÇÃO — aplicar SÓ junto com a versão do app que:
--   1. remove as chamadas estoqueCtrl.baixarEstoque/estornarBaixa da produção
--      (ordem_controller.onChangeProdutoStatus e ordem_pedido_elementos_dialog);
--   2. mantém os updates condicionais (EstoqueProducaoService) — continuam úteis
--      para a UI saber se a transição foi aplicada;
--   3. envia `atualizado_por` (nome do usuário) junto com cada mudança de status.
--   Se o trigger for ligado com o app atual, TODA baixa sai em dobro.
--
-- Teste antes num branch do Supabase ou numa cópia do banco.
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Rastreabilidade: cada movimentação de produção aponta para a OS ou item
-- -----------------------------------------------------------------------------
ALTER TABLE public.estoque_movimentacao
  ADD COLUMN IF NOT EXISTS posicao_id       text,
  ADD COLUMN IF NOT EXISTS pedido_bitola_id text,
  ADD COLUMN IF NOT EXISTS origem           text NOT NULL DEFAULT 'app';

CREATE INDEX IF NOT EXISTS idx_estoque_mov_posicao
  ON public.estoque_movimentacao (posicao_id, created_at DESC)
  WHERE posicao_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_estoque_mov_item
  ON public.estoque_movimentacao (pedido_bitola_id, created_at DESC)
  WHERE pedido_bitola_id IS NOT NULL AND posicao_id IS NULL;

-- Quem fez a mudança (o app não usa Supabase Auth, então o nome vem na linha)
ALTER TABLE public.elemento_posicoes ADD COLUMN IF NOT EXISTS atualizado_por text;
ALTER TABLE public.pedido_bitolas    ADD COLUMN IF NOT EXISTS atualizado_por text;

-- -----------------------------------------------------------------------------
-- 2. Auxiliares
-- -----------------------------------------------------------------------------

-- Ordem que contém o item (prefere a ativa mais recente)
CREATE OR REPLACE FUNCTION public.pcp_ordem_do_item(p_pedido_bitola_id text)
RETURNS text
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT o.id
  FROM ordens o
  WHERE o.id_pedidos_bitolas @> jsonb_build_array(jsonb_build_object('produtoId', p_pedido_bitola_id))
     OR o.id_pedidos_bitolas @> jsonb_build_array(jsonb_build_object('bitola_id', p_pedido_bitola_id))
  ORDER BY o.is_archived ASC, o.created_at DESC
  LIMIT 1
$$;

-- Item (pedido_bitolas) de uma OS: mesmo pedido do elemento + mesma bitola
CREATE OR REPLACE FUNCTION public.pcp_item_da_posicao(p_elemento_id text, p_bitola_id text)
RETURNS text
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT pb.id
  FROM pedido_bitolas pb
  JOIN elementos e ON e.pedido_id = pb.pedido_id
  WHERE e.id = p_elemento_id
    AND pb.bitola_id = p_bitola_id
  ORDER BY (pb.status <> 'separado') DESC
  LIMIT 1
$$;

-- Peso total das OS de um item (peso_kg × qtde do elemento — mesma regra do app)
CREATE OR REPLACE FUNCTION public.pcp_peso_os_do_item(p_pedido_id text, p_bitola_id text)
RETURNS numeric
LANGUAGE sql STABLE
SET search_path = public
AS $$
  SELECT COALESCE(SUM(p.peso_kg * COALESCE(e.qtde, 1)), 0)
  FROM elemento_posicoes p
  JOIN elementos e ON e.id = p.elemento_id
  WHERE e.pedido_id = p_pedido_id
    AND p.bitola_id = p_bitola_id
$$;

CREATE OR REPLACE FUNCTION public.pcp_registrar_mov_producao(
  p_bitola_id        text,
  p_quantidade       numeric,   -- negativo = baixa, positivo = estorno
  p_ordem_id         text,
  p_posicao_id       text,
  p_pedido_bitola_id text,
  p_usuario          text,
  p_detalhe          text
) RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_loc text := COALESCE(split_part(p_ordem_id, '_', 1), '?');
BEGIN
  IF abs(p_quantidade) < 0.0005 THEN
    RETURN;
  END IF;

  INSERT INTO estoque_movimentacao (
    id, bitola_id, tipo, quantidade, observacao, ordem_id,
    data_hora, usuario_nome, created_at,
    posicao_id, pedido_bitola_id, origem
  ) VALUES (
    gen_random_uuid()::text,
    p_bitola_id,
    CASE WHEN p_quantidade < 0 THEN 'baixa_producao' ELSE 'estorno' END,
    p_quantidade,
    CASE WHEN p_quantidade < 0
      THEN 'Baixa da Ordem ' || v_loc
      ELSE 'Estorno — Ordem ' || v_loc || ' voltou de Pronto'
    END || COALESCE(' · ' || p_detalhe, ''),
    p_ordem_id,
    clock_timestamp(),   -- clock_timestamp: ordem correta dentro da mesma transação
    p_usuario,
    clock_timestamp(),
    p_posicao_id,
    p_pedido_bitola_id,
    'trigger'
  );
END;
$$;

-- -----------------------------------------------------------------------------
-- 3. Trigger das OS (elemento_posicoes)
--    UPDATE: travessia da fronteira 'pronto'
--    INSERT pronto / DELETE pronto: edição ou reimportação de elementos
--      (o app apaga e recria as posições) — sem isso o estoque desalinha.
--      DECISÃO DE NEGÓCIO: se preferir que apagar uma OS pronta NÃO devolva
--      o material, remova INSERT/DELETE do CREATE TRIGGER no fim desta seção.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pcp_trg_posicao_estoque()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_antes   boolean := false;
  v_depois  boolean := false;
  v_id      text;
  v_elem    text;
  v_bitola  text;
  v_peso_kg numeric;
  v_usuario text;
  v_qtde_el integer;
  v_item    text;
  v_ordem   text;
  v_ult_tipo text;
  v_ult_qtde numeric;
  v_num_os  text;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    v_antes := OLD.status = 'pronto';
  END IF;
  IF TG_OP IN ('UPDATE', 'INSERT') THEN
    v_depois := NEW.status = 'pronto';
  END IF;
  IF v_antes = v_depois THEN
    RETURN NULL;           -- não cruzou a fronteira: sem efeito no estoque
  END IF;

  IF TG_OP = 'DELETE' THEN
    v_id := OLD.id; v_elem := OLD.elemento_id; v_bitola := OLD.bitola_id;
    v_peso_kg := OLD.peso_kg; v_usuario := OLD.atualizado_por; v_num_os := OLD.numero_os;
  ELSE
    v_id := NEW.id; v_elem := NEW.elemento_id; v_bitola := NEW.bitola_id;
    v_peso_kg := NEW.peso_kg; v_usuario := NEW.atualizado_por; v_num_os := NEW.numero_os;
  END IF;

  SELECT COALESCE(qtde, 1) INTO v_qtde_el FROM elementos WHERE id = v_elem;
  v_item  := pcp_item_da_posicao(v_elem, v_bitola);
  v_ordem := CASE WHEN v_item IS NULL THEN NULL ELSE pcp_ordem_do_item(v_item) END;

  -- Última movimentação vinculada a esta OS
  SELECT tipo, quantidade INTO v_ult_tipo, v_ult_qtde
  FROM estoque_movimentacao
  WHERE posicao_id = v_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_depois THEN
    -- Entrou em pronto. Se a última vinculada já é uma baixa, não repete.
    IF v_ult_tipo = 'baixa_producao' THEN
      RETURN NULL;
    END IF;
    PERFORM pcp_registrar_mov_producao(
      v_bitola, -(v_peso_kg * COALESCE(v_qtde_el, 1)), v_ordem, v_id, v_item,
      v_usuario, 'OS ' || COALESCE(v_num_os, v_id));
  ELSE
    -- Saiu de pronto. Devolve exatamente o que foi baixado; sem histórico
    -- vinculado (baixa feita pelo app antigo) usa o peso atual.
    IF v_ult_tipo = 'estorno' THEN
      RETURN NULL;         -- já estornada
    END IF;
    PERFORM pcp_registrar_mov_producao(
      v_bitola,
      CASE WHEN v_ult_tipo IS NOT NULL THEN -v_ult_qtde
           ELSE v_peso_kg * COALESCE(v_qtde_el, 1) END,
      v_ordem, v_id, v_item, v_usuario, 'OS ' || COALESCE(v_num_os, v_id));
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_posicao_estoque ON public.elemento_posicoes;
CREATE TRIGGER trg_posicao_estoque
  AFTER INSERT OR DELETE OR UPDATE OF status ON public.elemento_posicoes
  FOR EACH ROW EXECUTE FUNCTION public.pcp_trg_posicao_estoque();

-- -----------------------------------------------------------------------------
-- 4. Trigger do item (pedido_bitolas) — complemento
--    Complemento = qtde do item − peso das OS (ou qtde inteira sem OS).
--    É a parte que as OS não cobrem; baixada ao entrar em pronto e estornada
--    ao sair, em qualquer modo de apontamento (mesma regra do app corrigido).
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pcp_trg_item_estoque()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_antes  boolean := OLD.status = 'pronto';
  v_depois boolean := NEW.status = 'pronto';
  v_ordem  text;
  v_compl  numeric;
  v_ult_tipo text;
  v_ult_qtde numeric;
BEGIN
  IF v_antes = v_depois THEN
    RETURN NULL;
  END IF;

  v_ordem := pcp_ordem_do_item(NEW.id);

  SELECT tipo, quantidade INTO v_ult_tipo, v_ult_qtde
  FROM estoque_movimentacao
  WHERE pedido_bitola_id = NEW.id AND posicao_id IS NULL
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_depois THEN
    IF v_ult_tipo = 'baixa_producao' THEN
      RETURN NULL;
    END IF;
    v_compl := COALESCE(NEW.qtde, 0) - pcp_peso_os_do_item(NEW.pedido_id, NEW.bitola_id);
    IF v_compl > 0.05 THEN
      PERFORM pcp_registrar_mov_producao(
        NEW.bitola_id, -v_compl, v_ordem, NULL, NEW.id,
        NEW.atualizado_por, 'complemento do item');
    END IF;
  ELSE
    IF v_ult_tipo = 'estorno' THEN
      RETURN NULL;
    END IF;
    IF v_ult_tipo IS NOT NULL THEN
      v_compl := -v_ult_qtde;
    ELSE
      -- Legado (baixa feita pelo app antigo): recalcula o complemento atual
      v_compl := COALESCE(NEW.qtde, 0) - pcp_peso_os_do_item(NEW.pedido_id, NEW.bitola_id);
    END IF;
    IF v_compl > 0.05 THEN
      PERFORM pcp_registrar_mov_producao(
        NEW.bitola_id, v_compl, v_ordem, NULL, NEW.id,
        NEW.atualizado_por, 'complemento do item');
    END IF;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_item_estoque ON public.pedido_bitolas;
CREATE TRIGGER trg_item_estoque
  AFTER UPDATE OF status ON public.pedido_bitolas
  FOR EACH ROW EXECUTE FUNCTION public.pcp_trg_item_estoque();

COMMIT;

-- =============================================================================
-- Verificação após aplicar (rodar num ambiente de teste)
-- =============================================================================
-- 1) Marcar uma OS pronta duas vezes → deve existir UMA baixa vinculada:
--    UPDATE elemento_posicoes SET status = 'pronto' WHERE id = '<os>';
--    UPDATE elemento_posicoes SET status = 'pronto' WHERE id = '<os>';
--    SELECT tipo, quantidade FROM estoque_movimentacao WHERE posicao_id = '<os>';
--
-- 2) Voltar e marcar de novo → baixa, estorno, baixa (líquido = 1 baixa):
--    UPDATE elemento_posicoes SET status = 'produzindo' WHERE id = '<os>';
--    UPDATE elemento_posicoes SET status = 'pronto'     WHERE id = '<os>';
--    SELECT SUM(quantidade) FROM estoque_movimentacao WHERE posicao_id = '<os>';
--
-- 3) Concorrência: em duas sessões SQL, BEGIN; UPDATE ... 'pronto'; na mesma OS.
--    A segunda espera o COMMIT da primeira e não gera movimentação.

-- =============================================================================
-- Rollback
-- =============================================================================
-- DROP TRIGGER IF EXISTS trg_posicao_estoque ON public.elemento_posicoes;
-- DROP TRIGGER IF EXISTS trg_item_estoque    ON public.pedido_bitolas;
-- DROP FUNCTION IF EXISTS public.pcp_trg_posicao_estoque();
-- DROP FUNCTION IF EXISTS public.pcp_trg_item_estoque();
-- DROP FUNCTION IF EXISTS public.pcp_registrar_mov_producao(text, numeric, text, text, text, text, text);
-- DROP FUNCTION IF EXISTS public.pcp_peso_os_do_item(text, text);
-- DROP FUNCTION IF EXISTS public.pcp_item_da_posicao(text, text);
-- DROP FUNCTION IF EXISTS public.pcp_ordem_do_item(text);
-- (as colunas novas podem ficar; são opcionais e não quebram o app atual)
