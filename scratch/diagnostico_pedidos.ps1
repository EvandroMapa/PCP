$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$pedidos = @(
    @{ id = 'qPWJCbUg55XxfRCQgX13xpsaY'; loc = 'KENNETH.026 - 26349' },
    @{ id = 'jUIBwhwF3TG0RCrEuVICCI1Vn'; loc = 'RENATO-LU.003 - 27401' },
    @{ id = 'TpE9gZv6TR47uNAMju2KOXDtU'; loc = 'VICE-PURI.001 - 27460' },
    @{ id = 'baiFRaFIovuaHwraNiPl8eDap'; loc = 'CAIO-N.002 - 27500' }
)

# Buscar produtos para mapear id -> nome
$produtos = Invoke-RestMethod -Uri "$url/rest/v1/produtos?select=id,nome" -Headers $headers
$prodMap = @{}
foreach ($p in $produtos) { $prodMap[$p.id] = $p.nome }

foreach ($p in $pedidos) {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host "=== $($p.loc) (ID: $($p.id)) ===" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    $bitolas = Invoke-RestMethod -Uri "$url/rest/v1/pedido_bitolas?pedido_id=eq.$($p.id)&select=*" -Headers $headers

    foreach ($b in $bitolas) {
        $pNome = $prodMap[$b.produto_id]
        Write-Host "  Bitola: $pNome ($($b.produto_id)) | Qtde: $($b.qtde) | Status: $($b.status)" -ForegroundColor Yellow
        Write-Host "    Statusess Raw: $($b.statusess_raw | ConvertTo-Json -Compress)"
    }
}
