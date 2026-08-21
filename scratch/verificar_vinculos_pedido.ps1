$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$id = 'z1BUZEy10V9nE1oVYOS2Y8Lqi'

Write-Host "--- ELEMENTOS DO PEDIDO ---" -ForegroundColor Cyan
$elementos = Invoke-RestMethod -Uri "$url/rest/v1/elementos?pedido_id=eq.$id&select=*" -Headers $headers
Write-Host "Total Elementos: $($elementos.Count)"
foreach ($e in $elementos) {
    Write-Host "Elemento ID: $($e.id) | Nome: $($e.nome) | Status: $($e.status) | Qtde Pronto: $($e.qtde_pronto) / $($e.qtde_planejada)"
}

Write-Host "`n--- BITOLAS DO PEDIDO ---" -ForegroundColor Cyan
$bitolas = Invoke-RestMethod -Uri "$url/rest/v1/pedido_bitolas?pedido_id=eq.$id&select=*" -Headers $headers
foreach ($b in $bitolas) {
    Write-Host "Bitola ID: $($b.id) | Bitola_Id: $($b.bitola_id) | Status: $($b.status) | Qtde: $($b.quantidade)"
}

Write-Host "`n--- ORDENS QUE REFERENCIAM O PEDIDO ---" -ForegroundColor Cyan
$ordens = Invoke-RestMethod -Uri "$url/rest/v1/ordens?select=id,localizador,id_pedidos_bitolas,is_archived,created_at,updated_at" -Headers $headers
foreach ($ord in $ordens) {
    if ($ord.id_pedidos_bitolas) {
        $matches = $false
        foreach ($ref in $ord.id_pedidos_bitolas) {
            if ($ref.pedidoId -eq $id -or $ref.pedido_id -eq $id) {
                $matches = $true
                break
            }
            foreach ($b in $bitolas) {
                if ($ref.produtoId -eq $b.id -or $ref.bitola_id -eq $b.id) {
                    $matches = $true
                    break
                }
            }
        }
        if ($matches) {
            Write-Host "Ordem ID: $($ord.id) | Localizador: $($ord.localizador) | is_archived: $($ord.is_archived) | Updated: $($ord.updated_at)"
        }
    }
}
