-- 4) Baixas de OS que não existem mais (OS apagada por edição/reimportação
--    sem estorno): numero_os com líquido negativo sem posição correspondente
WITH mov AS (
  SELECT bitola_id, substring(observacao FROM '· OS (.+)$') AS numero_os,
         SUM(quantidade) AS liquido
  FROM estoque_movimentacao
  WHERE tipo IN ('baixa_producao', 'estorno') AND observacao LIKE '%· OS %'
  GROUP BY 1, 2
)
SELECT mov.*
FROM mov
WHERE mov.liquido < -0.01
  AND NOT EXISTS (SELECT 1 FROM elemento_posicoes p
                  WHERE p.numero_os = mov.numero_os AND p.bitola_id = mov.bitola_id)
ORDER BY mov.liquido;

