$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$ordens = Invoke-RestMethod -Uri "$url/rest/v1/ordens?id=eq.OP10-343_VyKbOop3BweyV71oLYtI9l1kL&select=*" -Headers $headers
$o = $ordens[0]
$refs = $o.id_pedidos_bitolas

$prontos = 0
$total = $refs.Count
$naoProntos = @()

foreach ($r in $refs) {
    $pedId = if ($r.pedidoId) { $r.pedidoId } else { $r.pedido_id }
    $bitId = if ($r.produtoId) { $r.produtoId } else { $r.bitola_id }
    
    $bitolas = Invoke-RestMethod -Uri "$url/rest/v1/pedido_bitolas?id=eq.$bitId&select=*" -Headers $headers
    if ($bitolas.Count -gt 0) {
        $b = $bitolas[0]
        if ($b.status -eq 'pronto') {
            $prontos++
        } else {
            $naoProntos += "Bitola $bitId - status=$($b.status) (pedido $pedId)"
        }
    } else {
        $naoProntos += "Bitola $bitId - NAO ENCONTRADA (pedido $pedId)"
    }
}

Write-Host "OP10-343: $prontos de $total itens estao com status PRONTO."
if ($naoProntos.Count -gt 0) {
    Write-Host "Itens nao prontos:"
    $naoProntos | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
}
