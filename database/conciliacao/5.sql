-- 5) Itens (pedido_bitolas) prontos cujo complemento não aparece no histórico,
--    e itens NÃO prontos com complemento ainda baixado
WITH comp AS (
  SELECT ordem_id, bitola_id, SUM(quantidade) AS liquido
  FROM estoque_movimentacao
  WHERE tipo IN ('baixa_producao', 'estorno')
    AND observacao LIKE '%complemento do item%'
  GROUP BY 1, 2
)
SELECT pb.id, pb.pedido_id, pb.bitola_id, pb.status, pb.qtde,
       round(COALESCE(os.peso_os, 0)::numeric, 3) AS peso_das_os,
       round(COALESCE(c.liquido, 0)::numeric, 3)   AS complemento_liquido
FROM pedido_bitolas pb
LEFT JOIN LATERAL (
  SELECT SUM(p.peso_kg * COALESCE(e.qtde, 1)) AS peso_os
  FROM elemento_posicoes p JOIN elementos e ON e.id = p.elemento_id
  WHERE e.pedido_id = pb.pedido_id AND p.bitola_id = pb.bitola_id
) os ON true
LEFT JOIN comp c ON c.bitola_id = pb.bitola_id
                AND c.ordem_id IN (SELECT o.id FROM ordens o
                     WHERE o.id_pedidos_bitolas::text LIKE '%' || pb.id || '%')
WHERE (pb.status = 'pronto'
       AND pb.qtde - COALESCE(os.peso_os, 0) > 0.05
       AND COALESCE(c.liquido, 0) > -0.01)
   OR (pb.status <> 'pronto' AND COALESCE(c.liquido, 0) < -0.01);

