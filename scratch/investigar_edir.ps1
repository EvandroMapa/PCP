$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

# 1. Buscar o pedido edir-so.053
$ped = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?localizador=ilike.*EDIR-SO.053*&select=*" -Headers $headers

Write-Host "=== PEDIDO EDIR-SO.053 ===" -ForegroundColor Cyan
if ($ped.Count -gt 0) {
    $p = $ped[0]
    Write-Host "ID: $($p.id)"
    Write-Host "Localizador: $($p.localizador)"
    Write-Host "Status: $($p.status)"
    
    # 2. Buscar as bitolas desse pedido
    $bitolas = Invoke-RestMethod -Uri "$url/rest/v1/pedido_bitolas?pedido_id=eq.$($p.id)&select=*" -Headers $headers
    Write-Host "`n=== BITOLAS DO PEDIDO ($($bitolas.Count)) ===" -ForegroundColor Yellow
    foreach ($b in $bitolas) {
        Write-Host "----------------------------------------------------"
        Write-Host "Bitola ID: $($b.id)"
        Write-Host "Bitola: $($b.bitola_raw.nome) - $($b.bitola_raw.descricao)"
        Write-Host "Status: $($b.status)"
        Write-Host "Qtde: $($b.quantidade) Kg"
        Write-Host "Materia Prima Raw: $($b.materia_prima_raw | ConvertTo-Json -Compress)"
        Write-Host "Statusess Raw: $($b.statusess_raw | ConvertTo-Json -Compress)"
        
        # 3. Verificar se essa bitola esta em alguma ordem
        $todasOrdens = Invoke-RestMethod -Uri "$url/rest/v1/ordens?select=id,localizador,is_archived,id_pedidos_bitolas" -Headers $headers
        $ordensComBitola = @()
        foreach ($ordem in $todasOrdens) {
            if ($ordem.id_pedidos_bitolas) {
                foreach ($ref in $ordem.id_pedidos_bitolas) {
                    $refId = if ($ref.produtoId) { $ref.produtoId } else { $ref.bitola_id }
                    if ($refId -eq $b.id) {
                        $ordensComBitola += $ordem
                    }
                }
            }
        }
        
        if ($ordensComBitola.Count -gt 0) {
            Write-Host "  -> PRESENTE NAS ORDENS ($($ordensComBitola.Count)): " -ForegroundColor Green
            foreach ($o in $ordensComBitola) {
                Write-Host "     - Ordem ID: $($o.id) | Localizador: $($o.localizador) | Archived: $($o.is_archived)"
            }
        } else {
            Write-Host "  -> NAO ESTA EM NENHUMA ORDEM (ORFA)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "Pedido EDIR-SO.053 nao encontrado!" -ForegroundColor Red
}
