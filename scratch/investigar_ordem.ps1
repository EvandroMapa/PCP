$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$ordens = Invoke-RestMethod -Uri "$url/rest/v1/ordens?id=ilike.*10-343*&select=*" -Headers $headers

Write-Host "Total de ordens encontradas: $($ordens.Count)"
foreach ($o in $ordens) {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "ORDEM ID: $($o.id) | is_archived: $($o.is_archived) | updated_at: $($o.updated_at)"
    Write-Host "Bitola raw: $($o.bitola_raw | ConvertTo-Json -Compress)"
    $refs = $o.id_pedidos_bitolas
    Write-Host "Qtd refs no id_pedidos_bitolas: $($refs.Count)"
    
    foreach ($r in $refs) {
        $pedidoId = if ($r.pedidoId) { $r.pedidoId } else { $r.pedido_id }
        $bitolaId = if ($r.produtoId) { $r.produtoId } else { $r.bitola_id }
        
        Write-Host "`n--- Ref: PedidoId=$pedidoId, BitolaId=$bitolaId ---" -ForegroundColor Yellow
        $ped = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?id=eq.$pedidoId&select=id,localizador,is_archived,step_id" -Headers $headers
        if ($ped.Count -eq 0) {
            Write-Host "  [FALHA] Pedido $pedidoId NAO EXISTE na tabela pedidos!" -ForegroundColor Red
        } else {
            Write-Host "  [OK] Pedido $($ped[0].localizador) (id: $pedidoId, is_archived: $($ped[0].is_archived))" -ForegroundColor Green
            
            # Buscar bitolas do pedido
            $bitolas = Invoke-RestMethod -Uri "$url/rest/v1/pedido_bitolas?pedido_id=eq.$pedidoId&select=*" -Headers $headers
            Write-Host "  Bitolas cadastradas no pedido ($($bitolas.Count)): "
            $achou = $false
            foreach ($b in $bitolas) {
                $isMatch = ($b.id -eq $bitolaId)
                if ($isMatch) { $achou = $true }
                $color = if ($isMatch) { "Green" } else { "Gray" }
                Write-Host "    - Bitola ID: $($b.id) | bitola_id: $($b.bitola_id) | qtde: $($b.qtde) | status: $($b.status) | MATCH: $isMatch" -ForegroundColor $color
            }
            if (-not $achou) {
                Write-Host "  [FALHA] BitolaId $bitolaId NAO EXISTE nas bitolas do pedido!" -ForegroundColor Red
            }
        }
    }
}
