-- 1) Saldo real por bitola x campo resumido estoque.quantidade
SELECT b.id AS bitola_id, b.nome,
       COALESCE(m.saldo, 0)            AS saldo_pelas_movimentacoes,
       COALESCE(e.quantidade, 0)       AS estoque_quantidade,
       COALESCE(e.quantidade, 0) - COALESCE(m.saldo, 0) AS diferenca
FROM bitolas b
LEFT JOIN (SELECT bitola_id, SUM(quantidade) saldo
           FROM estoque_movimentacao GROUP BY bitola_id) m ON m.bitola_id = b.id
LEFT JOIN estoque e ON e.bitola_id = b.id
WHERE abs(COALESCE(e.quantidade, 0) - COALESCE(m.saldo, 0)) > 0.001
ORDER BY abs(COALESCE(e.quantidade, 0) - COALESCE(m.saldo, 0)) DESC;

