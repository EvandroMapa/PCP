$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$ordens = Invoke-RestMethod -Uri "$url/rest/v1/ordens?id=eq.OP10-343_VyKbOop3BweyV71oLYtI9l1kL&select=*" -Headers $headers
$o = $ordens[0]
$refs = $o.id_pedidos_bitolas
Write-Host "Total refs: $($refs.Count)"

$i = 0
foreach ($r in $refs) {
    $i++
    $pedidoId = if ($r.pedidoId) { $r.pedidoId } else { $r.pedido_id }
    $bitolaId = if ($r.produtoId) { $r.produtoId } else { $r.bitola_id }
    
    $ped = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?id=eq.$pedidoId&select=id,localizador,is_archived,step_id" -Headers $headers
    if ($ped.Count -eq 0) {
        Write-Host "[$i] Pedido ID $pedidoId - NAO ENCONTRADO NO BANCO! (bitolaId: $bitolaId)" -ForegroundColor Red
    } else {
        $bitolas = Invoke-RestMethod -Uri "$url/rest/v1/pedido_bitolas?pedido_id=eq.$pedidoId&select=*" -Headers $headers
        $bMatch = $bitolas | Where-Object { $_.id -eq $bitolaId }
        if ($bMatch) {
            Write-Host "[$i] Pedido $($ped[0].localizador) (id: $pedidoId) - Bitola $bitolaId - OK ($($bMatch.qtde)kg, status: $($bMatch.status))" -ForegroundColor Green
        } else {
            Write-Host "[$i] Pedido $($ped[0].localizador) (id: $pedidoId) - Bitola $bitolaId - NAO ENCONTRADA NO PEDIDO!" -ForegroundColor Yellow
        }
    }
}
