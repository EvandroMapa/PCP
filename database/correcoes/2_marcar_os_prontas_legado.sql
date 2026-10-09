-- PASSO 2: só rodar depois do passo 1 e depois de conferir a contagem.
-- Marca como 'pronto' as OS de itens já prontos (a baixa já foi feita pelo item).
-- NÃO gera movimentação de estoque (nenhum trigger de baixa está ativo).
-- NÃO rodar depois de aplicar database/propostas/estoque_baixa_trigger.sql:
-- com o trigger ligado, este UPDATE geraria baixas.
BEGIN;
UPDATE elemento_posicoes p
SET status = 'pronto'
WHERE p.id IN (SELECT id FROM backup_posicoes_20261009)
  AND p.status <> 'pronto';

-- Deve bater com o os_no_backup do passo 1. Se não bater, rode ROLLBACK; em vez de COMMIT;
SELECT count(*) AS os_alteradas FROM elemento_posicoes
WHERE id IN (SELECT id FROM backup_posicoes_20261009) AND status = 'pronto';
COMMIT;

-- Desfazer, se precisar:
-- UPDATE elemento_posicoes p SET status = b.status
-- FROM backup_posicoes_20261009 b WHERE b.id = p.id;
