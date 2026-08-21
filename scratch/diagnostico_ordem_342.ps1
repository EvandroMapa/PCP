$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$uri = $url + '/rest/v1/ordens?id=ilike.*342*&select=*'
$ordens = Invoke-RestMethod -Uri $uri -Headers $headers

foreach ($o in $ordens) {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "Ordem ID: $($o.id)"
    Write-Host "Is Archived: $($o.is_archived)"
    
    if ($o.id_pedidos_bitolas) {
        Write-Host "`nBitolas na ordem ($($o.id_pedidos_bitolas.Count)):" -ForegroundColor Yellow
        foreach ($r in $o.id_pedidos_bitolas) {
            $itemProdId = if ($r.produtoId) { $r.produtoId } else { $r.bitola_id }
            $uriBit = $url + '/rest/v1/pedido_bitolas?id=eq.' + $itemProdId + '&select=*'
            $b = Invoke-RestMethod -Uri $uriBit -Headers $headers
            if ($b.Count -gt 0) {
                Write-Host "  -> Bitola Item: $($b[0].id) | Status: $($b[0].status) | Qtde: $($b[0].quantidade) Kg"
                Write-Host "     Statusess RAW: $($b[0].statusess_raw | ConvertTo-Json -Compress)"
            } else {
                Write-Host "  -> Bitola $itemProdId NAO ENCONTRADA" -ForegroundColor Red
            }
        }
    }
}
