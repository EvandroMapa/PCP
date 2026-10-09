-- 6) Falhas de gravação registradas pelo app (baixa que não chegou ao banco)
SELECT * FROM audit_logs
WHERE acao = 'falha_movimentacao_estoque'
ORDER BY 1 DESC;
