-- PASSO 1: backup das OS que serão alteradas (rodar primeiro)
CREATE TABLE IF NOT EXISTS backup_posicoes_20261009 AS
SELECT p.*
FROM elemento_posicoes p
JOIN elementos e ON e.id = p.elemento_id
JOIN pedido_bitolas pb ON pb.pedido_id = e.pedido_id AND pb.bitola_id = p.bitola_id
WHERE pb.status = 'pronto' AND p.status <> 'pronto'
  AND to_timestamp(((pb.statusess_raw -> -1) ->> 'createdAt')::bigint / 1000.0)
        < timestamptz '2026-07-01'
  AND NOT EXISTS (SELECT 1 FROM pedido_bitolas x
                  WHERE x.pedido_id = pb.pedido_id AND x.bitola_id = pb.bitola_id
                    AND x.status <> 'pronto');

-- Conferência: quantas OS entraram no backup (esperado: milhares, ~589 itens)
SELECT count(*) AS os_no_backup FROM backup_posicoes_20261009;
