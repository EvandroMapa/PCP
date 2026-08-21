$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$id = 'z1BUZEy10V9nE1oVYOS2Y8Lqi'

Write-Host "--- VINCULOS DE PEDIDOS ---" -ForegroundColor Cyan
$peds = Invoke-RestMethod -Uri "$url/rest/v1/pedidos?select=id,localizador,step_id,pedidos_vinculados,pedidos_filhos,pai_id" -Headers $headers

$vinculadosComEste = @()
foreach ($p in $peds) {
    if ($p.id -eq $id) {
        Write-Host "O proprio pedido 27028 tem vinculados: $($p.pedidos_vinculados | ConvertTo-Json -Compress) | Filhos: $($p.pedidos_filhos | ConvertTo-Json -Compress) | Pai: $($p.pai_id)"
    }
    if ($p.pedidos_vinculados -contains $id -or ($p.pedidos_vinculados -ne $null -and $p.pedidos_vinculados.Contains($id))) {
        $vinculadosComEste += $p
    }
    if ($p.pedidos_filhos -contains $id -or ($p.pedidos_filhos -ne $null -and $p.pedidos_filhos.Contains($id))) {
        Write-Host "Pedido pai deste: $($p.localizador) ($($p.id))"
    }
}

Write-Host "Pedidos que tem 27028 em pedidos_vinculados: $($vinculadosComEste.Count)"
foreach ($v in $vinculadosComEste) {
    Write-Host "  -> $($v.localizador) ($($v.id)) | Step: $($v.step_id)"
}
