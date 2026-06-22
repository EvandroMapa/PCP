$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

foreach ($loc in @('EVANDRO.002', 'EVANDRO.003')) {
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "=== $loc ===" -ForegroundColor Cyan

    $uri = "$url/rest/v1/pedidos?localizador=eq.$loc&select=id"
    $ped = Invoke-RestMethod -Uri $uri -Headers $headers
    if ($ped.Count -eq 0) { Write-Host "NAO ENCONTRADO"; continue }
    $pedidoId = $ped[0].id
    Write-Host "ID: $pedidoId"

    # Buscar bitolas com os campos de status
    $uri2 = "$url/rest/v1/pedido_bitolas?pedido_id=eq.$pedidoId&select=id,qtde,status,statusess_raw"
    $bitolas = Invoke-RestMethod -Uri $uri2 -Headers $headers

    foreach ($b in $bitolas) {
        $statusRaw = $b.statusess_raw | ConvertTo-Json -Compress
        Write-Host "  Bitola: $($b.id)"
        Write-Host "    qtde: $($b.qtde)"
        Write-Host "    status (campo): $($b.status)"
        Write-Host "    statusess_raw: $statusRaw"

        # Extrai o ultimo status do array JSON
        if ($b.statusess_raw -is [System.Array] -and $b.statusess_raw.Count -gt 0) {
            $ultimo = $b.statusess_raw[-1]
            Write-Host "    ULTIMO STATUS: $($ultimo.status)" -ForegroundColor Yellow
        } elseif ($b.statusess_raw -ne $null) {
            Write-Host "    statusess_raw nao eh array: $($b.statusess_raw.GetType().Name)" -ForegroundColor Red
        } else {
            Write-Host "    statusess_raw: NULL" -ForegroundColor Red
        }
    }
}
