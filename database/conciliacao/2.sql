-- 2) Movimentações duplicadas (mesma bitola, ordem, tipo, quantidade e
--    observação em até 5 s) — sinal de baixa/estorno em dobro
SELECT bitola_id, ordem_id, tipo, quantidade, observacao,
       count(*) AS repeticoes, min(data_hora) AS primeira, max(data_hora) AS ultima
FROM estoque_movimentacao
WHERE tipo IN ('baixa_producao', 'estorno')
GROUP BY bitola_id, ordem_id, tipo, quantidade, observacao
HAVING count(*) > 1
ORDER BY repeticoes DESC, ultima DESC;

