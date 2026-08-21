$url = 'https://aumfedyfrxuwgkdhwrel.supabase.co'
$key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1bWZlZHlmcnh1d2drZGh3cmVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM5MzI1NjUsImV4cCI6MjA4OTUwODU2NX0.egxt22BJdXhZndMKsAjNMIvZNBY807JGr5hqn9Gk3A8'
$headers = @{
    'apikey'        = $key
    'Authorization' = "Bearer $key"
}

$bitolasCorrigidas = @(
    '5kvzsUIrkUEX6tObE3ly24ltZ',
    'XGNNVkHqIuQYUBFjyTNeXBT9X',
    'ikfmDHWJfYBDzuCsPvkaGm4Uv',
    'Anf62WtYYUayeaPKSW1KlLSKP',
    'xjtzEU4XPNFLCATHYD3KqGUEN',
    'mncufQ8aAkqc9shaih3xmhTOo',
    'kHN49ibFb37AwTU8xGmrkejSj',
    'yYrfJcfncOg3yqfnqx2FwlOVd',
    'Nica0knQ5zh05RTSisbL0Q9Em',
    'O1UC1t20A4Q6tgf4f66qzo80W',
    'oLjYP5SsBw46L6psW3ibFM2ll',
    'T5WhFUb9udH6R6vxryCxTDSkb',
    '0nEa5tLx9GSQTokPZOnvxEMiS',
    'X5C8fYru7eMFBQeKowVI4RHAv',
    'jCxQDOz3mqvnk5qMSSYQyaQGD'
)

$resultado = @()
foreach ($bId in $bitolasCorrigidas) {
    $uriB = $url + '/rest/v1/pedido_bitolas?id=eq.' + $bId + '&select=*'
    $b = Invoke-RestMethod -Uri $uriB -Headers $headers
    if ($b.Count -gt 0) {
        $bit = $b[0]
        $uriP = $url + '/rest/v1/pedidos?id=eq.' + $bit.pedido_id + '&select=*'
        $ped = Invoke-RestMethod -Uri $uriP -Headers $headers
        $p = if ($ped.Count -gt 0) { $ped[0] } else { $null }
        
        $bitNome = if ($bit.bitola_raw -and $bit.bitola_raw.nome) { $bit.bitola_raw.nome } else { $bit.bitola_raw.descricao }
        $cliNome = if ($p.cliente_raw -and $p.cliente_raw.nome) { $p.cliente_raw.nome } else { "-" }

        $resultado += [PSCustomObject]@{
            Pedido      = $p.localizador
            Cliente     = $cliNome
            Bitola      = $bitNome
            PesoKg      = $bit.quantidade
            StatusFinal = $bit.status
        }
    }
}

$resultado | Format-Table -AutoSize
