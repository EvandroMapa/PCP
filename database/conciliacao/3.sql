-- 3) Baixas por OS: a observação traz "OS <numero_os>". Compara, por ordem e OS,
--    baixas x estornos. Líquido deve ser -peso da OS (pronta) ou 0 (não pronta).
WITH mov AS (
  SELECT ordem_id, bitola_id,
         substring(observacao FROM '· OS (.+)$') AS numero_os,
         SUM(quantidade) AS liquido,
         count(*) FILTER (WHERE tipo = 'baixa_producao') AS n_baixas,
         count(*) FILTER (WHERE tipo = 'estorno')        AS n_estornos
  FROM estoque_movimentacao
  WHERE tipo IN ('baixa_producao', 'estorno')
    AND observacao LIKE '%· OS %'
  GROUP BY 1, 2, 3
)
SELECT p.id AS posicao_id, p.numero_os, p.status,
       round((p.peso_kg * COALESCE(e.qtde, 1))::numeric, 3) AS peso_os,
       mov.n_baixas, mov.n_estornos, round(mov.liquido::numeric, 3) AS liquido,
       CASE
         WHEN p.status = 'pronto' AND mov.liquido IS NULL THEN 'PRONTA SEM BAIXA'
         WHEN p.status = 'pronto' AND abs(mov.liquido + p.peso_kg * COALESCE(e.qtde, 1)) > 0.01
              THEN 'PRONTA COM VALOR DIFERENTE (baixa em dobro/parcial/peso editado)'
         WHEN p.status <> 'pronto' AND abs(COALESCE(mov.liquido, 0)) > 0.01
              THEN 'NAO PRONTA MAS COM BAIXA LIQUIDA'
       END AS problema
FROM elemento_posicoes p
JOIN elementos e ON e.id = p.elemento_id
LEFT JOIN mov ON mov.numero_os = p.numero_os AND mov.bitola_id = p.bitola_id
WHERE CASE
  WHEN p.status = 'pronto' AND mov.liquido IS NULL THEN true
  WHEN p.status = 'pronto' AND abs(mov.liquido + p.peso_kg * COALESCE(e.qtde, 1)) > 0.01 THEN true
  WHEN p.status <> 'pronto' AND abs(COALESCE(mov.liquido, 0)) > 0.01 THEN true
  ELSE false END
ORDER BY problema, p.numero_os;
-- Obs.: se o mesmo numero_os se repetir entre pedidos, o cruzamento por
-- numero_os pode misturar casos; trate as linhas como "suspeitas a conferir".

