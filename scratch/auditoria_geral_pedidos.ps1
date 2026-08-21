$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

# 1. Carregar todos os steps válidos
$steps = Invoke-RestMethod -Uri "$url/rest/v1/steps?select=id,nome,index" -Headers $headers
$stepMap = @{}
foreach ($s in $steps) { $stepMap[$s.id] = $s.nome }

Write-Host "--- ANALISE COMPLETA DE TODOS OS PEDIDOS (ATIVOS E ARQUIVADOS) ---" -ForegroundColor Cyan

$allPedidos = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?select=id,localizador,step_id,status,is_archived,histories" -Headers $headers

Write-Host "Total de pedidos no banco: $($allPedidos.Count)"

$divergenciasEtapa = @()
$stepIdInvalido = @()

foreach ($p in $allPedidos) {
    # 1. Checar se step_id existe no mapa de steps
    if ($p.step_id -and -not $stepMap.ContainsKey($p.step_id)) {
        $stepIdInvalido += @{
            id = $p.id
            localizador = $p.localizador
            step_id = $p.step_id
            is_archived = $p.is_archived
        }
    }

    # 2. Checar divergência entre step_id e último histórico de etapa (type = 1)
    if ($p.histories -and $p.histories.Count -gt 0) {
        $stepHist = $p.histories | Where-Object { $_.type -eq 1 }
        if ($stepHist -and $stepHist.Count -gt 0) {
            $lastStep = $stepHist[-1]
            $lastStepId = $lastStep.data.id
            # Se for um step válido e diferente do step_id do banco
            if ($lastStepId -and $stepMap.ContainsKey($lastStepId) -and $lastStepId -ne $p.step_id) {
                $divergenciasEtapa += @{
                    id = $p.id
                    localizador = $p.localizador
                    step_id_banco = $p.step_id
                    step_nome_banco = if ($p.step_id -and $stepMap.ContainsKey($p.step_id)) { $stepMap[$p.step_id] } else { "DESCONHECIDO/VAZIO ($($p.step_id))" }
                    last_hist_id = $lastStepId
                    last_hist_nome = $stepMap[$lastStepId]
                    is_archived = $p.is_archived
                }
            }
        }
    }
}

Write-Host "`n1. Pedidos com step_id divergente do último histórico de etapa: $($divergenciasEtapa.Count)" -ForegroundColor Yellow
foreach ($de in $divergenciasEtapa) {
    Write-Host "  -> Pedido: $($de.localizador) [ID: $($de.id)] | Arquivado: $($de.is_archived)"
    Write-Host "     Banco: $($de.step_nome_banco)"
    Write-Host "     Último Histórico: $($de.last_hist_nome) ($($de.last_hist_id))"
}

Write-Host "`n2. Pedidos com step_id inexistente/inválido: $($stepIdInvalido.Count)" -ForegroundColor Yellow
foreach ($si in $stepIdInvalido) {
    Write-Host "  -> Pedido: $($si.localizador) [ID: $($si.id)] | step_id: $($si.step_id) | Arquivado: $($si.is_archived)"
}
