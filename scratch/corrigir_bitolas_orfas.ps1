$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
    'Content-Type'  = 'application/json'
    'Prefer'        = 'return=representation'
}

# 1. Carregar todas as ordens ativas para mapear os IDs de bitolas que REALMENTE estão em ordens
Write-Host "Buscando ordens ativas..." -ForegroundColor Cyan
$uriOrdens = $url + '/rest/v1/ordens?is_archived=eq.false&select=id,id_pedidos_bitolas'
$ordens = Invoke-RestMethod -Uri $uriOrdens -Headers $headers

$bitolasEmOrdens = @{}
foreach ($o in $ordens) {
    if ($o.id_pedidos_bitolas -ne $null) {
        foreach ($ref in $o.id_pedidos_bitolas) {
            $bitolaIdRef = if ($ref.produtoId) { $ref.produtoId } else { $ref.bitola_id }
            if ($bitolaIdRef) {
                $bitolasEmOrdens[$bitolaIdRef] = $o.id
            }
        }
    }
}
Write-Host "Total de bitolas vinculadas a ordens ativas: $($bitolasEmOrdens.Count)" -ForegroundColor Green

# 2. Buscar todas as bitolas com status 'aguardandoProducao'
Write-Host "`nBuscando bitolas com status 'aguardandoProducao'..." -ForegroundColor Cyan
$uriBitolasAg = $url + '/rest/v1/pedido_bitolas?status=eq.aguardandoProducao&select=*'
$bitolasAg = Invoke-RestMethod -Uri $uriBitolasAg -Headers $headers

Write-Host "Total de bitolas com status 'aguardandoProducao': $($bitolasAg.Count)" -ForegroundColor Yellow

$orfas = @()
foreach ($b in $bitolasAg) {
    if (-not $bitolasEmOrdens.ContainsKey($b.id)) {
        $orfas += $b
    }
}

Write-Host "`nBitolas ORFAS encontradas (sem ordem ativa): $($orfas.Count)" -ForegroundColor Red

foreach ($b in $orfas) {
    Write-Host "  -> Corrigindo Bitola ID: $($b.id) | Pedido ID: $($b.pedido_id) | Qtde: $($b.quantidade) Kg" -ForegroundColor Yellow
    
    $novoHistorico = @(
        @{
            id = $b.id + "_sep"
            status = "separado"
            createdAt = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        }
    )

    $patchBody = @{
        status = "separado"
        statusess_raw = $novoHistorico
        materia_prima_raw = $null
    } | ConvertTo-Json -Compress

    $uriPatch = $url + '/rest/v1/pedido_bitolas?id=eq.' + $b.id
    $res = Invoke-RestMethod -Uri $uriPatch -Method Patch -Headers $headers -Body $patchBody
    Write-Host "     Corrigido com sucesso!" -ForegroundColor Green
}

# 3. Atualizar o status dos pedidos afetados
$pedidosAlvo = @('qPWJCbUg55XxfRCQgX13xpsaY', 'baiFRaFIovuaHwraNiPl8eDap', 'TpE9gZv6TR47uNAMju2KOXDtU', 'jUIBwhwF3TG0RCrEuVICCI1Vn', 'bb5qkYVkwKKXywfFwj3Ph35Bt', 'JZzuk2HQl19qNklnH0LPmnT47', 'gRLNA9g6iqSZa3q53ISf7uQmI', 'SjHPM31jgFQne8hisT2oEV52r', 'UBxXScIFfHOxwrxfbvwcBJcaG', 'STYFGWylSorLx0K0bxE2ux75a', 'jGk4vPCzPVSvNnXvDVArMmpCs', 'QsUljbxbtwCMiZkoyaIg8X3dZ', 'DsCzPRAkf6GgxBdcGjbIA2G0G', 'iMK4Qntz8erqe3Z2QCNcfQZqy')

Write-Host "`nRecalculando status dos pedidos afetados ($($pedidosAlvo.Count))..." -ForegroundColor Cyan

foreach ($pedidoIdItem in $pedidosAlvo) {
    $uriPed = $url + '/rest/v1/pedidos?id=eq.' + $pedidoIdItem + '&select=*'
    $ped = Invoke-RestMethod -Uri $uriPed -Headers $headers
    if ($ped.Count -eq 0) { continue }
    $p = $ped[0]

    # Buscar todas as bitolas deste pedido
    $uriPBitolas = $url + '/rest/v1/pedido_bitolas?pedido_id=eq.' + $pedidoIdItem + '&select=*'
    $pBitolas = Invoke-RestMethod -Uri $uriPBitolas -Headers $headers
    
    $todasProntas = ($pBitolas.Count -gt 0) -and ($pBitolas | Where-Object { $_.status -ne 'pronto' }).Count -eq 0
    $algumaEmProducao = ($pBitolas | Where-Object { $_.status -in @('produzindo', 'aguardandoProducao', 'aguardaSegundaEtapa') }).Count -gt 0

    $novoStatusPedido = ""
    if ($todasProntas) {
        $novoStatusPedido = if ($p.tipo -eq 'cda') { 'aguardandoProducaoCDA' } else { 'pronto' }
    } elseif ($algumaEmProducao) {
        $novoStatusPedido = 'produzindoCD'
    } else {
        $novoStatusPedido = 'aguardandoProducaoCD'
    }

    Write-Host "  Pedido $($p.localizador) (ID: $pedidoIdItem): Status Atual = $($p.status) -> Novo Status = $novoStatusPedido" -ForegroundColor Cyan

    if ($p.status -ne $novoStatusPedido) {
        $patchPed = @{
            status = $novoStatusPedido
        } | ConvertTo-Json -Compress
        $uriPatchPed = $url + '/rest/v1/pedidos?id=eq.' + $pedidoIdItem
        $resPed = Invoke-RestMethod -Uri $uriPatchPed -Method Patch -Headers $headers -Body $patchPed
        Write-Host "     Status do pedido atualizado no banco!" -ForegroundColor Green
    }
}

Write-Host "`nVerificacao final de bitolas orfas..." -ForegroundColor Cyan
$uriCheck = $url + '/rest/v1/pedido_bitolas?status=eq.aguardandoProducao&select=id,pedido_id,quantidade'
$check = Invoke-RestMethod -Uri $uriCheck -Headers $headers
Write-Host "Bitolas restantes com status aguardandoProducao: $($check.Count)" -ForegroundColor Green

Write-Host "`nProcesso concluido com sucesso!" -ForegroundColor Green
