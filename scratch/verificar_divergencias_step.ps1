$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

Write-Host "--- VERIFICANDO DIVERGENCIA ENTRE STEP_ID E ULTIMO HISTORICO ---" -ForegroundColor Cyan

$pedidos = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?is_archived=eq.false&select=id,localizador,step_id,histories" -Headers $headers

$divergentes = @()

foreach ($p in $pedidos) {
    if ($p.histories -and $p.histories.Count -gt 0) {
        # Pegar o último histórico do tipo etapa (type = 1)
        $stepHistories = $p.histories | Where-Object { $_.type -eq 1 }
        if ($stepHistories -and $stepHistories.Count -gt 0) {
            $lastStepHist = $stepHistories[-1]
            $lastStepId = $lastStepHist.data.id
            if ($lastStepId -and $lastStepId -ne $p.step_id) {
                $divergentes += @{
                    id = $p.id
                    localizador = $p.localizador
                    step_id_banco = $p.step_id
                    last_hist_step_id = $lastStepId
                    last_hist_step_nome = $lastStepHist.data.name
                }
            }
        }
    }
}

Write-Host "Total de pedidos ativos analisados: $($pedidos.Count)"
Write-Host "Total de pedidos com divergência de etapa: $($divergentes.Count)" -ForegroundColor Yellow

foreach ($d in $divergentes) {
    Write-Host "  -> Pedido: $($d.localizador) (ID: $($d.id))" -ForegroundColor Red
    Write-Host "     step_id no banco: $($d.step_id_banco)"
    Write-Host "     última etapa no histórico: $($d.last_hist_step_nome) ($($d.last_hist_step_id))"
}
